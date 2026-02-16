# Root Cause Investigation Report - mermaid-offcenter

## Executive Summary
- **Problem**: Mermaid diagrams appear off-center with asymmetric left/right padding in the document preview view.
- **Root Cause**: The overlay positioning in `OverlayCoordinator.positionEntry()` uses the full `container.size.width` for the overlay width, but positions the overlay at `fragmentFrame.origin.x + textContainerOrigin.x`. If `fragmentFrame.origin.x` is non-zero (due to TextKit 2 layout fragment padding), the overlay overflows the right margin. Additionally, the overlay width does not account for `lineFragmentPadding` (default 5pt), creating a mismatch between the overlay bounds and the visual text content area.
- **Solution**: Fix the overlay x-position and width calculation in `positionEntry()` to align with the text content area, or explicitly set `lineFragmentPadding = 0` on the text container.
- **Urgency**: Medium -- visual polish issue affecting all overlay elements (Mermaid, images, thematic breaks, tables).

## Investigation Process
- **Duration**: Full static code analysis
- **Hypotheses Tested**: 6 hypotheses tested through code trace analysis
- **Key Evidence**: Code path analysis of positionEntry(), textContainerWidth(), and textContainerInset interactions

### Hypotheses and Results

| # | Hypothesis | Result |
|---|-----------|--------|
| 1 | Overlay x-position doesn't account for textContainerInset | **Rejected** -- `textContainerOrigin` already includes the inset |
| 2 | `containerWidth` doesn't subtract both left and right insets | **Rejected** -- `container.size.width` with `widthTracksTextView` correctly subtracts `2 * inset.width` |
| 3 | `fragmentFrame.origin.x` is non-zero due to `lineFragmentPadding` in TextKit 2 | **Likely root cause** -- see analysis below |
| 4 | `NSHostingView` resizes itself to intrinsic content size, ignoring the set frame | **Rejected** -- explicit frame setting overrides intrinsic sizing |
| 5 | MermaidBlockView aspect ratio fitting causes centering offset | **Rejected** -- attachment height is calculated to match aspect ratio exactly |
| 6 | Vertical scroller steals width asymmetrically | **Rejected** -- overlay scrollers with `autohidesScrollers` don't affect content width |

## Root Cause Analysis

### Technical Details

The bug lives in the interaction between three components:

**File**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator.swift`

**Location**: `positionEntry()` (lines 289-326) and `textContainerWidth()` (lines 345-351)

**The positioning code (lines 318-324)**:
```swift
let fragmentFrame = fragment.layoutFragmentFrame
entry.view.frame = CGRect(
    x: fragmentFrame.origin.x + context.origin.x,
    y: fragmentFrame.origin.y + context.origin.y,
    width: context.containerWidth,
    height: fragmentFrame.height
)
```

**The width calculation (lines 345-351)**:
```swift
private func textContainerWidth(in textView: NSTextView) -> CGFloat {
    if let container = textView.textContainer {
        return container.size.width
    }
    let inset = textView.textContainerInset
    return textView.bounds.width - inset.width * 2
}
```

**The textContainerInset** (in `SelectableTextView.swift` line 137):
```swift
textView.textContainerInset = NSSize(width: 32, height: 32)
```

### The Mismatch

In TextKit 2, `NSTextLayoutFragment.layoutFragmentFrame` represents the paragraph's bounding rectangle in the text container's coordinate system. The `NSTextContainer.lineFragmentPadding` (default: 5pt, never overridden in this codebase) adds internal padding within line fragments.

The problem manifests in two related ways:

**Issue A: fragmentFrame.origin.x may be non-zero**

In TextKit 2, the `layoutFragmentFrame.origin.x` for a paragraph containing only an `NSTextAttachment` may include the `lineFragmentPadding` offset. If so:
- `overlay.x = 5 + 32 = 37` (instead of expected 32)
- `overlay.width = containerWidth = bounds.width - 64`
- `overlay.rightEdge = 37 + (bounds.width - 64) = bounds.width - 27`
- Left margin: 37pt, Right margin: 27pt -- **10pt asymmetry**

**Issue B: overlay width vs text content area width**

Even if `fragmentFrame.origin.x` is 0:
- The overlay spans the full `container.size.width`
- But text content within the container is inset by `lineFragmentPadding` (5pt) on each side
- Text occupies `container.size.width - 2 * lineFragmentPadding`
- The overlay is 10pt wider than the text content area (5pt per side)

For Issue A, the diagram shifts right, creating visible asymmetry. For Issue B, the overlay is wider than text but symmetrically so -- less likely to cause the reported symptom.

**Contributing factor: Attachment bounds width mismatch**

In `updateAttachmentHeight()` (line 97):
```swift
attachment.bounds = CGRect(
    x: 0, y: 0,
    width: containerWidth,
    height: newHeight
)
```

The attachment width is set to `containerWidth` (the full text container width), but the usable line width inside the text container is `containerWidth - 2 * lineFragmentPadding`. An attachment wider than the usable line width forces the TextKit 2 layout engine to make layout decisions (wrapping, truncation, or overflow) that could shift the layout fragment's origin.

### Causation Chain

```
lineFragmentPadding (5pt, default, never zeroed)
  -> text attachment width set to container.size.width (too wide by 10pt)
  -> TextKit 2 layout positions fragment with non-zero origin.x
  -> positionEntry() adds fragmentFrame.origin.x to textContainerOrigin.x
  -> overlay x shifts right by ~5pt
  -> overlay extends past right margin by ~5pt
  -> visual asymmetry: ~37pt left margin, ~27pt right margin
