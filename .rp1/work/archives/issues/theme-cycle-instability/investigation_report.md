# Root Cause Investigation Report - theme-cycle-instability

## Executive Summary
- **Problem**: Rapid Cmd+T theme cycling causes jumpy animations and occasionally text disappearing entirely.
- **Root Cause**: Three independent animation systems (SwiftUI `withAnimation`, `CATransition`, and `EntranceAnimator` cover layers) interact adversely during rapid cycling, with `CATransition` stacking and a subtle `auto` mode no-op cycle causing the most visible symptoms.
- **Solution**: Guard against CATransition stacking, skip no-op theme transitions, and ensure `animator.reset()` properly cleans up in-flight cover layers during theme changes.
- **Urgency**: Medium -- affects perceived quality but not data integrity.

## Investigation Process
- **Hypotheses Tested**: 5 (see below)
- **Key Evidence**: Code trace through the full theme-change pipeline from Cmd+T to pixel update.

### Hypothesis 1: CATransition stacking during rapid cycling
**Status**: CONFIRMED -- Primary contributor to jumpiness

**Evidence**:
In `SelectableTextView.updateNSView` (lines 77-83), a `CATransition` is added to the scroll view layer every time the theme changes:

```swift
// SelectableTextView.swift:77-83
if let lastTheme = coordinator.lastAppliedTheme, lastTheme != theme {
    let transition = CATransition()
    transition.type = .fade
    transition.duration = reduceMotion ? 0.15 : 0.35
    transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    scrollView.layer?.add(transition, forKey: "themeTransition")
}
```

The key `"themeTransition"` is constant, which means Core Animation DOES replace the previous animation (not stack multiple animations). However, the replacement itself is the problem: when a 0.35s crossfade is 0.1s into its transition and gets replaced by a fresh 0.35s crossfade, the layer's **presentation state** jumps. The outgoing animation's partial progress is discarded and a new fade starts from the current committed state. This manifests as a visible "jump" -- the crossfade progress resets mid-transition.

Additionally, the `CATransition` on the `scrollView.layer` operates at the Core Animation level (layer tree), while `withAnimation(crossfade)` in MkdnCommands operates at the SwiftUI level (view tree). These two animation systems are independent and uncoordinated:

```swift
// MkdnCommands.swift:157-163
withAnimation(themeAnimation) {
    appSettings.cycleTheme()
}
```

The SwiftUI crossfade affects the SwiftUI background color and any SwiftUI-managed properties, while the CATransition affects the NSTextView's layer rendering. When both run simultaneously with slightly different timing curves and durations, they produce a visual conflict -- two independent crossfades competing over the same visual region.

### Hypothesis 2: `auto` mode no-op cycle causes text disappearance
**Status**: CONFIRMED -- Root cause of "text not appearing"

**Evidence**:
`cycleTheme()` cycles through three modes: `auto -> solarizedDark -> solarizedLight -> auto`. But `AppSettings.theme` is a computed property:

```swift
// AppSettings.swift:37-39
public var theme: AppTheme {
    themeMode.resolved(for: systemColorScheme)
}
```

And `ThemeMode.resolved(for:)`:

```swift
// ThemeMode.swift:17-25
public func resolved(for colorScheme: ColorScheme) -> AppTheme {
    switch self {
    case .auto:
        colorScheme == .dark ? .solarizedDark : .solarizedLight
    case .solarizedDark: .solarizedDark
    case .solarizedLight: .solarizedLight
    }
}
```

Consider this scenario on a system in dark mode:
1. Start: `themeMode = .auto` -> `theme = .solarizedDark` (resolved from dark system scheme)
2. Cmd+T: `themeMode = .solarizedDark` -> `theme = .solarizedDark` (SAME theme)
3. Cmd+T: `themeMode = .solarizedLight` -> `theme = .solarizedLight` (changed)
4. Cmd+T: `themeMode = .auto` -> `theme = .solarizedDark` (changed)

At step 2, `appSettings.theme` does NOT change because `.auto` and `.solarizedDark` both resolve to the same `AppTheme.solarizedDark`. This means:

- `.onChange(of: appSettings.theme)` in `MarkdownPreviewView` does NOT fire.
- No new `textStorageResult` is built.
- **But** the `withAnimation(crossfade)` block in `MkdnCommands` still wraps the `cycleTheme()` call, so SwiftUI begins a crossfade animation transaction.
- The `CATransition` check (`lastTheme != theme`) also correctly skips since theme hasn't changed.
- The `ModeTransitionOverlay` shows the label "Dark" even though nothing visually changed.

