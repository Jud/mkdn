# Root Cause Investigation Report - table-width-001

## Executive Summary
- **Problem**: Smart Tables do not expand to fill available horizontal width; a 2-column table uses ~60% of container width leaving a large gap on the right.
- **Root Cause**: `TableColumnSizer.computeWidths()` sizes columns strictly to intrinsic content width and never distributes remaining space. This is by design per FR-3 of the Smart Tables PRD ("narrow tables do NOT stretch to fill"), but produces a poor visual result for tables with short header text and moderate-length cell content.
- **Solution**: Add an optional proportional space-distribution step after intrinsic sizing, expanding columns to fill `containerWidth` when total intrinsic width is less than the container.
- **Urgency**: Low-to-medium. Cosmetic issue; no functionality is broken.

## Investigation Process
- **Hypotheses Tested**: 4 (see below)
- **Key Evidence**: Source code tracing through the complete width pipeline from `TableColumnSizer` through `OverlayCoordinator` positioning.

## Root Cause Analysis

### Hypothesis 1 (CONFIRMED): TableColumnSizer does not distribute remaining space
**Location**: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/TableColumnSizer.swift`, lines 35-78

The `computeWidths` algorithm:
1. Measures the intrinsic single-line width of every cell (header + data rows).
2. Takes the maximum intrinsic width per column.
3. Adds horizontal cell padding (13pt x 2 = 26pt) per column.
4. Caps each column at `containerWidth * 0.6` (the `maxColumnWidthFraction`).
5. Sums column widths to get `totalContentWidth`.
6. Sets `totalWidth = min(totalContentWidth, containerWidth)`.

**Critical gap**: There is no step between 4 and 5 that checks whether `totalContentWidth < containerWidth` and distributes the remaining space. The algorithm returns the intrinsic-fit widths unchanged, so for a table like:

| Mode | Behavior |
|------|----------|
| Short | Some longer descriptive text |

...the "Mode" column gets ~60pt and "Behavior" gets ~250pt, totaling ~310pt out of a ~600pt container -- leaving ~290pt of unused space.

### Hypothesis 2 (CONFIRMED as contributing): Overlay width uses preferredWidth, not containerWidth
**Location**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator.swift`, line 378

```swift
let overlayWidth = entry.preferredWidth ?? context.containerWidth
```

The overlay width is set to `entry.preferredWidth` when available. This `preferredWidth` is populated from the `onSizeChange` callback in `TableBlockView`, which reports the table's actual rendered width -- which is the intrinsic-fit width, not the container width. This means:
- The table renders at intrinsic width (e.g., 310pt)
- The `onSizeChange` callback fires with `width: 310`
- `updateAttachmentSize` stores `preferredWidth = 310`
- On reposition, the overlay frame is set to 310pt wide

This correctly implements the PRD's FR-10 ("Overlay width matches actual table width ... Narrow tables left-aligned") but it compounds the visual problem -- not only are the columns narrow, but the entire overlay frame is narrow too.

### Hypothesis 3 (REJECTED): containerWidth not being passed correctly
The `makeTableOverlay` method at line 306 correctly reads `containerWidth` from `textContainerWidth(in: textView)`, which returns the text container's actual width. This value is correctly passed to both `TableColumnSizer.computeWidths()` and `TableBlockView(containerWidth:)`. No issue here.

### Hypothesis 4 (REJECTED): TableBlockView frame modifiers preventing expansion
Looking at `TableBlockView.tableContent()` (lines 38-51), the non-scrolling path simply renders `tableBody(columnWidths:)` without any `.frame(maxWidth:)` constraint. The `VStack(alignment: .leading, spacing: 0)` at line 54 uses `.leading` alignment, which left-aligns content but does not prevent it from being wider. The column widths come from `sizingResult`, which is the core issue (Hypothesis 1). No additional frame constraint is artificially limiting width.

### Causation Chain

```
Root Cause: TableColumnSizer.computeWidths() returns intrinsic-fit column widths
     with no space-distribution step
  |
  +--> TableBlockView renders with narrow columns (e.g., 310pt total in 600pt container)
  |
  +--> onSizeChange callback reports actual table width as 310pt
  |
  +--> OverlayCoordinator.updateAttachmentSize stores preferredWidth = 310pt
  |
  +--> positionEntry sets overlay frame width = 310pt
  |
  +--> Symptom: Table visually occupies ~50-60% of available width
```

