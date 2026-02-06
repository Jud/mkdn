# PRD: Syntax Highlighting

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-06

## Surface Overview

Syntax highlighting for fenced code blocks in the Markdown preview, powered by Splash. A custom `ThemeOutputFormat` adapter (NOT Solarized-specific) maps Splash token types to SwiftUI `AttributedString` fragments using colors from any `SyntaxColors` conformance -- making the adapter fully theme-agnostic. Solarized Dark/Light are the first two themes providing `SyntaxColors`, but the adapter itself has no knowledge of any specific theme.

Currently Splash only ships a Swift grammar. Swift code blocks get full token-level highlighting; all other languages fall back to plain monospaced text rendered in the theme's `codeForeground` color. The language label above the code block is always displayed when a language tag is present.

## Scope

### In Scope
- **Rename `SolarizedOutputFormat` to `ThemeOutputFormat`** -- the existing struct is already generic in behavior; only the name is Solarized-specific
- **`ThemeOutputFormat` conforms to Splash `OutputFormat`** -- accepts a `plainTextColor` and a `tokenColorMap: [TokenType: SwiftUI.Color]`, produces `AttributedString`
- **Token-to-color mapping** -- map all 9 Splash `TokenType` cases to corresponding `SyntaxColors` fields from the active theme
- **Swift-only highlighting** -- gate on `language == "swift"`; all other languages fall back to unstyled codeForeground monospaced text
- **Theme reactivity** -- when the user switches themes, code blocks re-highlight with the new SyntaxColors immediately
- **`SyntaxColors` struct** -- already exists with 8 color fields; both themes provide mappings
- **Unit tests** -- tests for `ThemeOutputFormat` builder, confirming all themes provide distinct syntax colors

### Out of Scope
- Multi-language grammars (Python, JS, Rust, etc.) via tree-sitter or other engines
- Line numbers in code blocks
- Copy-to-clipboard button on code blocks
- Editor-side syntax highlighting (preview-side only)
- Custom user themes or theme creation/import

## Requirements

### Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Rename `SolarizedOutputFormat` to `ThemeOutputFormat` -- no Solarized-specific naming in code | Must |
| FR-2 | `ThemeOutputFormat` accepts any `[TokenType: SwiftUI.Color]` map and a `plainTextColor` | Must |
| FR-3 | Swift code blocks are tokenized by `SyntaxHighlighter(format:)` and rendered as colored `AttributedString` | Must |
| FR-4 | Non-Swift code blocks render as plain monospaced text in `codeForeground` color | Must |
| FR-5 | Language label displayed above code block when language tag is present | Should |
| FR-6 | Code blocks are horizontally scrollable for long lines | Should |
| FR-7 | Theme switching instantly re-highlights all code blocks | Must |
| FR-8 | `ThemeOutputFormat.Builder` maps all 9 Splash `TokenType` cases to `SyntaxColors` fields | Must |

### Non-Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-1 | Highlighting is synchronous -- must remain fast (<5ms for typical code blocks) | Must |
| NFR-2 | No Solarized-specific naming in any code path -- all adapter code is theme-agnostic | Must |
| NFR-3 | `ThemeOutputFormat` and `ThemeOutputFormat.Builder` are `Sendable`-compatible | Should |
| NFR-4 | Text selection enabled on highlighted code blocks | Should |
| NFR-5 | Code block styling (rounded corners, border, background) consistent with theme colors | Should |

## Dependencies & Constraints

### External Dependencies
| Dependency | Version | Purpose | Risk |
|------------|---------|---------|------|
| [Splash](https://github.com/JohnSundell/Splash) | >= 0.9.0 | Swift syntax tokenization and `OutputFormat`/`OutputBuilder` protocol | Swift-only; no other language grammars |
| SwiftUI `AttributedString` | macOS 14+ | Rich text rendering in `Text` views | Requires macOS Sonoma minimum |

### Internal Dependencies
| Component | Relationship |
|-----------|-------------|
| `SyntaxColors` struct (ThemeColors.swift) | Provides the 8 color fields consumed by `ThemeOutputFormat` |
| `AppTheme.syntaxColors` | Routes to the active theme's `SyntaxColors` |
| `AppState.theme` | Observable state that triggers re-render on theme change |
| `CodeBlockView` | View that hosts `ThemeOutputFormat` and `SyntaxHighlighter` |

### Constraints
- **Swift-only tokenization**: Splash has no pluggable grammar system. Only Swift code gets highlighting. Accepted limitation for v1.
- **No WKWebView**: No web-based syntax highlighters (highlight.js, Prism, etc.).
- **Swift 6 strict concurrency**: All types must be `Sendable`-safe.
- **SwiftLint strict mode**: All code must pass with all opt-in rules enabled.

## Milestones

| Phase | Deliverable |
|-------|-------------|
| Phase 1 | Rename `SolarizedOutputFormat` -> `ThemeOutputFormat` across codebase |
| Phase 2 | Add/update unit tests for `ThemeOutputFormat` builder (token coloring, plain text, whitespace) |
| Phase 3 | Verify theme reactivity (manual QA: switch themes, confirm code blocks update) |

**Note**: Core functionality is already implemented in the scaffold. This is primarily a naming cleanup + test hardening pass.

## Open Questions

| ID | Question | Impact | Status |
|----|----------|--------|--------|
| OQ-1 | Should `ThemeOutputFormat` be extracted from `CodeBlockView.swift` into its own file? | Code organization | Open |
| OQ-2 | Should the `plainTextColor` default to `codeForeground` instead of `comment` color? | Visual correctness | Open |

## Assumptions & Risks

| ID | Assumption | Risk if Wrong |
|----|------------|---------------|
| A-1 | Splash 0.9.x OutputFormat API is stable | Would require adapter rewrite |
| A-2 | Swift-only highlighting is acceptable for v1 daily-driver use | Polyglot users may find it limiting |
| A-3 | Synchronous highlighting is fast enough for typical code blocks (<100 lines) | Large code blocks could cause frame drops |
