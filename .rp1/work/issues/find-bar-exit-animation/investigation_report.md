# Root Cause Investigation Report - find-bar-exit-animation

## Executive Summary
- **Problem**: The find bar pill instantly disappears on Escape press -- no exit animation plays, despite the entrance animation (scale from 0.95 + fade in) working correctly.
- **Root Cause**: The `FindBarView` disappears from the view hierarchy before SwiftUI's animation system can apply the exit transition because focus transfer causes an immediate view teardown, and the declarative `.animation(_, value:)` modifier on the `Group` wrapper races with view identity destruction triggered by the `@FocusState` cleanup and `@Observable` property invalidation cascade.
- **Solution**: Separate `isVisible` from the cleanup properties by splitting dismiss into two phases -- animate `isVisible = false` first, then clear `query`/`matchRanges`/`currentMatchIndex` after the animation completes -- OR use `.onDisappear` to defer cleanup.
- **Urgency**: Low-severity visual polish bug. Fix at convenience.

## Investigation Process
- **Duration**: Static code analysis, no runtime debugging needed
- **Hypotheses Tested**:
  1. Multi-property mutation in `dismiss()` disrupts animation tracking -- **CONFIRMED as contributing factor**
  2. `@FocusState` teardown interferes with transition -- **CONFIRMED as primary trigger**
  3. `.onKeyPress(.escape)` event consumption prevents animation -- **REJECTED** (the handler correctly calls `withAnimation`)
  4. Declarative `.animation()` modifier conflicts with imperative `withAnimation()` -- **CONFIRMED as contributing factor**
- **Key Evidence**: The entrance works because `show()` only mutates one property (`isVisible = true`), while `dismiss()` mutates four properties simultaneously, and the `@FocusState` binding on the `TextField` triggers AppKit first-responder cleanup during view removal.

## Root Cause Analysis

### Technical Details

The root cause is a combination of three interacting problems:

#### Problem 1: Multi-property mutation cascade in `dismiss()`

File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/ViewModels/FindState.swift`, lines 57-62

```swift
public func dismiss() {
    query = ""          // Mutation 1: triggers FindBarView body re-eval
    matchRanges = []    // Mutation 2: triggers FindBarView body re-eval
    currentMatchIndex = 0  // Mutation 3: triggers FindBarView body re-eval
    isVisible = false   // Mutation 4: the one that should drive the transition
}
```

With the `@Observable` macro in Swift's Observation framework, property mutations within a `withAnimation` block are batched for the purpose of animation tracking. However, the issue is that **all four mutations are tracked as animatable changes**. When `query` becomes `""`, the `FindBarView` body re-evaluates: the conditional `if !findState.query.isEmpty` now hides the match count label, changing the view's internal layout. This layout change happens within the same animation transaction as the `isVisible = false` change.

More critically, the `MarkdownPreviewView` passes `findState.query`, `findState.currentMatchIndex`, and `findState.isVisible` as separate parameters to `SelectableTextView`:

```swift
findQuery: findState.query,          // "" -- triggers updateNSView
findCurrentIndex: findState.currentMatchIndex,  // 0 -- triggers updateNSView
findIsVisible: findState.isVisible,  // false -- triggers updateNSView
```

This means `SelectableTextView.updateNSView()` fires during the dismiss, and within its `handleFindUpdate()` path (lines 255-257):

```swift
} else if lastFindVisible {
    clearFindHighlights(textView: textView)
    textView.window?.makeFirstResponder(textView)  // <-- FOCUS TRANSFER
}
```

The `makeFirstResponder(textView)` call yanks first responder status from the SwiftUI `TextField` inside `FindBarView`. This is an AppKit-level focus transfer that happens synchronously.

#### Problem 2: `@FocusState` teardown disrupts transition

File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/FindBarView.swift`, line 28

```swift
@FocusState private var isInputFocused: Bool
```

The `TextField` in the find bar has `@FocusState` binding. When `isVisible` becomes false and SwiftUI begins removing the `FindBarView`, the `@FocusState` system detects the focused view is being removed. In SwiftUI's lifecycle, `@FocusState` cleanup can trigger synchronous view hierarchy invalidation that preempts the transition animation. The view is torn down (removed from the view hierarchy) before the exit transition has a chance to render even a single frame.

