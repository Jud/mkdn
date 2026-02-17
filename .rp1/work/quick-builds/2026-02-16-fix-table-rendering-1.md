# Quick Build: Fix Table Rendering

**Created**: 2026-02-16T00:00:00Z
**Request**: Fix table rendering: remove horizontal scroll, force text wrapping, cap total table width to container width. Tables with wide content (like 5-column Design Decisions Log) should wrap cell text instead of scrolling off-screen. Also improve table visual contrast (borders, header background, row alternation) on dark theme.
**Scope**: Medium

## Plan

**Reasoning**: 3 primary files affected (TableColumnSizer, TableBlockView, TableHeaderView), 1 system (table rendering within overlay pipeline), low-medium risk since changes are visual-only with no data flow impact. The overlay coordinator wiring (makeTableOverlay, updateAttachmentSize, preferredWidth) does not need structural changes -- it already handles dynamic resizing via the onSizeChange callback. The core change is in the sizing algorithm and visual styling.

**Files Affected**:
- `mkdn/Core/Markdown/TableColumnSizer.swift` -- change sizing algorithm to distribute columns within container width (no horizontal scroll)
- `mkdn/Features/Viewer/Views/TableBlockView.swift` -- remove scroll wrapper, improve border/header/row-alt contrast for dark theme
- `mkdn/Features/Viewer/Views/TableHeaderView.swift` -- match updated visual contrast from TableBlockView

**Approach**: Replace the current "measure intrinsic width, cap at 60%, allow horizontal scroll if overflow" algorithm with a "fit to container" algorithm: compute intrinsic widths, then proportionally compress columns that exceed their fair share so the total always fits within containerWidth. Remove the `needsHorizontalScroll` path entirely from TableBlockView. For visual contrast, increase border opacity from 0.3 to a more visible level, give the header row a more distinct background tint, and increase the alternating row opacity difference. The TableHeaderView sticky header must match these visual changes.

**Estimated Effort**: 2-3 hours

## Tasks

- [x] **T1**: Rewrite `TableColumnSizer.computeWidths` to always fit within containerWidth -- replace scroll fallback with proportional column compression, remove `needsHorizontalScroll` from Result `[complexity:medium]`
- [x] **T2**: Update `TableBlockView` to remove the horizontal ScrollView branch, remove `.fixedSize(horizontal: true, vertical: false)`, and ensure the table body uses `maxWidth: containerWidth` with text wrapping `[complexity:medium]`
- [x] **T3**: Improve table visual contrast in `TableBlockView` -- increase border stroke opacity, add distinct header background, increase row alternation contrast for dark theme readability `[complexity:simple]`
- [x] **T4**: Update `TableHeaderView` to match the new visual contrast (header background, border styling) from T3 `[complexity:simple]`
- [x] **T5**: Update `TableColumnSizer.estimateTableHeight` to account for increased wrapping from narrower columns, ensuring overlay height estimates remain accurate `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Core/Markdown/TableColumnSizer.swift` | Replaced 60%-cap + scroll fallback with fair-share locking + proportional compression algorithm in extracted `compressColumns` helper. Removed `needsHorizontalScroll` from `Result`, removed `maxColumnWidthFraction` constant. | Done |
| T2 | `mkdn/Features/Viewer/Views/TableBlockView.swift` | Removed `tableContent` scroll-vs-no-scroll branch and horizontal ScrollView. Removed `.fixedSize(horizontal: true, vertical: false)`. Added `.frame(maxWidth: containerWidth)`. | Done |
| T3 | `mkdn/Features/Viewer/Views/TableBlockView.swift` | Border stroke opacity 0.3 -> 0.5. Header gets additional `foregroundSecondary.opacity(0.06)` background layer. Row alternation opacity 0.5 -> 0.7. | Done |
| T4 | `mkdn/Features/Viewer/Views/TableHeaderView.swift` | Matched T3 visual changes: added `foregroundSecondary.opacity(0.06)` header background layer, divider border opacity to 0.5. | Done |
| T5 | `mkdn/Core/Markdown/TableColumnSizer.swift` | Added `wrappingOverhead` factor (1.2x) to `estimateRowHeight` to account for word-boundary breaks in narrower compressed columns. | Done |

## Verification

{To be added by task-reviewer if --review flag used}
