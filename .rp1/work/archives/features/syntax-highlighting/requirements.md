# Requirements Specification: Syntax Highlighting for Code Blocks

**Feature ID**: syntax-highlighting
**Parent PRD**: [Syntax Highlighting](../../prds/syntax-highlighting.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-06

## 1. Feature Overview

Syntax highlighting provides visually distinct, color-coded rendering of fenced code blocks within the Markdown preview. Swift code blocks receive full token-level highlighting powered by a theme-agnostic output format adapter, while all other languages fall back to plain monospaced text. The highlighting system draws its colors from whichever theme is active, re-rendering immediately when the user switches themes.

## 2. Business Context

### 2.1 Problem Statement

Developers viewing Markdown files produced by LLMs and coding agents encounter numerous fenced code blocks. Without syntax highlighting, these blocks are visually flat walls of monospaced text that are difficult to scan, comprehend, and verify. This friction undermines the core value proposition of mkdn as a beautiful, daily-driver Markdown viewer.

### 2.2 Business Value

- Elevates the perceived quality and polish of the entire application -- syntax highlighting is one of the most visible differentiators between a "good enough" viewer and a professional-grade one.
- Directly supports the charter's "obsessive attention to sensory detail" design philosophy by giving code blocks the same visual care as prose rendering.
- Reduces cognitive load for developers reviewing code-heavy Markdown artifacts, making mkdn more useful as a daily-driver tool.
- The charter explicitly calls syntax highlighting for code blocks "paramount."

### 2.3 Success Metrics

| Metric | Target |
|--------|--------|
| Swift code blocks render with distinct token-level coloring | 100% of Swift-tagged fenced blocks |
| Non-Swift code blocks render cleanly in monospaced fallback | 100% of non-Swift-tagged fenced blocks |
| Theme switch re-highlights all visible code blocks | Immediate, no stale colors visible |
| Highlighting latency for a typical code block (<100 lines) | <5ms synchronous |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Developer (Viewer) | A developer who opens Markdown files from the terminal to read documentation, specs, or reports produced by LLMs/agents. Uses preview-only mode. | Primary consumer of syntax-highlighted code blocks. Needs rapid visual comprehension of code snippets. |
| Developer (Editor) | A developer using side-by-side edit + preview mode to author or revise Markdown. | Views syntax-highlighted code blocks in the preview pane while editing. Note: editor-side highlighting is out of scope. |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project creator | Daily-driver quality code rendering that matches the beauty standard set by the charter. Syntax highlighting is explicitly called out as paramount in the charter scope. |

## 4. Scope Definition

### 4.1 In Scope

- Renaming `SolarizedOutputFormat` to `ThemeOutputFormat` to eliminate Solarized-specific naming from the code path.
- `ThemeOutputFormat` conforming to Splash's `OutputFormat` protocol, accepting a generic token-to-color map and a plain text color.
- Token-level syntax highlighting for Swift code blocks using Splash's Swift grammar.
- Plain monospaced fallback rendering (using theme `codeForeground` color) for all non-Swift language-tagged code blocks.
- Display of the language label above fenced code blocks when a language tag is present.
- Horizontal scrollability for code blocks with long lines.
- Immediate re-highlighting of all code blocks when the user switches themes.
- `ThemeOutputFormat.Builder` mapping all 9 Splash `TokenType` cases to the corresponding `SyntaxColors` fields from the active theme.
- Unit tests for `ThemeOutputFormat` builder covering token coloring, plain text handling, and whitespace preservation.

### 4.2 Out of Scope

- Multi-language grammar support (Python, JavaScript, Rust, etc.) via tree-sitter or other engines.
- Line numbers displayed alongside code block content.
- Copy-to-clipboard button on code blocks.
- Syntax highlighting in the editor pane (preview pane only).
- Custom user-defined themes or theme import/creation.
- Any use of WKWebView or web-based highlighting libraries (highlight.js, Prism, etc.).

### 4.3 Assumptions

| ID | Assumption | Impact if Wrong |
|----|------------|-----------------|
| A-1 | Splash 0.9.x `OutputFormat` / `OutputBuilder` API remains stable | Would require adapter rewrite to match new API surface |
| A-2 | Swift-only highlighting is sufficient for v1 daily-driver use | Polyglot users viewing Python/JS/Rust code blocks may find the experience incomplete |
| A-3 | Synchronous highlighting is fast enough for typical code blocks (<100 lines) | Large code blocks (hundreds of lines) could cause frame drops; would need async off-main-thread approach |
| A-4 | The `SyntaxColors` struct with 8 color fields provides sufficient granularity for meaningful Swift token differentiation | Some token types may appear visually too similar under certain themes |

## 5. Functional Requirements

### FR-001: Theme-Agnostic Output Format Naming
- **Priority**: Must Have
- **User Type**: All (system-wide correctness)
- **Requirement**: The syntax highlighting output format adapter must not contain any theme-specific naming (e.g., no "Solarized" in type names, file names, or code paths). It must be named `ThemeOutputFormat`.
- **Rationale**: The adapter is generic by design -- it accepts any color map. Theme-specific naming creates a false coupling and hinders future theme additions.
- **Acceptance Criteria**:
  - AC-1: No type, file, or symbol in the codebase contains "SolarizedOutputFormat".
  - AC-2: `ThemeOutputFormat` exists and is the sole syntax highlighting output format type.

### FR-002: Generic Token-to-Color Mapping
- **Priority**: Must Have
- **User Type**: All (system-wide)
- **Requirement**: `ThemeOutputFormat` must accept a `[TokenType: SwiftUI.Color]` map and a `plainTextColor`, with no assumptions about which theme provided the colors.
- **Rationale**: Enables any current or future theme to supply its own syntax color palette without modifying the highlighting adapter.
- **Acceptance Criteria**:
  - AC-1: `ThemeOutputFormat` initializer accepts a token-to-color map and a plain text color parameter.
  - AC-2: Passing different color maps produces correspondingly different `AttributedString` output.

### FR-003: Swift Code Block Tokenized Highlighting
- **Priority**: Must Have
- **User Type**: Developer (Viewer), Developer (Editor)
- **Requirement**: When a fenced code block has the language tag "swift", its content must be tokenized by Splash's `SyntaxHighlighter` and rendered as a colored `AttributedString` with token-level color differentiation.
- **Rationale**: Swift is the primary language of the mkdn project and its target user base. Meaningful token coloring (keywords, strings, types, comments, etc.) dramatically improves code readability.
- **Acceptance Criteria**:
  - AC-1: A fenced code block tagged `swift` renders with at least 3 visually distinct colors for different token types (e.g., keywords vs. strings vs. comments).
  - AC-2: The rendered output uses the active theme's `SyntaxColors` values.

### FR-004: Non-Swift Code Block Fallback
- **Priority**: Must Have
- **User Type**: Developer (Viewer), Developer (Editor)
- **Requirement**: Fenced code blocks with any language tag other than "swift" (or no language tag) must render as plain monospaced text using the active theme's `codeForeground` color.
- **Rationale**: Providing a clean, consistent fallback prevents visual inconsistency or errors when non-Swift code is encountered, which is a frequent occurrence in Markdown artifacts from LLMs.
- **Acceptance Criteria**:
  - AC-1: A code block tagged `python` renders entirely in `codeForeground` color with a monospaced font.
  - AC-2: A code block with no language tag renders entirely in `codeForeground` color with a monospaced font.
  - AC-3: No tokenization or color differentiation is attempted for non-Swift blocks.

### FR-005: Language Label Display
- **Priority**: Should Have
- **User Type**: Developer (Viewer), Developer (Editor)
- **Requirement**: When a fenced code block includes a language tag (e.g., "swift", "python", "bash"), a label displaying that language name must appear above the code block.
- **Rationale**: Knowing the language of a code block provides important context, especially in Markdown files containing snippets in multiple languages.
- **Acceptance Criteria**:
  - AC-1: A fenced code block with language tag "swift" displays "swift" as a label above the code content.
  - AC-2: A fenced code block with no language tag displays no language label.

### FR-006: Horizontal Scrollability for Long Lines
- **Priority**: Should Have
- **User Type**: Developer (Viewer), Developer (Editor)
- **Requirement**: Code blocks whose content exceeds the available horizontal width must be horizontally scrollable rather than wrapping text.
- **Rationale**: Code readability depends on preserving the original line structure. Wrapping long lines of code makes them difficult to read and understand.
- **Acceptance Criteria**:
  - AC-1: A code block containing a line wider than the viewport displays a horizontal scroll indicator.
  - AC-2: The user can scroll horizontally to reveal the full line content.
  - AC-3: Lines are not wrapped.

### FR-007: Theme-Reactive Re-Highlighting
- **Priority**: Must Have
- **User Type**: Developer (Viewer), Developer (Editor)
- **Requirement**: When the user switches the application theme (e.g., Solarized Dark to Solarized Light), all visible code blocks must immediately re-render with the new theme's syntax colors.
- **Rationale**: Stale colors after a theme switch would break the visual coherence of the application and undermine the charter's design philosophy.
- **Acceptance Criteria**:
  - AC-1: After switching from Solarized Dark to Solarized Light, all code block colors reflect the Light theme's `SyntaxColors`.
  - AC-2: No manual refresh, scroll, or re-open is required to see updated colors.

### FR-008: Complete Token Type Coverage in Builder
- **Priority**: Must Have
- **User Type**: All (system-wide correctness)
- **Requirement**: `ThemeOutputFormat.Builder` must map all 9 Splash `TokenType` cases to corresponding `SyntaxColors` fields from the active theme, with no unmapped cases.
- **Rationale**: Unmapped token types would silently fall through to an unexpected default color, creating visual inconsistencies.
- **Acceptance Criteria**:
  - AC-1: Each of the 9 Splash `TokenType` cases has an explicit mapping to a `SyntaxColors` field.
  - AC-2: Both Solarized Dark and Solarized Light themes provide distinct, non-identical `SyntaxColors` values.

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-001 | Syntax highlighting for a typical code block (<100 lines) must complete in <5ms synchronously on the main thread | Must Have |
| NFR-002 | Highlighting must not cause visible frame drops or UI jank during scroll | Should Have |

**Rationale**: The charter emphasizes that animations and transitions should feel physical and natural. Highlighting latency that causes scroll stutter would violate this principle. Synchronous execution is preferred for simplicity as long as performance targets are met.

### 6.2 Security Requirements

No specific security requirements for this feature. Code block content is rendered as styled text, not executed.

### 6.3 Usability Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-003 | Text within highlighted code blocks must be selectable by the user | Should Have |
| NFR-004 | Code block visual styling (rounded corners, border, background color) must be consistent with the active theme's palette | Should Have |
| NFR-005 | The visual distinction between highlighted and non-highlighted code blocks must be minimal -- both should feel like first-class citizens, not "degraded" vs. "enhanced" | Should Have |

### 6.4 Compliance Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-006 | No Solarized-specific naming in any code path -- all adapter code must be fully theme-agnostic | Must Have |
| NFR-007 | `ThemeOutputFormat` and `ThemeOutputFormat.Builder` must be `Sendable`-compatible to satisfy Swift 6 strict concurrency | Should Have |
| NFR-008 | All code must pass SwiftLint strict mode with all opt-in rules enabled | Must Have |

## 7. User Stories

### STORY-001: Viewing Swift Code with Highlighting

**As a** developer viewing a Markdown file in preview mode,
**I want** Swift code blocks to display with color-coded syntax highlighting,
**So that** I can quickly scan and comprehend code structure (keywords, strings, types, comments) without having to open the file in a separate editor.

**Acceptance Scenarios**:

**Scenario 1: Swift code block renders with token colors**
- GIVEN a Markdown file containing a fenced code block tagged `swift`
- WHEN the file is opened in mkdn preview mode
- THEN the code block content displays with at least 3 visually distinct colors corresponding to different token types

**Scenario 2: Colors match active theme**
- GIVEN the application theme is set to Solarized Dark
- WHEN a Swift code block is rendered
- THEN the token colors match the Solarized Dark `SyntaxColors` palette

### STORY-002: Viewing Non-Swift Code Gracefully

**As a** developer viewing a Markdown file containing code in multiple languages,
**I want** non-Swift code blocks to render cleanly in a consistent monospaced style,
**So that** I am not distracted by broken or missing highlighting, and all code blocks feel visually cohesive.

**Acceptance Scenarios**:

**Scenario 1: Python code block renders as plain monospaced text**
- GIVEN a Markdown file containing a fenced code block tagged `python`
- WHEN the file is opened in mkdn preview mode
- THEN the code block renders entirely in the theme's `codeForeground` color with a monospaced font

**Scenario 2: Untagged code block renders as plain monospaced text**
- GIVEN a Markdown file containing a fenced code block with no language tag
- WHEN the file is opened in mkdn preview mode
- THEN the code block renders entirely in the theme's `codeForeground` color with a monospaced font

### STORY-003: Switching Themes Updates Code Block Colors

**As a** developer who switches between Solarized Dark and Solarized Light depending on ambient lighting,
**I want** all code blocks to immediately reflect the new theme's colors when I switch,
**So that** the code remains readable and visually consistent with the rest of the document.

**Acceptance Scenarios**:

**Scenario 1: Theme switch updates syntax colors**
- GIVEN a Markdown file with Swift code blocks is displayed in Solarized Dark
- WHEN the user switches to Solarized Light
- THEN all code blocks immediately re-render with Solarized Light's `SyntaxColors` palette

### STORY-004: Identifying Code Block Language

**As a** developer viewing a Markdown file with code blocks in multiple languages,
**I want** to see a language label above each code block that has a language tag,
**So that** I immediately know which language I am looking at without reading the code itself.

**Acceptance Scenarios**:

**Scenario 1: Language label displayed**
- GIVEN a fenced code block with the language tag `swift`
- WHEN the block is rendered in preview
- THEN the label "swift" appears above the code content

**Scenario 2: No label for untagged blocks**
- GIVEN a fenced code block with no language tag
- WHEN the block is rendered in preview
- THEN no language label is displayed

### STORY-005: Scrolling Long Code Lines

**As a** developer viewing a Markdown file containing code with long lines,
**I want** to scroll horizontally within the code block to see the full line,
**So that** I can read the complete code without line wrapping destroying the structure.

**Acceptance Scenarios**:

**Scenario 1: Horizontal scroll on overflow**
- GIVEN a code block with lines exceeding the viewport width
- WHEN the block is rendered in preview
- THEN horizontal scrolling is available and lines are not wrapped

## 8. Business Rules

| ID | Rule | Rationale |
|----|------|-----------|
| BR-001 | Only code blocks with the exact language tag "swift" receive token-level highlighting. All other language tags (including variations like "Swift" or "SWIFT") receive fallback rendering. | Splash only supports Swift grammar. Clear gating prevents silent failures. Case sensitivity aligns with CommonMark convention where language tags are typically lowercase. |
| BR-002 | The highlighting adapter must never contain references to a specific theme name. Theme identity is the responsibility of the theme layer, not the highlighting layer. | Separation of concerns. Prevents the highlighting system from becoming coupled to any one theme. |
| BR-003 | Fallback (non-highlighted) code blocks must use the same container styling (background, border, corners, padding) as highlighted blocks. | Visual consistency. Users should not perceive non-highlighted blocks as "broken" or "lesser." |

## 9. Dependencies & Constraints

### External Dependencies

| Dependency | Purpose | Constraint |
|------------|---------|------------|
| Splash (>= 0.9.0) | Swift syntax tokenization via `SyntaxHighlighter` and `OutputFormat`/`OutputBuilder` protocols | Swift-only grammar; no pluggable language system |
| SwiftUI `AttributedString` | Rich text rendering for colored token output in `Text` views | Requires macOS 14.0+ (Sonoma) |

### Internal Dependencies

| Component | Relationship |
|-----------|-------------|
| `SyntaxColors` struct (in ThemeColors.swift) | Provides the 8 color fields consumed by `ThemeOutputFormat` |
| `AppTheme.syntaxColors` | Routes to the active theme's `SyntaxColors` instance |
| `AppState.theme` | Observable state that triggers view re-render (and thus re-highlighting) on theme change |
| `CodeBlockView` | The SwiftUI view that hosts `ThemeOutputFormat` and `SyntaxHighlighter`, rendering the final output |
| Core Markdown Rendering (MarkdownVisitor) | Must correctly parse fenced code blocks with language tags and pass them to `CodeBlockView` |

### Constraints

- No WKWebView or web-based syntax highlighting libraries permitted (charter constraint).
- Swift 6 strict concurrency: all types must be `Sendable`-safe.
- SwiftLint strict mode with all opt-in rules enabled.
- Synchronous highlighting on the main thread (acceptable given <5ms target for typical blocks).

## 10. Clarifications Log

| ID | Question | Resolution | Source |
|----|----------|------------|--------|
| CL-001 | Which languages should receive syntax highlighting? | Swift only, via Splash. All others get monospaced fallback. | PRD scope, Splash limitation |
| CL-002 | Should highlighting be synchronous or asynchronous? | Synchronous, with <5ms performance target for blocks under 100 lines. | PRD NFR-1 |
| CL-003 | Should the language label be case-sensitive for gating? | Yes -- only exact lowercase "swift" triggers highlighting. | Inferred from CommonMark convention (conservative default) |
| CL-004 | Should `ThemeOutputFormat` live in its own file or remain in `CodeBlockView.swift`? | Left as an implementation/architecture decision (out of scope for requirements). | PRD OQ-1 (open question) |
| CL-005 | Should `plainTextColor` default to `codeForeground` or `comment` color? | Left as an implementation decision. The requirement is that non-Swift blocks use `codeForeground`; internal defaults are an implementation detail. | PRD OQ-2 (open question) |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | syntax-highlighting.md | Exact filename match with FEATURE_ID "syntax-highlighting" |
| Language tag case sensitivity | Exact lowercase "swift" only | CommonMark convention uses lowercase language tags; conservative default avoids ambiguous gating behavior |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| No explicit requirements provided in REQUIREMENTS param | Derived all requirements from PRD syntax-highlighting.md + charter.md | PRD FR-1 through FR-8, NFR-1 through NFR-5 |
| "Fast" highlighting (vague in charter) | Defined as <5ms synchronous for blocks under 100 lines | PRD NFR-1 explicit target |
| Which users need syntax highlighting | Developer (Viewer) as primary, Developer (Editor) as secondary via preview pane | Charter target users + PRD scope (preview-side only) |
| What constitutes "theme-agnostic" naming | No type, file, or symbol name containing a specific theme name (e.g., "Solarized") in the highlighting code path | PRD FR-1, NFR-2 |
| Fallback rendering quality standard | Same container styling as highlighted blocks; visual parity except for token coloring | Inferred from charter design philosophy ("no element is too small to get right") |
| Case sensitivity of language tag matching for "swift" | Exact lowercase match only | Conservative default; CommonMark spec convention |