```

### Why It Occurred

1. `lineFragmentPadding` was never explicitly set to 0 or accounted for in overlay positioning
2. The overlay width uses `container.size.width` rather than the effective text line width
3. TextKit 2's layout fragment frame geometry differs subtly from TextKit 1 in how it reports fragment origins for attachment content
4. The `CodeBlockBackgroundTextView` drawing code avoids this issue because it uses `origin.x` directly (line 103) rather than `bounding.minX + origin.x`, hardcoding the x position to `textContainerOrigin.x`

## Proposed Solutions

### 1. Recommended: Set lineFragmentPadding to 0 and account for it in overlay positioning

**Approach**: In `SelectableTextView.configureTextView()`, set `textContainer.lineFragmentPadding = 0`. This eliminates the internal padding that causes the fragment offset. The visual text margin becomes purely `textContainerInset.width` = 32pt.

**Effort**: Small (1 line change + verification)
**Risk**: Low -- lineFragmentPadding = 0 is common for custom text views. Text content will shift left by 5pt, so verify visual compliance.
**Pros**: Simplest fix, aligns all content (text and overlays) to the same x position
**Cons**: Slightly changes text margins (from 37pt to 32pt effective). May need to increase `textContainerInset.width` by 5pt (to 37 or 40) to compensate.

### 2. Alternative A: Fix overlay positioning to ignore fragmentFrame.origin.x

**Approach**: In `positionEntry()`, use `context.origin.x` directly for the x position instead of adding `fragmentFrame.origin.x`. This mirrors how `CodeBlockBackgroundTextView` positions its backgrounds.

```swift
entry.view.frame = CGRect(
    x: context.origin.x,                // was: fragmentFrame.origin.x + context.origin.x
    y: fragmentFrame.origin.y + context.origin.y,
    width: context.containerWidth,
    height: fragmentFrame.height
)
```

**Effort**: Small (1 line change)
**Risk**: Low -- but this ignores fragment x for ALL overlay types, including any that might legitimately have non-zero origin.x (e.g., indented blocks)
**Pros**: Direct fix for the positioning issue
**Cons**: Loses flexibility for indented overlay content

### 3. Alternative B: Subtract lineFragmentPadding from overlay width and adjust x

**Approach**: Account for `lineFragmentPadding` explicitly:

```swift
let padding = textView.textContainer?.lineFragmentPadding ?? 0
let adjustedWidth = context.containerWidth - 2 * padding
entry.view.frame = CGRect(
    x: context.origin.x + padding,
    y: fragmentFrame.origin.y + context.origin.y,
    width: adjustedWidth,
    height: fragmentFrame.height
)
```

**Effort**: Small (3 lines changed)
**Risk**: Low
**Pros**: Precisely aligns overlay with text content area
**Cons**: Overlay is narrower than text container -- may look slightly inset compared to code block backgrounds

## Prevention Measures

1. **Add a spatial compliance test** for overlay alignment that verifies the mermaid diagram's left and right margins match the document margin specification.
2. **Set lineFragmentPadding explicitly** (even if to the default value) with a comment explaining its role in overlay positioning, so future developers are aware of the dependency.
3. **Add debug assertions** in `positionEntry()` that verify `fragmentFrame.origin.x` is 0 for non-indented paragraphs (catches TextKit 2 behavior changes).
4. **Unify positioning logic** between `CodeBlockBackgroundTextView` and `OverlayCoordinator` to use the same x-position calculation (both currently use different approaches to the same problem).

## Evidence Appendix

### Key Code Locations

| File | Line(s) | Relevance |
|------|---------|-----------|
| `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` | 289-326 | `positionEntry()` -- overlay positioning |
| `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` | 345-351 | `textContainerWidth()` -- width calculation |
| `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` | 86-118 | `updateAttachmentHeight()` -- attachment bounds |
| `mkdn/Features/Viewer/Views/SelectableTextView.swift` | 102-103 | Text container creation with `widthTracksTextView` |
| `mkdn/Features/Viewer/Views/SelectableTextView.swift` | 137 | `textContainerInset = NSSize(width: 32, height: 32)` |
| `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` | 100-106 | Code block drawing uses `origin.x` directly (not fragmentFrame.origin.x) |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift` | 127-154 | `appendAttachmentBlock()` -- initial attachment bounds (width: 1) |

