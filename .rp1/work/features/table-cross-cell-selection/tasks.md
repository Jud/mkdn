# Development Tasks: Table Cross-Cell Selection

**Feature ID**: table-cross-cell-selection
**Status**: In Progress
**Progress**: 25% (3 of 12 tasks)
**Estimated Effort**: 7 days
**Started**: 2026-02-23

## Overview

Make table cell content part of the document's NSTextStorage as invisible text so that selection, find, and clipboard operations work natively across table cells and across block boundaries. Visual rendering remains unchanged via the existing SwiftUI TableBlockView overlay. A transparent TableHighlightOverlay draws cell-level selection and find highlights on top.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1] - Foundation data types, no dependencies on other tasks
2. [T2, T5, T6] - All depend only on T1; T2 builds invisible text, T5 implements clipboard, T6 extends entrance animation
3. [T3, T7] - T3 depends on T2 (needs table overlay info from builder); T7 depends on T2 (needs isPrint flag and visible text mode)
4. [T4, T8] - T4 depends on T1 and T3 (needs cell map and overlay position); T8 depends on T3 (needs overlay coordinator table methods)

**Dependencies**:

- T2 -> T1 (Data: builder consumes TableAttributes, TableCellMap, TableOverlayInfo)
- T3 -> T2 (Interface: overlay coordinator consumes TableOverlayInfo from builder output)
- T4 -> T1 (Data: highlight overlay reads TableCellMap for cell geometry)
- T4 -> T3 (Interface: highlight overlay is managed by overlay coordinator)
- T5 -> T1 (Data: copy handler reads TableCellMap for content extraction)
- T6 -> T1 (Interface: animator reads TableAttributes.range)
- T7 -> T2 (Data: print path uses builder's isPrint flag)
- T8 -> T3 (Interface: coordinator delegates selection/find updates to overlay coordinator)

**Critical Path**: T1 -> T2 -> T3 -> T4

## Task Breakdown

### Foundation Data Types

- [x] **T1**: Define TableAttributes, TableCellMap, and TableColorInfo data types `[complexity:medium]`

    **Reference**: [design.md#31-tableattributes](design.md#31-tableattributes), [design.md#32-tablecellmap](design.md#32-tablecellmap), [design.md#33-tablecolorinfo](design.md#33-tablecolorinfo)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] New file `mkdn/Core/Markdown/TableAttributes.swift` with `range`, `cellMap`, `colors`, `isHeader` NSAttributedString.Key constants
    - [x] `TableColorInfo` NSObject subclass in `TableAttributes.swift` with background, backgroundSecondary, border, headerBackground, foreground, headingColor properties
    - [x] New file `mkdn/Core/Markdown/TableCellMap.swift` with `CellPosition` (Hashable), `CellEntry`, sorted cells array, column/row metadata
    - [x] `cellAt(offset:)` binary search returning correct CellPosition for character offset in O(log n)
    - [x] `cellsInRange(_:)` returns Set of all CellPositions whose ranges intersect the given NSRange
    - [x] `rangeFor(cell:)` returns NSRange for a given CellPosition
    - [x] `tabDelimitedText(for:)` generates tab-separated rows from selected cells
    - [x] `rtfData(for:colors:)` generates valid RTF table data from selected cells
    - [x] Header row uses row index -1, data rows use 0+
    - [x] New test file `mkdnTests/Unit/Core/TableCellMapTests.swift` with tests for binary search, range intersection, header distinction, tab-delimited output, RTF output, empty selection, full table selection
    - [x] New test file `mkdnTests/Unit/Core/TableAttributesTests.swift` with tests for attribute key distinctness and TableColorInfo storage
    - [x] All new types have correct Swift 6 concurrency annotations (@MainActor, Sendable as appropriate)

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/TableAttributes.swift`, `mkdn/Core/Markdown/TableCellMap.swift`, `mkdnTests/Unit/Core/TableAttributesTests.swift`, `mkdnTests/Unit/Core/TableCellMapTests.swift`
    - **Approach**: Mirrored CodeBlockAttributes pattern for TableAttributes enum with four NSAttributedString.Key constants. TableColorInfo as NSObject subclass with six resolved NSColor properties. TableCellMap as NSObject subclass with O(log n) binary search for cell lookup, O(n) range intersection via binary search + linear scan, tab-delimited and RTF content extraction. CellPosition uses Comparable+Hashable+Sendable with row -1 for header convention.
    - **Deviations**: None
    - **Tests**: 37/37 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ✅ PASS |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

### Builder and Parallel Dependents

- [x] **T2**: Implement table invisible text generation in MarkdownTextStorageBuilder `[complexity:complex]`

    **Reference**: [design.md#34-tableoverlayinfo](design.md#34-tableoverlayinfo), [design.md#35-markdowntextstoragebuilder-changes](design.md#35-markdowntextstoragebuilder-changes)

    **Effort**: 10 hours

    **Acceptance Criteria**:

    - [x] `TableOverlayInfo` struct added to `MarkdownTextStorageBuilder.swift` with blockIndex, block, tableRangeID, cellMap fields
    - [x] `TextStorageResult` extended with `tableOverlays: [TableOverlayInfo]` property
    - [x] New `appendTableInlineText` method in `MarkdownTextStorageBuilder+TableInline.swift` replacing attachment-based table rendering
    - [x] Table text uses `.foregroundColor: NSColor.clear` for invisible rendering
    - [x] Tab stops match cumulative column widths from `TableColumnSizer.computeWidths`
    - [x] Each row ends with newline; cells separated by tab characters
    - [x] `TableAttributes.range` set to unique UUID string on all table characters
    - [x] `TableAttributes.cellMap` set to same TableCellMap instance on all table characters
    - [x] `TableAttributes.colors` set to TableColorInfo on all table characters
    - [x] `TableAttributes.isHeader` set to true on header row characters only
    - [x] Paragraph style has fixed minimum line height matching visual row height, paragraphSpacing 0 for tight rows
    - [x] `isPrint: Bool` parameter added to builder; when true, uses visible foreground color instead of clear
    - [x] Modified tests in `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTableTests.swift` for invisible text attributes, tab structure, TableAttributes presence, print mode visibility, tableOverlays population

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`, `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift`, `mkdn/Core/Markdown/MarkdownTextStorageBuilder+TableInline.swift`, `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTests.swift`, `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTableTests.swift`
    - **Approach**: Added TableOverlayInfo struct and extended TextStorageResult with tableOverlays array (default empty for backward compat). Extracted table inline text generation into new +TableInline.swift extension with TableRowContext struct to bundle row-building parameters. appendTableInlineText replaces attachment-based table rendering, generating invisible (clear foreground) tab-separated text with fixed line heights and all four TableAttributes set on appropriate characters. Tab stops computed from cumulative TableColumnSizer column widths. isPrint parameter propagated through both build methods to switch between clear and visible foreground. Table tests extracted into dedicated MarkdownTextStorageBuilderTableTests.swift suite with 16 tests covering all acceptance criteria.
    - **Deviations**: Method placed in new +TableInline.swift file instead of +Complex.swift to satisfy SwiftLint file_length limit. Test file split into separate table test suite for the same reason.
    - **Tests**: 53/53 passing (37 original + 16 table)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ✅ PASS |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [ ] **T5**: Implement copy handler for RTF and tab-delimited clipboard output `[complexity:medium]`

    **Reference**: [design.md#38-codeblockbackgroundtextview-copy-override](design.md#38-codeblockbackgroundtextview-copy-override)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] `copy(_:)` override in `CodeBlockBackgroundTextView` detects table text in selection via `TableAttributes.cellMap`
    - [ ] When selection contains no table text, delegates to `super.copy(_:)`
    - [ ] `buildMixedClipboard` method walks selected range in document order, concatenating non-table text and formatted table content
    - [ ] RTF data placed on pasteboard as `.rtf` type
    - [ ] Tab-delimited plain text placed on pasteboard as `.string` type
    - [ ] Each table row maps to one line; columns separated by tab characters
    - [ ] Mixed selections (paragraph + table + paragraph) produce correctly ordered output
    - [ ] Header row included in output when selected (no separator line)

- [ ] **T6**: Extend EntranceAnimator to group table layout fragments `[complexity:simple]`

    **Reference**: [design.md#310-entranceanimator-table-grouping](design.md#310-entranceanimator-table-grouping)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [ ] Existing `codeBlockID(for:...)` method renamed to `blockGroupID(for:...)`
    - [ ] `blockGroupID` checks `TableAttributes.range` after `CodeBlockAttributes.range`
    - [ ] Table fragments return `"table-\(tableID)"` as group ID
    - [ ] All fragments sharing a table group ID get a single cover layer and shared stagger timing
    - [ ] Code block grouping behavior unchanged (no regression)
    - [ ] Reduce Motion respected (immediate appearance when enabled)

### Overlay Positioning and Print Path

- [x] **T3**: Extend OverlayCoordinator for text-range-based table overlay positioning `[complexity:complex]`

    **Reference**: [design.md#36-overlaycoordinator-extensions](design.md#36-overlaycoordinator-extensions)

    **Effort**: 10 hours

    **Acceptance Criteria**:

    - [x] `OverlayEntry` extended with optional `tableRangeID`, `highlightOverlay`, and `cellMap` fields
    - [x] `updateTableOverlays(tableOverlays:appSettings:documentState:in:)` creates/updates table visual overlays and their highlight overlay siblings
    - [x] `positionTextRangeEntry` positions overlay by scanning for `TableAttributes.range` matching tableRangeID, enumerating layout fragments, computing bounding rect union
    - [x] `updateTableSelections(selectedRange:)` maps NSTextView selection to cells per table via cellMap, updates each TableHighlightOverlay
    - [x] `updateTableFindHighlights(matchRanges:currentIndex:theme:)` maps find matches to table cells, updates highlight overlays with find state
    - [x] TableHighlightOverlay created and positioned on top of visual overlay for each table
    - [x] Sticky header logic updated to source column widths from TableCellMap on the entry
    - [x] Text-range overlays position correctly when scrolling

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/OverlayCoordinator.swift`, `mkdn/Features/Viewer/Views/OverlayCoordinator+TableOverlays.swift`, `mkdn/Features/Viewer/Views/OverlayCoordinator+Observation.swift`, `mkdn/Features/Viewer/Views/TableHighlightOverlay.swift`
    - **Approach**: Extended OverlayEntry with optional tableRangeID, highlightOverlay (TableHighlightOverlay), and cellMap fields. Split OverlayCoordinator into three files to satisfy SwiftLint file/type length limits: core coordinator, +TableOverlays extension (table lifecycle, text-range positioning, selection/find mapping), and +Observation extension (layout/scroll observers, sticky headers). Table overlays use text-range-based positioning by scanning for TableAttributes.range in the text storage, enumerating layout fragments to compute bounding rects. Created minimal TableHighlightOverlay NSView subclass with hitTest passthrough and properties for selected/find cells (drawing implementation deferred to a subsequent task). Removed tableColumnWidths dictionary in favor of cellMap.columnWidths. Removed dead .table case from attachment overlay path since T2 moved tables to inline text.
    - **Deviations**: Dropped documentState parameter from updateTableOverlays (not needed for table overlays, unlike images). Dropped theme parameter from updateTableFindHighlights (colors will be set on overlay in a subsequent task). Split into 3 files instead of 2 to satisfy SwiftLint 500-line file limit and 350-line type body limit.
    - **Tests**: 512/512 passing (3 pre-existing failures in AppSettings unrelated)

    **Review Feedback** (Attempt 1):
    - **Status**: FAILURE
    - **Issues**:
        - [comments] Task ID reference "(T4)" in doc comment of TableHighlightOverlay.swift. Removed in Attempt 2.
    - **Resolution**: Replaced "(T4)" with neutral phrasing "in a separate pass" in the doc comment.

- [ ] **T7**: Implement print path table container rendering `[complexity:medium]`

    **Reference**: [design.md#313-print-path](design.md#313-print-path)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] `drawTableContainers(in:)` method in `CodeBlockBackgroundTextView` renders table backgrounds during print only
    - [ ] Enumerates `TableAttributes.range` in textStorage to find table regions
    - [ ] Computes bounding rects from layout fragments for each table
    - [ ] Draws rounded-rect border using `TableColorInfo.border`
    - [ ] Draws header row background using `TableColorInfo.headerBackground`
    - [ ] Draws alternating row backgrounds using `TableColorInfo.background` and `TableColorInfo.backgroundSecondary`
    - [ ] `drawTableContainers` called from `drawBackground` only when `isPrinting` is true
    - [ ] Print output shows visible table text (verified by builder's `isPrint: true` flag)

### Highlight Overlay and Integration

- [ ] **T4**: Implement TableHighlightOverlay for cell-level selection and find drawing `[complexity:medium]`

    **Reference**: [design.md#37-tablehighlightoverlay](design.md#37-tablehighlightoverlay)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] New file `mkdn/Features/Viewer/Views/TableHighlightOverlay.swift` with NSView subclass
    - [ ] `hitTest(_:)` returns nil (all mouse events pass through)
    - [ ] `selectedCells` property drives selection highlight drawing
    - [ ] `findHighlightCells` and `currentFindCell` properties drive find highlight drawing
    - [ ] Cell rectangles computed from `TableCellMap.columnWidths` and `TableCellMap.rowHeights`
    - [ ] Selection highlight uses system accent color at 0.3 opacity for data cells
    - [ ] Header cell selection uses 0.4 opacity for subtle differentiation (FR-012)
    - [ ] Find highlights use theme's findHighlight color at 0.15 opacity for passive matches
    - [ ] Current find match uses 0.4 opacity
    - [ ] `setNeedsDisplay()` called on state changes to trigger redraw

- [ ] **T8**: Wire selection change and find integration through SelectableTextView `[complexity:medium]`

    **Reference**: [design.md#39-selection-change-handler](design.md#39-selection-change-handler), [design.md#312-find-integration](design.md#312-find-integration)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] `textViewDidChangeSelection(_:)` implemented in `SelectableTextView.Coordinator`
    - [ ] Selection change delegates to `overlayCoordinator.updateTableSelections(selectedRange:)`
    - [ ] `handleFindUpdate` calls `overlayCoordinator.updateTableFindHighlights` after `applyFindHighlights`
    - [ ] `tableOverlays` from `TextStorageResult` passed through `SelectableTextView` to `OverlayCoordinator`
    - [ ] Find Next/Previous navigates to matches inside tables via `scrollRangeToVisible`
    - [ ] Find match count includes table cell matches
    - [ ] Selection highlight updates in real time as mouse moves

### User Docs

- [ ] **TD1**: Update architecture.md - Tables rendering pipeline `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Tables rendering pipeline

    **KB Source**: architecture.md:Tables

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Section reflects the dual-layer rendering model: invisible text in NSTextStorage + SwiftUI visual overlay + TableHighlightOverlay
    - [ ] Pipeline change from attachment-based to inline invisible text documented

- [ ] **TD2**: Update modules.md - Core/Markdown new files `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Core/Markdown

    **KB Source**: modules.md:Markdown

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] TableAttributes.swift entry added with purpose description
    - [ ] TableCellMap.swift entry added with purpose description
    - [ ] MarkdownTextStorageBuilder+Complex.swift entry updated to reflect table inline text generation

- [ ] **TD3**: Update modules.md - Features/Viewer/Views new and modified files `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Features/Viewer/Views

    **KB Source**: modules.md:Viewer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] TableHighlightOverlay.swift entry added with purpose description
    - [ ] OverlayCoordinator.swift entry updated to mention text-range positioning and table selection/find management
    - [ ] EntranceAnimator.swift entry updated to mention table fragment grouping
    - [ ] CodeBlockBackgroundTextView.swift entry updated to mention table copy override and print table containers

- [ ] **TD4**: Update patterns.md - Dual-layer table rendering pattern `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: (new section)

    **KB Source**: patterns.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New section documents the dual-layer table rendering pattern (invisible text + visual overlay + highlight overlay)
    - [ ] TableAttributes pattern documented as parallel to CodeBlockAttributes

## Acceptance Criteria Checklist

### Must Have
- [ ] FR-001: Cross-cell selection with cell-level granularity highlights (AC-1, AC-2, AC-3)
- [ ] FR-002: Cross-block selection continuity from paragraph through table to paragraph (AC-1, AC-2, AC-3)
- [ ] FR-003: Cmd+A selects all content including table text (AC-1, AC-2)
- [ ] FR-004: Cmd+C produces RTF primary + tab-delimited plain text fallback (AC-1, AC-2, AC-3, AC-4, AC-5)
- [ ] FR-005: Mixed selection copy preserves paragraph + table content in order (AC-1, AC-2, AC-3)
- [ ] FR-006: Cmd+F finds text within table cells, navigable with Find Next/Previous (AC-1, AC-2, AC-3, AC-4)
- [ ] FR-007: Visual rendering parity -- no visual regression in table appearance (AC-1, AC-2, AC-3)
- [ ] FR-011: Selection overlay passes through all mouse events (AC-1, AC-2, AC-3)

### Should Have
- [ ] FR-008: Print path renders tables with visible text and proper containers (AC-1, AC-2, AC-3)
- [ ] FR-009: Entrance animation groups table fragments as single unit (AC-1, AC-2, AC-3)
- [ ] FR-010: Sticky header pins correctly with updated table text representation (AC-1, AC-2, AC-3)

### Could Have
- [ ] FR-012: Header cell selection highlight visually distinguishable from data cell (AC-1, AC-2)

### Non-Functional
- [ ] NFR-001: Selection overlay redraw within 16ms
- [ ] NFR-002: 60fps scrolling with up to 5 tables of 100 rows
- [ ] NFR-003: O(log n) cell-to-position lookup
- [ ] NFR-004: O(rows x columns) memory per table
- [ ] NFR-008: TextKit 2 throughout, no TextKit 1 fallback
- [ ] NFR-009: SwiftLint strict mode + SwiftFormat clean
- [ ] NFR-010: Correct Swift 6 concurrency annotations

## Definition of Done

- [ ] All 12 tasks completed
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] `swift build` compiles clean
- [ ] `swift test` passes all unit tests
- [ ] `DEVELOPER_DIR=/Applications/Xcode-16.3.0.app/Contents/Developer swiftlint lint` clean
- [ ] `swiftformat .` clean
- [ ] Visual test harness screenshot comparison shows no regression
- [ ] Docs updated (TD1-TD4)
