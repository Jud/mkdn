# Development Tasks: Smart Tables

**Feature ID**: smart-tables
**Status**: Not Started
**Progress**: 10% (1 of 10 tasks)
**Estimated Effort**: 5 days
**Started**: 2026-02-11

## Overview

Smart Tables replaces the current equal-width, non-wrapping table renderer with a content-aware layout engine. The implementation introduces a column measurement pass (TableColumnSizer), a rewritten TableBlockView with text wrapping and horizontal scroll, variable-width overlay positioning in the OverlayCoordinator, improved height estimation in MarkdownTextStorageBuilder, and scroll-offset-based sticky headers for long tables.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T3, T4] - T1 is pure computation with no overlay dependency; T3 modifies overlay system with no table logic dependency; T4 modifies builder estimation independently
2. [T2, T6] - T2 reads column widths from T1; T6 tests T1
3. [T5] - requires working table (T2) and overlay variable width (T3) for scroll observation context

**Dependencies**:

- T2 -> T1 (data: TableBlockView reads column widths computed by TableColumnSizer)
- T6 -> T1 (data: tests exercise TableColumnSizer API)
- T5 -> [T2, T3] (interface: sticky header needs working table view and variable-width overlay positioning)

**Critical Path**: T1 -> T2 -> T5

## Task Breakdown

### Foundation (Parallel Group 1)

