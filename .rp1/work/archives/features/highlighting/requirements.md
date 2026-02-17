# Requirements Specification: Multi-Language Syntax Highlighting

**Feature ID**: highlighting
**Parent PRD**: [highlighting](../../prds/highlighting.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-17

## 1. Feature Overview

mkdn currently highlights only Swift code blocks using the Splash library; all other language-tagged fenced code blocks render as plain monospace text. This feature replaces Splash with SwiftTreeSitter-based parsing to deliver token-level syntax coloring for 16 languages commonly found in LLM-generated Markdown artifacts, so that every fenced code block in mkdn receives the same level of visual polish as the rest of the native rendering pipeline.

## 2. Business Context

### 2.1 Problem Statement

Developers using LLMs and coding agents produce Markdown containing code in many languages -- Python, JavaScript, Rust, Go, and others. When these files are opened in mkdn, only Swift code blocks receive syntax highlighting. Every other language renders as undifferentiated monospace text, creating a jarring contrast between beautifully themed prose and flat, uncolored code. This undermines the project charter's stated goal that syntax highlighting is "paramount" and breaks the visual consistency that defines mkdn's value proposition.

### 2.2 Business Value

- **Visual completeness**: Code blocks are among the most frequently occurring elements in developer-oriented Markdown. Highlighting them properly makes mkdn a credible daily-driver viewer for polyglot codebases.
- **Competitive parity**: Terminal-based viewers (bat, glow) and heavyweight editors (VS Code) already highlight multiple languages. mkdn must match this baseline to justify its niche.
- **Dependency hygiene**: Replacing Splash (a third-party dependency maintained by a single author) with tree-sitter (an industry-standard parser backed by a large ecosystem) reduces long-term maintenance risk and unifies all highlighting under one engine.
- **Charter alignment**: The project charter lists "syntax highlighting for code blocks" as a Will Do item with explicit emphasis ("paramount"). This feature fulfills that commitment across the full language spectrum.

### 2.3 Success Metrics

| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| Language coverage | 16 languages produce colored tokens | Manual verification with test fixtures per language |
| Splash removal | Zero references to Splash in Package.swift and source tree | Grep / build verification |
| Visual quality | Token coloring is at least as granular as current Swift highlighting | Side-by-side comparison of Swift code blocks before/after migration |
| Rendering performance | Each code block highlights in under 16ms | Instrumented timing in debug builds |
| Theme consistency | All token colors come from SyntaxColors and render correctly in both Solarized Dark and Solarized Light | Visual inspection of all 16 languages in both themes |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Markdown Viewer | Developer who opens LLM-generated or hand-written Markdown from the terminal to read code examples, documentation, and specs | Primary consumer -- sees code blocks in many languages daily |
| Markdown Editor | Developer who edits Markdown in mkdn's side-by-side mode and previews the result | Sees highlighted code blocks in the preview pane while editing |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project creator (daily-driver user) | Code blocks must look beautiful and match terminal theming across all languages encountered in coding-agent output |
| Future contributors | A single, well-documented highlighting engine (tree-sitter) is easier to extend than a patchwork of per-language libraries |

## 4. Scope Definition

### 4.1 In Scope

- Token-level syntax highlighting for 16 languages: Swift, Python, JavaScript, TypeScript, Rust, Go, Bash/Shell, JSON, YAML, HTML, CSS, C, C++, Ruby, Java, Kotlin
- Replacement of the Splash dependency with SwiftTreeSitter for all languages including Swift
- Extension of the SyntaxColors palette with additional token types beyond the current set (e.g., operator, variable, constant, attribute, type, number, boolean)
- Bundling of all 16 tree-sitter grammar binaries in the application binary
- Graceful fallback: languages without a bundled grammar render as plain monospace text (existing behavior preserved)
- Theme integration: all new token colors defined in both Solarized Dark and Solarized Light palettes, plus the print palette
- Language label display on code blocks (already implemented, unchanged)

### 4.2 Out of Scope

- Languages not in the 16-language list (deferred to future work)
- Line numbers in code blocks
- Code block copy-to-clipboard enhancements (existing copy button behavior unchanged)
- Editor-side syntax highlighting (the editing pane remains plain text)
- Custom user-defined language grammars or grammar loading from disk
- Language auto-detection for untagged code blocks (untagged blocks remain unhighlighted)
- Async or background highlighting (highlighting runs synchronously in the existing rendering pipeline)
- Theme additions beyond Solarized Dark/Light (new themes are a separate feature)

### 4.3 Assumptions

| ID | Assumption | Impact if Wrong |
|----|------------|-----------------|
| A-1 | SwiftTreeSitter provides a synchronous parsing API that produces token ranges compatible with NSAttributedString construction | Would require refactoring the rendering pipeline to support async highlighting or finding an alternative tree-sitter wrapper |
| A-2 | SPM-compatible packages exist for all 16 target language grammars | May need to create or fork SPM wrappers for some grammars, adding one-time setup effort |
| A-3 | Tree-sitter's Swift grammar produces token quality equal to or better than Splash | Regression in Swift highlighting quality; mitigation is visual comparison testing before Splash removal |
| A-4 | Bundling 16 grammar binaries has acceptable impact on app binary size (estimated tens of MB) | May need to evaluate grammar loading strategies, though PRD explicitly prioritizes simplicity over binary size |
| A-5 | Tree-sitter node types across 16 grammars can be mapped to a finite, manageable set of SyntaxColors token types | May need per-language mapping tables; mitigated by defining a universal token type enum with language-specific overrides |

## 5. Functional Requirements

### FR-1: Tree-Sitter-Based Multi-Language Highlighting
**Priority**: Must Have
**User Type**: Markdown Viewer, Markdown Editor
**Requirement**: When a user opens a Markdown file containing fenced code blocks tagged with any of the 16 supported languages, the code block content is rendered with token-level syntax coloring derived from tree-sitter parsing.
**Rationale**: The core value proposition -- code blocks should look as polished as the rest of the rendering pipeline across all common languages in developer workflows.
**Acceptance Criteria**:
- AC-1.1: A fenced code block tagged with any of the 16 supported language identifiers (swift, python, javascript, typescript, rust, go, bash, sh, shell, json, yaml, yml, html, css, c, cpp, c++, ruby, java, kotlin) renders with colored tokens.
- AC-1.2: Token coloring distinguishes at minimum: keywords, strings, comments, numbers, functions/methods, types, and operators.
- AC-1.3: Common language tag aliases are recognized (e.g., "js" for JavaScript, "ts" for TypeScript, "py" for Python, "rb" for Ruby, "sh"/"shell" for Bash, "yml" for YAML, "cpp"/"c++" for C++).

### FR-2: Extended SyntaxColors Palette
**Priority**: Must Have
**User Type**: Markdown Viewer, Markdown Editor
**Requirement**: The SyntaxColors palette is extended with new token types to support richer coloring beyond the current set, so that different semantic elements within code are visually distinguishable.
**Rationale**: Tree-sitter produces a richer set of token types than Splash. Exposing more token types in the palette enables more informative coloring that helps users read and understand code at a glance.
**Acceptance Criteria**:
- AC-2.1: SyntaxColors includes token color definitions for at least: keyword, string, comment, number, function/method name, type name, operator, variable, constant/boolean, attribute/decorator, property, and punctuation.
- AC-2.2: Each new token type has a defined color in Solarized Dark, Solarized Light, and Print palettes.
- AC-2.3: All token colors maintain readable contrast against the code block background in both themes.

### FR-3: All 16 Language Grammars Bundled
**Priority**: Must Have
**User Type**: Markdown Viewer
**Requirement**: Tree-sitter grammars for all 16 target languages are bundled within the application binary so that highlighting works without network access or external grammar files.
**Rationale**: mkdn is a local-first tool launched from the terminal. Highlighting must work immediately, offline, with no setup beyond installing the app.
**Acceptance Criteria**:
- AC-3.1: The application builds with tree-sitter grammars for Swift, Python, JavaScript, TypeScript, Rust, Go, Bash/Shell, JSON, YAML, HTML, CSS, C, C++, Ruby, Java, and Kotlin.
- AC-3.2: No grammar is loaded from the filesystem at runtime; all are compiled into the binary.
- AC-3.3: Adding a new language grammar in the future requires only adding a new SPM dependency and a mapping entry (no architectural changes).

### FR-4: Complete Splash Replacement
**Priority**: Must Have
**User Type**: Markdown Viewer, Markdown Editor
**Requirement**: The Splash library dependency is fully removed from the project. Tree-sitter handles all syntax highlighting including Swift, which was previously handled by Splash.
**Rationale**: Maintaining two highlighting engines increases complexity, creates inconsistency in token granularity, and adds an unnecessary dependency. A single engine simplifies maintenance and ensures uniform behavior.
**Acceptance Criteria**:
- AC-4.1: Splash is removed from Package.swift dependencies.
- AC-4.2: No source file imports or references Splash.
- AC-4.3: ThemeOutputFormat.swift (Splash's OutputFormat implementation) is removed or replaced.
- AC-4.4: Swift code blocks are highlighted by tree-sitter with quality equal to or better than the previous Splash output.

### FR-5: Graceful Fallback for Unsupported Languages
**Priority**: Must Have
**User Type**: Markdown Viewer
**Requirement**: Fenced code blocks tagged with a language not in the 16 supported languages render as plain monospace text with the code block background styling, matching the current behavior for unsupported languages.
**Rationale**: Users may encounter niche languages (Elixir, Haskell, Lua, etc.) in Markdown files. The app must not crash, produce errors, or display broken rendering for these blocks.
**Acceptance Criteria**:
- AC-5.1: A code block tagged with an unsupported language (e.g., "elixir", "haskell") renders as monospace text with no coloring.
- AC-5.2: A code block with no language tag renders as monospace text with no coloring.
- AC-5.3: No error is logged, no crash occurs, and no visual glitch appears for unsupported or untagged code blocks.

### FR-6: Synchronous Rendering Pipeline Integration
**Priority**: Must Have
**User Type**: Markdown Viewer, Markdown Editor
**Requirement**: Syntax highlighting runs synchronously within the existing NSAttributedString rendering pipeline, matching the current integration pattern used by Splash.
**Rationale**: The rendering pipeline builds NSAttributedString synchronously. Introducing async highlighting would require significant architectural changes to the rendering pipeline, text storage builder, and view layer -- out of scope for this feature.
**Acceptance Criteria**:
- AC-6.1: Highlighting does not use async/await, Task, or any concurrency primitive in the hot path.
- AC-6.2: The MarkdownTextStorageBuilder calls the highlighting engine synchronously and receives colored attributed string ranges in the same call.
- AC-6.3: Preview rendering latency does not perceptibly increase for typical documents (under 10 code blocks of moderate size).

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| NFR-1 | Individual code block highlighting completes in under 16ms (single-frame budget at 60fps) | Must Have | Measured via instrumented timing on code blocks up to 200 lines. Blocks over 200 lines may exceed budget but must not block the UI for more than 50ms. |
| NFR-2 | Full document rendering with multiple code blocks does not regress perceptibly compared to current Splash-based rendering | Should Have | Side-by-side timing comparison with a benchmark document containing 10 code blocks in mixed languages. |

### 6.2 Security Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| NFR-3 | Tree-sitter grammars execute no user-supplied code; parsing is read-only analysis | Must Have | Tree-sitter is a parser generator producing deterministic state machines. No grammar can execute arbitrary code. Verified by architecture review. |

### 6.3 Usability Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| NFR-4 | Token colors are visually distinguishable from each other and from the code block background in both Solarized themes | Must Have | Visual inspection of all 16 languages in both themes. No two adjacent token types share the same color. All tokens readable against background. |
| NFR-5 | Highlighting does not interfere with existing code block interactions (text selection, copy button, find) | Must Have | Text selection across highlighted code blocks works correctly. Copy button copies raw unhighlighted text. Find highlights matches within highlighted code. |

### 6.4 Compliance Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| NFR-6 | All tree-sitter grammar dependencies use permissive open-source licenses (MIT, Apache 2.0, or equivalent) | Must Have | License audit of all 16 grammar packages before integration. |

## 7. User Stories

### STORY-1: Viewing Python Code in LLM Output
**As a** Markdown Viewer,
**I want** Python code blocks in LLM-generated Markdown to be syntax highlighted,
**So that** I can quickly scan function definitions, string literals, and control flow without reading every character.

**Acceptance**:
- GIVEN a Markdown file containing a fenced code block tagged with "python"
- WHEN the file is opened in mkdn
- THEN the code block renders with colored tokens for keywords (def, class, if, return), strings, comments, numbers, function names, and decorators

### STORY-2: Viewing Multi-Language Documentation
**As a** Markdown Viewer,
**I want** a Markdown file containing code blocks in JavaScript, Rust, and YAML to all be highlighted,
**So that** I can read a multi-language tutorial or spec without the visual jarring of some blocks being colored and others being plain text.

**Acceptance**:
- GIVEN a Markdown file containing fenced code blocks in JavaScript, Rust, and YAML
- WHEN the file is opened in mkdn
- THEN all three code blocks render with language-appropriate token coloring
- AND the coloring is consistent with the active Solarized theme

### STORY-3: Switching Themes with Highlighted Code
**As a** Markdown Viewer,
**I want** syntax highlighting colors to update correctly when I cycle between Solarized Dark and Solarized Light,
**So that** code blocks remain readable and visually consistent regardless of which theme I choose.

**Acceptance**:
- GIVEN a Markdown file with highlighted code blocks is open
- WHEN the user cycles the theme (e.g., via menu or keyboard shortcut)
- THEN all code block token colors update to match the new theme's SyntaxColors palette
- AND no tokens become invisible or unreadable against the new background

### STORY-4: Opening a File with an Unsupported Language
**As a** Markdown Viewer,
**I want** code blocks tagged with languages I use occasionally (e.g., Elixir, Haskell) to render cleanly even without highlighting,
**So that** I am not penalized for using a niche language -- the code is still readable.

**Acceptance**:
- GIVEN a Markdown file containing a fenced code block tagged with "elixir"
- WHEN the file is opened in mkdn
- THEN the code block renders as plain monospace text with the standard code block background
- AND no error message or visual artifact appears

### STORY-5: Printing a Document with Highlighted Code
**As a** Markdown Viewer,
**I want** syntax highlighting to use the print palette when I print a document,
**So that** code blocks are legible on paper with ink-efficient colors.

**Acceptance**:
- GIVEN a Markdown file with highlighted code blocks is open
- WHEN the user prints via Cmd+P
- THEN code block tokens use the PrintPalette.syntaxColors values
- AND the print output has readable contrast on white paper

### STORY-6: Swift Highlighting Quality After Migration
**As a** Markdown Viewer,
**I want** Swift code blocks to look at least as good after the migration from Splash to tree-sitter,
**So that** the highlighting upgrade does not regress the one language that was already working well.

**Acceptance**:
- GIVEN a Markdown file containing a complex Swift code block (class definition, closures, generics, string interpolation)
- WHEN the file is opened in mkdn after the migration
- THEN the token coloring is at least as granular as the previous Splash-based highlighting
- AND no Swift-specific constructs (e.g., @Observable, #expect, async/await) lose their coloring

## 8. Business Rules

| ID | Rule | Rationale |
|----|------|-----------|
| BR-1 | Language tag matching is case-insensitive. "Python", "python", and "PYTHON" all resolve to the Python grammar. | Markdown files from different sources use varying capitalization for language tags. |
| BR-2 | Common language aliases are recognized: js -> JavaScript, ts -> TypeScript, py -> Python, rb -> Ruby, sh/shell -> Bash, yml -> YAML, cpp/c++ -> C++. | LLM-generated Markdown uses both formal names and abbreviations interchangeably. |
| BR-3 | When a language tag matches no bundled grammar, the block renders as plain monospace with no error. The highlighting engine does not attempt partial matching or fuzzy lookup. | Predictable behavior is more important than best-effort guessing that could produce incorrect coloring. |
| BR-4 | Token-to-color mapping uses a universal token type enum. All 16 languages map their tree-sitter node types to this shared set. | Ensures visual consistency across languages -- a keyword looks the same color whether it is `def` in Python or `fn` in Rust. |
| BR-5 | The existing code block copy button copies raw, unhighlighted text regardless of highlighting state. Highlighting attributes do not affect clipboard content. | The rawCode attribute pattern (see Anti-Patterns in patterns.md) must be preserved. |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Purpose | Notes |
|------------|---------|-------|
| SwiftTreeSitter (ChimeHQ/SwiftTreeSitter) | Swift wrapper for tree-sitter parsing | SPM package. Provides synchronous parsing API. |
| 16 tree-sitter grammar packages | Language-specific parsers | Each as a separate SPM dependency. Specific packages to be identified during implementation (some may require SPM wrappers). |
| Existing SyntaxColors palette | Token color definitions | Must be extended, not replaced. Backward-compatible changes only. |
| Existing MarkdownTextStorageBuilder | NSAttributedString construction | Integration point for highlighting. Currently calls Splash; will call tree-sitter engine instead. |
| Existing ThemeColors system | Theme-aware color resolution | New token types must integrate with the existing Solarized Dark/Light/Print color system. |

### Constraints

| ID | Constraint | Impact |
|----|------------|--------|
| C-1 | Swift 6 strict concurrency | All new highlighting code must be concurrency-safe. Tree-sitter parser instances must be correctly isolated. |
| C-2 | Synchronous NSAttributedString pipeline | Highlighting must run synchronously. Cannot introduce async boundaries in the rendering hot path. |
| C-3 | macOS 14.0+ deployment target | Can use modern Swift/AppKit APIs available in macOS 14 but nothing requiring macOS 15+. |
| C-4 | SPM-only build system | All grammar dependencies must be available as SPM packages. No CocoaPods, Carthage, or manual framework embedding. |
| C-5 | Single rendering engine | After migration, tree-sitter is the sole highlighting engine. No Splash fallback, no dual-engine code path. |

## 10. Clarifications Log

| Date | Question | Resolution | Source |
|------|----------|------------|--------|
| 2026-02-17 | Which specific SPM packages exist for each grammar? | Deferred to implementation phase. PRD acknowledges this as OQ-1. Requirements specify the 16 languages; package selection is an implementation decision. | PRD OQ-1 |
| 2026-02-17 | What is the binary size impact of bundling 16 grammars? | PRD NFR-2 explicitly states "simplicity prioritized over binary size." No binary size constraint imposed at the requirements level. | PRD NFR-2 |
| 2026-02-17 | Should highlighting run async for large code blocks? | No. PRD FR-6 and C-2 require synchronous integration. Performance is bounded by NFR-1 (<16ms per block). Blocks exceeding 200 lines may take longer but must not exceed 50ms. | PRD FR-6, C-2 |
| 2026-02-17 | How should the "shell" language tag be handled vs "bash" vs "sh"? | All three aliases (bash, sh, shell) map to the Bash grammar. This is standard practice and avoids user confusion. | Conservative default, industry convention |
| 2026-02-17 | Should tree-sitter parsers be cached or recreated per block? | Implementation decision, not a requirement. The requirement is that highlighting meets the <16ms performance target. Caching is an optimization strategy. | Deferred to implementation |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | highlighting.md | FEATURE_ID "highlighting" directly matches PRD filename "highlighting.md". Single match, no ambiguity. |
| Performance threshold for large blocks | 50ms cap for blocks over 200 lines | PRD specifies <16ms for typical blocks. Extended a conservative 50ms cap for outliers to avoid over-constraining implementation while ensuring UI responsiveness. |
| Language alias set | js, ts, py, rb, sh, shell, yml, cpp, c++ | Industry-standard abbreviations. Conservative set covering only well-established aliases to avoid false matches. |
| Token type granularity | 12 token types minimum | Balances tree-sitter's rich node taxonomy with the need for a manageable palette. More than Splash's current set, fewer than the hundreds of tree-sitter node types. |
| Print palette integration | Included as requirement | Existing PrintPalette pattern (patterns.md) already has SyntaxColors. New token types must extend it. Omitting would create an inconsistency. |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| "Extend SyntaxColors palette" -- how many new token types? | Minimum 12 types: keyword, string, comment, number, function, type, operator, variable, constant/boolean, attribute/decorator, property, punctuation | Inferred from tree-sitter's common highlight query categories across multiple languages. Conservative minimum. |
| Case sensitivity of language tag matching | Case-insensitive matching | Industry convention; Markdown processors universally treat language tags as case-insensitive. |
| Handling of "c++" as a language tag | Supported as alias for C++ alongside "cpp" | The "+" characters are valid in Markdown info strings. Not supporting "c++" would confuse users. |
| Whether untagged code blocks should attempt detection | No auto-detection; render as plain monospace | PRD explicitly lists "Language auto-detection for untagged code blocks" as Out of Scope. |
| Whether the copy button behavior changes | No change; continues to use rawCode attribute | KB patterns.md anti-pattern explicitly requires rawCode attribute for clipboard content. Highlighting is display-only. |
| Whether entrance animations apply to highlighted tokens | Yes, existing entrance animation behavior unchanged | Highlighting changes only foreground color attributes on the NSAttributedString. EntranceAnimator operates on layout fragments, which are independent of text attributes. |