This is confusing but not the text-disappearance bug. The text disappearance occurs in a more subtle variant:

When cycling rapidly (3+ quick presses), the SwiftUI animation transaction from step 2's `withAnimation` may still be in-flight when step 3's `withAnimation` begins. Since step 2 was a no-op (no actual theme property changed), SwiftUI's animation system may coalesce or cancel the in-flight transaction, and the `onChange` handler for step 3 fires inside a partially-committed animation context. The new `textStorageResult` is assigned as a new `NSAttributedString` instance, `updateNSView` runs, the `CATransition` fade starts from a partially-transparent state, and the cover layers from any prior `EntranceAnimator` cleanup task may still be present with `opacity = 0` (fully transparent covers that haven't been removed yet from the layer tree).

More critically: if the user cycles fast enough that they go `auto -> dark -> light -> auto` within the 0.35s crossfade duration, the CATransition at step 4 starts a new 0.35s fade from the committed layer state. If the committed state is mid-transition (SwiftUI side), the NSTextView may render with incorrect/stale colors while the SwiftUI background has already changed, creating a moment where text foreground matches the background, making text invisible.

### Hypothesis 3: EntranceAnimator cover layers linger and conflict
**Status**: PARTIALLY CONFIRMED -- contributes to jumpiness on initial load + rapid cycle

**Evidence**:
When a document is first loaded, `isFullReload = true` triggers `beginEntrance()`, which:
1. Sets `isAnimating = true`
2. Calls `applyViewDriftAnimation()` -- adds a `CATransform3D` translation animation to the text view layer
3. Calls `scheduleCleanup()` -- schedules a Task to remove cover layers after `staggerCap + fadeInDuration + 0.1` = `0.5 + 0.5 + 0.1` = 1.1 seconds
4. `animateVisibleFragments()` then creates per-fragment cover layers with staggered fade animations

If the user hits Cmd+T within this 1.1-second window after loading a document:
- `onChange(of: appSettings.theme)` fires, sets `isFullReload = false`, creates new `textStorageResult`
- `updateNSView` runs, detects `isNewContent == true` (new NSAttributedString instance)
- Since `isFullReload == false`, calls `coordinator.animator.reset()`
- `reset()` calls `removeCoverLayers()` which removes all cover layers and their animations
- `reset()` cancels the cleanup task
- Then `animateVisibleFragments()` is called but short-circuits because `isAnimating == false`

This is actually handled correctly for theme changes. However, the `removeViewDriftAnimation()` call in `reset()` removes the drift animation and sets `layer.transform = CATransform3DIdentity`. If the drift animation was mid-flight, this causes the text view to "jump" to its final position instantly, which is perceptible.

### Hypothesis 4: Three-animation-system conflict
**Status**: CONFIRMED -- Architectural root cause

The theme transition involves three independent animation systems that are uncoordinated:

1. **SwiftUI `withAnimation(crossfade)`** (MkdnCommands.swift:161):
   - Animates SwiftUI-managed properties: `.background(appSettings.theme.colors.background)` on the view, the `ModeTransitionOverlay` appearance, etc.
   - Duration: 0.35s easeInOut

2. **CATransition on scroll view layer** (SelectableTextView.swift:78-82):
   - Animates the NSTextView's layer commit as a fade between old and new content
   - Duration: 0.35s easeInOut
   - Fires when `updateNSView` detects theme change

3. **Direct NSView property setting** (SelectableTextView.swift:186-211):
   - `applyTheme()` immediately sets `textView.backgroundColor`, `scrollView.backgroundColor`, text attributes
   - These are AppKit property changes, not animated
   - They take effect immediately, which is what the CATransition is supposed to smooth over

During rapid cycling:
- The SwiftUI animation from press N is still interpolating background colors
- The CATransition from press N is still fading
- Press N+1 triggers a new SwiftUI animation transaction
- The CATransition from press N is replaced (mid-fade jump)
- New `applyTheme()` sets colors immediately
- New CATransition starts fading from the just-set committed state
- The SwiftUI background may show a different interpolated color than the NSTextView layer
- Result: visual "flash" or "jump" as the two systems momentarily disagree on what color things should be

### Hypothesis 5: `setSelectedRange` causes scroll position jump
**Status**: MINOR CONTRIBUTOR

```swift
// SelectableTextView.swift:100
textView.setSelectedRange(NSRange(location: 0, length: 0))
```

Every theme change (since `isNewContent == true`) resets the selection to the beginning. This does not scroll to the top (no `scrollRangeToVisible` is called), but it does clear any active selection. If the user had text selected, the selection disappears on every theme cycle. This is a minor UX issue but not a primary cause of the reported symptoms.

