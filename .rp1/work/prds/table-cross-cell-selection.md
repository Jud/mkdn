# PRD: Table Cross-Cell Selection

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-23

## Surface Overview

Table Cross-Cell Selection enables native macOS text selection that flows across table cells and across block boundaries (paragraph, table, paragraph) in mkdn's Markdown preview pane. Currently, tables are rendered as NSTextAttachment placeholders with SwiftUI overlays (TableBlockView), which gives beautiful visual rendering but zero cross-cell text selection -- each SwiftUI Text view has independent selection.

This feature implements a three-layer architecture:
1. **Layer 1 (bottom)**: Invisible tab-separated text in NSTextStorage with `.foregroundColor: .clear` and tab stops computed from TableColumnSizer. Receives all mouse events for native selection tracking.
2. **Layer 2 (middle)**: Visual SwiftUI TableBlockView overlay in PassthroughHostingView with `hitTest -> nil`. Identical to current rendering -- opaque backgrounds, borders, styled text.
3. **Layer 3 (top)**: Custom TableSelectionOverlay that observes `selectedRanges` and draws translucent cell-boundary highlights mapped from the invisible text selection via TableCellMap.

Selection granularity is cell-level initially (any selected character in a cell highlights the full cell), with character-level as a future upgrade. The architecture preserves TextKit 2 throughout and follows the established CodeBlockAttributes pattern for attribute tagging.

## Scope

### In Scope

- **TableBlockAttributes**: Custom NSAttributedString.Key constants (`.range`, `.colors`, `.cellMap`) following the CodeBlockAttributes pattern, plus TableCellMap data structure with binary search for character-to-cell mapping
- **Invisible table text**: Modify MarkdownTextStorageBuilder to emit tab-separated invisible text instead of NSTextAttachment placeholders for tables, using cumulative tab stops from TableColumnSizer.computeWidths()
- **PassthroughHostingView**: Generic NSHostingView subclass with `hitTest -> nil` for visual-only overlays, following MermaidContainerView pattern
- **OverlayCoordinator text-range positioning**: Extend OverlayCoordinator to position table overlays using text-range layout fragment geometry instead of attachment-based positioning
- **TableSelectionOverlay**: Transparent NSView that observes NSTextView.didChangeSelectionNotification, maps selected ranges to cells via TableCellMap, and draws translucent highlights at cell geometry positions
- **Cross-block selection continuity**: Seamless selection from paragraph text through table cells to paragraph text below
- **Copy/paste**: Markdown pipe-separated table format (`| Col A | Col B |`) for table content in clipboard
- **Print path**: Visible table text with proper backgrounds (rounded rect border, header background, alternating rows) using `tableTextVisible: true` parameter
- **Entrance animation grouping**: Group table layout fragments by TableBlockAttributes.range for unified fade-in (same as code block grouping in EntranceAnimator)
- **Sticky header update**: Adapt sticky header positioning from attachment frame to text-range frame
- **Unit tests**: TableCellMap mapping tests, TableBlockAttributes tagging tests, tab stop computation tests

### Out of Scope

- **Character-level sub-cell selection highlighting**: V1 uses cell-level granularity only. Character-level is a future upgrade.
- **Multi-line cell wrapping in invisible text**: Invisible text is single-line per row. The visual overlay handles wrapping; selection highlight covers the full visual cell regardless.
- **Dynamic tab stop rebuild on resize**: Tab stops are fixed at build time for V1. The visual overlay re-renders correctly via SwiftUI; invisible text tab stops may become slightly stale at extreme width changes. Follow-up: rebuild attributed string on significant container width changes.
- **Horizontal scrolling for wide tables**: Pre-existing gap, not addressed in this surface.
- **TextKit 1 / NSTextTable approach**: Rejected -- would break entrance animations, overlay positioning, and live resize.
- **Pixel-identical alignment between invisible text and visual overlay**: The visual SwiftUI TableBlockView handles all visual complexity. The invisible text layer is for selection/clipboard only. No attempt to make them pixel-identical.

## Requirements