### Positioning Math Trace

For a text view with `bounds.width = 800`:
- `textContainerInset.width = 32`
- `container.size.width = 800 - 64 = 736`
- `textContainerOrigin.x = 32`
- `lineFragmentPadding = 5` (default, never overridden)

**If fragmentFrame.origin.x = 0** (ideal case):
- Overlay: x=32, width=736, right edge=768, margins: 32/32 (symmetric)

**If fragmentFrame.origin.x = 5** (lineFragmentPadding effect):
- Overlay: x=37, width=736, right edge=773, margins: 37/27 (asymmetric by 10pt)

### Comparison with CodeBlockBackgroundTextView

The code block background drawing in `CodeBlockBackgroundTextView.drawCodeBlockContainers()` (line 101-106) uses:
```swift
let drawRect = CGRect(
    x: origin.x + borderInset,       // Uses textContainerOrigin.x directly
    y: bounding.minY + origin.y,
    width: containerWidth - 2 * borderInset,
    height: bounding.height + Self.bottomPadding
)
```

This code does NOT add `bounding.minX` (fragmentFrame.origin.x) to the x position. It uses `origin.x` (textContainerOrigin.x) directly. This means code block backgrounds are always positioned symmetrically at the container origin, regardless of fragment frame x-offset.

The `OverlayCoordinator.positionEntry()` DOES add `fragmentFrame.origin.x`:
```swift
x: fragmentFrame.origin.x + context.origin.x,
```

This inconsistency between the two components is the likely source of the visual asymmetry.

### Runtime Verification Needed

This investigation identified the root cause through static code analysis. To confirm, runtime verification should:

1. Log `fragmentFrame.origin.x` for attachment paragraphs to verify it's non-zero
2. Log `textContainerOrigin.x` to verify it equals `textContainerInset.width`
3. Log `container.size.width` to verify it equals `textView.bounds.width - 2 * textContainerInset.width`
4. Compare the overlay's actual frame with the expected symmetric frame
