# Tables

## Overview

Tables renders Markdown tables as native SwiftUI views with content-aware column sizing, text wrapping, and cross-cell text selection. The feature has two layers: **Smart Tables** handles visual layout (column measurement, wrapping, sticky headers), while **Cross-Cell Selection** makes table text part of the NSTextStorage so selection, find, and clipboard operations flow continuously across cell and block boundaries.

Tables are SwiftUI-only (no WKWebView). The visual overlay (`TableBlockView`) provides pixel-perfect rendering. An invisible text layer in the NSTextStorage provides selection, find, and copy semantics. A third layer (`TableHighlightOverlay`) draws cell-level selection and find highlights on top.

## User Experience

- **Content-aware widths**: Columns size to their content. Narrow tables stay narrow; wide tables compress proportionally to fit the container.
- **Text wrapping**: Long cell content wraps at word boundaries. Rows grow to fit. No truncation or clipping ever.
- **Column alignment**: Markdown colon syntax (`:---`, `:---:`, `---:`) controls left/center/right alignment.
- **Sticky headers**: When scrolling through tall tables, the header row pins at the viewport top.
- **Cross-cell selection**: Click-drag selects at cell granularity. Selection flows continuously from paragraph through table cells into the next paragraph.
- **Copy**: Cmd+C places RTF (primary, preserves table structure in rich text editors) and tab-delimited plain text (fallback, lands correctly in spreadsheets) on the pasteboard.
- **Find**: Cmd+F matches text inside table cells. Matches are highlighted in the visual overlay and navigable via Find Next/Previous.
- **Themes**: All colors sourced from `ThemeColors`. Tables adapt instantly on theme switch. Zebra-striped rows, distinct header background, rounded 6pt border.

## Architecture

Dual-layer rendering driven by a shared data model:

1. **Invisible text layer** -- `MarkdownTextStorageBuilder+TableInline` appends each table as clear-foreground text with tab-separated cells and newline-separated rows into the NSTextStorage. Custom `TableAttributes` keys tag every character with a table ID, `TableCellMap`, color info, and header flag. This layer handles all interaction: selection, find, clipboard, Select All.

2. **Visual overlay layer** -- `OverlayCoordinator` positions an `NSHostingView` containing `TableBlockView` (SwiftUI) over the invisible text range. `TableBlockView` renders headers, data rows, borders, and alternating backgrounds using column widths from `TableColumnSizer`.

3. **Highlight overlay layer** -- `TableHighlightOverlay` (an NSView with `hitTest -> nil`) draws cell-level selection and find highlights on top of the visual overlay. The `OverlayCoordinator` feeds it selected cell sets derived from the NSTextView's selection range intersected with the `TableCellMap`.

Sticky headers use AppKit scroll observation: `OverlayCoordinator` watches `boundsDidChangeNotification` on the scroll view's clip view and positions a separate `TableHeaderView` NSHostingView at the viewport top when the original header scrolls out of view.

## Implementation Decisions

- **Invisible inline text for selection continuity**: Table text is appended to NSTextStorage with `.foregroundColor: .clear` so it participates in native TextKit 2 selection, find, and clipboard without being visible. The visual overlay provides the rendered appearance. This follows the same dual-layer pattern used for code blocks (`CodeBlockAttributes`).
- **Content-aware column sizing**: `TableColumnSizer` measures every cell with `NSAttributedString.size()` (same Core Text metrics as SwiftUI Text), adds 26pt horizontal padding per column, then fits within `containerWidth` via proportional compression -- columns at or below fair share keep intrinsic width, wider columns share remaining space proportionally.
- **RTF + TSV copy**: `TableCellMap.rtfData(for:colors:)` generates RTF with `\trowd`/`\cell`/`\row` markup. `TableCellMap.tabDelimitedText(for:)` generates plain text with tab-separated columns and newline-separated rows. Both are placed on the pasteboard simultaneously so the paste target picks the richest format it supports.
- **Sticky headers via scroll observation**: Since tables are overlays inside an NSTextView (no internal vertical ScrollView), LazyVStack `pinnedViews` is not viable. Instead, `OverlayCoordinator` observes scroll position and manages a separate `TableHeaderView` overlay.
- **Cell-level selection granularity**: Selecting any character in a cell highlights the full cell. Character-level sub-cell highlighting is deferred to a future version.
- **VStack over LazyVStack**: Tables up to 100 rows use VStack for straightforward height measurement. LazyVStack's deferred loading would complicate height calculation and sticky header positioning.

## Files

| File | Role |
|------|------|
| `mkdn/Core/Markdown/TableColumnSizer.swift` | Pure column width computation and height estimation |
| `mkdn/Core/Markdown/TableCellMap.swift` | Cell position lookup (binary search), range intersection, RTF/TSV clipboard generation |
| `mkdn/Core/Markdown/TableAttributes.swift` | NSAttributedString keys (`range`, `cellMap`, `colors`, `isHeader`) and `TableColorInfo` |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder+TableInline.swift` | Invisible text generation: tab stops, row heights, cell entries, paragraph styles |
| `mkdn/Features/Viewer/Views/TableBlockView.swift` | SwiftUI visual rendering: header, data rows, borders, zebra striping, size reporting |
| `mkdn/Features/Viewer/Views/TableHeaderView.swift` | Lightweight SwiftUI header clone for sticky header overlay |
| `mkdn/Features/Viewer/Views/TableHighlightOverlay.swift` | NSView drawing cell selection and find highlights, event pass-through |

## Dependencies

| Dependency | Relationship |
|------------|-------------|
| `ThemeColors` | All table colors sourced from the active theme |
| `OverlayCoordinator` | Manages table visual overlay, highlight overlay, sticky header, and text-range positioning |
| `CodeBlockBackgroundTextView` | Copy override detects `TableAttributes.cellMap` in selection, delegates to `TableCellMap` for clipboard |
| `SelectableTextView` | Forwards `textViewDidChangeSelection` to overlay coordinator for highlight updates |
| `EntranceAnimator` | Groups table layout fragments by `TableAttributes.range` for unified fade-in |
| `TableColumnSizer` | Consumed by both the builder (tab stops, row heights) and the visual overlay (column widths) |

## Testing

| Test file | Coverage |
|-----------|----------|
| `mkdnTests/Unit/Core/TableColumnSizerTests.swift` | Column width computation: narrow fit, compression, padding, bold header measurement, height estimation |
| `mkdnTests/Unit/Core/TableCellMapTests.swift` | Binary search cell lookup, range intersection, tab-delimited output, RTF generation, edge cases |
| `mkdnTests/Unit/Core/TableAttributesTests.swift` | Attribute key uniqueness, `TableColorInfo` storage |
| `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTableTests.swift` | Invisible text structure, clear foreground, tab-separated content, attribute presence, print-mode visible foreground |

Visual verification via test harness: load `fixtures/table-test.md`, capture screenshots at multiple scroll positions in both Solarized Light and Solarized Dark themes.