### Functional Requirements

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-1 | Click-drag across multiple table cells produces a visible selection highlight tracing cell boundaries | Must | Visual test: load table fixture, drag across cells, capture screenshot showing blue cell highlights |
| FR-2 | Selection flows continuously from paragraph text above a table, through table cells, to paragraph text below | Must | Visual test: drag selection starting in paragraph, through table, ending in paragraph below |
| FR-3 | Cmd+A selects all content including table text | Must | Unit test: verify selectedRange spans full text storage after selectAll |
| FR-4 | Cmd+C on selected table cells copies Markdown pipe-separated format to clipboard | Must | Integration test: select table cells, copy, verify pasteboard contains `| Col | Col |` format |
| FR-5 | Mixed selection (paragraph + table) copies paragraph text verbatim concatenated with formatted table | Must | Integration test: select across boundary, verify clipboard format |
| FR-6 | Visual table rendering is identical to current behavior (TableBlockView overlay) | Must | Visual test: capture before/after screenshots, compare rendering |
| FR-7 | Cmd+P prints tables with visible text and proper container backgrounds (rounded rect, header bg, alternating rows, divider) | Should | Visual test: print preview screenshot comparison |
| FR-8 | Table entrance animation groups all table layout fragments for unified fade-in | Should | Animation test: verify table fragments animate as single unit |
| FR-9 | Sticky table headers work correctly using text-range frame positioning | Should | Visual test: scroll long table, verify header pins at viewport top |
| FR-10 | TableCellMap provides O(log n) character-to-cell lookup via binary search | Must | Unit test: verify cellPosition(forCharacterOffset:) returns correct (row, col) for known offsets |
| FR-11 | Selection highlight uses system accent color at 30% opacity (NSColor.selectedTextBackgroundColor.withAlphaComponent(0.3)) | Should | Visual test: verify highlight color matches system selection |
| FR-12 | TableSelectionOverlay passes through all mouse events (hitTest returns nil) | Must | Integration test: verify click-through to NSTextView layer |

### Non-Functional Requirements

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| NFR-1 | TextKit 2 is preserved throughout -- no fallback to TextKit 1 | Must | Code review: verify no NSLayoutManager, NSTextTable usage |
| NFR-2 | Selection overlay redraws within 16ms of selection change (single frame at 60fps) | Should | Performance test: measure didChangeSelection to drawRect latency |
| NFR-3 | No regression in scroll performance for documents with multiple tables | Should | Visual test: scroll long document with 5+ tables, verify smooth 60fps |
| NFR-4 | Memory: TableCellMap overhead is O(rows x columns) per table, no unbounded growth | Must | Code review: verify CellRange array sizing |
| NFR-5 | All new code passes SwiftLint strict mode and SwiftFormat | Must | `swiftlint lint` + `swiftformat .` clean |
| NFR-6 | All new types use Swift 6 concurrency annotations (@MainActor, Sendable) correctly | Must | `swift build` with strict concurrency checking |

## Dependencies & Constraints

### Dependencies

| Dependency | Type | Impact |
|------------|------|--------|
| TableColumnSizer | Internal | Single source of truth for column geometry. Both invisible text tab stops and visual overlay use `computeWidths()`. Changes to column width algorithm affect both layers. |
| CodeBlockAttributes pattern | Internal | TableBlockAttributes follows identical pattern -- NSAttributedString.Key constants with NSObject subclass value types. Must stay consistent. |
| OverlayCoordinator | Internal | Must be extended for text-range-based positioning alongside existing attachment-based positioning. Backward-compatible change. |
| CodeBlockBackgroundTextView | Internal | Must be extended with `drawTableContainers()` and copy override for table-attributed ranges. Additive change to existing code block drawing infrastructure. |
| EntranceAnimator | Internal | Must support grouping by TableBlockAttributes.range in addition to CodeBlockAttributes.range. Additive change. |
| NSTextView.didChangeSelectionNotification | System | Standard AppKit notification. No version constraints beyond macOS 14.0+. |
| TextKit 2 (NSTextLayoutManager) | System | Layout fragment enumeration for text-range positioning. Already used extensively by OverlayCoordinator and EntranceAnimator. |
| MarkdownTextStorageBuilder | Internal | Core modification point: table blocks switch from attachment path to inline text path. Most significant change in the feature. |
| SelectableTextView | Internal | Must wire selection observation and pass table info to new overlay components. |

### Constraints

| Constraint | Impact | Mitigation |
|------------|--------|------------|
| Tab stops are fixed at build time | Selection accuracy may degrade at extreme window width changes | V1 accepts this; follow-up rebuilds attributed string on significant width changes |
| NSTextView selection tracking is per-paragraph | Tab-separated cells within a paragraph are selected as contiguous text, not individually | Cell-level highlight granularity in overlay maps character ranges to whole-cell visual highlights |
| SwiftUI overlay is visual-only (no hit testing) | Cannot use SwiftUI for selection interaction | By design: invisible text layer handles all interaction |
| NSAttributedString attribute values must be NSObject or bridged | TableCellMap must be NSObject subclass | Follows established CodeBlockColorInfo pattern |
| macOS 14.0+ minimum deployment target | All TextKit 2 APIs available | No constraint -- TextKit 2 APIs used are available since macOS 12 |

## Milestones & Timeline

### Phase 1: Foundation (TableBlockAttributes + TableCellMap)

**Deliverables**: `TableBlockAttributes.swift`, `TableCellMap` with binary search, unit tests
**Verification**: `swift test` -- TableCellMap mapping, attribute key constants
**Risk**: Low -- follows established CodeBlockAttributes pattern exactly

**Files**:
- NEW: `mkdn/Core/Markdown/TableBlockAttributes.swift`
- NEW: `mkdnTests/Unit/Core/TableCellMapTests.swift`
- NEW: `mkdnTests/Unit/Core/TableBlockAttributesTests.swift`

### Phase 2: Invisible Table Text

