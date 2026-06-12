# mkdn

the reading side of the agentic loop. agents produce markdown — plans, code, diagrams, docs — and mkdn renders all of it natively on macOS. SwiftUI + TextKit 2, not a web browser in disguise.

and now the writing-back side: select text, comment on it. comments live in the `.md` file itself, and agents read them with `mkdn comments`.

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

```bash
mkdn comments list file.md            # read comments + reply threads as JSON
mkdn comments reply file.md k7 "done" --author agent
mkdn comments wait file.md            # block until new comments appear
```

## What it renders

Everything agents produce:

- **CommonMark** via [swift-markdown](https://github.com/apple/swift-markdown) — headings, lists, tables, blockquotes, images, inline formatting
- **Fenced code blocks** with [tree-sitter](https://github.com/ChimeHQ/SwiftTreeSitter) syntax highlighting (Swift, Python, JavaScript, TypeScript, Rust, Go, Bash, JSON, HTML, CSS, C, C++, Ruby, Java, YAML, Kotlin, TOML)
- **Source code files** — open `.swift`, `.py`, `.rs`, or any text file directly. full syntax highlighting, line numbers, horizontal scrolling
- **LaTeX math** — inline `$...$` and display `$$...$$` via [SwiftMath](https://github.com/mgriebling/SwiftMath)
- **Mermaid diagrams** in lightweight embedded WKWebViews (one per diagram, bundled mermaid.js, no network requests)

## Comments

select text — a word, inline code, mid-sentence — and comment on it. the comment lives in a sidecar block at the end of the `.md` file, so it survives in git, passes invisibly through other renderers, and re-finds its text by what it says, not where it sits. edit the prose around a comment in another editor and it re-anchors; if its text is gone, it collects in a detached footer instead of vanishing.

- comment rail (Cmd+Shift+C) — cards beside the text they annotate, following the scroll
- reply threads — replies nest under comments; agent replies via `mkdn comments reply` carry their author name
- paste-to-comment — paste onto a selection and the pasteboard text becomes a comment on it
- headless access — `mkdn comments list | reply | wait` for agents, no window needed

format reference: [docs/features/markdown-comments/comment-format.md](docs/features/markdown-comments/comment-format.md)

## Features

- Solarized Dark / Light themes (auto-follows system, or pinned)
- Staggered entrance animations — content cascades in on load and file switch
- Find in page (Cmd+F, Cmd+G / Cmd+Shift+G to navigate)
- Document outline (Cmd+J) — collapsible heading tree with a breadcrumb trail
- Marker track — headings and comments plotted along the right gutter, draggable thumb; swaps for a minimap (Cmd+Shift+M)
- Table selection that matches Chrome — drag across cells, double-click a word, triple-click a cell; Cmd+C copies tab-separated
- Big documents open fast — first screen paints in ~a third of a second, the rest fills in behind it
- VoiceOver-ready — custom rotors for headings, links, and comments; labeled table semantics
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
| Cmd+Shift+T | Cycle theme |
| Cmd+F | Find in page |
| Cmd+G | Next match |
| Cmd+Shift+G | Previous match |
| Cmd+E | Use selection for find |
| Cmd+J | Document outline |
| Cmd+Plus | Zoom in |
| Cmd+Minus | Zoom out |
| Cmd+0 | Reset zoom |
| Cmd+Shift+L | Toggle sidebar |
| Cmd+Shift+C | Toggle comment rail |
| Cmd+Shift+M | Toggle minimap |
| Cmd+Shift+O | Open directory |
| Cmd+P | Print |
| Cmd+Shift+P | Page setup |

## Architecture

Two-target SPM layout: `mkdnLib` (library) and `mkdn` (thin executable entry point). Feature-Based MVVM. Tests use `@testable import mkdnLib` — 844 tests across 89 suites.

```
mkdn/
  App/                  Entry point, AppSettings, commands
  Features/
    Viewer/             Markdown preview (TextKit 2 rendering)
    Editor/             Side-by-side editing
    Sidebar/            Directory browsing
    Outline/            Document outline navigator + breadcrumbs
  Core/
    Markdown/           swift-markdown parsing + NSAttributedString, comments
    Mermaid/            WKWebView + mermaid.js diagram rendering
    Highlighting/       Tree-sitter syntax highlighting
    Math/               LaTeX math rendering
    FileWatcher/        Kernel-level file change detection
    DirectoryScanner/   Recursive Markdown file discovery
    DirectoryWatcher/   Directory-level change monitoring
    Git/                Git status for the sidebar
    Services/           Shared service layer
    CLI/                Argument parsing, mkdn comments
    Instrumentation/    Performance instrumentation
    TestHarness/        Visual testing infrastructure
  Platform/
    iOS/                iOS-specific view implementations
  UI/
    Components/         WelcomeView, BreathingOrb, ModeOverlay, WindowAccessor
    Theme/              Solarized color palettes, ThemeMode, DesignTokens
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

Plus 17 tree-sitter grammar packages (one per language, pinned for build reproducibility).

## iOS

`mkdnLib` also compiles for iOS 17+. The `Platform/iOS/` layer provides 8 view implementations (text blocks, code blocks, math, images, tables, Mermaid). The app itself is macOS-only.

## License

MIT License. See [LICENSE](LICENSE) for details.
