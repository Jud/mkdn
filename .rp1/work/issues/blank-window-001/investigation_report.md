# Root Cause Investigation Report - blank-window-001

## Executive Summary
- **Problem**: After integrating SelectableTextView (NSTextView with TextKit 2), the app shows a completely blank dark teal/navy window with no markdown content visible
- **Root Cause**: The `Coordinator` replaces `NSTextView`'s internal `NSTextViewportLayoutControllerDelegate`, hijacking the fragment rendering pipeline so text layout fragments are never configured for display
- **Solution**: Remove the custom viewport delegate and use a different mechanism to hook into fragment lifecycle (e.g., `NSTextLayoutManager` delegate, layout observation notifications, or subclassing `NSTextLayoutFragment`)
- **Urgency**: Blocking -- the feature is completely non-functional

## Investigation Process
- **Duration**: Systematic code analysis + debug log review
- **Hypotheses Tested**:
  1. `.task(id:)` not firing on initial launch -- **REJECTED** (debug log confirms task fires with 9613 chars)
  2. Empty attributed string / no blocks rendered -- **REJECTED** (debug log confirms 81-82 blocks rendered)
  3. EntranceAnimator cover layers permanently hiding content -- **REJECTED** (cover layer animation logic is correct; `scheduleCleanup` removes them)
  4. NSTextView sizing/layout failure within SwiftUI -- **REJECTED** (scroll view setup is standard)
  5. Foreground colors matching background -- **REJECTED** (Solarized palette has distinct foreground/background)
  6. **NSTextViewportLayoutControllerDelegate replacement breaking NSTextView internal rendering -- CONFIRMED**
- **Key Evidence**:
  1. Debug log proves content pipeline works: blocks rendered, attributed string built, task fires correctly
  2. The code at `SelectableTextView.swift:128` replaces the viewport layout controller's delegate with a custom `Coordinator`
  3. The `Coordinator`'s `textViewportLayoutController(_:configureRenderingSurfaceFor:)` method only calls `animator.animateFragment(fragment)` -- it does NOT perform any fragment rendering configuration

## Root Cause Analysis

### Technical Details

**File**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`
**Lines**: 123-129 (`installViewportDelegate`) and 155-181 (`Coordinator`)

The code at line 128:
```swift
textView.textLayoutManager?
    .textViewportLayoutController.delegate = coordinator
