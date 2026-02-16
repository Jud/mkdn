# Root Cause Investigation Report - table-full-width-001

## Executive Summary
- **Problem**: 2-column table (Mode | Behavior) is stretched to fill the entire container width, producing excessive dead space in cells
- **Root Cause**: Proportional scaling code added to `TableColumnSizer.computeWidths()` (lines 73-78) unconditionally scales all column widths to fill `containerWidth`, regardless of how small the intrinsic content is relative to the container
- **Solution**: Remove the proportional scaling block (lines 73-78) and restore the original `totalWidth = min(totalContentWidth, containerWidth)` computation; update PRD FR-3 and FR-10 to reflect content-intrinsic sizing
- **Urgency**: Low-risk revert; can be done immediately

## Investigation Process
- **Hypotheses Tested**: 1 (confirmed on first hypothesis)
- **Key Evidence**:
  1. `git diff HEAD -- mkdn/Core/Markdown/TableColumnSizer.swift` shows the exact uncommitted change that introduced proportional scaling
  2. The original T1 commit (`3b87ba8`) had no scaling -- `totalWidth = min(totalContentWidth, containerWidth)` was the original behavior
  3. The `OverlayCoordinator.positionEntry()` uses `entry.preferredWidth ?? context.containerWidth` (line 378), meaning when `TableBlockView` reports its actual rendered width through `onSizeChange`, the overlay shrinks to match content -- but the scaling in `computeWidths` has already inflated the column widths to fill the container, so the "actual rendered width" is itself the full container width

## Root Cause Analysis

### Technical Details

**File**: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/TableColumnSizer.swift`
**Lines**: 73-78 (uncommitted change)

The offending code:

```swift
if !needsHorizontalScroll, totalContentWidth > 0 {
    let scale = containerWidth / totalContentWidth
    for colIndex in 0 ..< columnCount {
        columnWidths[colIndex] *= scale
    }
}
```

This was added after the original T1 implementation (`3b87ba8`) as an uncommitted change, along with an update to the doc comment (line 34-35 changing step 5 to describe proportional scaling and adding step 6).

The original code at this location was simply:

```swift
let totalWidth = min(totalContentWidth, containerWidth)
```

### Causation Chain

1. **Root Cause**: Proportional scaling multiplies every column width by `containerWidth / totalContentWidth`
2. **Intermediate Effect**: For a narrow 2-column table where content might be ~200pt total but container is ~600pt, the scale factor is ~3x, tripling every column width
3. **Intermediate Effect**: `TableBlockView` renders cells with `.frame(width: columnWidths[colIndex])`, so each cell is 3x wider than its content needs
4. **Intermediate Effect**: `onSizeChange` reports the full container width back to `OverlayCoordinator.updateAttachmentSize`, which sets `preferredWidth` to the full container width
5. **Symptom**: The table visually fills the entire container with excessive dead space in every cell

### Why It Occurred

The PRD (smart-tables.md) was written to include FR-3: "Table fills container width via proportional column scaling" and FR-10: "Overlay width matches container width." The user originally saw the table at ~60% of the container width and interpreted this as a bug -- but it was actually correct content-aware sizing. The PRD was then authored with this "fill container width" requirement baked in, and the proportional scaling code was added to satisfy it.

In reality, the ~60% width was the correct behavior for a narrow table. GitHub and other markdown renderers do NOT scale narrow tables to fill the container. Tables are sized to their content. GitHub tables use `width: max-content` or auto-width behavior -- they are as wide as their content requires and no wider.

### Reference: How GitHub Handles Table Width

GitHub Markdown tables:
- Columns are sized to content (auto-width)
- The table element does NOT stretch to fill the container unless the content naturally requires that width
- Narrow tables (like 2-column key-value tables) render at their intrinsic content width
- Only when content is wide enough does the table naturally approach or exceed the container width, triggering overflow

This is the same behavior the original T1 implementation (`3b87ba8`) provided before the scaling was added.

## Proposed Solutions

### 1. Recommended: Revert the Scaling Change

**What to change**: In `TableColumnSizer.computeWidths()`:
- Remove lines 73-78 (the `if !needsHorizontalScroll` scaling block)
- Restore `let totalWidth = min(totalContentWidth, containerWidth)` (the original line)
- Revert the doc comment change on lines 34-35 back to: `/// 5. Sum all column widths; determine table width and scroll need.`

**What to change in PRD**: Update `smart-tables.md`:
- FR-3: Change from "Table fills container width via proportional column scaling" to "Columns sized to intrinsic content width; table width matches total column width (not stretched to fill container)"
- FR-10: Change from "Overlay width matches container width" to "Overlay width matches table content width (intrinsic sizing)"

**Effort**: ~5 minutes. Single file revert + PRD text update.

**Risk**: None. This restores the original T1 behavior that was working correctly.

