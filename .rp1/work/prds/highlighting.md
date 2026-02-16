# PRD: highlighting

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-11

## Surface Overview

The **highlighting** surface expands mkdn's syntax highlighting from Swift-only (via Splash) to multi-language token-level coloring for the common languages that appear in LLM-generated Markdown artifacts. Currently, code blocks tagged with any language other than Swift render as plain monospace text with no semantic coloring. This surface delivers language-aware highlighting for the languages developers encounter most frequently in coding-agent output -- Python, JavaScript/TypeScript, Rust, Go, Bash, JSON, YAML, and others -- so that fenced code blocks in mkdn look as good as the rest of the native rendering pipeline.

## Scope
### In Scope
- Multi-language syntax highlighting for fenced code blocks with language tags
- Language coverage (first pass): Python, JavaScript, TypeScript, Rust, Go, Bash/Shell, JSON, YAML, HTML, CSS, C, C++, Ruby, Java, Kotlin
- Swift syntax highlighting (existing via Splash, maintained or migrated)
- Token-level coloring consistent with the existing Solarized theme system (SyntaxColors palette)
- Language label display on code blocks (already implemented)

### Out of Scope
- Languages not in the above list (deferred to future passes)
- Line numbers in code blocks
- Code block copy-to-clipboard
- Editor-side syntax highlighting (editing pane)
- Custom user-defined language grammars
- Language auto-detection for untagged code blocks

## Requirements
### Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Use SwiftTreeSitter wrapping tree-sitter grammars for multi-language syntax highlighting with semantic token accuracy | Must |
| FR-2 | Extend the SyntaxColors palette with new token types for richer coloring beyond the current 8 types (e.g., operator, variable, constant, attribute) | Must |
| FR-3 | Bundle tree-sitter grammars for all 16 target languages: Swift, Python, JavaScript, TypeScript, Rust, Go, Bash/Shell, JSON, YAML, HTML, CSS, C, C++, Ruby, Java, Kotlin | Must |
| FR-4 | Replace the Splash dependency entirely; tree-sitter handles all languages including Swift | Must |
| FR-5 | Languages without a bundled grammar render as plain monospace text with no highlighting (current fallback behavior preserved) | Must |
| FR-6 | Highlighting runs synchronously in the rendering pipeline, matching the current integration pattern | Must |

### Non-Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-1 | Target <16ms per code block for highlighting (single-frame budget at 60fps) | Must |
| NFR-2 | All 16 language grammars bundled in the app binary; simplicity prioritized over binary size | Must |
| NFR-3 | All token colors derived from the Solarized theme system (ThemeColors / SyntaxColors), consistent across light and dark modes | Must |

## Dependencies & Constraints

### Dependencies
| Dependency | Purpose | Integration |
|------------|---------|-------------|
| [SwiftTreeSitter](https://github.com/ChimeHQ/SwiftTreeSitter) | Swift wrapper for tree-sitter parsing | SPM package |
| tree-sitter language grammars (16 total) | Language-specific parsers for Swift, Python, JavaScript, TypeScript, Rust, Go, Bash/Shell, JSON, YAML, HTML, CSS, C, C++, Ruby, Java, Kotlin | Each grammar as a separate SPM dependency |

### Constraints
| ID | Constraint | Impact |
|----|------------|--------|
| C-1 | Swift 6 strict concurrency | All new highlighting code must be concurrency-safe |
| C-2 | Synchronous NSAttributedString pipeline | Highlighting must run synchronously in the existing rendering pipeline, not async |
| C-3 | macOS 14.0+ deployment target | Can use modern Swift/AppKit APIs but nothing requiring macOS 15+ |
| C-4 | Splash removal | Splash dependency must be fully removed; tree-sitter replaces it for all languages including Swift |
| C-5 | SPM-only build system | All grammar dependencies must be available as SPM packages |

## Milestones & Timeline
| Phase | Description | Key Deliverables |
|-------|-------------|------------------|
| Phase 1: Foundation | Integrate SwiftTreeSitter, add one grammar (Swift), extend SyntaxColors palette | SwiftTreeSitter SPM dependency added, Swift grammar bundled, new token types defined in SyntaxColors |
| Phase 2: Splash Replacement | Replace Splash with tree-sitter for Swift highlighting, remove Splash dependency | Splash removed from Package.swift, Swift code blocks highlighted via tree-sitter, all existing tests pass |
| Phase 3: Language Expansion | Add remaining 15 language grammars, implement language-to-grammar mapping | All 16 grammars bundled, language tag lookup working for all target languages |
| Phase 4: Polish & Performance | Performance validation (<16ms target), theme consistency audit, edge case handling | Performance benchmarks passing, light/dark mode verified for all languages, graceful fallback for untagged blocks |

## Open Questions
| ID | Question | Impact | Status |
|----|----------|--------|--------|
| OQ-1 | Which specific SPM packages exist for each of the 16 tree-sitter grammars? Some may need forks or wrappers. | Phase 3 delivery | Open |
| OQ-2 | What is the actual binary size impact of bundling all 16 grammars? | NFR-2 acceptance | Open |
| OQ-3 | Does SwiftTreeSitter's synchronous API meet the <16ms budget for large code blocks (500+ lines)? | NFR-1 acceptance | Open |

## Assumptions & Risks
| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A-1 | SwiftTreeSitter provides a synchronous parsing API compatible with NSAttributedString construction | Would require async pipeline refactor or a different tree-sitter wrapper | Syntax highlighting for code blocks (paramount) |
| A-2 | SPM-compatible packages exist for all 16 target language grammars | May need to create SPM wrappers for some grammars, adding maintenance burden | Will Do: Syntax highlighting |
| A-3 | Tree-sitter Swift grammar produces token quality equal to or better than Splash | Regression in Swift highlighting quality; may need to keep Splash as fallback | Will Do: Syntax highlighting |
| A-4 | Bundling 16 grammar binaries has acceptable impact on app binary size | May need to load grammars dynamically or reduce language count | Design Philosophy: simplicity |
| A-5 | Tree-sitter node types map cleanly to a finite set of SyntaxColors token types | May need per-language mapping tables, increasing maintenance complexity | Terminal-consistent theming |
