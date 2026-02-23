# Requirements Specification: Table Cross-Cell Selection

**Feature ID**: table-cross-cell-selection
**Parent PRD**: [Table Cross-Cell Selection](../../prds/table-cross-cell-selection.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-23

## 1. Feature Overview

Table Cross-Cell Selection enables native macOS text selection that flows continuously across table cell boundaries and across block boundaries (paragraph into table, table into paragraph) in mkdn's preview pane. Currently, each table cell is an independent SwiftUI Text view with isolated selection. This feature makes table content part of the document's selectable text flow, so users can click-drag through tables exactly as they would through paragraphs, copy table content as rich text or tab-delimited plain text, and find text within table cells using Cmd+F.

## 2. Business Context

### 2.1 Problem Statement

Developers viewing LLM-generated Markdown frequently encounter tabular data -- requirement matrices, comparison tables, configuration references, API parameter lists. When they need to extract data from these tables (to paste into a spreadsheet, email, or another document), they cannot select across cell boundaries. They must copy cell-by-cell or fall back to the raw Markdown source. This friction breaks the "open, view beautifully, extract what you need, close" workflow that mkdn is built for.

### 2.2 Business Value

- Completes the cross-element selection story: paragraphs, headings, code blocks, and lists already support cross-block selection; tables are the remaining gap.
- Eliminates a daily-driver friction point: extracting tabular data is a common developer task when reviewing LLM output.
- Provides rich clipboard integration (RTF primary, tab-delimited fallback) so table data lands correctly in the target application -- whether that is a rich text editor, spreadsheet, or plain text field.
- Enables Find (Cmd+F) to locate text within table cells, closing a discoverability gap.

### 2.3 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Selection continuity | User can click-drag from paragraph through table to paragraph below without selection breaking | Manual verification: visual test with fixture document |
| Copy fidelity | Pasted table content preserves structure in rich text editors and spreadsheets | Manual verification: paste into TextEdit (RTF) and Numbers (tab-delimited) |
| Find coverage | Cmd+F matches text inside table cells | Manual verification: search for a known table cell value |
| Visual regression | Table rendering is indistinguishable from current behavior | Visual test: before/after screenshot comparison |
| Performance | Documents with up to 5 tables of 100 rows each scroll at 60fps | Manual verification: scroll performance on fixture document |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Developer (primary) | Terminal-centric developer viewing LLM-generated Markdown artifacts containing tables. Needs to extract tabular data for use in other tools. | Primary beneficiary. Expects native macOS selection and copy behavior. |
| Developer (printing) | Same user, occasionally printing documents containing tables for offline review or meetings. | Needs tables to render with visible text and proper visual structure in print output. |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project owner | Closes the last major selection gap for daily-driver use. Tables are the most common structured data format in LLM output. |
| End users | Expect tables to behave like native macOS content: selectable, copyable, searchable. Current behavior (isolated cell selection) feels broken compared to browser or native app table interactions. |

## 4. Scope Definition

### 4.1 In Scope

- Click-drag selection across multiple table cells with visual cell-level highlight
- Continuous selection flowing from paragraph text through table cells to paragraph text below (cross-block continuity)
- Cmd+A selecting all document content including table text
- Cmd+C copying selected table content as RTF (primary) with tab-delimited plain text (fallback)
- Mixed selection copy: paragraph text concatenated with formatted table content
- Cmd+F (Find) highlighting matches within table cells
- Visual table rendering identical to current behavior (no visual regression)
- Print path rendering tables with visible text and proper visual containers (rounded borders, header background, alternating rows)
- Table entrance animation grouping (unified fade-in per table)
- Sticky header positioning updated for the new table text representation
- Cell-level selection granularity (selecting any character in a cell highlights the entire cell)

### 4.2 Out of Scope

- Character-level sub-cell selection highlighting (future upgrade beyond V1)
- Dynamic tab stop rebuild on window resize (V1 accepts fixed-at-build-time tab stops)
- Multi-line cell wrapping in the invisible text layer (visual overlay handles wrapping; selection covers full visual cell)
- Horizontal scrolling for wide tables (pre-existing gap, not addressed here)
- Table editing or inline cell modification
- Drag-and-drop of selected table content
- Selection within side-by-side edit mode (this feature is preview-only)

### 4.3 Assumptions

| ID | Assumption | Impact if Wrong |
|----|------------|-----------------|
| A1 | Cell-level selection granularity is sufficient for user satisfaction in V1 | Users accustomed to browser-style character-level table selection may find it coarse; mitigated by documenting as V1 scope |
| A2 | RTF as primary clipboard type with tab-delimited plain text fallback covers the two dominant paste targets (rich text editors and spreadsheets) | Users pasting into other contexts (e.g., Markdown editors) may want pipe-separated format; can be added as a future clipboard type |
| A3 | Tables up to 100 rows represent the upper bound of real-world usage | Larger tables from LLM output could exist but are rare; performance above 100 rows is best-effort |
| A4 | Existing Find (Cmd+F) infrastructure searches the NSTextView text storage and will naturally find text within table cells once table content is part of the text storage | If table text is invisible (clear foreground), Find highlight rendering may need adjustment to ensure matches are visible |

## 5. Functional Requirements

### FR-001: Cross-Cell Selection
**Priority**: Must Have
**Actor**: Developer viewing a Markdown document with tables
**Requirement**: When the user click-drags across multiple table cells, the selection must visually highlight each cell boundary that the selection passes through, using cell-level granularity (any selected character in a cell highlights the full cell).
**Rationale**: Users expect native macOS selection behavior across table content, matching how selection works across paragraphs and other block types.
**Acceptance Criteria**:
- AC-1: Click-drag starting in cell (1,1) and ending in cell (3,2) highlights all cells in between
- AC-2: Selection highlight uses the system accent color at reduced opacity, visually consistent with standard macOS text selection
- AC-3: Selection highlight updates in real time as the mouse moves (within one frame at 60fps)

### FR-002: Cross-Block Selection Continuity
**Priority**: Must Have
**Actor**: Developer viewing a document with paragraphs surrounding a table
**Requirement**: When the user click-drags starting in a paragraph above a table, through table cells, and into a paragraph below the table, the selection must flow continuously without breaking at block boundaries.
**Rationale**: This is the core value proposition -- tables must participate in the document's unified selection flow, not be selection islands.
**Acceptance Criteria**:
- AC-1: Selection starting in a paragraph, passing through a table, and ending in a paragraph below produces a single continuous selection
- AC-2: The selection visually indicates both the paragraph text highlight and the table cell highlights simultaneously
- AC-3: The copied content includes the paragraph text, the table content, and the trailing paragraph text in order

### FR-003: Select All
**Priority**: Must Have
**Actor**: Developer wanting to copy entire document content
**Requirement**: Cmd+A must select all content in the document, including text within table cells.
**Rationale**: Select All is a fundamental macOS expectation. Table content must not be excluded from the selection range.
**Acceptance Criteria**:
- AC-1: After Cmd+A, the selected range spans the full text storage including all table cell text
- AC-2: All table cells show selection highlights after Cmd+A

### FR-004: Copy as Rich Text with Plain Text Fallback
**Priority**: Must Have
**Actor**: Developer copying table content to paste into another application
**Requirement**: Cmd+C on selected table cells must place RTF (rich text) as the primary pasteboard type, with tab-delimited plain text as a fallback type. RTF preserves table structure and styling for rich text editors. Tab-delimited plain text enables direct paste into spreadsheets with correct column alignment.
**Rationale**: Developers paste table data into diverse targets -- email clients, documentation tools, spreadsheets. RTF + tab-delimited covers the two dominant use cases without requiring the user to think about clipboard formats.
**Acceptance Criteria**:
- AC-1: Cmd+C on selected table cells places RTF data on the pasteboard
- AC-2: Cmd+C on selected table cells simultaneously places tab-delimited plain text on the pasteboard as a fallback type
- AC-3: Pasting into a rich text editor (e.g., TextEdit) produces a formatted table
- AC-4: Pasting into a spreadsheet (e.g., Numbers) produces data in correct columns via tab delimiters
- AC-5: Each table row maps to one line in the tab-delimited output; columns are separated by tab characters

### FR-005: Mixed Selection Copy
**Priority**: Must Have
**Actor**: Developer copying a selection that spans paragraph text and table content
**Requirement**: When the selection includes both paragraph text and table cells, Cmd+C must produce clipboard content that includes paragraph text verbatim concatenated with the formatted table content, in document order.
**Rationale**: Cross-block selection is only useful if the copy output preserves the full selection, not just the table portion or just the paragraph portion.
**Acceptance Criteria**:
- AC-1: Selection spanning "paragraph text" + table + "more text" copies all three segments in order
- AC-2: The table portion uses the same RTF + tab-delimited formatting as FR-004
- AC-3: Paragraph text portions are unaltered plain text in the output

### FR-006: Find in Tables
**Priority**: Must Have
**Actor**: Developer searching for specific content within a document containing tables
**Requirement**: Cmd+F (Find) must locate and highlight text matches within table cells. The Find bar match count must include matches found in table cells. Find Next / Find Previous must navigate to matches inside table cells.
**Rationale**: If table text is part of the document but invisible to Find, users will assume the content does not exist. Find must be comprehensive.
**Acceptance Criteria**:
- AC-1: Searching for a string that appears only in a table cell produces at least one match
- AC-2: The match count displayed in the Find bar includes table cell matches
- AC-3: Find Next navigates to and visually highlights the match within the table cell
- AC-4: Find Previous navigates backward through matches including table cell matches

### FR-007: Visual Rendering Parity
**Priority**: Must Have
**Actor**: Developer viewing any document containing tables
**Requirement**: Table visual rendering must be identical to the current behavior. The visual appearance of tables (column widths, cell padding, alternating row colors, header styling, rounded borders, text wrapping) must not change.
**Rationale**: This feature changes the selection and interaction model for tables, not their visual presentation. Any visual regression would undermine trust in the rendering quality.
**Acceptance Criteria**:
- AC-1: Side-by-side screenshot comparison of tables before and after shows no visual differences
- AC-2: All theme variants (Solarized Dark, Solarized Light) render tables identically to current behavior
- AC-3: Column sizing, cell padding, and text alignment are preserved

### FR-008: Print Path
**Priority**: Should Have
**Actor**: Developer printing a document containing tables
**Requirement**: When printing (Cmd+P), tables must render with visible text and proper visual containers including rounded-rect borders, header background, alternating row backgrounds, and header/body dividers.
**Rationale**: Print output must be readable and professional. The invisible-text approach used for screen rendering must switch to visible text for print.
**Acceptance Criteria**:
- AC-1: Printed tables show all cell text in visible ink
- AC-2: Printed tables show rounded-rect border, distinct header row, and alternating row backgrounds using the print palette
- AC-3: Print output visual structure matches the on-screen table appearance (adapted for print colors)

### FR-009: Entrance Animation Grouping
**Priority**: Should Have
**Actor**: Developer opening or reloading a document containing tables
**Requirement**: Table content must animate in as a single unified group during the staggered entrance animation, matching the existing behavior for code blocks.
**Rationale**: Per the project charter's design philosophy, every visual element deserves careful animation treatment. Tables appearing fragment-by-fragment would look broken.
**Acceptance Criteria**:
- AC-1: All layout fragments belonging to a single table fade in together as one unit
- AC-2: The table entrance animation timing is consistent with code block entrance animation
- AC-3: Reduce Motion is respected (immediate appearance when enabled)

### FR-010: Sticky Header Positioning
**Priority**: Should Have
**Actor**: Developer scrolling through a long table that exceeds the viewport height
**Requirement**: The sticky table header must continue to pin correctly at the top of the viewport when scrolling through tall tables, using the updated table text representation.
**Rationale**: Sticky headers are an existing feature that must not regress when the underlying table representation changes.
**Acceptance Criteria**:
- AC-1: Scrolling through a table taller than the viewport pins the header row at the viewport top
- AC-2: The sticky header disappears when the table scrolls fully out of view
- AC-3: Tables that fit entirely within the viewport never show a sticky header

### FR-011: Selection Overlay Pass-Through
**Priority**: Must Have
**Actor**: Developer interacting with the document
**Requirement**: The selection highlight overlay must pass through all mouse events to the underlying text view. The overlay must be visual-only and must not intercept clicks, drags, or scroll events.
**Rationale**: If the selection overlay captures mouse events, basic text interaction (clicking to place cursor, dragging to select, scrolling) would break.
**Acceptance Criteria**:
- AC-1: Clicking through the selection overlay area reaches the NSTextView and places the cursor
- AC-2: Drag-to-select works identically whether or not a selection overlay is currently visible
- AC-3: Scroll events pass through the overlay without interference

### FR-012: Selection Header Differentiation
**Priority**: Could Have
**Actor**: Developer selecting across table cells that include the header row
**Requirement**: When the selection includes the header row, the header cells should be visually distinguishable from data cell selection -- for example, a slightly more opaque or differently bordered highlight on header cells.
**Rationale**: Header rows carry semantic meaning (column labels vs. data). Differentiating them in the selection highlight helps the user understand what they have selected.
**Acceptance Criteria**:
- AC-1: Header cell selection highlight is visually distinguishable from data cell selection highlight
- AC-2: The distinction is subtle and does not distract from the selection interaction

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| ID | Expectation | Target |
|----|-------------|--------|
| NFR-001 | Selection overlay redraw latency | Within 16ms of selection change (single frame at 60fps) |
| NFR-002 | Scroll performance with tables | 60fps scrolling for documents with up to 5 tables of 100 rows each |
| NFR-003 | Cell-to-position lookup | O(log n) via binary search on the cell map |
| NFR-004 | Memory overhead per table | O(rows x columns) for the cell map; no unbounded growth |

### 6.2 Security Requirements

No additional security requirements. Table content is read from local Markdown files already validated by the existing file loading pipeline.

### 6.3 Usability Requirements

| ID | Expectation |
|----|-------------|
| NFR-005 | Selection behavior must feel native to macOS -- no custom gestures, no unfamiliar interaction patterns |
| NFR-006 | Selection highlight color must use the system accent color (respecting user's System Settings choice) |
| NFR-007 | Reduce Motion must be respected for entrance animations (immediate appearance, no drift) |

### 6.4 Compliance Requirements

| ID | Expectation |
|----|-------------|
| NFR-008 | TextKit 2 must be preserved throughout; no fallback to TextKit 1 APIs |
| NFR-009 | All new code must pass SwiftLint strict mode and SwiftFormat |
| NFR-010 | All new types must use correct Swift 6 concurrency annotations (@MainActor, Sendable) |

## 7. User Stories

### STORY-001: Select Across Table Cells
**As a** developer viewing an LLM-generated comparison table,
**I want to** click-drag across multiple table cells to select their content,
**So that** I can copy specific rows or columns of data without switching to the raw Markdown source.

**Acceptance**:
- GIVEN a rendered table with 3 columns and 5 rows
- WHEN the user click-drags from the first cell to the last cell
- THEN all traversed cells show a selection highlight at cell-level granularity

### STORY-002: Select From Paragraph Through Table
**As a** developer viewing a document where a table is embedded between paragraphs,
**I want to** click-drag starting in the paragraph above the table, through the table, and into the paragraph below,
**So that** I can copy a complete section of the document including both prose and tabular data.

**Acceptance**:
- GIVEN a paragraph followed by a table followed by another paragraph
- WHEN the user click-drags from the first paragraph through the table to the second paragraph
- THEN the selection flows continuously without breaking at any boundary

### STORY-003: Copy Table to Spreadsheet
**As a** developer who needs to analyze table data in a spreadsheet,
**I want to** select table cells and Cmd+C to copy, then paste into a spreadsheet application,
**So that** the data lands in the correct columns and rows without manual reformatting.

**Acceptance**:
- GIVEN a table with headers "Name", "Type", "Default" and 3 data rows
- WHEN the user selects all cells and presses Cmd+C
- THEN pasting into Numbers/Excel places each column's data in a separate spreadsheet column

### STORY-004: Copy Table to Rich Text Editor
**As a** developer drafting documentation that includes table data,
**I want to** select table cells and Cmd+C to copy, then paste into a rich text editor,
**So that** the table structure and basic formatting are preserved in the target document.

**Acceptance**:
- GIVEN a table with a header row and data rows selected
- WHEN the user presses Cmd+C and pastes into TextEdit (Rich Text mode)
- THEN the pasted content renders as a formatted table

### STORY-005: Find Text in Table
**As a** developer searching for a specific configuration value in a long document,
**I want to** use Cmd+F to find text that happens to be inside a table cell,
**So that** I can quickly locate the information without manually scanning every table.

**Acceptance**:
- GIVEN a document with multiple paragraphs and tables
- WHEN the user presses Cmd+F and types a string that appears only in a table cell
- THEN the Find bar shows a match count of at least 1 and Find Next scrolls to and highlights the cell containing the match

### STORY-006: Print Document with Tables
**As a** developer printing a document for offline review,
**I want** tables to appear in the printed output with visible text, proper borders, and distinct header styling,
**So that** the printed document is readable and professional.

**Acceptance**:
- GIVEN a document containing a table
- WHEN the user presses Cmd+P and prints
- THEN the printed page shows the table with visible cell text, rounded borders, header background, and alternating row colors in print-appropriate colors

### STORY-007: Select All Including Tables
**As a** developer who wants to copy an entire document,
**I want** Cmd+A to select all content including table cells,
**So that** no content is silently excluded from the selection.

**Acceptance**:
- GIVEN a document with paragraphs, code blocks, and tables
- WHEN the user presses Cmd+A
- THEN all content is selected, including all table cell text, and the selection highlights are visible on table cells

## 8. Business Rules

| ID | Rule |
|----|------|
| BR-001 | Table cell selection granularity is cell-level: selecting any portion of a cell's text results in the entire cell being highlighted. There is no partial-cell selection in V1. |
| BR-002 | Clipboard format hierarchy: RTF is the primary pasteboard type; tab-delimited plain text is the fallback. Applications choose the richest format they support. |
| BR-003 | Each row in the tab-delimited clipboard output corresponds to one table row. Columns within a row are separated by a single tab character. |
| BR-004 | The header row is included in clipboard output when it is part of the selection. There is no special header separator line in the output (no `|---|---|` equivalent). |
| BR-005 | Visual table rendering must not change. The selection system is additive; it must not alter the appearance of tables when no selection is active. |
| BR-006 | Find (Cmd+F) searches all text in the document including table cell content. Table cell matches are counted and navigable identically to paragraph text matches. |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Type | Impact |
|------------|------|--------|
| Cross-Element Selection (complete) | Internal, prerequisite | The NSTextView-based preview renderer and cross-block selection infrastructure must be in place. This feature extends that infrastructure to tables. |
| Smart Tables (complete) | Internal, prerequisite | The TableBlockView visual rendering, TableColumnSizer column width computation, and sticky header behavior must be in place. This feature preserves their visual output. |
| TableColumnSizer | Internal, consumed | Column width data drives both the invisible text tab stops and the selection overlay cell geometry. Changes to column sizing affect both layers. |
| CodeBlockAttributes pattern | Internal, followed | The attribute tagging approach for tables follows the identical pattern established by CodeBlockAttributes. |
| OverlayCoordinator | Internal, extended | Must be extended to support text-range-based positioning alongside existing attachment-based positioning. |
| FindState | Internal, extended | Find must search the full text storage which now includes table cell text. No structural change to FindState is expected, but verification is required. |
| EntranceAnimator | Internal, extended | Must support grouping table layout fragments for unified entrance animation. |

### Constraints

| Constraint | Impact |
|------------|--------|
| Preview-only mode | This feature applies to the preview reading mode only, not the side-by-side editor pane. |
| macOS 14.0+ minimum | All TextKit 2 APIs used are available on the project's minimum deployment target. |
| Tab stops fixed at build time | Selection accuracy may degrade at extreme window width changes. Accepted for V1; follow-up to rebuild on significant resize. |
| SwiftUI overlay is visual-only | The visual table rendering (TableBlockView) cannot handle selection interaction. The invisible text layer handles all interaction by design. |
| Cell-level granularity only | V1 does not support character-level selection within individual cells. |

## 10. Clarifications Log

| Question | Answer | Source |
|----------|--------|--------|
| Which view modes does this feature apply to? | Preview-only reading mode. The app is a viewer, not an editor. | User clarification |
| What clipboard format should Cmd+C produce? | RTF as primary pasteboard type, tab-delimited plain text as fallback. No Markdown pipe format. | User clarification |
| Is cell-level selection granularity acceptable for V1? | Yes. Cell-level (full cell highlights on any character selected) is sufficient for V1. | User clarification |
| Should Cmd+C include header separator lines? | Not applicable -- clipboard is RTF + tab-delimited, not Markdown pipe format. | User clarification |
| Should header row selection look different from data row selection? | Use best judgment. Specified as Could Have (FR-012) with subtle visual differentiation. | User clarification |
| What table size is the upper bound for performance? | 100-row tables per the Smart Tables PRD. | User clarification |
| Is cell-level selection with cross-block continuity sufficient for MVP? | Yes, sufficient for V1. | User clarification |
| Should Cmd+F find text within table cells? | Yes. Find must highlight matches within table cells. | User clarification |
