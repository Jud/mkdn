# PRD: Core Markdown Rendering

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-06

## Surface Overview

The core-markdown-rendering surface is the foundational rendering pipeline for mkdn. It is responsible for parsing Markdown text using apple/swift-markdown, walking the AST with a custom MarkdownVisitor to produce MarkdownBlock model types, and rendering those blocks as native SwiftUI views.

Covered elements include all standard Markdown constructs: headings (H1-H6), paragraphs, ordered and unordered lists (including nested), tables, blockquotes, code blocks with language-aware syntax highlighting via Splash, images, links, and inline formatting (bold, italic, code, strikethrough).

Theming is structural and pluggable at the rendering level. The rendering pipeline accepts a theme (color palette, typography) and applies it uniformly across all block views. Solarized Dark and Light are the initial theme implementations, but the architecture supports any theme conforming to the ThemeColors protocol.

This surface explicitly excludes Mermaid diagram rendering and the editor/split-screen functionality, which will build on this rendering foundation as separate surfaces.

## Scope

### In Scope
- Markdown parsing via apple/swift-markdown (AST generation)
- Custom MarkdownVisitor that walks the AST and produces MarkdownBlock enum values
- MarkdownBlock model types covering: headings (H1-H6), paragraphs, ordered lists, unordered lists (including nested), tables, blockquotes, code blocks, images, links, inline formatting (bold, italic, code, strikethrough)
- MarkdownBlockView SwiftUI component that renders each MarkdownBlock variant as a native view
- CodeBlockView with language-aware syntax highlighting via Splash
- TableBlockView for native table rendering
- Pluggable theming system: ThemeColors protocol applied uniformly across all block views
- Solarized Dark and Solarized Light theme implementations
- MarkdownPreviewView (full-width preview mode) as the primary consumer of this pipeline

### Out of Scope
- Mermaid diagram detection and rendering (separate surface: mermaid-rendering)
- Editor functionality and SplitEditorView (separate surface: editor)
- File watching and reload (handled by FileWatcher, orthogonal to rendering)
- CLI argument handling (separate concern)
- Additional themes beyond Solarized Dark/Light (future work; architecture supports it)
- Export or serialization of rendered output

## Requirements

### Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Parse any valid Markdown document into a swift-markdown Document AST without error | Must |
| FR-2 | MarkdownVisitor converts the full AST into an array of MarkdownBlock values covering all supported block types | Must |
| FR-3 | MarkdownBlockView renders each MarkdownBlock variant as a native SwiftUI view with correct visual hierarchy | Must |
| FR-4 | Code blocks display syntax highlighting using Splash, with language detection from the fenced code block info string | Must |
| FR-5 | Tables render with aligned columns, header row styling, and row striping consistent with the active theme | Must |
| FR-6 | Nested lists render with correct indentation up to at least 4 levels | Must |
| FR-7 | Inline formatting (bold, italic, code, strikethrough) renders correctly within any block type including list items and blockquotes | Must |
| FR-8 | All rendered views consume ThemeColors for their palette (foreground, background, accent, code background, etc.) | Must |
| FR-9 | Links are visually styled and interactive (open in default browser on click) | Should |
| FR-10 | Images load from URL or local file path and display inline | Should |

### Non-Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-1 | Rendering a typical Markdown document (< 500 lines) completes in under 100ms on Apple Silicon | Must |
| NFR-2 | No WKWebView usage anywhere in the rendering pipeline -- fully native SwiftUI | Must |
| NFR-3 | Pipeline is stateless: given the same Markdown text and theme, output is deterministic | Must |
| NFR-4 | All public APIs are @MainActor-safe for direct use in SwiftUI view bodies | Must |
| NFR-5 | SwiftLint strict mode passes on all rendering pipeline code | Must |
| NFR-6 | Unit tests use Swift Testing framework (not XCTest) | Must |

## Dependencies & Constraints

