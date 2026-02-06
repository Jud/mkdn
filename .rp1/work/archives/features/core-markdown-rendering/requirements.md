# Requirements Specification: Core Markdown Rendering

**Feature ID**: core-markdown-rendering
**Parent PRD**: [Core Markdown Rendering](../../prds/core-markdown-rendering.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-06

## 1. Feature Overview

Core Markdown Rendering is the foundational rendering pipeline for mkdn, responsible for parsing Markdown text into a structured AST, converting that AST into typed model values, and rendering those values as native SwiftUI views with full theming support. This pipeline must handle all standard Markdown constructs -- headings, paragraphs, lists, tables, blockquotes, code blocks with syntax highlighting, images, links, and inline formatting -- beautifully and performantly, providing the visual foundation upon which all other mkdn features (Mermaid diagrams, editor, split-screen) are built.

## 2. Business Context

### 2.1 Problem Statement

Developers working with LLMs and coding agents produce large volumes of Markdown artifacts daily -- documentation, reports, specs, and notes. No existing Mac-native application offers a fast, beautiful, terminal-integrated viewing experience for these files. Current options are either heavyweight editors (VS Code, Xcode) that impose unnecessary friction or terminal-based renderers that lack visual fidelity. A lightweight, native rendering pipeline is needed that transforms Markdown into visually polished output without the overhead, latency, or aesthetic compromise of web-based rendering (WKWebView).

### 2.2 Business Value

- **Daily-driver utility**: The rendering pipeline is the core experience -- if Markdown does not render beautifully, the app has no value proposition.
- **Performance trust**: Fast, native rendering builds user trust that the tool is lightweight and respects their workflow.
- **Theming consistency**: Terminal-consistent theming (Solarized) makes mkdn feel like a natural extension of the developer's environment rather than a foreign app.
- **Foundation for growth**: A well-structured, pluggable rendering pipeline enables future features (Mermaid, editor, additional themes) without architectural rework.

### 2.3 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Render latency | < 100ms for documents under 500 lines on Apple Silicon | Instrumented timing in preview view |
| Block type coverage | 100% of standard CommonMark block and inline types | Unit test suite covering all MarkdownBlock variants |
| Theme consistency | All rendered elements use ThemeColors; no hardcoded colors | Code review + visual inspection |
| Daily-driver adoption | Creator uses mkdn as default Markdown viewer | Self-reported usage |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Primary Needs |
|-----------|-------------|---------------|
| Terminal Developer | Developer who works primarily from the terminal, launches mkdn via CLI to view Markdown files produced by coding agents and LLMs | Fast, beautiful preview; terminal-consistent theming; minimal friction to open and read |
| Markdown Author | Developer who edits Markdown files and uses mkdn for live preview (future editor surface consumes this pipeline) | Accurate rendering of all Markdown constructs; visual fidelity matching final output |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project Creator | Beautiful, correct, performant rendering that makes mkdn a daily-driver tool |
| Future Feature Consumers | Stable, well-typed rendering pipeline API that Mermaid rendering, editor, and other surfaces can build upon |

## 4. Scope Definition

### 4.1 In Scope

- Markdown parsing via apple/swift-markdown (AST generation from raw Markdown text)
- Custom AST visitor that produces typed MarkdownBlock model values for all supported block types
- SwiftUI view layer that renders each MarkdownBlock variant as a native view
- Block types: headings (H1-H6), paragraphs, ordered lists, unordered lists (including nested up to 4+ levels), tables, blockquotes, code blocks, images, links, thematic breaks
- Inline formatting: bold, italic, inline code, strikethrough
- Code block syntax highlighting via Splash with language detection from fenced code block info strings
- Table rendering with column alignment, header row styling, and row striping
- Pluggable theming: ThemeColors protocol consumed by all rendered views
- Solarized Dark and Solarized Light theme implementations
- MarkdownPreviewView as the primary consumer (full-width preview mode)

### 4.2 Out of Scope

- Mermaid diagram detection and rendering (separate feature: mermaid-rendering)
- Editor functionality and split-screen view (separate feature: split-screen-editor)
- File watching and reload (orthogonal concern)
- CLI argument handling (separate feature: cli-launch)
- Additional themes beyond Solarized Dark and Light (future work; architecture supports it)
- Export or serialization of rendered output (charter Won't Do)
- HTML blocks embedded in Markdown (open question; conservatively excluded from MVP)
- Cloud sync, collaboration, plugin system (charter Won't Do)

### 4.3 Assumptions

| ID | Assumption | Impact if Wrong |
|----|------------|-----------------|
| A1 | apple/swift-markdown AST covers all standard CommonMark block and inline types needed | Would require supplemental parsing or a different parser |
| A2 | Splash provides sufficient language grammar coverage for typical developer code blocks | Code blocks in unsupported languages render as plain monospace text; may need custom grammars |
| A3 | SwiftUI Text + AttributedString is performant enough for syntax-highlighted code blocks up to ~500 lines | May need lazy rendering or virtualization for very large code blocks |
| A4 | ThemeColors protocol can express all color and typography needs for every block type | Theme system may need extension; but pluggable by design |
| A5 | The rendering pipeline can remain stateless and re-render on every view update without performance issues for typical documents | May need a caching layer for large documents |

## 5. Functional Requirements

### FR-001: Markdown Parsing
- **Priority**: Must Have
- **Actor**: Terminal Developer
- **Requirement**: The system must parse any valid Markdown document into a structured AST without error or data loss.
- **Rationale**: Parsing is the entry point of the entire rendering pipeline; if parsing fails or drops content, all downstream rendering is compromised.
- **Acceptance Criteria**:
  - AC-1: Given a valid CommonMark document, when parsed, then a complete AST is produced with no errors thrown.
  - AC-2: Given a document containing all supported block types (headings, paragraphs, lists, tables, blockquotes, code blocks, images, links, thematic breaks), when parsed, then every block is represented in the AST.
  - AC-3: Given a document with inline formatting (bold, italic, code, strikethrough), when parsed, then inline markup is preserved in the AST.

### FR-002: AST-to-Model Conversion
- **Priority**: Must Have
- **Actor**: Terminal Developer
- **Requirement**: A custom visitor must convert the full swift-markdown AST into an array of typed model values covering all supported block types.
- **Rationale**: A typed model layer decouples parsing from rendering, enabling independent testing and future extensibility.
- **Acceptance Criteria**:
  - AC-1: Given a parsed AST containing headings H1-H6, when visited, then a model value is produced for each heading with correct level.
  - AC-2: Given a parsed AST containing nested lists (up to 4 levels), when visited, then model values preserve nesting depth and list type (ordered/unordered).
  - AC-3: Given a parsed AST containing a fenced code block with language info string, when visited, then the model value captures both the code content and the language identifier.
  - AC-4: Given a parsed AST containing a table, when visited, then the model value captures headers, rows, and column alignments.
  - AC-5: Given a parsed AST containing inline formatting within any block type, when visited, then the model value captures the formatting semantics.

### FR-003: Native SwiftUI Block Rendering
- **Priority**: Must Have
- **Actor**: Terminal Developer
- **Requirement**: Each model variant must render as a native SwiftUI view with correct visual hierarchy, spacing, and typography.
- **Rationale**: Native rendering is a hard architectural constraint (no WKWebView) and the core value proposition of mkdn -- beautiful, fast, Mac-native Markdown display.
- **Acceptance Criteria**:
  - AC-1: Given a heading model value (H1-H6), when rendered, then the view displays with descending font sizes and appropriate weight.
  - AC-2: Given a paragraph model value, when rendered, then the view displays with appropriate line spacing and text wrapping.
  - AC-3: Given a blockquote model value, when rendered, then the view displays with a visual left-edge indicator and differentiated styling.
  - AC-4: Given a thematic break, when rendered, then a horizontal rule is displayed.
  - AC-5: No WKWebView is used anywhere in the rendering pipeline.

### FR-004: Code Block Syntax Highlighting
- **Priority**: Must Have
- **Actor**: Terminal Developer
- **Requirement**: Code blocks must display with language-aware syntax highlighting, using the language identifier from the fenced code block info string.
- **Rationale**: Syntax highlighting for code blocks is described as "paramount" in the project charter; developers viewing LLM-generated code need visual token differentiation.
- **Acceptance Criteria**:
  - AC-1: Given a fenced code block with a supported language (e.g., swift, python, javascript), when rendered, then tokens are highlighted with theme-consistent colors.
  - AC-2: Given a fenced code block with an unsupported or missing language, when rendered, then the code displays in theme-consistent monospace styling without token highlighting.
  - AC-3: Given a code block, when rendered, then the background color is distinct from the document background per the active theme.

### FR-005: Table Rendering
- **Priority**: Must Have
- **Actor**: Terminal Developer
- **Requirement**: Tables must render with aligned columns, distinct header row styling, and row striping consistent with the active theme.
- **Rationale**: Tables are common in LLM-generated documentation and specs; correct alignment and visual structure are essential for readability.
- **Acceptance Criteria**:
  - AC-1: Given a table with left, center, and right column alignments, when rendered, then cell content aligns accordingly.
  - AC-2: Given a table, when rendered, then the header row is visually distinct (e.g., bold text, different background).
  - AC-3: Given a table with multiple rows, when rendered, then alternating rows have subtle background differentiation (row striping).

### FR-006: Nested List Rendering
- **Priority**: Must Have
- **Actor**: Terminal Developer
- **Requirement**: Ordered and unordered lists must render with correct indentation up to at least 4 nesting levels, with appropriate bullet/numbering styles per level.
- **Rationale**: Nested lists are common in Markdown documentation and must be visually distinguishable at each nesting depth.
- **Acceptance Criteria**:
  - AC-1: Given a 4-level nested unordered list, when rendered, then each level has increasing indentation.
  - AC-2: Given a 4-level nested ordered list, when rendered, then numbering restarts correctly at each level.
  - AC-3: Given a list item containing inline formatting (bold, italic, code), when rendered, then the formatting is preserved within the list item.

### FR-007: Inline Formatting
- **Priority**: Must Have
- **Actor**: Terminal Developer
- **Requirement**: Inline formatting (bold, italic, inline code, strikethrough) must render correctly within any block type, including list items, blockquotes, and table cells.
- **Rationale**: Inline formatting is pervasive in Markdown; incorrect rendering within composite blocks would undermine visual fidelity.
- **Acceptance Criteria**:
  - AC-1: Given bold text within a list item, when rendered, then the text appears bold.
  - AC-2: Given inline code within a blockquote, when rendered, then the code appears with monospace font and code-styled background.
  - AC-3: Given strikethrough text in a table cell, when rendered, then the text appears with a strikethrough decoration.
  - AC-4: Given combined formatting (e.g., bold + italic), when rendered, then both styles are applied simultaneously.

### FR-008: Theme Integration
- **Priority**: Must Have
- **Actor**: Terminal Developer
- **Requirement**: All rendered views must consume a theming protocol for their color palette, typography, and spacing -- no hardcoded visual values.
- **Rationale**: Terminal-consistent theming is a key differentiator; the pluggable architecture enables future themes without code changes to the rendering pipeline.
- **Acceptance Criteria**:
  - AC-1: Given a switch from Solarized Dark to Solarized Light, when the theme changes, then all rendered block views update their colors and typography accordingly.
  - AC-2: Given any rendered view, when inspected, then no color or font values are hardcoded -- all are sourced from the active theme.
  - AC-3: Given both Solarized Dark and Solarized Light themes, when applied, then all block types render with visually correct and consistent styling.

### FR-009: Link Interaction
- **Priority**: Should Have
- **Actor**: Terminal Developer
- **Requirement**: Links must be visually styled as interactive elements and, when clicked, open the target URL in the user's default browser.
- **Rationale**: Markdown files frequently contain reference links; users expect clickable links in a rendered view.
- **Acceptance Criteria**:
  - AC-1: Given a Markdown link, when rendered, then the link text is visually distinct (e.g., colored, underlined per theme).
  - AC-2: Given a rendered link, when clicked, then the target URL opens in the system default browser.

### FR-010: Image Display
- **Priority**: Should Have
- **Actor**: Terminal Developer
- **Requirement**: Images referenced in Markdown (via URL or local file path) must load and display inline within the rendered document.
- **Rationale**: Markdown documentation sometimes includes images; displaying them inline provides a complete reading experience.
- **Acceptance Criteria**:
  - AC-1: Given a Markdown image with a valid URL, when rendered, then the image loads and displays inline.
  - AC-2: Given a Markdown image with a valid local file path, when rendered, then the image loads and displays inline.
  - AC-3: Given a Markdown image with an invalid or unreachable source, when rendered, then a placeholder or error indication is displayed (not a crash or blank space).

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-001 | Rendering a typical Markdown document (< 500 lines) must complete in under 100ms on Apple Silicon | Must Have |
| NFR-002 | The rendering pipeline must be stateless: given the same Markdown text and theme, output is deterministic | Must Have |

### 6.2 Security Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-003 | Links opened via the rendering pipeline must use the system's default browser mechanism (NSWorkspace.shared.open); the app must not execute arbitrary URLs internally | Must Have |
| NFR-004 | Image loading from local file paths must be scoped to readable locations; the app must not expose a path traversal vector | Should Have |

### 6.3 Usability Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-005 | Rendered documents must be visually beautiful and consistent with the design philosophy: obsessive attention to spacing, typography, and color | Must Have |
| NFR-006 | The preview view must fill the available width and handle window resizing gracefully | Must Have |

### 6.4 Compliance Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-007 | No WKWebView usage anywhere in the rendering pipeline -- fully native SwiftUI | Must Have |
| NFR-008 | All public APIs must be @MainActor-safe for direct use in SwiftUI view bodies | Must Have |
| NFR-009 | All rendering pipeline code must pass SwiftLint strict mode | Must Have |
| NFR-010 | All unit tests must use the Swift Testing framework (not XCTest) | Must Have |

## 7. User Stories

### STORY-001: View a Markdown File
- **As a** Terminal Developer
- **I want to** open a Markdown file and see it rendered as beautiful, styled native content
- **So that** I can quickly read LLM-generated documentation without switching to a heavyweight editor

**Acceptance Scenario**:
- GIVEN a valid Markdown file containing headings, paragraphs, lists, and code blocks
- WHEN the file content is loaded into the preview view
- THEN all elements render as styled native SwiftUI views with correct hierarchy, spacing, and theming

### STORY-002: Read Syntax-Highlighted Code
- **As a** Terminal Developer
- **I want to** see code blocks rendered with language-aware syntax highlighting
- **So that** I can quickly scan and understand code snippets in documentation without opening a separate editor

**Acceptance Scenario**:
- GIVEN a Markdown file containing a fenced code block tagged with "swift"
- WHEN rendered in the preview view
- THEN Swift keywords, types, strings, and comments are highlighted with distinct, theme-consistent colors

### STORY-003: Read a Tabular Specification
- **As a** Terminal Developer
- **I want to** see tables rendered with aligned columns and clear row separation
- **So that** I can read structured data (requirements tables, comparison matrices) at a glance

**Acceptance Scenario**:
- GIVEN a Markdown file containing a table with headers, aligned columns, and multiple rows
- WHEN rendered in the preview view
- THEN columns are aligned per their Markdown alignment markers, headers are visually distinct, and alternating rows are subtly differentiated

### STORY-004: Switch Between Dark and Light Themes
- **As a** Terminal Developer
- **I want to** switch between Solarized Dark and Solarized Light themes
- **So that** the viewer matches my terminal environment's appearance

**Acceptance Scenario**:
- GIVEN a rendered Markdown document in Solarized Dark
- WHEN the user switches to Solarized Light
- THEN all rendered elements update to the Light palette without re-parsing the document

### STORY-005: Follow a Link in Documentation
- **As a** Terminal Developer
- **I want to** click a link in a rendered Markdown document and have it open in my browser
- **So that** I can follow references without manually copying URLs

**Acceptance Scenario**:
- GIVEN a rendered Markdown document containing a hyperlink
- WHEN the user clicks the link
- THEN the URL opens in the system default browser

### STORY-006: View a Document with Nested Lists
- **As a** Markdown Author
- **I want to** see deeply nested lists rendered with clear indentation and correct numbering/bullets
- **So that** I can verify the structure of complex hierarchical content

**Acceptance Scenario**:
- GIVEN a Markdown file containing a 4-level nested list mixing ordered and unordered types
- WHEN rendered in the preview view
- THEN each nesting level has progressively deeper indentation and appropriate bullet or numbering style

### STORY-007: View a Document with Images
- **As a** Terminal Developer
- **I want to** see inline images rendered within the Markdown document
- **So that** I can view diagrams and screenshots without opening a separate image viewer

**Acceptance Scenario**:
- GIVEN a Markdown file containing an image reference (URL or local path)
- WHEN rendered in the preview view
- THEN the image displays inline at an appropriate size within the document flow

## 8. Business Rules

| ID | Rule | Rationale |
|----|------|-----------|
| BR-001 | Code blocks in languages not supported by Splash must render as plain monospace text with theme-consistent styling -- never as an error or blank block | Graceful degradation preserves readability; unsupported languages are an accepted limitation, not an error |
| BR-002 | Image loading failures must display a visible placeholder -- never a crash, blank space, or infinite spinner | Robust handling of external resources prevents the app from feeling broken when images are unavailable |
| BR-003 | Theme colors must be the single source of truth for all visual styling in the rendering pipeline -- no hardcoded color or font values | Ensures theme switching works completely and future themes require zero rendering code changes |
| BR-004 | The rendering pipeline must produce identical visual output given the same input Markdown and theme -- stateless and deterministic | Predictability is essential for user trust and testability |
| BR-005 | HTML blocks embedded in Markdown are not rendered; they are either displayed as raw text or omitted | Conservative approach for MVP; avoids security and complexity risks of HTML interpretation in a native app |

## 9. Dependencies & Constraints

### External Dependencies

| Dependency | Version | Purpose | Risk |
|------------|---------|---------|------|
| apple/swift-markdown | >= 0.5.0 | Markdown parsing to AST | Low -- Apple-maintained, stable API |
| JohnSundell/Splash | >= 0.9.0 | Syntax highlighting for code blocks | Low -- mature, widely used. Limited language grammar set is an accepted trade-off |

### Platform Dependencies

| Dependency | Constraint |
|------------|------------|
| macOS 14.0+ (Sonoma) | Minimum deployment target; required for @Observable macro |
| Swift 6 / Xcode 16+ | Required for strict concurrency, swift-tools-version 6.0 |
| SwiftUI | Native rendering framework -- no WKWebView |

### Internal Dependencies

| Dependency | Relationship |
|------------|-------------|
| UI/Theme (ThemeColors, SolarizedDark, SolarizedLight) | Consumed by all rendering views; must be defined before rendering views compile |
| App/AppState | Provides the active theme and Markdown content to views |

### Constraints

- No WKWebView anywhere -- hard architectural constraint from the project charter
- SwiftLint strict mode with all opt-in rules enabled
- @Observable macro for all state (not ObservableObject/Combine)
- SPM only -- no CocoaPods or Carthage

## 10. Clarifications Log

| ID | Question | Resolution | Source |
|----|----------|------------|--------|
| CL-001 | Should the renderer cache parsed model arrays for unchanged content? | Left as open question for technical design phase; requirements specify stateless pipeline with < 100ms target | PRD OQ-1 |
| CL-002 | How should image loading failures be displayed? | Visible placeholder or error indication; never crash or blank space (BR-002) | Inferred from design philosophy |
| CL-003 | Should HTML blocks embedded in Markdown be rendered? | No -- displayed as raw text or omitted for MVP (BR-005) | Conservative default; PRD OQ-3 |
| CL-004 | What Markdown specification is targeted? | CommonMark, as supported by apple/swift-markdown | PRD FR-1 + dependency choice |
| CL-005 | Are GFM (GitHub Flavored Markdown) extensions supported? | Tables and strikethrough are in scope; other GFM extensions (task lists, autolinks) are not explicitly required for MVP | Inferred from PRD scope |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | core-markdown-rendering.md | Exact filename match with FEATURE_ID |
| REQUIREMENTS input | Derived from PRD + charter | REQUIREMENTS parameter was empty; PRD provides comprehensive functional and non-functional requirements |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| HTML block handling (PRD OQ-3) | Excluded from rendering; displayed as raw text or omitted | Conservative default -- avoids security/complexity risk in native app |
| Image loading failure UX (PRD OQ-2) | Visible placeholder or error indication displayed | Design philosophy: no element is too small to get right; failure must be visible, not hidden |
| Rendering caching strategy (PRD OQ-1) | Deferred to technical design; requirements specify stateless pipeline | Caching is an implementation concern; requirements focus on the < 100ms performance target |
| GFM extensions beyond tables/strikethrough | Not required for MVP | PRD scope lists tables and strikethrough explicitly; other GFM extensions not mentioned |
| Thematic break rendering | Included in scope | Concept map lists "Thematic Break" as a block element; PRD does not explicitly exclude it |
