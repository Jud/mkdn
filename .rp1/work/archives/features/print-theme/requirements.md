# Requirements Specification: Print-Friendly Theme

**Feature ID**: print-theme
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-15

## 1. Feature Overview

When a user prints a Markdown document from mkdn (Cmd+P), the printed output must use a dedicated print-friendly color palette -- white background, black text, subtle gray code blocks, and dark ink-efficient colors -- regardless of which screen theme (Solarized Dark or Solarized Light) is active. This ensures legible, professional, ink-efficient printed documents every time.

## 2. Business Context

### 2.1 Problem Statement

mkdn currently prints whatever is on screen. When the Solarized Dark theme is active, the print output has a dark background with light text, which is illegible on paper and wastes ink. Even Solarized Light produces output that is not optimized for print (colored backgrounds, tinted code blocks, theme-specific link colors). Users who need to print or "Print to PDF" a Markdown document get an unacceptable result that undermines the app's design quality.

### 2.2 Business Value

- Eliminates a daily-driver friction point: users can print or export to PDF without switching themes or post-processing.
- Upholds the charter's design philosophy ("obsessive attention to detail") by ensuring print output is as carefully crafted as screen output.
- Ink efficiency: white backgrounds and dark text minimize toner/ink consumption.
- Professional appearance: printed documents look intentional, not like an accidental screenshot of a dark-mode app.

### 2.3 Success Metrics

- SM-1: A document printed from Solarized Dark has a white background, black body text, and no dark-theme artifacts on paper.
- SM-2: A document printed from Solarized Light produces identical print output to one printed from Solarized Dark (theme-independent).
- SM-3: Code blocks in printed output are readable with subtle background distinction and darker syntax colors.
- SM-4: Ink usage for a typical Markdown document is comparable to printing plain text (no large solid-fill backgrounds).

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Developer (primary) | Terminal-centric developer using mkdn as daily Markdown viewer | Prints docs for meetings, code reviews, or archives via Cmd+P or Print to PDF |
| Reviewer | Colleague receiving a printed/PDF copy of a Markdown document | Needs legible, professional output on paper or in a PDF viewer |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| App creator | Print output must reflect the same level of design care as screen rendering; no embarrassing dark-background printouts |
| End user | Cmd+P just works -- no manual theme switching or workarounds needed |

## 4. Scope Definition

### 4.1 In Scope

- A print-specific color palette (white background, black text, light gray code blocks, dark syntax colors, dark blue links).
- Intercepting the print operation to rebuild the NSAttributedString with print colors before the print dialog appears.
- Print-friendly code block background drawing (very subtle fill, minimal or no border).
- The print palette must apply to all text elements: headings, paragraphs, code blocks, inline code, links, blockquotes, lists.
- Syntax highlighting in code blocks must use darker, print-readable color variants.
- The same print palette is used regardless of which screen theme is active.

### 4.2 Out of Scope

- PDF export as a separate feature (the charter explicitly lists "Export formats (PDF, HTML, etc.)" under "Won't Do"; this feature only fixes the existing macOS print path).
- Print-specific layout changes (margins, page breaks, headers/footers) -- these are separate concerns.
- Print preview customization UI (users use the standard macOS print dialog).
- Printer-specific color management or ICC profiles.
- Adding a user-facing "Print Theme" preference or picker -- the print palette is a fixed, curated set of colors.

### 4.3 Assumptions

| ID | Assumption | Risk if Wrong |
|----|------------|---------------|
| A-1 | macOS print operation on NSTextView goes through `printOperation(for:)` which can be overridden to substitute content before printing | If the print path bypasses this method, a different interception point would be needed |
| A-2 | Rebuilding the NSAttributedString with a different color palette reuses the same MarkdownTextStorageBuilder pipeline with different theme colors | If the builder has theme-dependent side effects beyond colors, the rebuild may need additional parameters |
| A-3 | The `drawBackground(in:)` method on CodeBlockBackgroundTextView is called during print rendering and can detect the print context | If AppKit uses a different drawing path for print, the code block background override may need a separate approach |
| A-4 | The markdown content and scale factor are accessible at print time to rebuild the attributed string | If content is not retained or accessible, additional state plumbing is needed |

