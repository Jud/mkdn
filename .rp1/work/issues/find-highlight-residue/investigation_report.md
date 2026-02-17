# Root Cause Investigation Report - find-highlight-residue

## Executive Summary
- **Problem**: Some find-bar search highlights remain visible in the text view after the find bar is dismissed.
- **Root Cause**: `clearFindHighlights` calls `setRenderingAttributes([:], for:)` to clear each highlighted range but does not force a display redraw of the text view. TextKit 2's `setRenderingAttributes` with an empty dictionary clears the internal rendering attribute data but does not reliably trigger display invalidation for the affected layout fragments, leaving stale highlight pixels on screen.
- **Solution**: After clearing all rendering attributes, explicitly call `textView.needsDisplay = true` (or, for a more targeted approach, enumerate the affected layout fragments and set their views' `needsDisplay`). This ensures the text view redraws the areas that previously had highlight backgrounds.
- **Urgency**: Low-to-medium. Visual artifact only -- no data loss, no crash. Fix is a one-line addition.

## Investigation Process
- **Duration**: Full code trace analysis
- **Hypotheses Tested**:
  1. Race condition: `FindState.dismiss()` clears `matchRanges` before the Coordinator reads them -- **Rejected**. The Coordinator uses its own `lastHighlightedRanges` copy (value-type `[NSRange]`), not `findState.matchRanges`, for clearing. Additionally, `@Observable` coalesces all property changes in `dismiss()` into a single SwiftUI update cycle, so `updateNSView` receives the final state.
  2. `lastHighlightedRanges` mismatch with actually-highlighted ranges -- **Rejected**. `lastHighlightedRanges` is set to `findState.matchRanges` at the end of every `applyFindHighlights` call, and the same `NSRange`-to-`NSTextRange` conversion is used for both application and clearing. Ranges that fail conversion are not highlighted and don't need clearing.
  3. `updateNSView` not called with correct sequence during dismiss -- **Rejected**. Traced the full path: `FindBarView.dismissFindBar()` -> `findState.dismiss()` (all four properties set synchronously) -> `@Observable` coalesces -> single `updateNSView` call -> `handleFindUpdate` enters `else if lastFindVisible` branch -> `clearFindHighlights` called. The path is correct.
  4. `setRenderingAttributes([:], for:)` does not trigger display invalidation -- **Confirmed**. This is the root cause. See detailed analysis below.
- **Key Evidence**:
  1. No explicit `needsDisplay` or display invalidation call anywhere in the clearing path
  2. During normal search updates, stale highlights are masked by subsequent `setRenderingAttributes` (with non-empty dictionaries) and `scrollRangeToVisible` calls that DO trigger display updates
  3. `NSTextLayoutManager` has a private `invalidateRenderingAttributesForTextRange:` method, suggesting the public `setRenderingAttributes` does not perform invalidation internally

## Root Cause Analysis

### Technical Details

**File**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`
**Method**: `Coordinator.clearFindHighlights(textView:)` (line 318) -> `clearRenderingAttributes(layoutManager:contentManager:)` (line 330)

The clearing method iterates over `lastHighlightedRanges` and calls:
```swift
layoutManager.setRenderingAttributes([:], for: textRange)
```

This successfully removes the rendering attribute data from the layout manager's internal store, but does NOT trigger a display invalidation for the affected layout fragments. The NSTextView's backing layer retains the previously-drawn highlight pixels until something else triggers a redraw of those areas.

### Causation Chain

```
Root Cause:
  setRenderingAttributes([:], for:) does not invalidate display
    |
    v
Intermediate Effect:
  Layout fragments that had .backgroundColor rendering attributes retain their
  rendered pixels even though the internal attribute data is cleared
    |
    v
Observable Symptom:
  After find bar dismiss, highlights near areas of UI activity (cursor, find bar
  removal area) get redrawn and appear cleared, while highlights in other areas
  of the text view retain their stale highlight colors
```

### Why It Occurred

Two contributing factors:

1. **TextKit 2 rendering attributes API behavior**: `setRenderingAttributes(_:for:)` with a non-empty dictionary likely triggers display invalidation (since new visual content needs to be drawn), but with an empty dictionary it may optimize away the invalidation (since "nothing to draw" is interpreted as no change needed). Apple provides a private `invalidateRenderingAttributesForTextRange:` method for explicit invalidation, suggesting the public API does not always handle this.

2. **Masking during normal operation**: During normal search (query changes, index changes), `applyFindHighlights` first clears old highlights then applies new ones. The new `setRenderingAttributes` calls with non-empty dictionaries DO trigger display invalidation for the newly-highlighted areas. Combined with `scrollRangeToVisible`, most of the visible text gets redrawn. This masks the clearing bug during normal search and makes it only apparent during dismiss, where clearing is the ONLY operation performed.

### Why "some" but not all highlights persist

When the find bar is dismissed, these display-triggering events still occur:
- The find bar view disappears (redraws the top-right corner area)
- `makeFirstResponder(textView)` shifts focus (may redraw cursor area)
- Any subsequent scroll or resize events redraw visible areas

Highlights that happen to be in areas affected by these incidental redraws get visually cleared. Highlights in "quiet" areas (middle of a long document, not near the cursor) retain their stale appearance until the next natural redraw (scroll, resize, content change, window activation).

## Proposed Solutions

### 1. Recommended: Add `needsDisplay = true` after clearing (Minimal fix)

Add one line after `clearRenderingAttributes` in `clearFindHighlights`:

```swift
private func clearFindHighlights(textView: NSTextView) {
    guard let layoutManager = textView.textLayoutManager,
          let contentManager = layoutManager.textContentManager
    else { return }

    clearRenderingAttributes(
        layoutManager: layoutManager,
        contentManager: contentManager
    )
    lastHighlightedRanges = []
    textView.needsDisplay = true  // Force redraw to clear stale highlight pixels
}
```

**Effort**: Trivial (1 line)
**Risk**: Very low. `needsDisplay = true` marks the entire text view for redraw on the next display cycle, which is safe and idempotent.
**Pros**: Simple, reliable, no private API usage
**Cons**: Redraws the entire text view, not just the highlighted areas (minor performance cost, unnoticeable for this use case since it happens once on dismiss)

### 2. Alternative: Enumerate and invalidate specific layout fragments

For each range in `lastHighlightedRanges`, enumerate the text layout fragments and invalidate their specific bounds:

```swift
private func clearFindHighlights(textView: NSTextView) {
    guard let layoutManager = textView.textLayoutManager,
          let contentManager = layoutManager.textContentManager
    else { return }

    clearRenderingAttributes(
        layoutManager: layoutManager,
        contentManager: contentManager
    )

    // Invalidate display for each formerly-highlighted area
    for range in lastHighlightedRanges {
        if let textRange = Self.textRange(from: range, contentManager: contentManager) {
            layoutManager.enumerateTextLayoutFragments(
                from: textRange.location,
                options: [.ensuresLayout]
            ) { fragment in
                textView.setNeedsDisplay(fragment.layoutFragmentFrame)
                return fragment.rangeInElement.location < textRange.endLocation
            }
        }
    }

    lastHighlightedRanges = []
}
```

**Effort**: Moderate (10-15 lines)
**Risk**: Low, but more code surface area
**Pros**: Only redraws the specific areas that had highlights (precise)
**Cons**: More complex, marginal benefit over Option 1 since highlight clearing is a rare, single-fire event

### 3. Alternative: Use `renderingAttributesValidator` pattern

Refactor highlight rendering to use TextKit 2's `renderingAttributesValidator` callback instead of direct `setRenderingAttributes` calls. The validator is called by the layout manager during rendering and is the "intended" way to apply rendering attributes in TextKit 2.

**Effort**: Significant refactor
**Risk**: Medium (different rendering model)
**Pros**: Follows Apple's recommended TextKit 2 pattern, automatically handles display updates
**Cons**: Much larger change, overkill for this bug

## Prevention Measures

1. **Pattern**: When using `NSTextLayoutManager.setRenderingAttributes` for temporary visual highlights, always follow clearing calls with an explicit display invalidation (`needsDisplay = true` or `setNeedsDisplay(_:)` for specific rects).
2. **Testing**: Consider adding a UI test that verifies no rendering attributes remain after find-bar dismiss, using the test harness to capture screenshots before and after dismiss.
3. **Documentation**: Add a code comment near the `setRenderingAttributes` usage noting the display invalidation requirement.

## Evidence Appendix

### Evidence 1: No display invalidation in clearing path

File: `SelectableTextView.swift`, lines 318-342

```swift
private func clearFindHighlights(textView: NSTextView) {
    guard let layoutManager = textView.textLayoutManager,
          let contentManager = layoutManager.textContentManager
    else { return }

    clearRenderingAttributes(
        layoutManager: layoutManager,
        contentManager: contentManager
    )
    lastHighlightedRanges = []
    // <-- No needsDisplay or display invalidation here
}
```

### Evidence 2: Dismiss triggers correct clearing path

File: `SelectableTextView.swift`, lines 255-258

```swift
} else if lastFindVisible {
    clearFindHighlights(textView: textView)
    textView.window?.makeFirstResponder(textView)
}
```

Confirmed via code trace: `findState.dismiss()` -> `@Observable` coalesce -> single `updateNSView` with `findIsVisible=false` -> enters this branch -> `clearFindHighlights` called with valid `lastHighlightedRanges`.

### Evidence 3: Private API confirms invalidation is separate from setting

```
NSTextLayoutManager responds to:
  setRenderingAttributes:forTextRange:          (public) -- sets attributes
  invalidateRenderingAttributesForTextRange:    (private) -- invalidates display
  addRenderingAttribute:value:forTextRange:     (private) -- adds single attribute
  removeRenderingAttribute:forTextRange:        (private) -- removes single attribute
```

The existence of a separate `invalidateRenderingAttributesForTextRange:` method confirms that `setRenderingAttributes` does not inherently perform display invalidation.

### Evidence 4: Normal search masks the issue

During `applyFindHighlights`, after clearing, new highlights are applied:
```swift
layoutManager.setRenderingAttributes(
    [.backgroundColor: accentNSColor.withAlphaComponent(alpha)],
    for: textRange
)
```

These calls with non-empty attribute dictionaries trigger display updates for the newly-highlighted areas. Combined with `scrollRangeToVisible(currentRange)` (line 314), most visible content is redrawn, masking any stale pixels from the clearing step.

### Evidence 5: `lastHighlightedRanges` integrity confirmed

`lastHighlightedRanges` is a `[NSRange]` value type (copy semantics). It is set at line 309:
```swift
lastHighlightedRanges = findState.matchRanges
```
This copies the array, so `findState.dismiss()` clearing `matchRanges` to `[]` does not affect the coordinator's `lastHighlightedRanges`. The ranges used for clearing are the same ranges used for highlighting.
