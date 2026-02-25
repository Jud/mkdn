# mkdn - Knowledge Base

**Type**: Single Project
**Languages**: Swift 6
**Stack**: SwiftUI, macOS 14.0+, SPM
**Updated**: 2026-02-25

## Project Summary

mkdn is a Mac-native Markdown viewer/editor built with Swift 6 and SwiftUI. It renders Markdown documents using apple/swift-markdown for parsing and a custom NSAttributedString-based renderer with native text selection, syntax-highlighted code blocks (tree-sitter, 16 languages), Mermaid diagram rendering (WKWebView), LaTeX math (SwiftMath), and smart table layout with cross-cell selection.

## Quick Reference

| Aspect | Value |
|--------|-------|
| Entry Point | `mkdnEntry/main.swift` → CLI parse → execv → SwiftUI lifecycle |
| Key Pattern | Feature-Based MVVM with Environment-based DI |
| Tech Stack | Swift 6, SwiftUI, swift-markdown, SwiftTreeSitter, SwiftMath, Mermaid.js |
| Central State | `AppSettings` (app-wide), `DocumentState` (per-window) |
| Rendering Pipeline | MarkdownVisitor → [MarkdownBlock] → MarkdownTextStorageBuilder → NSAttributedString |

## KB File Manifest

**Progressive Loading**: Load files on-demand based on your task.

| File | Lines | Load For |
|------|-------|----------|
| architecture.md | ~190 | System design, layer structure, data flows, dependencies |
| modules.md | ~225 | Component breakdown, file inventory, module responsibilities |
| patterns.md | ~73 | Code conventions, naming, error handling, testing idioms |
| concept_map.md | ~121 | Domain terminology, rendering concepts, bounded contexts |

## Task-Based Loading

| Task | Files to Load |
|------|---------------|
| Code review | `patterns.md` |
| Bug investigation | `architecture.md`, `modules.md` |
| Feature implementation | `modules.md`, `patterns.md` |
| Strategic analysis | ALL files |

## How to Load

```
Read: .rp1/context/{filename}
```

## Quick Reference Paths

- Entry point: `mkdnEntry/main.swift`
- Central state: `mkdn/App/AppSettings.swift`, `mkdn/App/DocumentState.swift`
- Markdown pipeline: `mkdn/Core/Markdown/`
- Mermaid pipeline: `mkdn/Core/Mermaid/`
- Math rendering: `mkdn/Core/Math/`
- Syntax highlighting: `mkdn/Core/Highlighting/`
- Directory browser: `mkdn/Features/Sidebar/`, `mkdn/Core/DirectoryScanner/`
- Theme definitions: `mkdn/UI/Theme/`
- Animation constants: `mkdn/UI/Theme/AnimationConstants.swift`
- Test harness (app-side): `mkdn/Core/TestHarness/`
- Test harness (client-side): `mkdnTests/Support/`
- Unit tests: `mkdnTests/Unit/`

## Project Structure

```
mkdnEntry/              # Executable entry point (main.swift)
mkdn/
├── App/                # SwiftUI lifecycle, state, commands, window management
├── Core/
│   ├── CLI/            # Argument parsing, validation, launch context
│   ├── Markdown/       # Visitor, renderer, text storage builder, table support
│   ├── Highlighting/   # Tree-sitter syntax highlighting (16 languages)
│   ├── Math/           # LaTeX rendering via SwiftMath
│   ├── Mermaid/        # WKWebView-based diagram rendering
│   ├── FileWatcher/    # Per-document change detection (DispatchSource)
│   ├── DirectoryScanner/ # Recursive file tree builder
│   ├── DirectoryWatcher/ # Directory change monitoring
│   ├── Services/       # DefaultHandlerService (Launch Services)
│   └── TestHarness/    # Unix socket test automation
├── Features/
│   ├── Viewer/         # Preview, text view, overlays, find bar, block views
│   ├── Editor/         # Split editor, resizable pane
│   ├── Sidebar/        # Directory browser sidebar
│   └── Theming/        # Theme picker
├── UI/
│   ├── Theme/          # AppTheme, colors, animations, print palette
│   └── Components/     # Orb, welcome view, window accessor, overlays
└── Resources/          # Info.plist, AppIcon, mermaid template
mkdnTests/
├── Unit/               # ~55 test files (Core/, Features/, UI/, Support/)
└── Support/            # Test utilities (ImageAnalyzer, TestHarnessClient, etc.)
```

## Critical Constraints

1. WKWebView only for Mermaid diagrams (one per diagram)
2. `@Observable` macro (not ObservableObject)
3. Swift Testing for unit tests (`@Test`, `#expect`, `@Suite`)
4. SwiftLint strict mode (Homebrew install, needs Xcode toolchain)
5. Two-target layout: `mkdnLib` (library) + `mkdn` (executable) — tests import `mkdnLib`

## Navigation

- **[architecture.md](architecture.md)**: System design, layers, data flows, dependencies
- **[modules.md](modules.md)**: File inventory, module responsibilities
- **[patterns.md](patterns.md)**: Code conventions, testing idioms
- **[concept_map.md](concept_map.md)**: Domain terminology, bounded contexts
