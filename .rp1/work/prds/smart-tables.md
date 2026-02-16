# PRD: Smart Tables

**Charter**: [Project Charter](.rp1/context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-11

## Surface Overview

Smart Tables replaces the current full-width, clipping table renderer in mkdn with a content-aware table display that sizes columns to fit their data, wraps long text instead of truncating, and adapts gracefully to diverse table shapes -- from narrow two-column key-value pairs to wide multi-column data sets. The rendering follows GitHub Markdown table semantics (content-driven column widths, text wrapping, horizontal scroll when needed) implemented entirely in native SwiftUI (no WKWebView). This directly serves mkdn's target users -- developers viewing LLM-generated Markdown artifacts that frequently contain tabular data in varied shapes and sizes.

## Scope

### In Scope

- Content-aware column sizing: columns sized to intrinsic content width, not equal-width
- Text wrapping within cells (break-word semantics) -- never clip or truncate
- Table width = sum of column widths + padding, capped at container width; narrow tables do NOT stretch to fill
- Horizontal scrolling when total table width exceeds container width
- Column alignment (left/center/right) from Markdown colon syntax, applied to header and data cells
- Alternating row background colors using theme colors
- Visually distinct header row (bold text, secondary background, bottom border)
- Cell padding: 6pt vertical, 13pt horizontal
- 1px border with rounded corners (6pt radius)
- Overlay width matches actual table width (narrow tables left-aligned, not stretched to container)
- Full click-drag text selection across table cells
- Sticky/frozen headers when scrolling vertically through tables taller than the viewport

### Out of Scope

- Sortable columns
- Resizable columns (drag-to-resize)
- Editable cells or inline editing
- Row selection / interactive row actions
- Column filtering
- CSV import or export
- Responsive breakpoints or mobile-style table layouts

## Requirements

### Functional Requirements

| ID | Requirement | Notes |
|----|-------------|-------|
| FR-1 | Column widths sized to intrinsic content | Measure header and data cell content; use max width per column. No equal-width distribution. |
| FR-2 | Text wrapping within cells (break-word) | Long text wraps to multiple lines. Never clips or truncates. Row height grows to accommodate. |
| FR-3 | Table width = sum of column widths + padding, capped at container | Narrow tables do NOT stretch to fill container width. Table is left-aligned within its container. |
| FR-4 | Horizontal scrolling when table exceeds container | Wrap table body in horizontal ScrollView. Scrollbar visible on hover/scroll. |
| FR-5 | Column alignment from Markdown syntax | Left (`:---`), center (`:---:`), right (`---:`) applied to both header and data cells. Default: left. |
| FR-6 | Alternating row backgrounds | Even rows: theme `background`. Odd rows: theme `backgroundSecondary` at 50% opacity. |
| FR-7 | Distinct header row | Bold text, `backgroundSecondary` fill, bottom border/divider separating header from body. |
| FR-8 | Cell padding | 6pt vertical, 13pt horizontal. |
| FR-9 | Rounded-corner border | 1px stroke using theme `border` color at 30% opacity, 6pt corner radius. |
| FR-10 | Overlay width matches actual table width | OverlayCoordinator positions overlay at actual computed table width, not full container width. Narrow tables left-aligned. |
| FR-11 | Click-drag text selection across cells | `.textSelection(.enabled)` on cell text. Selection spans across cells via standard macOS text selection. |
| FR-12 | Sticky/frozen headers on vertical scroll | Header row pins to the top of the visible area only when the table is taller than the viewport. Tables that fit entirely on screen never show a sticky header. |

### Non-Functional Requirements

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-1 | Performance | Tables up to 100 rows render and scroll without perceptible lag (<16ms frame time). |
| NFR-2 | Theme awareness | All colors sourced from `ThemeColors`. Adapts to theme changes without restart. |
| NFR-3 | Native implementation | SwiftUI only. No WKWebView, no HTML tables. |
| NFR-4 | Accessibility | Respects Dynamic Type / system font size scaling. Column widths recalculate on font size change. |

## Dependencies & Constraints

### Files to Modify

| File | Change |
|------|--------|
| `mkdn/Features/Viewer/Views/TableBlockView.swift` | Full rewrite. Replace `maxWidth: .infinity` equal-width layout with content-measuring intrinsic-width layout. Add horizontal ScrollView, sticky header, text wrapping. |
| `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` | Update `positionEntry` and `makeTableOverlay` to support variable-width overlays. Table overlays should be positioned at their actual computed width rather than forced to `containerWidth`. |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` | Update table height estimation to account for dynamic row heights from text wrapping (current fixed `rowHeight: 32` will underestimate). May need callback-based height update similar to Mermaid pattern. |

### No Changes Needed

- `MarkdownBlock.swift` -- existing `.table(columns, rows)` enum case is sufficient
- `ThemeColors` -- existing color properties cover all needed values

### External Dependencies

None. Pure SwiftUI implementation using existing framework APIs.

### Technical Constraints

1. **Tables are NSHostingView overlays**: Tables render as SwiftUI views hosted in `NSHostingView`, positioned over `NSTextAttachment` placeholders in the `NSTextView`. This means table width/height must be communicated back to the attachment system.
2. **Sticky headers require nested scroll or split subview**: Since the table is an overlay within a scrolling `NSTextView`, sticky headers cannot rely on a simple outer `ScrollView`. Implementation options: (a) split the table into a pinned header subview and a body subview, repositioning the header on scroll; (b) use a nested `ScrollView` with `pinnedViews: [.sectionHeaders]` inside a `LazyVStack`.
3. **Dynamic height via updateAttachmentHeight**: The existing pattern (used by Mermaid) calls `OverlayCoordinator.updateAttachmentHeight(blockIndex:newHeight:)` after the view measures itself. Tables should adopt this same pattern -- render, measure actual height (accounting for wrapped text), then update the placeholder attachment height to match.
4. **Content measurement**: Column width calculation requires measuring text content before layout. Use `NSAttributedString.size()` or SwiftUI's `GeometryReader` to determine intrinsic content widths, then distribute widths before the final layout pass.

## Milestones

| Phase | Description | Key Deliverables |
|-------|-------------|------------------|
| M1: Content-Aware Sizing | Column width measurement + intrinsic sizing | FR-1, FR-3, FR-8, FR-9, FR-10 |
| M2: Text Wrapping & Scroll | Cell wrapping + horizontal overflow | FR-2, FR-4, dynamic height callback |
| M3: Visual Polish | Alignment, alternating rows, header styling | FR-5, FR-6, FR-7 |
| M4: Interaction & Advanced | Text selection, sticky headers | FR-11, FR-12, NFR-1 |

## Open Questions

| ID | Question | Impact |
|----|----------|--------|
| OQ-1 | Should column width measurement use a two-pass approach (measure all cells, then layout) or a single-pass with GeometryReader adjustments? | Performance for large tables |
| OQ-2 | For sticky headers, should we split into two NSHostingViews (header + body) or use LazyVStack with pinnedViews? | Implementation complexity vs. scroll behavior |
| OQ-3 | Should there be a maximum column width before wrapping is forced, even if content would fit on one line? | Very wide single-column content could produce awkward layouts |
| OQ-4 | How should the table behave when the window is narrower than a single column's minimum content width? | Edge case for very narrow windows |

## Assumptions & Risks

| ID | Assumption | Risk if Wrong |
|----|------------|---------------|
| A-1 | NSAttributedString.size() provides accurate enough width measurements for column sizing | Column widths may be slightly off, requiring fallback to GeometryReader-based measurement |
| A-2 | SwiftUI LazyVStack with pinnedViews will work correctly inside an NSHostingView overlay | May need to fall back to manual header repositioning via scroll offset observation |
| A-3 | Tables up to 100 rows can be rendered without lazy loading | Large tables may need LazyVStack for performance; adds complexity to sticky headers |
| A-4 | The updateAttachmentHeight callback pattern (proven with Mermaid) will scale to tables with dynamic wrapping heights | Tables may resize more frequently than Mermaid (on window resize, font change), potentially causing layout thrashing |