```

replaces the `NSTextViewportLayoutController`'s delegate with the custom `Coordinator` object. In TextKit 2 architecture, `NSTextView` is (internally) its own viewport layout controller delegate. It relies on the `textViewportLayoutController(_:configureRenderingSurfaceFor:)` callback to configure each `NSTextLayoutFragment` for rendering -- setting up sublayers or subviews that display the actual glyph/character content.

The replacement `Coordinator` implements this callback as:
```swift
func textViewportLayoutController(
    _: NSTextViewportLayoutController,
    configureRenderingSurfaceFor fragment: NSTextLayoutFragment
) {
    animator.animateFragment(fragment)
}
```

`animateFragment` does only two things:
1. Tracks the fragment ID in a set (to avoid re-animating)
2. When `isAnimating` is true, creates a background-colored cover layer over the fragment

Critically, it does **not** perform whatever configuration `NSTextView` would normally do in this callback. The internal `NSTextView` rendering pipeline -- which attaches fragment rendering surfaces to the text view's layer hierarchy -- is completely bypassed.

Additionally, the `Coordinator` does not implement:
- `textViewportLayoutControllerWillLayout(_:)` -- called before layout, where `NSTextView` may prepare rendering surfaces
- `textViewportLayoutControllerDidLayout(_:)` -- called after layout, where `NSTextView` may finalize rendering

### Causation Chain

```
Custom Coordinator set as NSTextViewportLayoutControllerDelegate
  -> NSTextView's internal delegate callbacks intercepted
    -> configureRenderingSurfaceFor: only adds cover layers, skips fragment rendering setup
      -> NSTextLayoutFragment rendering surfaces never attached to view hierarchy
        -> Text content exists in layout manager but is not drawn
          -> User sees only the NSTextView background color (Solarized Dark base03 = #002b36)
            -> Completely blank dark teal/navy window
```

### Why It Occurred

The `EntranceAnimator` design required per-layout-fragment hooks to apply staggered entrance animations. The `NSTextViewportLayoutControllerDelegate` appeared to be the right API for this, as it provides a `configureRenderingSurfaceFor:` callback that fires for each visible fragment. However, for `NSTextView` (as opposed to building a custom text rendering view from scratch using `NSTextLayoutManager` directly), this delegate is an internal rendering mechanism, not an observation hook. Replacing it breaks `NSTextView`'s ability to render its own content.

### Supporting Evidence

1. **Debug log confirms content pipeline is functional**:
   ```
   [PREVIEW] .task fired, content length=9613, isInitial=true
   [PREVIEW] rendered 82 blocks
   [PREVIEW] mermaid blocks: 2
   [PREVIEW] fullReload=true, blocks=81
   ```

2. **Viewport delegate replacement** at `SelectableTextView.swift:128`:
   ```swift
   textView.textLayoutManager?.textViewportLayoutController.delegate = coordinator
   ```

3. **Coordinator does not forward to NSTextView's rendering**:
   The `configureRenderingSurfaceFor:` implementation at lines 174-179 only calls `animator.animateFragment(fragment)` -- no fragment rendering setup.

4. **All other rendering components verified working**:
   - `MarkdownTextStorageBuilder.build()` produces valid `NSAttributedString` with correct colors/fonts
   - `textView.textStorage?.setAttributedString(attributedText)` is called with non-empty content
   - Theme colors are correctly applied to the text view

## Proposed Solutions

### 1. Recommended: Use NSTextLayoutManagerDelegate Instead

**Approach**: Remove the viewport layout controller delegate entirely. Instead, use `NSTextLayoutManagerDelegate` which provides `textLayoutManager(_:textLayoutFragmentFor:in:)` for fragment customization without hijacking the viewport rendering pipeline. Alternatively, observe layout completion via `NSTextView.didChangeTextNotification` or by subclassing `NSTextLayoutFragment` to add animation behavior in the fragment's own rendering.

**Effort**: Medium (2-4 hours)
**Risk**: Low -- `NSTextLayoutManagerDelegate` is designed for customization without breaking rendering
**Pros**: Clean separation of concerns; does not interfere with `NSTextView`'s internal rendering
**Cons**: Different API shape; may need to rethink when/how cover layers are positioned

### 2. Alternative A: Post-Layout Cover Layer Approach

**Approach**: Remove the viewport delegate entirely. After `setAttributedString`, use `textLayoutManager.enumerateTextLayoutFragments(from:options:)` to iterate visible fragments and create cover layers. Schedule this in a `DispatchQueue.main.async` after content is set to ensure layout has completed.

**Effort**: Low-Medium (1-3 hours)
**Risk**: Low -- no delegate replacement, just observation
**Pros**: Simplest fix; cover layer animation logic can remain largely unchanged
**Cons**: Slight delay before animation starts (one run loop cycle); may miss fragments that appear during scrolling

### 3. Alternative B: Remove Per-Fragment Animation

**Approach**: Replace the per-fragment stagger animation with a whole-view animation (e.g., a single cover layer over the entire text view, or a SwiftUI opacity animation on the `SelectableTextView`). This eliminates the need for fragment-level hooks entirely.

**Effort**: Low (1-2 hours)
**Risk**: Very low -- simplest approach
**Pros**: No TextKit 2 internals involved; works reliably
**Cons**: Loses the per-block stagger entrance aesthetic; visually less sophisticated

## Prevention Measures

1. **Document TextKit 2 API boundaries**: `NSTextViewportLayoutControllerDelegate` is an internal rendering mechanism for `NSTextView`, not an observation hook. Add this to the project's patterns.md.
2. **Test NSViewRepresentable views in isolation**: Create a minimal test harness that verifies text actually renders before integrating with the full app.
3. **Add rendering verification**: A debug-mode check that verifies `textView.attributedString().length > 0` and visible fragments exist after content update.

## Evidence Appendix

### Debug Log Excerpts (most recent launch)
```
[2026-02-08 13:33:36 +0000] [PREVIEW] .task fired, content length=9221, isInitial=true
[2026-02-08 13:33:36 +0000] [PREVIEW] rendered 81 blocks
[2026-02-08 13:33:36 +0000] [PREVIEW] mermaid blocks: 2
[2026-02-08 13:33:36 +0000] [PREVIEW] fullReload=true, blocks=81
```

### Key Code Locations
- Delegate replacement: `SelectableTextView.swift:123-129` (`installViewportDelegate`)
- Coordinator delegate impl: `SelectableTextView.swift:155-181`
- EntranceAnimator fragment hook: `EntranceAnimator.swift:89-111`
- Cover layer creation: `EntranceAnimator.swift:115-128`
- Cover layer animation: `EntranceAnimator.swift:130-144`