**OverlayCoordinator impact**: No changes needed. The overlay already supports variable-width tables via `preferredWidth` (line 378: `let overlayWidth = entry.preferredWidth ?? context.containerWidth`). When the table reports its actual content width through `onSizeChange`, the overlay correctly sizes to match. This was the design from T3 commit (`b6ddbe9`).

### 2. Alternative: Partial Scaling with Minimum Threshold

If a "slightly wider than content but not full width" aesthetic is desired, a capped scaling approach could be used:

```swift
if !needsHorizontalScroll, totalContentWidth > 0 {
    let ratio = totalContentWidth / containerWidth
    // Only scale if table already fills >70% of container
    if ratio > 0.7 {
        let scale = containerWidth / totalContentWidth
        for colIndex in 0 ..< columnCount {
            columnWidths[colIndex] *= scale
        }
    }
}
```

**Effort**: ~10 minutes. Requires choosing the right threshold and testing with various table shapes.

**Risk**: Low, but introduces a magic number threshold. Not recommended -- content-intrinsic sizing is simpler and matches GitHub behavior.

## Prevention Measures

1. When a user reports a visual issue (e.g., "table is only 60% width"), investigate whether the behavior is actually correct before writing requirements to "fix" it. The ~60% width was correct content-aware sizing.
2. PRD requirements should reference established rendering behavior (e.g., GitHub Markdown rendering) as a baseline before specifying custom behavior.
3. Visual verification captures should include narrow tables as a regression test fixture.

## Evidence Appendix

### E1: Git Diff Showing the Offending Change

```diff
diff --git a/mkdn/Core/Markdown/TableColumnSizer.swift b/mkdn/Core/Markdown/TableColumnSizer.swift
index f8583e7..6eb0aba 100644
--- a/mkdn/Core/Markdown/TableColumnSizer.swift
+++ b/mkdn/Core/Markdown/TableColumnSizer.swift
@@ -31,7 +31,8 @@ enum TableColumnSizer {
     /// 2. Take the maximum intrinsic width per column.
     /// 3. Add horizontal cell padding (13pt x 2 = 26pt) to each column.
     /// 4. Cap each column at `containerWidth * 0.6`.
-    /// 5. Sum all column widths; determine table width and scroll need.
+    /// 5. If total fits within container, scale columns proportionally to fill width.
+    /// 6. Sum all column widths; determine table width and scroll need.
     static func computeWidths(

@@ -68,7 +69,17 @@ enum TableColumnSizer {

         let totalContentWidth = columnWidths.reduce(0, +)
         let needsHorizontalScroll = totalContentWidth > containerWidth
-        let totalWidth = min(totalContentWidth, containerWidth)
+
+        if !needsHorizontalScroll, totalContentWidth > 0 {
+            let scale = containerWidth / totalContentWidth
+            for colIndex in 0 ..< columnCount {
+                columnWidths[colIndex] *= scale
+            }
+        }
+
+        let totalWidth = needsHorizontalScroll
+            ? containerWidth
+            : columnWidths.reduce(0, +)
```

### E2: Original T1 Implementation (commit 3b87ba8)

The original `computeWidths` had no scaling step. After computing padded and capped column widths, it simply computed:

```swift
let totalContentWidth = columnWidths.reduce(0, +)
let needsHorizontalScroll = totalContentWidth > containerWidth
let totalWidth = min(totalContentWidth, containerWidth)
```

This produced correct content-intrinsic column widths.

### E3: OverlayCoordinator Width Flow

`OverlayCoordinator.positionEntry()` (line 378):
```swift
let overlayWidth = entry.preferredWidth ?? context.containerWidth
```

`preferredWidth` is set by `updateAttachmentSize()` when `TableBlockView` reports its rendered size via `onSizeChange`. With the scaling in place, the rendered size equals `containerWidth`, so `preferredWidth` is set to `containerWidth` -- making the overlay fill the entire container. Without scaling, `preferredWidth` would be the intrinsic content width, and the overlay would correctly match.

### E4: Height Estimation Side Effect

`MarkdownTextStorageBuilder.estimatedTableAttachmentHeight()` calls `TableColumnSizer.computeWidths()` with `defaultEstimationContainerWidth = 600`. With scaling, this inflates column widths to 600pt total, which causes `estimateTableHeight` to underestimate row heights (wider columns = fewer wrapping lines estimated). However, this is corrected at runtime by the `onSizeChange` callback updating the attachment height. The height estimation is an initial approximation, not the final layout. Reverting the scaling would slightly increase estimated row heights (narrower columns = more conservative wrapping estimate), which is actually more accurate.

### E5: PRD References That Need Updating

- FR-3: Currently says "Table fills container width via proportional column scaling" -- should be changed to content-intrinsic sizing
- FR-10: Currently says "Overlay width matches container width" -- should be changed to match content width
- Scope bullet "Table fills container width: columns sized to intrinsic content then scaled proportionally to fill available space" -- should be removed/revised
- Scope bullet "Overlay width matches container width (table fills available space)" -- should be revised
