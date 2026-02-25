# mkdn

**A Mac-native Markdown viewer built entirely in SwiftUI.**

No Electron. No compromise. Native SwiftUI rendering for all Markdown -- headings, code blocks, tables, and more -- with lightweight embedded web views only for Mermaid diagrams. macOS 14+.

Open this file in mkdn to see every feature in action.

---

## Why mkdn?

Most Markdown previewers are web browsers in disguise. mkdn takes a different path: every Markdown element is rendered by SwiftUI. Mermaid diagrams render in lightweight embedded web views -- one per diagram, shared process pool, no network requests. The result is a viewer that launches instantly, scrolls at 120fps, and feels like it belongs on your Mac.

---

## Features

### Native Rendering

Every Markdown element -- headings, paragraphs, lists, blockquotes, tables, thematic breaks, images, and inline formatting -- is parsed by Apple's [swift-markdown](https://github.com/apple/swift-markdown) library and rendered into a single `NSAttributedString` via TextKit 2, enabling native cross-block text selection. No HTML. No CSS. No DOM.

### Syntax Highlighting

Fenced code blocks display with full token-level syntax highlighting powered by [tree-sitter](https://tree-sitter.github.io/tree-sitter/) via [SwiftTreeSitter](https://github.com/ChimeHQ/SwiftTreeSitter). 16 languages with semantic coloring:

Swift, Python, JavaScript, TypeScript, Rust, Go, Bash, JSON, HTML, CSS, C, C++, Ruby, Java, YAML, Kotlin

```swift
@Observable
final class AppState {
    var currentFileURL: URL?
    var markdownContent = ""
    var viewMode: ViewMode = .previewOnly

    func loadFile(at url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        currentFileURL = url
        markdownContent = content
        fileWatcher.watch(url: url)
    }
}
```

### LaTeX Math

Inline (`$...$`) and display (`$$...$$`) LaTeX math expressions render natively using [SwiftMath](https://github.com/mgriebling/SwiftMath). No web views, no MathJax -- pure native rendering that matches the surrounding text style.

### Mermaid Diagrams

Flowcharts, sequence diagrams, state machines, class diagrams, and ER diagrams render in lightweight embedded web views:

1. Each diagram gets its own `WKWebView` with bundled `mermaid.js` -- no network requests
2. All diagram web views share a single `WKProcessPool` for efficiency
3. Click a diagram to activate pinch-to-zoom and pan
4. Press Escape to deactivate

### Directory Browsing

Open a directory to browse all Markdown files in a sidebar. Click files to preview them. The sidebar shows a recursive tree of directories and `.md`/`.markdown` files, sorted alphabetically with directories first.

### Find in Page

Press Cmd+F to search within the rendered preview. Matches are highlighted with the current match emphasized. Navigate between matches with Cmd+G / Cmd+Shift+G. Use Cmd+E to search for the current text selection.

### Tables

Tables render with full column alignment support, alternating row stripes, and native text selection across cells. Horizontal scrolling for wide tables.

### Solarized Theming

Two carefully tuned themes -- Solarized Dark and Solarized Light -- with an Auto mode that follows macOS system appearance. Theme changes crossfade smoothly. Every color in the app, from heading tints to code block backgrounds to table row stripes, is defined in a single `ThemeColors` struct.

| Mode | Behavior |
|:-----|:---------|
| Auto | Follows macOS light/dark appearance in real time |
| Dark | Solarized Dark, always |
| Light | Solarized Light, always |

### Zoom

Cmd+Plus to zoom in, Cmd+Minus to zoom out, Cmd+0 to reset. Zoom level persists across sessions.

### Chrome-less Window

mkdn hides the traffic lights, title bar, and all standard window chrome. The window is draggable by its background and fully resizable. What remains is just your content -- clean, focused, distraction-free.

### Breathing Orb

When the file changes on disk (edited in Vim, saved by a script, updated by git), a small orb pulses gently in the bottom-right corner. No modal dialogs. No alerts. Just a calm, breathing indicator that something changed. Press Cmd+R to reload.

### Side-by-Side Editing

Toggle between a full-width preview for reading and a split view with a live editor alongside the rendered output. Edits are reflected immediately. Unsaved changes are tracked; Cmd+S writes back to disk.

### File Watching

A kernel-level `DispatchSource` monitors the open file for changes. When another process writes to it, the breathing orb appears. Watching is paused during saves to avoid false triggers, then resumed automatically.

### CLI Integration

Launch from any terminal:

```bash
mkdn path/to/file.md
mkdn path/to/directory/
```

Built with Swift Argument Parser. Invalid paths produce clear error messages to stderr with appropriate exit codes.

### Drag and Drop

Drop any `.md` or `.markdown` file onto the window to open it. No file picker required.

---

## Keyboard Shortcuts

| Shortcut | Action |
|:---------|:-------|
| Cmd+O | Open a Markdown file |
| Cmd+S | Save current edits |
| Cmd+Shift+S | Save As |
| Cmd+W | Close window |
| Cmd+R | Reload file from disk |
| Cmd+1 | Switch to Preview mode |
| Cmd+2 | Switch to Edit mode |
| Cmd+T | Cycle theme (Auto / Dark / Light) |
| Cmd+F | Find in page |
| Cmd+G | Find next match |
| Cmd+Shift+G | Find previous match |
| Cmd+E | Use selection for find |
| Cmd+Plus | Zoom in |
| Cmd+Minus | Zoom out |
| Cmd+0 | Actual size |
| Cmd+Shift+L | Toggle sidebar |
| Cmd+P | Print |
| Escape | Deactivate Mermaid diagram zoom |

---

## Supported Markdown Elements

mkdn renders the full CommonMark spec natively:

- **Headings** (levels 1-6)
- **Paragraphs** with inline formatting (**bold**, *italic*, `code`, ~~strikethrough~~, [links](https://example.com))
- **Fenced code blocks** with language tags and 16-language syntax highlighting
- **LaTeX math** -- inline `$...$` and display `$$...$$`
- **Mermaid diagrams** (flowchart, sequence, state, class, ER)
- **Blockquotes**
- **Ordered and unordered lists**
- **Tables** with column alignment and text selection
- **Thematic breaks**
- **Images**

> mkdn is built for developers who live in the terminal and want their Markdown to look beautiful without leaving the native Mac experience.

---

## Supported Mermaid Diagrams

| Type | Keyword |
|:-----|:--------|
| Flowchart | `flowchart` or `graph` |
| Sequence Diagram | `sequenceDiagram` |
| State Diagram | `stateDiagram` or `stateDiagram-v2` |
| Class Diagram | `classDiagram` |
| ER Diagram | `erDiagram` |

---

## Install

### Homebrew

```bash
brew tap jud/mkdn
brew install --cask mkdn
```

### Build from Source

Requires macOS 14.0+ (Sonoma) and Xcode 16+ / Swift 6.

```bash
git clone https://github.com/jud/mkdn.git
cd mkdn
swift build
```

### Run

```bash
swift run mkdn path/to/file.md
```

### Test

```bash
swift test
```

---

## Project Structure

```
mkdn/
  App/                  Entry point, AppState, commands
  Features/
    Viewer/             Markdown preview (TextKit 2 rendering)
    Editor/             Side-by-side editing
    Sidebar/            Directory browsing
  Core/
    Markdown/           swift-markdown parsing + NSAttributedString rendering
    Mermaid/            WKWebView + mermaid.js diagram rendering
    Highlighting/       Tree-sitter syntax highlighting engine
    FileWatcher/        Kernel-level file change detection
    DirectoryScanner/   Recursive Markdown file discovery
    CLI/                Argument parsing and validation
  UI/
    Components/         WelcomeView, BreathingOrb, ModeOverlay, WindowAccessor
    Theme/              Solarized color palettes, ThemeMode
  Resources/            mermaid.min.js bundle

mkdnEntry/
  main.swift            Thin executable entry point

mkdnTests/
  Unit/                 Swift Testing suites (548 tests)
```

---

## Dependencies

| Package | Purpose |
|:--------|:--------|
| [swift-markdown](https://github.com/apple/swift-markdown) | Markdown AST parsing |
| [SwiftTreeSitter](https://github.com/ChimeHQ/SwiftTreeSitter) | Syntax highlighting (16 languages) |
| [SwiftMath](https://github.com/mgriebling/SwiftMath) | LaTeX math rendering |
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) | CLI argument handling |

---

## Design Philosophy

1. **Native over web.** Every Markdown element is rendered in SwiftUI. WKWebView is used only for Mermaid diagrams -- one per diagram, no network requests.
2. **Keyboard-first.** Every action has a shortcut. The mouse is optional.
3. **Calm feedback.** No modal alerts. A breathing orb for file changes. An ephemeral overlay for mode switches. Animations that feel physical, not decorative.
4. **Terminal-friendly.** Launch from the command line, edit in your terminal editor, preview in mkdn. The file watcher keeps everything in sync.
5. **Honest rendering.** What you see in mkdn is what swift-markdown parses. No custom extensions, no magic transformations.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
