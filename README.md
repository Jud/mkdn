# mkdn

A beautiful, simple, Mac-native Markdown viewer and editor for terminal-based developer workflows.

## Features

- **Native SwiftUI rendering** -- no WKWebView, fully native performance
- **Mermaid diagram support** -- flowcharts, sequence diagrams, state machines, class diagrams, ER diagrams rendered natively via JavaScriptCore + beautiful-mermaid
- **Terminal-consistent theming** -- Solarized Dark and Light themes
- **Split-screen toggle** -- preview-only reading mode or side-by-side edit + preview
- **Syntax highlighting** -- code blocks with language-aware highlighting
- **File-change detection** -- subtle "outdated" indicator with manual reload
- **CLI-launchable** -- `mkdn file.md` from your terminal
- **Drag and drop** -- drop any .md file onto the window

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 16+ / Swift 6

## Build

```bash
swift build
```

## Run

```bash
swift run mkdn path/to/file.md
```

Or open in Xcode and run the mkdn scheme.

## Test

```bash
swift test
```

## Project Structure

```
mkdn/
  App/                  Entry point, app state, commands
  Features/
    Viewer/             Markdown preview (Views/, ViewModels/)
    Editor/             Edit mode (Views/, ViewModels/)
    Theming/            Theme picker
  Core/
    Markdown/           Parsing + native SwiftUI rendering
    Mermaid/            JavaScriptCore + beautiful-mermaid -> SVG -> native Image
    FileWatcher/        Kernel-level file change detection
    CLI/                Command-line argument handling
  UI/
    Components/         Reusable SwiftUI components
    Theme/              Solarized color definitions
  Resources/            Mermaid.js bundle

mkdnTests/
  Unit/
    Core/               MarkdownRenderer, FileWatcher, CLI, Theme tests
    Features/           AppState, EditorViewModel tests
  UI/                   UI automation tests (future)
```

## Architecture

- **Pattern**: Feature-Based MVVM
- **Rendering**: apple/swift-markdown for parsing, custom SwiftUI visitor for rendering
- **Mermaid**: JavaScriptCore (via JXKit) + beautiful-mermaid -> SVG string -> SwiftDraw -> native NSImage
- **File watching**: DispatchSource kernel-level filesystem events
- **No WKWebView**: The entire application is native SwiftUI

## License

Private project.