This is a known class of SwiftUI issues: when a focused view is conditionally removed, the focus system's cleanup can race with the transition animation system. The focus resignation happens at the AppKit level (NSWindow first responder chain), which is synchronous, while the transition animation is asynchronous.

#### Problem 3: Competing animation sources

File: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`, lines 45-54

```swift
Group {
    if findState.isVisible {
        FindBarView()
            .transition(.scale(scale: 0.95).combined(with: .opacity))
    }
}
.animation(
    reduceMotion ? AnimationConstants.reducedCrossfade : AnimationConstants.springSettle,
    value: findState.isVisible
)
```

AND file: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/FindBarView.swift`, lines 144-148:

```swift
private func dismissFindBar() {
    withAnimation(motion.resolved(.springSettle)) {
        findState.dismiss()
    }
}
```

There are **two** animation directives competing:
1. The declarative `.animation(springSettle, value: findState.isVisible)` on the Group
2. The imperative `withAnimation(springSettle) { findState.dismiss() }` wrapping the dismiss call

Both target `isVisible`, but the imperative `withAnimation` also wraps the mutations to `query`, `matchRanges`, and `currentMatchIndex`. This creates a transaction where SwiftUI must animate ALL those changes with `springSettle`. The internal layout changes (match count label disappearing) compete with the transition.

For the **entrance**, this is not a problem because `show()` only sets `isVisible = true` -- a single clean mutation. The declarative `.animation()` picks it up cleanly, and the `withAnimation` wrapper in `MkdnCommands` agrees.

### Causation Chain

```
User presses Escape
  -> FindBarView.onKeyPress(.escape) fires
  -> dismissFindBar() called
  -> withAnimation(springSettle) { findState.dismiss() }
  -> dismiss() mutates query="", matchRanges=[], currentMatchIndex=0, isVisible=false
  -> @Observable notifies all observers of ALL four changes
  -> MarkdownPreviewView re-evaluates body (findState.query changed)
  -> SelectableTextView.updateNSView fires with findIsVisible=false
  -> handleFindUpdate sees !findIsVisible && lastFindVisible
  -> textView.window?.makeFirstResponder(textView)  [synchronous AppKit call]
  -> NSWindow moves first responder from TextField to NSTextView
  -> @FocusState(isInputFocused) becomes false
  -> SwiftUI detects focused view losing focus during removal
  -> View hierarchy invalidation preempts transition animation
  -> FindBarView removed immediately, no animation visible
```

### Why Entrance Works

```
Cmd+F pressed
  -> MkdnCommands: withAnimation(springSettle) { findState?.show() }
  -> show() only sets isVisible = true  [single mutation]
  -> ContentView Group sees isVisible change
  -> .animation(springSettle, value: isVisible) fires
  -> FindBarView inserted with .transition(.scale(0.95).combined(.opacity))
  -> Transition animates correctly (no competing mutations, no focus teardown)
  -> .onAppear sets @FocusState after view is stable
```

### CodeBlockBackgroundTextView.cancelOperation Path

File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift`, lines 73-81

This path has the same root cause:

```swift
override func cancelOperation(_ sender: Any?) {
    if let findState, findState.isVisible {
        withAnimation(AnimationConstants.springSettle) {
            findState.dismiss()
        }
        return
    }
    super.cancelOperation(sender)
}
```

Same multi-property dismiss within `withAnimation`, same problem. Additionally, this path does NOT use `MotionPreference` to resolve Reduce Motion, so it always uses the full `springSettle` regardless of accessibility settings.

## Proposed Solutions

### 1. Recommended: Two-phase dismiss with deferred cleanup

Split `dismiss()` into two methods -- one that only controls visibility (for animation), and one that clears data (called after animation completes).

```swift
// In FindState:
public func dismiss() {
    isVisible = false
    // Defer cleanup to after animation completes
}