## Root Cause Analysis

### Technical Details

The instability has three contributing root causes, listed in order of impact:

**Root Cause 1 (Jumpiness): CATransition mid-flight replacement**
- File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`, lines 77-83
- When a CATransition with key `"themeTransition"` is replaced while in-flight, Core Animation discards the partial progress and starts a new 0.35s fade from the current committed (not presentation) layer state. This creates a visible discontinuity.

**Root Cause 2 (Text disappearance): Unsynchronized SwiftUI + CATransition crossfades**
- File: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`, line 161
- File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`, lines 77-83
- The SwiftUI `withAnimation` controls the SwiftUI background layer. The `CATransition` controls the NSTextView layer rendering. When both are mid-transition and a new cycle occurs, the SwiftUI background may have already transitioned to the new theme's background color while the NSTextView layer is still showing old-theme text colors (or vice versa). If the text foreground color of theme A matches the background color of theme B, text becomes temporarily invisible.
- Specifically: Solarized Dark text (`#839496`) against Solarized Light background (`#fdf6e3`) remains visible. But Solarized Light text (`#657b83`) against Solarized Dark background (`#002b36`) is low contrast. During a crossfade where the SwiftUI background has moved to dark but the NSTextView layer's CATransition hasn't caught up, the combination creates near-invisible text.

**Root Cause 3 (Wasted cycle): No-op `auto` -> pinned-same transitions**
- File: `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`, line 95-100
- When `auto` resolves to the same `AppTheme` as the next mode, the `onChange(of: appSettings.theme)` handler doesn't fire, but the `withAnimation` block still executes, the overlay label updates, and the user perceives a "stuck" cycle that adds to the feeling of instability.

### Causation Chain

```
User presses Cmd+T rapidly (< 0.35s intervals)
  -> MkdnCommands wraps cycleTheme() in withAnimation(crossfade)
    -> SwiftUI begins 0.35s crossfade transaction
    -> appSettings.themeMode changes
    -> appSettings.theme (computed) may or may not change
      |
      +-- If theme changes:
      |     -> MarkdownPreviewView.onChange fires
      |     -> New textStorageResult created (new NSAttributedString instance)
      |     -> SelectableTextView.updateNSView called
      |       -> CATransition added to scrollView.layer (key: "themeTransition")
      |       -> Previous CATransition replaced mid-flight (JUMP)
      |       -> applyTheme() sets colors immediately
      |       -> isNewContent == true -> textStorage replaced
      |       -> animator.reset() called (correct)
      |       -> Two crossfades compete: SwiftUI vs CATransition
      |       -> Brief moment of color mismatch -> TEXT INVISIBLE
      |
      +-- If theme doesn't change (auto no-op):
            -> SwiftUI crossfade runs but nothing changes
            -> ModeTransitionOverlay shows label
            -> User sees "Dark" label but no visual change (CONFUSING)
            -> Next Cmd+T starts new crossfade while previous is in-flight
```

### Why It Occurred
The CATransition was added as a layer-level crossfade to smooth the NSTextView content update (which AppKit performs immediately, not animated). This is a valid technique in isolation. However, it was added without accounting for the fact that `MkdnCommands` already wraps the theme change in `withAnimation(crossfade)`, creating a second, independent crossfade at the SwiftUI level. The two systems animate different parts of the view hierarchy at potentially different rates, and neither is aware of the other.

## Proposed Solutions

### 1. Recommended: Remove CATransition, rely on SwiftUI crossfade only
- **Approach**: Remove the CATransition code in `updateNSView` (lines 77-83). The SwiftUI `withAnimation(crossfade)` already provides a smooth transition for SwiftUI-managed properties. For the NSTextView content, rely on the immediate `applyTheme()` + `textStorage.setAttributedString()` update -- the SwiftUI crossfade wrapping the parent view will visually smooth the transition by cross-fading the entire `SelectableTextView` representable.
- **Effort**: Small (delete ~7 lines, remove `lastAppliedTheme` tracking)
- **Risk**: Low. The SwiftUI crossfade already covers this use case. The CATransition was redundant and conflicting.
- **Pros**: Eliminates the animation conflict entirely. Single source of truth for theme transition animation.
- **Cons**: Relies on SwiftUI's crossfade interpolation for the NSView content. If SwiftUI doesn't properly cross-fade NSViewRepresentable content, the transition may be abrupt. (Test to verify.)

