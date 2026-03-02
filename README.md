# mkdn

Native Markdown viewer for macOS. SwiftUI rendering, not a web browser in disguise.

## Install

**Homebrew:**

```bash
brew install jud/mkdn/mkdn
```

**Build from source** (macOS 14+, Xcode 16+, Swift 6, Apple Silicon):

```bash
git clone https://github.com/jud/mkdn.git
cd mkdn
swift build
```

## Usage

```bash
mkdn file.md
mkdn docs/           # directory mode with sidebar
```

Also supports Cmd+O and drag-and-drop.

## What it renders

- **CommonMark** via [swift-markdown](https://github.com/apple/swift-markdown) — headings, lists, tables, blockquotes, images, inline formatting
- **Fenced code blocks** with [tree-sitter](https://github.com/ChimeHQ/SwiftTreeSitter) syntax highlighting (Swift, Python, JavaScript, TypeScript, Rust, Go, Bash, JSON, HTML, CSS, C, C++, Ruby, Java, YAML, Kotlin)
- **LaTeX math** — inline `$...$` and display `$$...$$` via [SwiftMath](https://github.com/mgriebling/SwiftMath)
- **Mermaid diagrams** in lightweight embedded WKWebViews (one per diagram, bundled mermaid.js, no network requests)

## Features

- Solarized Dark / Light themes (auto-follows system, or pinned)
- Find in page (Cmd+F, Cmd+G / Cmd+Shift+G to navigate)
- Side-by-side editor with live preview
- Zoom (Cmd+/-, persists across sessions)
- File watching — kernel-level DispatchSource, breathing orb on change
- Chrome-less window — no title bar, no traffic lights
- Directory browsing with sidebar (Cmd+Shift+L to toggle)
- Print (Cmd+P)

## Keyboard shortcuts

| Shortcut | Action |
|:---------|:-------|
| Cmd+O | Open file |
| Cmd+S | Save |
| Cmd+Shift+S | Save As |
| Cmd+W | Close window |
| Cmd+R | Reload from disk |
| Cmd+1 | Preview mode |
| Cmd+2 | Edit mode |
| Cmd+T | Cycle theme |
| Cmd+F | Find in page |
| Cmd+G | Next match |
| Cmd+Shift+G | Previous match |
| Cmd+E | Use selection for find |
| Cmd+Plus | Zoom in |
| Cmd+Minus | Zoom out |
| Cmd+0 | Reset zoom |
| Cmd+Shift+L | Toggle sidebar |
| Cmd+P | Print |

## Architecture

Two-target SPM layout: `mkdnLib` (library) and `mkdn` (thin executable entry point). Feature-Based MVVM. Tests use `@testable import mkdnLib` — 634 tests across 57 suites.

```
mkdn/
  App/                  Entry point, AppSettings, commands
  Features/
    Viewer/             Markdown preview (TextKit 2 rendering)
    Editor/             Side-by-side editing
    Sidebar/            Directory browsing
  Core/
    Markdown/           swift-markdown parsing + NSAttributedString
    Mermaid/            WKWebView + mermaid.js diagram rendering
    Highlighting/       Tree-sitter syntax highlighting
    Math/               LaTeX math rendering
    FileWatcher/        Kernel-level file change detection
    DirectoryScanner/   Recursive Markdown file discovery
    DirectoryWatcher/   Directory-level change monitoring
    Services/           Shared service layer
    CLI/                Argument parsing and validation
    TestHarness/        Visual testing infrastructure
  Platform/
    iOS/                iOS-specific view implementations
  UI/
    Components/         WelcomeView, BreathingOrb, ModeOverlay, WindowAccessor
    Theme/              Solarized color palettes, ThemeMode
  Resources/            mermaid.min.js bundle

mkdnEntry/
  main.swift            Executable entry point

mkdnTests/
  App/                  App-level tests
  Unit/                 Unit test suites
  Support/              Test helpers and fixtures
```

## Dependencies

| Package | Purpose |
|:--------|:--------|
| [swift-markdown](https://github.com/apple/swift-markdown) | Markdown parsing |
| [SwiftTreeSitter](https://github.com/ChimeHQ/SwiftTreeSitter) | Syntax highlighting |
| [SwiftMath](https://github.com/mgriebling/SwiftMath) | LaTeX math rendering |
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) | CLI argument handling |

Plus 16 tree-sitter grammar packages (one per language, pinned for build reproducibility).

## iOS

`mkdnLib` also compiles for iOS 17+. The `Platform/iOS/` layer provides 8 view implementations (text blocks, code blocks, math, images, tables, Mermaid). The app itself is macOS-only.

## License

MIT License. See [LICENSE](LICENSE) for details.