### Why It Occurred

The Smart Tables PRD explicitly specifies in FR-3: "Table width = sum of column widths + padding, capped at container. Narrow tables do NOT stretch to fill container width." The implementation faithfully follows this requirement. However, the visual result is suboptimal for the common case of 2-3 column tables where the content is moderately sized -- the table looks "lost" in the available space.

This is a design specification issue rather than an implementation bug. The PRD was written with the concern about avoiding equal-width distribution (which was the old behavior), but overcorrected by specifying no distribution at all.

### PRD Reference

The relevant PRD requirement is FR-3 in `/Users/jud/Projects/mkdn/.rp1/work/prds/smart-tables.md`:
> FR-3 | Table width = sum of column widths + padding, capped at container | Narrow tables do NOT stretch to fill container width. Table is left-aligned within its container.

## Proposed Solutions

### 1. Recommended: Proportional Space Distribution (Medium Effort)

Add a space-distribution step to `TableColumnSizer.computeWidths()` after step 4 (capping) and before step 5 (summing):

```
If totalContentWidth < containerWidth:
    remainingSpace = containerWidth - totalContentWidth
    Distribute remainingSpace proportionally among columns based on their intrinsic widths
    (text-heavy columns get more of the extra space)
```

This would go in `TableColumnSizer.swift` after line 67, before line 69. The distribution should be proportional to each column's current width so that wider columns (which tend to contain more text) get more of the extra space.

**Effort**: Small (~20 lines of code in `TableColumnSizer.computeWidths`)
**Risk**: Low. Only affects visual layout; no functional change.
**Pros**: Tables fill available space naturally; text-heavy columns get proportionally more room.
**Cons**: Changes the explicitly-specified PRD behavior (FR-3). The PRD would need to be updated.

Also requires updating `OverlayCoordinator.makeTableOverlay()` to stop storing a `preferredWidth` (or set it to `containerWidth` when the table fits), so the overlay fills the container width too.

### 2. Alternative A: Fill-Width with Minimum Intrinsic (Low Effort)

Always set total table width to `containerWidth` when content fits, and distribute space equally among columns (after ensuring each column meets its minimum intrinsic width).

**Effort**: Small
**Risk**: Low
**Pros**: Simple implementation.
**Cons**: Equal distribution may give too much space to narrow columns (e.g., a "Mode" column) and not enough to wide columns (e.g., "Behavior").

### 3. Alternative B: Configurable Fill Behavior (Higher Effort)

Add a `shouldFillContainerWidth: Bool` parameter to `TableColumnSizer.computeWidths()`, controlled by a user preference or heuristic (e.g., always fill for tables with <= 4 columns).

**Effort**: Medium
**Risk**: Low
**Pros**: Most flexible.
**Cons**: Adds configuration complexity.

## Prevention Measures

- For visual layout features, prototype with representative content (2-column tables with short/long content, wide multi-column tables) before finalizing the PRD.
- Consider adding visual verification test fixtures that specifically test table width filling behavior.

## Evidence Appendix

### E1: TableColumnSizer.computeWidths Algorithm (lines 35-78)
The algorithm never distributes remaining space. After computing intrinsic widths + padding and capping at 60% of container, it simply sums and returns. No redistribution occurs when `totalContentWidth < containerWidth`.

### E2: OverlayCoordinator.positionEntry (line 378)
```swift
let overlayWidth = entry.preferredWidth ?? context.containerWidth
```
Uses the table's reported width (from `onSizeChange`), which is the intrinsic-fit width, not the container width.

### E3: OverlayCoordinator.makeTableOverlay (lines 300-328)
The `onSizeChange` callback stores the reported width as `preferredWidth`, which then governs the overlay frame width.

### E4: PRD FR-3 Specification
The PRD explicitly says "Narrow tables do NOT stretch to fill container width." The implementation is faithful to the spec; the spec itself is the root cause of the visual issue.

### E5: TableBlockView.tableContent (lines 38-51)
No `.frame(maxWidth:)` modifier forces the non-scrolling table to a particular width. Width is determined entirely by column widths from `sizingResult`.