## 5. Functional Requirements

### FR-1: Print Color Palette (Must Have)

**Actor**: Developer
**Action**: Prints a document via Cmd+P
**Outcome**: The printed output uses a dedicated print color palette with white background, black body text, and ink-efficient styling
**Rationale**: Dark-theme screen colors are illegible and wasteful on paper
**Acceptance Criteria**:
- AC-1.1: Printed document background is white (#FFFFFF or equivalent)
- AC-1.2: Body text foreground is black (#000000 or near-black)
- AC-1.3: Heading text is black
- AC-1.4: The print palette is defined as a complete set of colors covering all ThemeColors fields plus SyntaxColors fields

### FR-2: Theme-Independent Print Output (Must Have)

**Actor**: Developer
**Action**: Prints the same document from Solarized Dark and then from Solarized Light
**Outcome**: Both printouts are visually identical
**Rationale**: Print output quality must not depend on which screen theme happens to be active
**Acceptance Criteria**:
- AC-2.1: Printing from Solarized Dark produces the same color palette as printing from Solarized Light
- AC-2.2: No screen theme colors appear anywhere in the printed output

### FR-3: Print-Friendly Code Blocks (Must Have)

**Actor**: Developer
**Action**: Prints a document containing fenced code blocks
**Outcome**: Code blocks have a very subtle, light gray background that distinguishes them from surrounding text without wasting ink
**Rationale**: Code blocks need visual separation on paper, but heavy backgrounds waste ink and look poor in print
**Acceptance Criteria**:
- AC-3.1: Code block background is a very light gray (subtle enough to be ink-efficient, visible enough to distinguish from surrounding content)
- AC-3.2: Code block border is either absent or a thin, light gray line
- AC-3.3: Code block text uses a monospaced font in black or near-black

### FR-4: Print-Friendly Syntax Highlighting (Must Have)

**Actor**: Developer
**Action**: Prints a document containing syntax-highlighted code blocks
**Outcome**: Syntax tokens use darker, print-readable colors that are distinguishable on white paper
**Rationale**: Solarized syntax colors (designed for colored backgrounds) do not read well on white paper; print needs its own palette
**Acceptance Criteria**:
- AC-4.1: Keywords, strings, types, functions, numbers, comments, properties, and preprocessor directives each have a distinct, dark-enough color that is legible on white paper
- AC-4.2: Comments are visually de-emphasized (e.g., gray) relative to code tokens, consistent with print conventions
- AC-4.3: All syntax colors pass a minimum contrast ratio against white background for readability

### FR-5: Print-Friendly Links (Must Have)

**Actor**: Developer
**Action**: Prints a document containing hyperlinks
**Outcome**: Links appear in dark blue, following standard print conventions
**Rationale**: Dark blue is the universal print convention for hyperlinks and is highly legible on white paper
**Acceptance Criteria**:
- AC-5.1: Link text in printed output is dark blue
- AC-5.2: Link underline styling is preserved in print

### FR-6: Print Operation Interception (Must Have)

**Actor**: System (print subsystem)
**Action**: User triggers Cmd+P, which dispatches to the text view
**Outcome**: The print operation intercepts the request, rebuilds the attributed string with print colors, and presents the print dialog with print-friendly content
**Rationale**: The attributed string must be rebuilt before the print operation runs so the print dialog preview and final output both reflect print colors
**Acceptance Criteria**:
- AC-6.1: The print dialog preview shows the print-friendly palette, not the screen theme
- AC-6.2: After printing, the on-screen display returns to the active screen theme without any flicker or artifacts
- AC-6.3: The rebuild uses the same markdown content currently displayed (not stale content)

### FR-7: Print-Friendly Code Block Backgrounds (Must Have)

**Actor**: System (drawing subsystem during print)
**Action**: Code block background containers are drawn during the print rendering pass
**Outcome**: The custom background drawing uses print-friendly colors (light gray fill, subtle or no border) instead of the screen theme's code block colors
**Rationale**: CodeBlockBackgroundTextView draws code block containers in drawBackground(in:), which is called during print; these must also use the print palette
**Acceptance Criteria**:
- AC-7.1: Code block rounded-rectangle backgrounds in print use the print palette's code block background color
- AC-7.2: Code block borders in print use the print palette's border color (or are omitted)

### FR-8: Print-Friendly Blockquote Styling (Should Have)

**Actor**: Developer
**Action**: Prints a document containing blockquotes
**Outcome**: Blockquotes have a subtle left border and light background appropriate for paper
**Rationale**: Blockquotes need visual distinction in print without heavy ink usage
**Acceptance Criteria**:
- AC-8.1: Blockquote left border is a medium gray, visible but not heavy
- AC-8.2: Blockquote background is white or very light gray

### FR-9: Print-Friendly Inline Code (Should Have)

**Actor**: Developer
**Action**: Prints a document containing inline code spans
**Outcome**: Inline code is rendered in monospace with subtle visual distinction from surrounding text
**Rationale**: Inline code needs to be identifiable in print without relying on colored backgrounds
**Acceptance Criteria**:
- AC-9.1: Inline code text is monospaced and black
- AC-9.2: Inline code has subtle visual distinction (e.g., the monospace font itself provides sufficient differentiation)

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

- NFR-1: The attributed string rebuild for print must complete within 200ms for a typical document (under 500 lines) on Apple Silicon. The user should not perceive a delay between pressing Cmd+P and seeing the print dialog.
- NFR-2: No visible flicker or theme flash on screen when the print operation rebuilds the attributed string for print and restores it afterward.

### 6.2 Security Requirements

- No security requirements specific to this feature.

### 6.3 Usability Requirements

- NFR-3: Zero user configuration required. The print palette is automatically applied whenever printing.
- NFR-4: The feature is invisible to the user -- they press Cmd+P and get a good-looking printout. No new UI, no preferences, no prompts.

### 6.4 Compliance Requirements

- NFR-5: Print output text colors should maintain sufficient contrast against the white background for accessibility (WCAG AA minimum contrast ratio of 4.5:1 for normal text).

## 7. User Stories

### STORY-01: Print a Dark-Theme Document

**As a** developer using Solarized Dark,
**I want** the printed output to use a white-background, black-text palette,
**So that** my printout is legible and professional on paper.

**Acceptance**:
- GIVEN the app is displaying a Markdown document in Solarized Dark
- WHEN I press Cmd+P and print
- THEN the printed pages have a white background, black text, and subtle code block backgrounds

### STORY-02: Print a Document with Code Blocks

**As a** developer reviewing code in Markdown,
**I want** code blocks to print with readable syntax highlighting on a light background,
**So that** I can review syntax-highlighted code on paper without squinting.

**Acceptance**:
- GIVEN a document containing fenced code blocks with syntax highlighting
- WHEN I print the document
- THEN code blocks have a very light gray background, monospaced dark text, and distinguishable syntax colors

### STORY-03: Print Produces Identical Output Regardless of Theme

**As a** developer who switches between Dark and Light themes,
**I want** print output to look the same regardless of my current theme,
**So that** I do not need to switch themes before printing.

**Acceptance**:
- GIVEN the same Markdown document
- WHEN I print it once from Solarized Dark and once from Solarized Light
- THEN both printouts use the same print color palette and are visually identical

### STORY-04: Screen Display Unaffected After Print

**As a** developer continuing work after printing,
**I want** the on-screen display to remain in my chosen theme after printing,
**So that** the print operation does not disrupt my editing environment.

**Acceptance**:
- GIVEN I am viewing a document in Solarized Dark
- WHEN I print and then dismiss the print dialog
- THEN the on-screen display is still in Solarized Dark with no flicker or artifacts

## 8. Business Rules

- BR-1: The print color palette is a single, fixed set of colors. It is not user-configurable and does not vary by screen theme. This is a deliberate design decision to ensure consistent, curated print quality.
- BR-2: The print palette must prioritize ink efficiency. Large solid-color fills (backgrounds) are either white or very light gray. No medium or dark background fills.
- BR-3: Every color in the print palette must be legible on white paper. No color may rely on a dark background for contrast.
- BR-4: The print feature must respect the charter's design philosophy: the print output should feel intentionally designed, not like a fallback or afterthought.

## 9. Dependencies & Constraints

### Internal Dependencies

| Component | Dependency Type | Description |
|-----------|----------------|-------------|
| ThemeColors / SyntaxColors | Data model | The print palette must cover all fields in both structs to fully replace screen colors |
| MarkdownTextStorageBuilder | Build pipeline | The attributed string rebuild for print uses this builder with print-palette colors |
| CodeBlockBackgroundTextView | Drawing pipeline | Custom drawBackground(in:) must detect print context and use print colors |
| SelectableTextView | View hosting | The NSTextView that receives the print action and hosts the attributed string |
| AppTheme | Theme system | The print palette exists alongside but separate from the screen theme enum |

### External Dependencies

- macOS AppKit print infrastructure (NSView.printView, NSPrintOperation, NSPrintInfo).
- No new third-party dependencies.

### Constraints

- Must work on macOS 14.0+ (Sonoma).
- Must not introduce WKWebView usage (charter constraint).
- The attributed string rebuild requires access to the parsed markdown content and the current scale factor at print time.
- SwiftLint strict mode and SwiftFormat must pass.

## 10. Clarifications Log

| # | Question | Resolution | Source |
|---|----------|------------|--------|
| 1 | Should the print palette be user-configurable? | No. Fixed, curated palette. Consistent with charter's design philosophy of opinionated quality. | Charter: "obsessive attention to detail" |
| 2 | Should tables also use print-friendly colors? | Yes. Tables are rendered as overlay views (TableBlockView) but the same principle applies -- print colors should be appropriate for paper. However, tables are NSView overlays positioned by OverlayCoordinator, not part of the NSAttributedString. Table print behavior may require a follow-up feature. | Concept map, modules.md |
| 3 | Should Mermaid diagrams get print-friendly colors? | Out of scope for this feature. Mermaid diagrams are rendered via WKWebView and have their own rendering pipeline. A separate feature would be needed for Mermaid print optimization. | Architecture: Mermaid pipeline is separate |
| 4 | What about images in print? | Images print as-is. No color transformation needed for raster images. | Common sense default |
| 5 | Does this conflict with the charter's "Won't Do: Export formats (PDF, HTML, etc.)"? | No. This feature fixes the existing macOS print path (which already exists via Cmd+P). It does not add a new export format. | Charter scope guardrails |

---

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | No matching PRD | No existing PRD matches "print-theme". Closest candidates (terminal-consistent-theming, core-markdown-rendering) are about screen rendering, not print. Feature proceeds without parent PRD. |
| Print palette configurability | Fixed, non-configurable palette | Charter emphasizes opinionated design quality; a single curated print palette is consistent with this philosophy and simpler to implement correctly. |
| Table print colors | Noted as follow-up concern | Tables use overlay NSViews (TableBlockView), not NSAttributedString. Their print behavior is architecturally separate and may need its own handling. |
| Mermaid print colors | Out of scope | Mermaid uses WKWebView with its own rendering pipeline. Print optimization for diagrams is a separate concern. |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| "readable syntax highlighting colors" -- how dark? | Inferred WCAG AA contrast (4.5:1) against white as minimum threshold for all print syntax colors | Industry standard for print readability |
| "very subtle" code block backgrounds -- how subtle? | Inferred very light gray (~#F5F5F5 to #EFEFEF range) -- visible enough to distinguish, light enough to be nearly invisible in print | Print design conventions; "saves ink, looks clean on paper" from requirements |
| "dark blue" for links -- which blue? | Inferred standard print link blue (~#0000CC to #003399 range) | "standard print convention" from requirements |
| Screen restoration after print -- mechanism? | Inferred that the print operation should use a temporary attributed string for print, not modify the displayed one, to avoid flicker | Performance constraint (NFR-2) and UX quality from charter |
| Access to markdown content at print time | Inferred that the view or its coordinator retains a reference to the parsed markdown blocks and scale factor needed for rebuild | Requirements statement: "Need access to the markdown content + scaleFactor to rebuild" |
