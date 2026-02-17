# Root Cause Investigation Report - find-bar-focus

## Executive Summary
- **Problem**: Cmd+F opens the find bar but the text field does not receive keyboard focus, requiring a manual click before the user can type or dismiss with Escape
- **Root Cause**: The `FindBarView` relies on `.onChange(of: findState.isVisible)` to set `@FocusState`, but `onChange` does not fire on the initial appearance of a view -- only on subsequent changes. Since the `FindBarView` is conditionally rendered (`if findState.isVisible`), it is created fresh each time with `isVisible` already `true`, meaning `onChange` never sees the transition from `false` to `true`.
- **Solution**: Add `.onAppear { isInputFocused = true }` to `FindBarView`, or set focus with a small `DispatchQueue.main.async` / `Task` delay in `onAppear` to ensure the view hierarchy is fully installed before focus is requested
- **Urgency**: High -- this breaks the entire keyboard-driven find workflow (Cmd+F, type query, Escape to dismiss)

## Investigation Process
- **Hypotheses Tested**: 3
- **Key Evidence**: 2 critical findings in code analysis

### Hypothesis 1: `onChange` Does Not Fire on Initial View Creation
**Status**: CONFIRMED -- this is the root cause

**Analysis**:

In `ContentView.swift` (line 45-53), the `FindBarView` is conditionally rendered:

```swift
if findState.isVisible {
    FindBarView()
        .transition(...)
}
```

In `FindBarView.swift` (lines 57-61), focus is set via:

```swift
.onChange(of: findState.isVisible) { _, isVisible in
    if isVisible {
        isInputFocused = true
    }
}
```

The sequence when the user presses Cmd+F:

1. `MkdnCommands` calls `findState?.show()` (line 63 of MkdnCommands.swift)
2. `FindState.show()` sets `isVisible = true` (line 53 of FindState.swift)
3. SwiftUI evaluates the `if findState.isVisible` condition in `ContentView.body` -- it is now `true`
4. SwiftUI creates a **new** `FindBarView` instance
5. The new `FindBarView` is inserted into the view hierarchy
6. The `.onChange(of: findState.isVisible)` handler is registered

The critical issue: at step 6, `findState.isVisible` is already `true`. The `onChange` modifier only fires when the observed value **changes** after the modifier is attached. Since `isVisible` was `true` before `FindBarView` was ever created, and remains `true` after creation, the `onChange` closure **never fires**.

**Evidence**: SwiftUI documentation states that `onChange(of:)` "calls the action closure when the value changes" -- it does not call it with the initial value. This is distinct from `.onReceive` or `.task(id:)`, which do fire on initial appearance.

The `FindBarView` has no `.onAppear` modifier at all (verified via grep -- zero matches for `onAppear` in FindBarView.swift).

### Hypothesis 2: Timing Issue Between View Appearance and FocusState
**Status**: PARTIALLY RELEVANT

Even if `.onAppear` were used, there is a known SwiftUI behavior where setting `@FocusState` to `true` in `onAppear` can be unreliable if the view is still being laid out. The recommended pattern is to defer focus assignment slightly using `DispatchQueue.main.async` or `Task { @MainActor in }` to allow the view to fully install in the hierarchy before requesting focus.

However, this is a secondary concern. The primary issue is that focus is never requested at all.

### Hypothesis 3: NSTextView First Responder Conflict
**Status**: NOT THE CAUSE

The `CodeBlockBackgroundTextView` (NSTextView) in the `SelectableTextView` is the window's first responder when the user is viewing content. When the SwiftUI `FindBarView` appears, there could theoretically be a conflict between the NSTextView holding first responder status and SwiftUI's `@FocusState` trying to claim focus for the TextField.

However, this is not the immediate cause. The `@FocusState` is never set to `true` in the first place (Hypothesis 1), so there is no conflict to observe. This may become relevant **after** the primary fix is applied -- if `isInputFocused = true` is set but the NSTextView still holds first responder, the SwiftUI TextField may not receive actual keyboard focus.

When the find bar is dismissed, the Coordinator already handles returning focus to the NSTextView (line 257 of SelectableTextView.swift):
```swift
textView.window?.makeFirstResponder(textView)
```

This confirms the team is aware of the NSTextView/SwiftUI focus interplay.

## Root Cause Analysis

### Technical Details

**File**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/FindBarView.swift`, lines 57-61
**File**: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`, lines 45-53

The `FindBarView` is conditionally rendered -- it only exists in the view hierarchy when `findState.isVisible` is `true`. The `.onChange(of: findState.isVisible)` modifier that sets `isInputFocused = true` is attached to the `FindBarView` itself. Since the view is only created when `isVisible` is already `true`, the `onChange` never observes a transition and never fires.

### Causation Chain

```
Root Cause: FindBarView uses .onChange(of: isVisible) to set @FocusState
    |
    +-> FindBarView is conditionally rendered (if findState.isVisible)
    |     |
    |     +-> View is only created when isVisible is already true
    |     |
    |     +-> .onChange never observes a value change (true -> true is not a change)
    |
    +-> isInputFocused is never set to true
    |     |
    |     +-> TextField does not receive keyboard focus
    |     |
    |     +-> User cannot type in search field without clicking
    |     |
    |     +-> .onKeyPress(.escape) on TextField requires focus, so Escape does not work
    |
    +-> Symptom: Find bar appears but is non-functional until user clicks TextField
```