### External Package Dependencies
| Package | Version | Purpose | Risk |
|---------|---------|---------|------|
| [apple/swift-markdown](https://github.com/apple/swift-markdown) | >= 0.5.0 | Markdown parsing to AST (Document, MarkupWalker) | Low -- Apple-maintained, stable API |
| [JohnSundell/Splash](https://github.com/JohnSundell/Splash) | >= 0.9.0 | Syntax highlighting for code blocks | Low -- mature, widely used. Note: limited language grammar set; may need custom grammars for less common languages |

### Platform Dependencies
| Dependency | Constraint |
|------------|------------|
| macOS 14.0+ (Sonoma) | Minimum deployment target; required for @Observable macro |
| Swift 6 / Xcode 16+ | Required for strict concurrency, swift-tools-version 6.0 |
| SwiftUI | Native rendering framework |

### Internal Dependencies
| Module | Relationship |
|--------|-------------|
| UI/Theme (ThemeColors, SolarizedDark, SolarizedLight) | Consumed by rendering pipeline; must be defined before rendering views can compile |
| App/AppState | Provides the active theme and markdown content to views via @Environment |

### Constraints
- **No WKWebView**: Hard architectural constraint from charter. All rendering must be native SwiftUI views.
- **SwiftLint strict mode**: All code must pass with all opt-in rules enabled.
- **@Observable macro**: State management must use @Observable (not ObservableObject/Combine).
- **SPM only**: No CocoaPods or Carthage; all dependencies managed through Swift Package Manager.
- **Splash language coverage**: Splash supports a fixed set of language grammars. Code blocks in unsupported languages will render with theme-consistent monospace styling but without token-level highlighting. This is an accepted limitation.

## Milestones

| Phase | Milestone | Description |
|-------|-----------|-------------|
| M1 | Parsing Foundation | MarkdownBlock enum, MarkdownVisitor walking swift-markdown AST, unit tests proving all block types parse correctly |
| M2 | Block Rendering | MarkdownBlockView + individual block views (headings, paragraphs, lists, blockquotes, images, links, inline formatting). Basic ThemeColors integration. |
| M3 | Code Block Highlighting | CodeBlockView with Splash integration, language detection, theme-consistent styling for unsupported languages |
| M4 | Table Rendering | TableBlockView with column alignment, header styling, row striping |
| M5 | Theme Polish & Preview Integration | ThemeColors protocol finalized, Solarized Dark/Light fully applied across all views, MarkdownPreviewView wired up |
| M6 | Testing & Hardening | Full unit test coverage (Swift Testing), edge case handling, SwiftLint clean |

## Open Questions

| ID | Question | Impact | Status |
|----|----------|--------|--------|
| OQ-1 | Should MarkdownRenderer cache parsed MarkdownBlock arrays for unchanged content, or re-parse on every view body evaluation? | Performance for large files | Open |
| OQ-2 | How should image loading failures be displayed (placeholder, error text, hidden)? | UX polish | Open |
| OQ-3 | Should the rendering pipeline support HTML blocks embedded in Markdown, or ignore them? | Feature completeness | Open |

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A1 | apple/swift-markdown AST covers all standard CommonMark block and inline types needed | Would need supplemental parsing or a different parser | Vision: "render beautifully" |
| A2 | Splash provides sufficient language grammar coverage for the user's typical code blocks | Code blocks in unsupported languages lack highlighting; may need custom grammars | Will Do: "Syntax highlighting for code blocks (paramount)" |
| A3 | SwiftUI Text + AttributedString is performant enough for syntax-highlighted code blocks up to ~500 lines | May need lazy rendering or virtualization for very large code blocks | NFR-1 |
| A4 | ThemeColors protocol can express all color and typography needs for every block type | Theme system may need extension; but pluggable by design | Will Do: "Terminal-consistent theming" |
| A5 | Rendering pipeline can remain stateless and re-render on every view update without performance issues | May need caching layer (see OQ-1) | Success: "daily-driver use" |

## Discoveries

- **Workaround**: When `GIT_COMMIT=false` leaves multiple tasks uncommitted, project-wide formatters/linters can destroy prior work via `git checkout`; run formatters only on specific files, or stash/commit intermediate work first. -- *Ref: [field-notes.md](archives/features/core-markdown-rendering/field-notes.md)*
- **Codebase Discovery**: Untracked (new) files survive `git checkout` incidents; when triaging recovery after accidental reverts, verify actual file state before re-assigning tasks. -- *Ref: [field-notes.md](archives/features/core-markdown-rendering/field-notes.md)*
