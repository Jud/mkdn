# Design Decisions: Smart Tables

**Feature ID**: smart-tables
**Created**: 2026-02-11

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | Column width measurement API | `NSAttributedString.size()` | Synchronous, deterministic, uses same Core Text font metrics as SwiftUI Text. No async layout passes or measurement jitter. Proven AppKit API. | GeometryReader-based measurement (async, causes multiple layout passes, potential thrashing), SwiftUI intrinsic sizing with fixedSize() (widths unpredictable, no programmatic access to computed value) |
| D2 | Maximum column width cap | `containerWidth * 0.6` | Adaptive to window size. Ensures at least two columns remain visible side-by-side before horizontal scroll kicks in. Prevents a single column with long content from consuming the entire table width. | Fixed 400pt cap (does not adapt to window width; too wide on narrow windows, too narrow on ultra-wide), No cap (single long-content column could dominate, making multi-column tables effectively single-column) |
| D3 | Behavior when total column width exceeds container | Horizontal scroll with original column widths preserved | Preserves column readability by keeping each column at its content-appropriate width. Compressing columns would increase text wrapping density, making cells harder to read. Matches GitHub Markdown rendering behavior. | Proportionally shrink all columns to fit (causes dense text wrapping in every column), Two-stage: compress to minimum then scroll (complex heuristics, inconsistent user experience) |
| D4 | Variable-width overlay strategy | Optional `preferredWidth` field on `OverlayEntry` | Minimal, backward-compatible change. Existing overlay types (mermaid, images, thematic breaks) continue using `containerWidth` via `nil` default. Only tables opt into variable width. No new protocols or coordinator types needed. | Separate `TableOverlayCoordinator` subclass (code duplication, split responsibility), Width callback protocol on overlay views (over-engineered for a single consumer, adds protocol conformance burden) |
| D5 | Sticky header implementation | AppKit scroll observation + separate `NSHostingView` pinned within scroll view | The table is an NSHostingView overlay inside an NSTextView inside an NSScrollView. There is no SwiftUI `ScrollView` wrapping the table body, so `LazyVStack(pinnedViews: .sectionHeaders)` cannot work. Observing the parent `NSScrollView.contentView.bounds` is the only way to detect when the table header scrolls out of view. A separate `NSHostingView` for the header can be positioned absolutely within the scroll view's coordinate space. | `LazyVStack` with `pinnedViews` (requires a `ScrollView` parent; the table's vertical scrolling comes from the parent `NSTextView`'s `NSScrollView`, not an internal one), Manual offset tracking in SwiftUI (no access to parent `NSScrollView` scroll position from within `NSHostingView`) |
| D6 | Size reporting from table to overlay coordinator | `.onGeometryChange()` modifier | Available on macOS 14.0+ (within deployment target). Cleaner than `GeometryReader` -- does not inject a parent view that affects layout. Reports size changes as a callback without consuming the proposed size. | `GeometryReader` (consumes proposed size, can cause unexpected sizing behavior when used as a measurement tool rather than a layout container), Override `intrinsicContentSize` on `NSHostingView` (undocumented timing, fragile across macOS versions) |
| D7 | Table body view hierarchy | `VStack` (eager) for all rows, not `LazyVStack` | The performance target is 100 rows (NFR-ST-001). 100 rows of `Text` views in a `VStack` is well within SwiftUI's rendering budget. `VStack` renders all rows immediately, making total height measurement deterministic and enabling accurate sticky header positioning. `LazyVStack` defers row creation, complicating both height reporting and sticky header calculations. | `LazyVStack` (deferred loading makes total height unknown until all rows are scrolled through; sticky header positioning requires knowing the body height), `List` (applies its own opinionated styling: row separators, insets, selection highlights that conflict with the table's custom styling) |
| D8 | Height estimation in TextStorageBuilder | Use `TableColumnSizer` for wrapping-aware estimation | The current fixed `rowHeight: 32` significantly underestimates tables with wrapped content, causing a visible jump when the dynamic height callback corrects it. Using the same measurement engine produces estimates within 10-20% of actual height, resulting in smoother initial rendering. | Keep fixed 32pt per row (large visual jump when callback fires, especially for tables with long cell content), Pre-render the full table in a background NSHostingView to get exact height (complex, slow, blocks initial layout) |

## Technology Selection Rationale

### User-Selected Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| Sticky header strategy | Scroll offset observation + separate NSHostingView | User selection during design session | User chose AppKit scroll observation over deferral. Monitors parent NSScrollView's contentView.bounds changes. When the table header scrolls above the visible area, renders a separate fixed-position header overlay pinned at the top of the visible table region. |

### Auto-Aligned Decisions (from KB/codebase patterns)

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| UI framework | SwiftUI | KB patterns.md, charter constraint | WKWebView reserved for Mermaid only. All other UI is native SwiftUI. |
| State pattern | `@Environment(AppSettings.self)` | KB patterns.md, existing TableBlockView | Existing table view already uses this pattern |
| Overlay architecture | NSHostingView positioned by OverlayCoordinator | KB architecture.md, existing pattern | Tables already use this exact pattern; we are enhancing, not replacing |
| Test framework | Swift Testing (`@Suite`, `@Test`, `#expect`) | KB patterns.md | All existing unit tests use this framework |
| Theme sourcing | ThemeColors via AppSettings | KB patterns.md, existing TableBlockView | No hardcoded colors; all from theme |
| Concurrency model | @MainActor for overlay/view code | KB architecture.md | OverlayCoordinator is already @MainActor |
