# Requirements Specification: Smart Tables

**Feature ID**: smart-tables
**Parent PRD**: [Smart Tables](../../prds/smart-tables.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-11

## 1. Feature Overview

Smart Tables replaces mkdn's current equal-width, clipping table renderer with a content-aware table display that sizes columns to fit their data, wraps long text instead of truncating, and adapts gracefully to diverse table shapes -- from narrow two-column key-value pairs to wide multi-column data sets. Tables follow GitHub Markdown rendering semantics (content-driven column widths, text wrapping, horizontal scroll when needed), implemented entirely in native SwiftUI. This directly serves developers viewing LLM-generated Markdown artifacts that frequently contain tabular data in varied shapes and sizes.

## 2. Business Context

### 2.1 Problem Statement

The current table renderer distributes columns at equal width across the full container, which produces poor results for the diverse table shapes found in LLM-generated Markdown. Narrow two-column tables are stretched unnecessarily wide. Wide multi-column tables clip or truncate content because there is no horizontal scrolling. Long cell text is not wrapped, causing data loss. These rendering deficiencies undermine the charter goal of "beautiful" Markdown viewing and force developers to open alternative tools to read tabular data.

### 2.2 Business Value

Tables are one of the most common structural elements in LLM-generated Markdown -- specs, comparison matrices, configuration references, API docs, and data summaries all use tables heavily. Rendering them beautifully and readably is essential to mkdn's value proposition as the daily-driver Markdown viewer for developers working with coding agents. Smart Tables closes the gap between mkdn's table rendering and what developers expect from GitHub-quality Markdown display.

### 2.3 Success Metrics

- Tables of all shapes (narrow, wide, tall, mixed content) render readably without manual intervention
- No text is ever clipped or truncated in any table cell
- Narrow tables occupy only the space their content requires, not the full viewport width
- Wide tables are horizontally scrollable with no content loss
- Tables up to 100 rows render and scroll without perceptible lag
- The creator uses mkdn to view table-heavy Markdown without switching to another tool

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Interaction with Tables |
|-----------|-------------|------------------------|
| Developer (Viewer) | Primary user. Opens LLM-generated Markdown from the terminal to read specs, reports, data. Uses preview-only mode. | Views tables of all shapes and sizes. Needs content to be readable without scrolling horizontally for narrow tables. Needs horizontal scroll for wide tables. Selects and copies table data. |
| Developer (Editor) | Same user in side-by-side edit mode. Writes Markdown with tables. | Sees live table rendering in the preview pane while editing. Needs fast re-render as table content changes. |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project creator | Tables must look as polished as the rest of the rendering pipeline. No visual element should feel "good enough" when it could be "perfect." (Charter: Design Philosophy) |
| End users | Tables must be readable at a glance, with no data hidden or cut off. Text selection must work for copying data out of tables. |

## 4. Scope Definition

### 4.1 In Scope

- Content-aware column sizing based on intrinsic content width
- Text wrapping within cells (break-word semantics, never clip or truncate)
- Table width sized to content, capped at container width; narrow tables do not stretch
- Horizontal scrolling when table total width exceeds container
- Column alignment (left/center/right) from Markdown colon syntax
- Alternating row background colors
- Visually distinct header row (bold, secondary background, bottom border)
- Cell padding: 6pt vertical, 13pt horizontal
- 1px rounded-corner border (6pt radius)
- Overlay width matches actual table width (not forced to container width)
- Full click-drag text selection across table cells
- Sticky/frozen headers when scrolling vertically through long tables

### 4.2 Out of Scope

- Sortable columns (click header to sort)
- Resizable columns (drag-to-resize)
- Editable cells or inline editing
- Row selection or interactive row actions
- Column filtering
- CSV import or export
- Responsive breakpoints or mobile-style table layouts
- Line numbers or row indices

### 4.3 Assumptions

| ID | Assumption | Risk if Wrong |
|----|------------|---------------|
| A-1 | Text size measurement provides accurate enough width values for column sizing | Column widths may be slightly off, requiring fallback measurement strategies |
| A-2 | SwiftUI LazyVStack with pinnedViews works correctly inside NSHostingView overlays | May need manual header repositioning via scroll offset observation |
| A-3 | Tables up to 100 rows can be rendered without lazy loading | Large tables may need LazyVStack, adding complexity to sticky header implementation |
| A-4 | The dynamic height callback pattern (proven with Mermaid overlays) scales to tables with text-wrapping-driven dynamic heights | Tables may resize more frequently than Mermaid blocks (on window resize, font change), potentially causing layout thrashing |

## 5. Functional Requirements

### REQ-ST-001: Content-Aware Column Sizing

- **Priority**: Must Have
- **User Type**: All viewers
- **Requirement**: Column widths are determined by the intrinsic content width of each column's cells (header and data). The widest cell in each column sets that column's width. Columns are not distributed equally.
- **Rationale**: Equal-width columns waste space on narrow content and squeeze wide content. Content-aware sizing produces readable, proportional layouts that match GitHub Markdown rendering expectations.
- **Acceptance Criteria**:
  - AC-1: A two-column table with a short label column and a long description column allocates more width to the description column
  - AC-2: A table where all columns have similar content lengths produces approximately equal column widths
  - AC-3: Column widths recalculate when the system font size changes (Dynamic Type)

### REQ-ST-002: Text Wrapping in Cells

- **Priority**: Must Have
- **User Type**: All viewers
- **Requirement**: Long text within a table cell wraps to multiple lines using break-word semantics. Cell content is never clipped or truncated. Row height grows to accommodate wrapped content.
- **Rationale**: LLM-generated tables frequently contain sentences, file paths, and long identifiers in cells. Truncation causes data loss and defeats the purpose of viewing the table.
- **Acceptance Criteria**:
  - AC-1: A cell containing a 200-character string wraps to multiple lines; all text is visible
  - AC-2: Row height expands to fit the tallest cell in that row
  - AC-3: No ellipsis or clipping is ever applied to cell content

### REQ-ST-003: Table Width Fits Content

- **Priority**: Must Have
- **User Type**: All viewers
- **Requirement**: The rendered table width equals the sum of all column widths plus cell padding, capped at the container width. Narrow tables do not stretch to fill the container. The table is left-aligned within its container.
- **Rationale**: A two-column key-value table with short values should not span the full viewport. Content-fitting width produces a cleaner, more intentional visual layout.
- **Acceptance Criteria**:
  - AC-1: A narrow two-column table occupies less than 50% of a standard-width window
  - AC-2: The table's left edge aligns with the left margin of surrounding paragraph text
  - AC-3: The overlay hosting the table matches the actual table width, not the container width

### REQ-ST-004: Horizontal Scrolling for Wide Tables

- **Priority**: Must Have
- **User Type**: All viewers
- **Requirement**: When a table's total content width exceeds the container width, the table is wrapped in a horizontal scroll view. The scrollbar is visible on hover or during active scrolling.
- **Rationale**: Wide tables (10+ columns, or columns with wide content) must remain fully accessible without distorting the document layout or clipping columns.
- **Acceptance Criteria**:
  - AC-1: A 12-column table in a standard-width window shows a horizontal scrollbar
  - AC-2: All columns are reachable by scrolling horizontally
  - AC-3: Vertical document scrolling is not captured by the horizontal table scrollbar (scroll axes are independent)

### REQ-ST-005: Column Alignment from Markdown Syntax

- **Priority**: Must Have
- **User Type**: All viewers
- **Requirement**: Column alignment is determined by Markdown table syntax: `:---` (left), `:---:` (center), `---:` (right). Alignment applies to both the header cell and all data cells in that column. Default alignment is left.
- **Rationale**: Markdown authors use alignment syntax intentionally (e.g., right-aligning numeric columns). Respecting this produces professional-looking tables.
- **Acceptance Criteria**:
  - AC-1: A column with `---:` syntax renders all cells right-aligned
  - AC-2: A column with `:---:` syntax renders all cells center-aligned
  - AC-3: A column with no alignment markers renders left-aligned

### REQ-ST-006: Alternating Row Backgrounds

- **Priority**: Must Have
- **User Type**: All viewers
- **Requirement**: Table body rows alternate between two background colors sourced from the active theme: even rows use the theme `background` color, odd rows use theme `backgroundSecondary` at 50% opacity.
- **Rationale**: Alternating row colors (zebra striping) improve readability by helping the eye track across wide rows.
- **Acceptance Criteria**:
  - AC-1: Adjacent rows have visually distinguishable backgrounds
  - AC-2: Colors adapt when the user switches between Solarized Light and Solarized Dark themes
  - AC-3: Alternation pattern is consistent regardless of row count

### REQ-ST-007: Distinct Header Row

- **Priority**: Must Have
- **User Type**: All viewers
- **Requirement**: The header row is visually distinct from data rows: bold text, `backgroundSecondary` fill, and a bottom border/divider separating the header from the table body.
- **Rationale**: Clear header delineation is essential for table readability, especially in data-heavy LLM output.
- **Acceptance Criteria**:
  - AC-1: Header text renders in bold
  - AC-2: Header row background is visually distinct from both even and odd data rows
  - AC-3: A visible divider separates the header from the first data row

### REQ-ST-008: Cell Padding

- **Priority**: Must Have
- **User Type**: All viewers
- **Requirement**: All table cells (header and data) have 6pt vertical padding and 13pt horizontal padding.
- **Rationale**: Consistent padding provides comfortable whitespace around cell content without wasting vertical space.
- **Acceptance Criteria**:
  - AC-1: Cell content does not touch the cell edges
  - AC-2: Padding is uniform across all cells in the table

### REQ-ST-009: Rounded-Corner Border

- **Priority**: Must Have
- **User Type**: All viewers
- **Requirement**: The table has a 1px stroke border using the theme `border` color at 30% opacity with 6pt corner radius.
- **Rationale**: Rounded borders match the established visual language of mkdn's code blocks and other contained elements.
- **Acceptance Criteria**:
  - AC-1: The table has a visible, subtle border on all four sides
  - AC-2: Corners are visibly rounded (not sharp 90-degree angles)

### REQ-ST-010: Overlay Width Matches Table Width

- **Priority**: Must Have
- **User Type**: All viewers
- **Requirement**: The overlay system (OverlayCoordinator) positions the table overlay at the actual computed table width rather than forcing it to the full container width. Narrow tables are left-aligned, not stretched.
- **Rationale**: Forcing overlays to container width would undermine content-aware sizing by stretching narrow tables or adding unnecessary empty space.
- **Acceptance Criteria**:
  - AC-1: A narrow table's overlay does not extend beyond the table's right edge
  - AC-2: A wide table's overlay extends to the container edge with horizontal scrolling enabled
  - AC-3: The overlay border and background match the actual table dimensions

### REQ-ST-011: Text Selection Across Cells

- **Priority**: Must Have
- **User Type**: All viewers
- **Requirement**: Users can click-drag to select text within and across table cells using standard macOS text selection behavior.
- **Rationale**: Developers frequently need to copy data from tables in Markdown specs and reports. Text selection must work naturally.
- **Acceptance Criteria**:
  - AC-1: Text within a single cell can be selected by click-drag
  - AC-2: Selection can span across multiple cells
  - AC-3: Selected text can be copied to clipboard via Cmd+C

### REQ-ST-012: Sticky Headers on Vertical Scroll

- **Priority**: Should Have
- **User Type**: Viewers of long tables
- **Requirement**: When a table with many rows is scrolled vertically within the document, the header row remains visible, pinned at the top of the visible table area, so users always know which column they are reading.
- **Rationale**: Long tables (20+ rows) are common in LLM output (e.g., API reference tables, configuration matrices). Losing the header while scrolling forces users to scroll back up to identify columns.
- **Acceptance Criteria**:
  - AC-1: A 50-row table, when scrolled past the header, still shows the header row pinned at the top of the visible table area
  - AC-2: The sticky header has the same visual styling (bold, background, border) as the normal header
  - AC-3: The sticky header does not overlap or obscure table data

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-ST-001 | Table rendering performance | Tables up to 100 rows render and scroll without perceptible lag. Frame time stays below 16ms during scrolling. |
| NFR-ST-002 | Column width recalculation | Column widths recalculate promptly on font size change or window resize without visible flicker or layout thrashing. |

### 6.2 Security Requirements

No specific security requirements. Tables render static Markdown content with no external data fetching or user input processing.

### 6.3 Usability Requirements

| ID | Requirement |
|----|-------------|
| NFR-ST-003 | All colors sourced from ThemeColors. Tables adapt to theme changes (Solarized Light/Dark) without requiring app restart. |
| NFR-ST-004 | Tables respect Dynamic Type / system font size scaling. Column widths and row heights recalculate when the system font size changes. |
| NFR-ST-005 | Horizontal scroll within a table does not capture vertical document scroll events. Scroll axes remain independent. |

### 6.4 Compliance Requirements

| ID | Requirement |
|----|-------------|
| NFR-ST-006 | Native SwiftUI implementation only. No WKWebView or HTML table rendering. Consistent with the charter constraint that WKWebView is reserved exclusively for Mermaid diagrams. |

## 7. User Stories

### STORY-ST-001: Viewing a Narrow Key-Value Table

**As a** developer viewing an LLM-generated spec,
**I want** a two-column table to occupy only the width its content requires,
**So that** the table looks intentional and proportional, not awkwardly stretched across the full window.

**Acceptance**:
- GIVEN a Markdown file with a two-column table where the longest cell is 30 characters
- WHEN the file is opened in mkdn
- THEN the table renders at approximately 30-character width, left-aligned, not stretched to the window edge

### STORY-ST-002: Viewing a Wide Data Table

**As a** developer reviewing an API reference document,
**I want** a 10-column table to be horizontally scrollable,
**So that** I can access all columns without any data being clipped or hidden.

**Acceptance**:
- GIVEN a Markdown file with a 10-column table that exceeds the window width
- WHEN the file is opened in mkdn
- THEN a horizontal scrollbar appears and all columns are reachable by scrolling

### STORY-ST-003: Reading a Long Configuration Table

**As a** developer reviewing a configuration reference with 50+ rows,
**I want** the table header to stay visible as I scroll down,
**So that** I always know which column I am reading without scrolling back to the top.

**Acceptance**:
- GIVEN a Markdown file with a 50-row table
- WHEN I scroll down past the header row
- THEN the header row remains pinned at the top of the visible table area

### STORY-ST-004: Copying Data from a Table

**As a** developer extracting values from an LLM-generated comparison matrix,
**I want** to click-drag to select text across table cells and copy it,
**So that** I can paste table data into other tools without retyping.

**Acceptance**:
- GIVEN a rendered table in mkdn
- WHEN I click and drag across multiple cells
- THEN the text is selected and I can copy it with Cmd+C

### STORY-ST-005: Viewing a Table with Long Cell Content

**As a** developer reading an LLM-generated spec with detailed requirement descriptions in table cells,
**I want** long text in cells to wrap to multiple lines,
**So that** I can read the full content without any truncation or clipping.

**Acceptance**:
- GIVEN a table cell containing a 200-character description
- WHEN the file is rendered in mkdn
- THEN the cell text wraps and the row height expands to show all content

### STORY-ST-006: Switching Themes with Tables Visible

**As a** developer who switches between Solarized Light and Solarized Dark,
**I want** table colors to update immediately when I change the theme,
**So that** the table remains readable and visually consistent with the rest of the document.

**Acceptance**:
- GIVEN a rendered table in Solarized Dark theme
- WHEN I switch to Solarized Light
- THEN all table colors (background, borders, text, header, alternating rows) update immediately

### STORY-ST-007: Viewing Tables with Right-Aligned Numbers

**As a** developer reviewing a table with numeric data in right-aligned columns,
**I want** column alignment from Markdown syntax to be respected,
**So that** numbers align at the decimal/ones place for easy comparison.

**Acceptance**:
- GIVEN a Markdown table with `---:` alignment on a numeric column
- WHEN the file is rendered in mkdn
- THEN both the header and data cells in that column are right-aligned

## 8. Business Rules

| ID | Rule |
|----|------|
| BR-1 | Table rendering must follow GitHub Markdown table semantics. Column widths are content-driven, not fixed or percentage-based. |
| BR-2 | No table cell content is ever hidden, clipped, or truncated. All content is accessible either directly or via scrolling. |
| BR-3 | Tables are read-only in preview mode. No interactive editing, sorting, or filtering. |
| BR-4 | The table visual style must be consistent with mkdn's existing component language: rounded corners, theme-sourced colors, subtle borders. |
| BR-5 | Narrow tables must not stretch. A table's visual footprint should reflect its content, not the available space. |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Type | Impact |
|------------|------|--------|
| ThemeColors | Internal | All table colors sourced from theme. No hardcoded colors. |
| OverlayCoordinator | Internal | Table overlays must support variable widths. Currently forces container width; must be updated. |
| MarkdownTextStorageBuilder | Internal | Table height estimation must account for dynamic row heights from text wrapping. Current fixed `rowHeight: 32` will underestimate. |
| NSHostingView overlay pattern | Internal | Tables render as SwiftUI views in NSHostingView overlays positioned over NSTextAttachment placeholders. Table dimensions must be communicated back to the attachment system. |
| Dynamic height callback pattern | Internal | Uses `OverlayCoordinator.updateAttachmentHeight(blockIndex:newHeight:)` (established by Mermaid rendering) to update placeholder height after table measures itself. |

### Constraints

| ID | Constraint |
|----|------------|
| C-1 | SwiftUI only. No WKWebView. Charter reserves WKWebView exclusively for Mermaid diagrams. |
| C-2 | Tables are NSHostingView overlays. Width and height must be communicated back to the NSTextAttachment system. |
| C-3 | Sticky headers cannot rely on a simple outer ScrollView because the table is an overlay within a scrolling NSTextView. Requires either a split header/body approach or nested LazyVStack with pinnedViews. |
| C-4 | Swift 6 strict concurrency. All code must be concurrency-safe. |
| C-5 | macOS 14.0+ deployment target. |
| C-6 | SwiftLint strict mode enforced. |

## 10. Clarifications Log

| Date | Question | Resolution | Source |
|------|----------|------------|--------|
| 2026-02-11 | What does "smart" mean for tables? | Content-aware column sizing, text wrapping, horizontal scroll, sticky headers. Full spec in PRD. | PRD: smart-tables.md |
| 2026-02-11 | Are sortable or resizable columns in scope? | No. Explicitly out of scope per PRD. | PRD: Out of Scope |
| 2026-02-11 | What cell padding values? | 6pt vertical, 13pt horizontal. | PRD: FR-8 |
| 2026-02-11 | How should narrow tables behave? | Left-aligned, not stretched to container width. Table width equals content width. | PRD: FR-3, FR-10 |
| 2026-02-11 | What is the performance target? | 100 rows without lag, <16ms frame time during scroll. | PRD: NFR-1 |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | smart-tables.md | Feature ID "smart-tables" directly matches PRD filename "smart-tables.md" |
| REQ-ST-012 priority | Should Have (not Must Have) | Sticky headers involve significant implementation complexity per PRD technical constraints (C-3). Classified as Should Have to allow phased delivery per PRD milestone M4. All other FRs are Must Have. |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| PRD OQ-1: Two-pass vs single-pass column measurement | Left as implementation decision; not a requirements concern (WHAT not HOW) | Requirements discipline: exclude technical implementation |
| PRD OQ-2: Split NSHostingViews vs LazyVStack for sticky headers | Left as implementation decision; requirement specifies only that headers stay visible | Requirements discipline: exclude technical implementation |
| PRD OQ-3: Maximum column width before forced wrapping | No maximum column width specified. Text wrapping occurs naturally when table width hits container width cap. | PRD: FR-2 (break-word), FR-3 (capped at container) |
| PRD OQ-4: Behavior when window narrower than minimum column width | Horizontal scrolling applies (FR-4). No special narrow-window behavior specified. | PRD: FR-4 (horizontal scroll as general overflow solution) |
| Editor-side table rendering | Out of scope. Feature applies to preview/viewer pane only. | PRD: Out of Scope (no mention of editor); Charter: split-screen has separate edit and preview panes |