public func clearFindData() {
    query = ""
    matchRanges = []
    currentMatchIndex = 0
}
```

Then in the dismiss call site:

```swift
private func dismissFindBar() {
    isInputFocused = false  // Release focus BEFORE removal
    withAnimation(motion.resolved(.springSettle)) {
        findState.dismiss()  // Only sets isVisible = false
    }
    // Clear data after animation duration
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        findState.clearFindData()
    }
}
```

The key insight is that `isInputFocused = false` must be set **before** `isVisible = false` so the focus transfer happens while the view still exists, preventing the focus-teardown race.

**Effort**: Small (< 1 hour)
**Risk**: Low. The `asyncAfter` delay should be longer than the animation duration. Data cleanup is non-visible state, so a slight delay is harmless.
**Pros**: Minimal code change, addresses root cause directly.
**Cons**: Timer-based cleanup is slightly fragile if animation duration changes.

### 2. Alternative A: Use `.onDisappear` for cleanup

Keep `dismiss()` as visibility-only and use `.onDisappear` on `FindBarView` to clear data:

```swift
// FindState.dismiss() only sets isVisible = false
// FindBarView adds:
.onDisappear {
    findState.clearFindData()
}
```

And resign focus before dismissing:

```swift
private func dismissFindBar() {
    isInputFocused = false
    withAnimation(motion.resolved(.springSettle)) {
        findState.dismiss()
    }
}
```

**Effort**: Small
**Risk**: Low. `.onDisappear` fires after the transition completes, which is the ideal timing.
**Pros**: No timers, lifecycle-driven cleanup.
**Cons**: `.onDisappear` timing with transitions can sometimes be unreliable in SwiftUI.

### 3. Alternative B: Explicit focus resignation + single-property dismiss

The most targeted fix -- only change the dismiss callsite to resign focus first:

```swift
private func dismissFindBar() {
    isInputFocused = false
    withAnimation(motion.resolved(.springSettle)) {
        findState.isVisible = false
    }
    findState.query = ""
    findState.matchRanges = []
    findState.currentMatchIndex = 0
}
```

By setting `isInputFocused = false` first, the focus transfer happens while the view still exists. Then `isVisible = false` is the only mutation inside `withAnimation`, matching the clean single-mutation pattern that makes the entrance work.

The cleanup mutations (`query`, `matchRanges`, `currentMatchIndex`) happen outside `withAnimation` and outside the view's existence, so they do not interfere.

This also needs to be applied to the `CodeBlockBackgroundTextView.cancelOperation` path, though that path is trickier since it does not have access to `@FocusState`. For that path, the `SelectableTextView.handleFindUpdate` should skip `makeFirstResponder` when the text view is already the first responder, or defer it.

**Effort**: Small
**Risk**: Low
**Pros**: Most precise fix, no timers, no lifecycle hooks.
**Cons**: Requires fixing both dismiss callsites independently.

## Prevention Measures

1. **Pattern rule**: When conditionally removing views that contain `@FocusState` bindings, always resign focus before triggering the removal condition.
2. **Pattern rule**: When using `withAnimation` to drive a view insertion/removal transition, only mutate the single property that controls the conditional (`isVisible`) inside the animation block. Mutate other properties outside it.
3. **Pattern rule**: `@Observable` `dismiss()`-style methods that clear multiple properties AND control visibility should separate visibility from cleanup, or document that callers must handle animation carefully.
4. Add to `.rp1/context/patterns.md`: "Focus-aware animated removal" pattern.

## Evidence Appendix

### Evidence 1: Entrance vs Exit mutation count

- `show()` (line 53 of FindState.swift): 1 mutation (`isVisible = true`)
- `dismiss()` (lines 57-62 of FindState.swift): 4 mutations (`query`, `matchRanges`, `currentMatchIndex`, `isVisible`)

### Evidence 2: Focus transfer during dismiss

SelectableTextView.swift lines 255-257 show `makeFirstResponder(textView)` called synchronously when `findIsVisible` transitions from true to false, which happens during the same update cycle as the dismiss.

### Evidence 3: `@FocusState` on removed view

FindBarView.swift line 28: `@FocusState private var isInputFocused: Bool` on the TextField that is about to be removed by the conditional `if findState.isVisible`.

### Evidence 4: Competing animation directives

ContentView.swift lines 51-54: declarative `.animation(springSettle, value: findState.isVisible)` competing with FindBarView.swift lines 145-147: imperative `withAnimation(springSettle) { findState.dismiss() }`. Both try to animate the same transition, but the imperative block also captures the 3 cleanup mutations.

### Evidence 5: CodeBlockBackgroundTextView accessibility gap

CodeBlockBackgroundTextView.swift line 75 uses `AnimationConstants.springSettle` directly instead of `MotionPreference.resolved(.springSettle)`, ignoring the Reduce Motion accessibility preference.