**Deliverables**: Modified MarkdownTextStorageBuilder (route tables to inline path), upgraded tab stops with real column widths, invisible text with attribute tagging
**Verification**: `swift build` clean, unit tests for tab stop computation, visual test confirming table overlay still renders
**Risk**: Medium -- core rendering pipeline change; must preserve all existing table visual rendering

**Files**:
- MODIFY: `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` -- change `.table` case from `appendAttachmentBlock()` to inline text path, add `tableTextVisible` parameter
- MODIFY: `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift` -- upgrade `appendTable()` with cumulative tab stops from TableColumnSizer, `.foregroundColor: .clear`, TableBlockAttributes tagging

### Phase 3: PassthroughHostingView + OverlayCoordinator

**Deliverables**: PassthroughHostingView, text-range-based overlay positioning, AttachmentInfo extension
**Verification**: Visual test: tables still render correctly, overlays position at correct geometry
**Risk**: Medium -- OverlayCoordinator is critical infrastructure; text-range positioning must coexist with attachment positioning

**Files**:
- NEW: `mkdn/Features/Viewer/Views/PassthroughHostingView.swift`
- MODIFY: `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` -- text-range positioning, PassthroughHostingView for tables, selection overlay lifecycle

### Phase 4: TableSelectionOverlay

**Deliverables**: TableSelectionOverlay view, selection observation wiring
**Verification**: Visual test: click-drag across cells shows blue highlights; cross-block selection works
**Risk**: Medium -- notification-based selection tracking must be responsive without performance impact

**Files**:
- NEW: `mkdn/Features/Viewer/Views/TableSelectionOverlay.swift`
- MODIFY: `mkdn/Features/Viewer/Views/SelectableTextView.swift` -- wire selection observation, pass table info

### Phase 5: Copy/Paste

**Deliverables**: Copy override for table-attributed ranges with Markdown pipe-separated formatting
**Verification**: Integration test: select table, Cmd+C, verify pipe-separated Markdown in clipboard
**Risk**: Low -- follows existing copyCodeBlock pattern

**Files**:
- MODIFY: `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` -- override `copy(_:)` for table-attributed ranges

### Phase 6: Print Path

**Deliverables**: Table container drawing in print path, visible table text for print
**Verification**: Visual test: Cmd+P shows tables with visible text and proper backgrounds
**Risk**: Low -- follows existing drawCodeBlockContainers pattern

**Files**:
- MODIFY: `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` -- add `drawTableContainers(in:)` alongside `drawCodeBlockContainers(in:)`

### Phase 7: Polish

**Deliverables**: EntranceAnimator grouping, sticky header update, resize acceptance
**Verification**: Animation test (unified fade-in), visual test (sticky headers), lint/format clean
**Risk**: Low -- additive changes to existing systems

**Files**:
- MODIFY: `mkdn/Features/Viewer/Views/EntranceAnimator.swift` -- group by TableBlockAttributes.range
- MODIFY: `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` -- sticky header frame source update

### Known Deadlines

No external deadlines. This is a quality-of-life feature for the daily-driver success criterion. Implementation should be phased to keep the app shippable after each phase (each phase builds on the previous but the app remains functional if a later phase is deferred).

## Open Questions

| ID | Question | Impact | Status |
|----|----------|--------|--------|
| OQ-1 | Should cell-level selection highlight the header row differently (e.g., bold highlight border)? | Visual polish | Open -- decide during Phase 4 implementation |
| OQ-2 | Should Cmd+C from a full-table selection include the header separator line (`|---|---|`)? | Clipboard format fidelity | Open -- decide during Phase 5; leaning yes for Markdown round-trip fidelity |
| OQ-3 | Should the tab stop rebuild on resize be triggered by a threshold (e.g., >50pt width change) or on every resize end? | Performance vs accuracy tradeoff | Deferred to follow-up |

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A1 | TextKit 2 layout fragment enumeration for text ranges performs equivalently to attachment-based enumeration | Overlay positioning could be slower or less reliable; may need caching | Design Philosophy: "obsessive attention to sensory detail" |
| A2 | NSTextView.didChangeSelectionNotification fires synchronously on the main thread for all selection changes | Selection overlay could lag or miss updates | Design Philosophy: responsive interaction |
| A3 | Tab-separated invisible text with .clear foreground does not affect TextKit 2 line height or paragraph spacing calculations | Could cause layout mismatches between invisible text and visual overlay | Will Do: terminal-consistent theming |
| A4 | Cell-level selection granularity is sufficient for user satisfaction (vs character-level) | Users may expect finer-grained selection; browser comparison sets expectations | Success Criteria: daily-driver use |
| A5 | PassthroughHostingView with hitTest->nil reliably passes all mouse events to the underlying NSTextView on macOS 14+ | Edge cases in responder chain could swallow events | Won't Do: no plugin system (simpler responder chain) |
| A6 | Existing TableColumnSizer.computeWidths() output is stable enough for tab stop positioning across the invisible text lifetime | Column width changes on resize could desynchronize layers | Scope Guardrails: file-change detection (implies static content model) |