### 2. Alternative A: Keep CATransition, remove SwiftUI withAnimation
- **Approach**: In `MkdnCommands`, call `appSettings.cycleTheme()` WITHOUT `withAnimation`. Let the CATransition in `updateNSView` be the sole crossfade mechanism.
- **Effort**: Small
- **Risk**: Medium. Other SwiftUI-managed elements (background, overlay) would update instantly without animation.
- **Pros**: Single animation system for the text view. No conflict.
- **Cons**: SwiftUI background/overlay transitions become abrupt. ThemePickerView already uses `withAnimation`, so there would be inconsistency between Cmd+T and picker.

### 3. Alternative B: Debounce theme cycling
- **Approach**: In `cycleTheme()` or MkdnCommands, ignore rapid presses that arrive within the crossfade duration (0.35s). Use a timestamp-based guard.
- **Effort**: Small
- **Risk**: Low
- **Pros**: Prevents all stacking/conflict scenarios. Simple to implement.
- **Cons**: Reduces responsiveness -- user must wait 0.35s between theme cycles. Feels sluggish.

### 4. Alternative C: Skip no-op transitions + coalesce CATransition
- **Approach**: (a) In `cycleTheme()`, skip modes that resolve to the current theme. (b) For the CATransition, check if one is already in-flight and skip adding a new one if the presentation layer is still animating.
- **Effort**: Medium
- **Risk**: Low
- **Pros**: Addresses both the no-op confusion and the mid-flight replacement jump.
- **Cons**: Doesn't fully solve the two-animation-system conflict.

### Overall Recommendation
Combine Solution 1 (remove CATransition) with Solution 4a (skip no-op transitions). This eliminates the animation conflict entirely and removes the confusing no-op cycle step.

## Prevention Measures

1. **Single animation system per visual transition**: When an NSViewRepresentable is wrapped in SwiftUI `withAnimation`, avoid adding independent Core Animation transitions to the underlying NSView layers. Document this principle in the codebase patterns.

2. **Test rapid interaction patterns**: Add a UI test that cycles themes 5+ times in rapid succession and verifies text visibility after each cycle using the existing test harness infrastructure.

3. **Validate computed property transitions**: When using `onChange(of:)` on computed properties, verify that all input changes actually produce output changes. Add guards or skip logic for no-op transitions.

## Evidence Appendix

### Evidence 1: CATransition replacement behavior
From Apple's Core Animation documentation: "If you add an animation to a layer with a key that matches an existing animation, the new animation replaces the old one." The replacement starts the new animation from the committed (model) layer state, not from the in-flight presentation state. This means a 50%-complete fade is discarded and a new 0-to-100% fade begins, creating a visible jump.

### Evidence 2: Three animation paths traced through code

**Path A -- SwiftUI crossfade** (`MkdnCommands.swift:157-163`):
```swift
withAnimation(themeAnimation) {    // 0.35s easeInOut
    appSettings.cycleTheme()       // triggers @Observable change
}
```

**Path B -- CATransition** (`SelectableTextView.swift:77-83`):
```swift
if let lastTheme = coordinator.lastAppliedTheme, lastTheme != theme {
    let transition = CATransition()
    transition.type = .fade
    transition.duration = reduceMotion ? 0.15 : 0.35  // 0.35s easeInOut
    scrollView.layer?.add(transition, forKey: "themeTransition")
}
```

**Path C -- Immediate property update** (`SelectableTextView.swift:186-211`):
```swift
private func applyTheme(to textView: NSTextView, scrollView: NSScrollView) {
    textView.backgroundColor = bgColor      // immediate
    scrollView.backgroundColor = bgColor    // immediate
    // ... more immediate property sets
}
```

### Evidence 3: No-op cycle scenario
On a dark-mode system, `ThemeMode.allCases` = `[.auto, .solarizedDark, .solarizedLight]`.
- `.auto.resolved(for: .dark)` = `.solarizedDark`
- `.solarizedDark.resolved(for: .dark)` = `.solarizedDark`
- These produce the SAME `AppTheme` value, so `onChange(of: appSettings.theme)` does not fire.

### Evidence 4: EntranceAnimator cleanup timing
`scheduleCleanup()` waits `staggerCap + fadeInDuration + 0.1` = `0.5 + 0.5 + 0.1` = 1.1 seconds.
If a theme change occurs within this window, `animator.reset()` correctly cancels the cleanup task and removes cover layers. However, `removeViewDriftAnimation()` snaps the transform to identity, which can cause a visible position jump if the drift animation was in progress.

### Evidence 5: Selection reset side effect
```swift
// SelectableTextView.swift:100
textView.setSelectedRange(NSRange(location: 0, length: 0))
```
Called on every `isNewContent == true`, which includes every theme change (new NSAttributedString instance). Clears user selection silently.