### Why It Occurred

The `.onChange(of:)` modifier is a common SwiftUI foot-gun. It is frequently mistaken for "run this when this value is this particular value" rather than "run this when this value transitions." When the `FindBarView` was inside an always-present container (not conditionally rendered), `.onChange` would have correctly fired when `isVisible` transitioned from `false` to `true`. The conditional rendering (`if findState.isVisible`) changed the lifetime semantics of the view, breaking the `onChange` contract.

## Proposed Solutions

### 1. Recommended: Add `.onAppear` with Deferred Focus

**Effort**: 5 minutes

Replace the `onChange` focus logic (or supplement it) with an `onAppear` that sets focus with a slight deferral:

```swift
.onAppear {
    // Defer to next run loop to ensure view is fully installed
    DispatchQueue.main.async {
        isInputFocused = true
    }
}
```

The `onChange` can be kept for the case where the `FindBarView` is NOT conditionally rendered (defensive programming), or removed entirely since the conditional rendering guarantees `isVisible` is always `true` when the view exists.

**Risk**: Very low. Isolated to find bar focus behavior.

**Pros**: Simple, direct fix. Addresses the root cause.

**Cons**: The `DispatchQueue.main.async` deferral is a workaround for a SwiftUI layout timing behavior. If Apple changes this behavior, the deferral may become unnecessary (but harmless).

### 2. Alternative: Move Focus Logic to ContentView

**Effort**: 10 minutes

Instead of having `FindBarView` manage its own focus, have `ContentView` manage a `@FocusState` that is bound to the TextField inside `FindBarView` via a Binding:

```swift
// ContentView
@FocusState private var findBarFocused: Bool

// In body:
if findState.isVisible {
    FindBarView(isFocused: $findBarFocused)
}
.onChange(of: findState.isVisible) { _, isVisible in
    if isVisible {
        findBarFocused = true
    }
}
```

Here, the `.onChange` is on `ContentView` which is always present, so it correctly observes the `false -> true` transition.

**Risk**: Low. Requires minor API change to FindBarView.

**Pros**: Architecturally cleaner -- the parent controls focus lifecycle.

**Cons**: Slightly more refactoring; couples ContentView to FindBarView's focus model.

### 3. Alternative: Use `.task(id:)` Instead of `.onChange`

**Effort**: 5 minutes

Replace `.onChange(of: findState.isVisible)` with `.task(id: findState.isVisible)`:

```swift
.task(id: findState.isVisible) {
    if findState.isVisible {
        isInputFocused = true
    }
}
```

`.task(id:)` fires both on initial appearance AND on value changes, which would correctly trigger focus on first creation.

**Risk**: Low.

**Pros**: Minimal change, leverages SwiftUI's own mechanism.

**Cons**: `.task(id:)` is async and may have the same timing issue as `onAppear` without deferral. May need a small `try? await Task.sleep(for: .milliseconds(50))` before setting focus.

## Prevention Measures

1. **SwiftUI `onChange` awareness**: When using `.onChange(of:)` inside conditionally rendered views, always consider whether the view will be created with the observed value already in its "target" state. If so, use `.onAppear` or `.task(id:)` instead.

2. **Focus testing**: Add a manual or automated test that verifies keyboard focus after Cmd+F: press Cmd+F, immediately type a character, and verify it appears in the search field.

3. **Code review checklist**: For any `@FocusState` usage, verify that the trigger mechanism works with the view's lifecycle (conditional rendering vs. always-present).

## Evidence Appendix

### E1: FindBarView onChange Handler (Never Fires)

File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/FindBarView.swift`, lines 57-61:
```swift
.onChange(of: findState.isVisible) { _, isVisible in
    if isVisible {
        isInputFocused = true
    }
}
```

### E2: Conditional Rendering in ContentView

File: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`, lines 45-53:
```swift
if findState.isVisible {
    FindBarView()
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .opacity
            )
        )
}
```

### E3: FindState.show() Sets isVisible Before View Creation

File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/ViewModels/FindState.swift`, lines 52-54:
```swift
public func show() {
    isVisible = true
}
```

### E4: MkdnCommands Cmd+F Handler

File: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`, lines 60-65:
```swift
Button("Find...") {
    withAnimation(motionAnimation(.springSettle)) {
        findState?.show()
    }
}
.keyboardShortcut("f", modifiers: .command)
```

### E5: No onAppear in FindBarView

Confirmed via grep: zero matches for `onAppear` in FindBarView.swift. The view has no initialization-time focus request.

### E6: FocusState Declaration

File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/FindBarView.swift`, line 28:
```swift
@FocusState private var isInputFocused: Bool
```

Line 69 (binding to TextField):
```swift
.focused($isInputFocused)
```

The `@FocusState` is correctly declared and bound to the TextField. The only issue is that it is never set to `true`.