- [x] **T1**: Implement TableColumnSizer - pure column width computation engine `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/TableColumnSizer.swift`
    - **Approach**: Caseless enum with `computeWidths` and `estimateTableHeight` static methods. Cell widths measured via `NSAttributedString.size()` with bold font for headers. Padding (26pt), column cap (0.6x container), and minimum width enforced. Height estimation uses line-count calculation from content-to-column-width ratio.
    - **Deviations**: None
    - **Tests**: Build passes, SwiftLint 0 violations, SwiftFormat clean, existing 32 builder tests pass

    **Reference**: [design.md#31-tablecolumnsizer](design.md#31-tablecolumnsizer)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] New file `mkdn/Core/Markdown/TableColumnSizer.swift` created as a caseless enum
    - [x] `computeWidths(columns:rows:containerWidth:font:)` returns `Result` with `columnWidths`, `totalWidth`, and `needsHorizontalScroll`
    - [x] Column width equals widest cell intrinsic width (measured via `NSAttributedString.size()`) plus 26pt horizontal padding (13pt x 2)
    - [x] Header cells measured with bold font variant; data cells with regular font
    - [x] Maximum column width capped at `containerWidth * 0.6`
    - [x] `needsHorizontalScroll` is true when `totalContentWidth > containerWidth`
    - [x] `tableWidth = min(totalContentWidth, containerWidth)` -- narrow tables do not stretch
    - [x] `estimateTableHeight(columns:rows:columnWidths:font:)` method accounts for text wrapping by estimating wrapped line count per cell
    - [x] Empty cells produce minimum padding-based width (26pt)
    - [x] Passes SwiftLint strict mode

- [ ] **T3**: Add variable-width overlay positioning and table size callback to OverlayCoordinator `[complexity:medium]`

    **Reference**: [design.md#33-overlaycoordinator-updates](design.md#33-overlaycoordinator-updates)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] `OverlayEntry` struct gains optional `preferredWidth: CGFloat?` field (nil = use containerWidth, preserving existing behavior for Mermaid/image overlays)
    - [ ] `positionEntry` uses `entry.preferredWidth ?? context.containerWidth` for overlay frame width
    - [ ] `makeTableOverlay` passes `containerWidth` and an `onSizeChange` closure to `TableBlockView`
    - [ ] `updateAttachmentSize(blockIndex:newWidth:newHeight:)` method updates both entry `preferredWidth` and attachment bounds
    - [ ] Width change triggers `repositionOverlays()` to apply new width
    - [ ] Height change triggers existing `updateAttachmentHeight` logic with 1pt threshold
    - [ ] Existing Mermaid and image overlay behavior is unchanged (nil preferredWidth)
    - [ ] Passes SwiftLint strict mode

- [ ] **T4**: Improve table height estimation in MarkdownTextStorageBuilder `[complexity:simple]`

    **Reference**: [design.md#34-markdowntextstoragebuilder-updates](design.md#34-markdowntextstoragebuilder-updates)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [ ] Table attachment height estimation uses `TableColumnSizer.computeWidths` and `TableColumnSizer.estimateTableHeight` instead of fixed `rowHeight: 32`
    - [ ] Uses `PlatformTypeConverter.bodyFont()` for measurement font
    - [ ] Uses a reasonable default containerWidth (600pt) for estimation since the builder does not have access to actual container width
    - [ ] Estimated height accounts for text wrapping -- tables with long cell content produce taller estimates than tables with short content
    - [ ] Dynamic height callback from OverlayCoordinator still corrects any estimation error
    - [ ] Passes SwiftLint strict mode

### Table View and Tests (Parallel Group 2)

- [ ] **T2**: Rewrite TableBlockView with content-aware widths, text wrapping, horizontal scroll, and size reporting `[complexity:complex]`

    **Reference**: [design.md#32-tableblockview-rewrite](design.md#32-tableblockview-rewrite)

    **Effort**: 10 hours

    **Acceptance Criteria**:

    - [ ] Calls `TableColumnSizer.computeWidths` to determine column widths from cell content
    - [ ] Each cell uses `.frame(width: columnWidths[colIndex], alignment: column.alignment)` with explicit width (not `.infinity`)
    - [ ] Cell text uses `.lineLimit(nil)` and `.fixedSize(horizontal: false, vertical: true)` for unlimited wrapping
    - [ ] Cell padding is `.padding(.horizontal, 13)` and `.padding(.vertical, 6)` per REQ-ST-008
    - [ ] When `needsHorizontalScroll` is true, table content is wrapped in `ScrollView(.horizontal, showsIndicators: true)` -- vertical document scrolling is not captured
    - [ ] Header row renders bold text with `backgroundSecondary` fill and bottom divider per REQ-ST-007
    - [ ] Alternating row backgrounds: even rows use `background`, odd rows use `backgroundSecondary.opacity(0.5)` per REQ-ST-006
    - [ ] Table has 1px stroke border with `border.opacity(0.3)` and 6pt corner radius per REQ-ST-009
    - [ ] `.onGeometryChange()` modifier reports actual rendered size via `onSizeChange(width, height)` callback
    - [ ] Layout uses VStack (not LazyVStack) for up to 100 rows per design decision D7
    - [ ] All colors sourced from `ThemeColors` via `@Environment(AppSettings.self)` -- no hardcoded colors
    - [ ] `containerWidth` parameter accepted for passing to TableColumnSizer
    - [ ] Passes SwiftLint strict mode

- [ ] **T6**: Add unit tests for TableColumnSizer and table height estimation `[complexity:medium]`

    **Reference**: [design.md#7-testing-strategy](design.md#7-testing-strategy)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [ ] New file `mkdnTests/Unit/Core/TableColumnSizerTests.swift` using Swift Testing (`@Suite`, `@Test`, `#expect`)
    - [ ] Test `narrowTableFitsContent`: two-column table with short content produces widths < containerWidth (REQ-ST-001, REQ-ST-003)
    - [ ] Test `widestCellSetsColumnWidth`: column width equals widest cell measured width + 26pt padding (REQ-ST-001)
    - [ ] Test `equalContentProducesEqualWidths`: similar content columns produce approximately equal widths (REQ-ST-001 AC-2)
    - [ ] Test `wideTableFlagsHorizontalScroll`: 12-column table sets `needsHorizontalScroll = true` (REQ-ST-004)
    - [ ] Test `columnWidthCapped`: single very wide column does not exceed `containerWidth * 0.6` (REQ-ST-001)
    - [ ] Test `paddingIncludedInWidth`: each column width includes 26pt horizontal padding (REQ-ST-008)
    - [ ] Test `headerBoldFontUsedForMeasurement`: bold header text is measured, not regular weight (REQ-ST-007)
    - [ ] Test `emptyRowsProduceMinimumWidths`: empty cells produce minimum padding-based width (edge case)
    - [ ] Test `heightEstimateAccountsForWrapping`: long cells produce taller height estimates than short cells (NFR-ST-002)
    - [ ] Addition to `MarkdownTextStorageBuilderTests`: `tableHeightEstimateGrowsWithContent` verifies larger attachment height for long cell content
    - [ ] All tests pass with `swift test`

### Sticky Headers (Parallel Group 3)

- [ ] **T5**: Implement sticky header overlay via scroll observation `[complexity:complex]`

    **Reference**: [design.md#334-sticky-header-via-scroll-observation](design.md#334-sticky-header-via-scroll-observation)

    **Effort**: 10 hours

    **Acceptance Criteria**:

    - [ ] New file `mkdn/Features/Viewer/Views/TableHeaderView.swift` -- lightweight SwiftUI view rendering just the header row with same column widths, bold text, background, and bottom divider
    - [ ] `StickyHeaderEntry` struct in OverlayCoordinator stores `view`, `blockIndex`, `headerHeight`
    - [ ] `stickyHeaders: [Int: StickyHeaderEntry]` dictionary tracks active sticky headers
    - [ ] Registers `boundsDidChangeNotification` observer on NSScrollView's contentView when table overlay is created
    - [ ] On scroll event: for each table entry, calculates whether header region has scrolled above visible viewport
    - [ ] When header is scrolled past: adds/repositions separate `NSHostingView` containing `TableHeaderView` at top of visible table area
    - [ ] When table scrolls back into full view: removes sticky header overlay
    - [ ] Sticky header uses same `TableColumnSizer.Result` data as main table for column alignment
    - [ ] Sticky header styling matches normal header: bold text, `backgroundSecondary` background, bottom border per REQ-ST-012 AC-2
    - [ ] Sticky header does not overlap or obscure table data (REQ-ST-012 AC-3)
    - [ ] Scroll observer is cleaned up when overlays are removed
    - [ ] Passes SwiftLint strict mode

### User Docs

- [ ] **TD1**: Create documentation for TableColumnSizer - Core/Markdown `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: add

    **Target**: `.rp1/context/modules.md`

    **Section**: Core/Markdown

    **KB Source**: modules.md:Core/Markdown

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New row added to Core/Markdown table: `TableColumnSizer.swift` with purpose "Pure column width computation from cell content"

- [ ] **TD2**: Create documentation for TableHeaderView - Features/Viewer/Views `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: add

    **Target**: `.rp1/context/modules.md`

    **Section**: Features/Viewer/Views (within Viewer table)

    **KB Source**: modules.md:Features/Viewer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New row added to Viewer Views table: `Views/TableHeaderView.swift` with purpose "Sticky header overlay for long tables"

- [ ] **TD3**: Update architecture.md - Rendering Pipeline `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Rendering Pipeline

    **KB Source**: architecture.md:Rendering Pipeline

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Rendering Pipeline section documents the table rendering pipeline: column measurement (TableColumnSizer) -> layout (TableBlockView) -> overlay positioning (OverlayCoordinator with preferredWidth) -> sticky headers (scroll observation)

- [ ] **TD4**: Update patterns.md - Feature-Based MVVM `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: Feature-Based MVVM

    **KB Source**: patterns.md:Feature-Based MVVM

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Feature-Based MVVM section includes note about variable-width overlay pattern: overlays can specify `preferredWidth` instead of defaulting to container width

## Acceptance Criteria Checklist

### Content-Aware Column Sizing (REQ-ST-001)
- [ ] AC-1: A two-column table with a short label column and a long description column allocates more width to the description column
- [ ] AC-2: A table where all columns have similar content lengths produces approximately equal column widths
- [ ] AC-3: Column widths recalculate when the system font size changes (Dynamic Type)

### Text Wrapping in Cells (REQ-ST-002)
- [ ] AC-1: A cell containing a 200-character string wraps to multiple lines; all text is visible
- [ ] AC-2: Row height expands to fit the tallest cell in that row
- [ ] AC-3: No ellipsis or clipping is ever applied to cell content

### Table Width Fits Content (REQ-ST-003)
- [ ] AC-1: A narrow two-column table occupies less than 50% of a standard-width window
- [ ] AC-2: The table's left edge aligns with the left margin of surrounding paragraph text
- [ ] AC-3: The overlay hosting the table matches the actual table width, not the container width

### Horizontal Scrolling for Wide Tables (REQ-ST-004)
- [ ] AC-1: A 12-column table in a standard-width window shows a horizontal scrollbar
- [ ] AC-2: All columns are reachable by scrolling horizontally
- [ ] AC-3: Vertical document scrolling is not captured by the horizontal table scrollbar

### Column Alignment from Markdown Syntax (REQ-ST-005)
- [ ] AC-1: A column with `---:` syntax renders all cells right-aligned
- [ ] AC-2: A column with `:---:` syntax renders all cells center-aligned
- [ ] AC-3: A column with no alignment markers renders left-aligned

### Alternating Row Backgrounds (REQ-ST-006)
- [ ] AC-1: Adjacent rows have visually distinguishable backgrounds
- [ ] AC-2: Colors adapt when the user switches between Solarized Light and Solarized Dark themes
- [ ] AC-3: Alternation pattern is consistent regardless of row count

### Distinct Header Row (REQ-ST-007)
- [ ] AC-1: Header text renders in bold
- [ ] AC-2: Header row background is visually distinct from both even and odd data rows
- [ ] AC-3: A visible divider separates the header from the first data row

### Cell Padding (REQ-ST-008)
- [ ] AC-1: Cell content does not touch the cell edges
- [ ] AC-2: Padding is uniform across all cells in the table

### Rounded-Corner Border (REQ-ST-009)
- [ ] AC-1: The table has a visible, subtle border on all four sides
- [ ] AC-2: Corners are visibly rounded (not sharp 90-degree angles)

### Overlay Width Matches Table Width (REQ-ST-010)
- [ ] AC-1: A narrow table's overlay does not extend beyond the table's right edge
- [ ] AC-2: A wide table's overlay extends to the container edge with horizontal scrolling enabled
- [ ] AC-3: The overlay border and background match the actual table dimensions

### Text Selection Across Cells (REQ-ST-011)
- [ ] AC-1: Text within a single cell can be selected by click-drag
- [ ] AC-2: Selection can span across multiple cells
- [ ] AC-3: Selected text can be copied to clipboard via Cmd+C

### Sticky Headers on Vertical Scroll (REQ-ST-012)
- [ ] AC-1: A 50-row table, when scrolled past the header, still shows the header row pinned at the top of the visible table area
- [ ] AC-2: The sticky header has the same visual styling (bold, background, border) as the normal header
- [ ] AC-3: The sticky header does not overlap or obscure table data

### Non-Functional Requirements
- [ ] NFR-ST-001: Tables up to 100 rows render and scroll without perceptible lag (<16ms frame time)
- [ ] NFR-ST-002: Column widths recalculate promptly on font size change or window resize without flicker
- [ ] NFR-ST-003: All colors sourced from ThemeColors; tables adapt to theme changes without restart
- [ ] NFR-ST-004: Tables respect Dynamic Type / system font size scaling
- [ ] NFR-ST-005: Horizontal scroll does not capture vertical document scroll events
- [ ] NFR-ST-006: Native SwiftUI only, no WKWebView

## Definition of Done

- [ ] All tasks completed (T1-T6, TD1-TD4)
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] Unit tests pass (`swift test`)
- [ ] SwiftLint strict mode passes
- [ ] SwiftFormat applied
- [ ] Docs updated (modules.md, architecture.md, patterns.md)
