# mkdn Architecture

## System Overview

```
CLI (mkdn file.md)
  |
  v
MkdnApp (SwiftUI App)
  |
  v
AppState (@Observable, environment)
  |
  +---> ContentView
  |       |
  |       +---> WelcomeView (no file)
  |       +---> MarkdownPreviewView (preview-only)
  |       +---> SplitEditorView (side-by-side)
  |
  +---> FileWatcher (DispatchSource)
  |
  +---> Theme system (Solarized Dark/Light)
```

## Rendering Pipeline

### Markdown
```
Raw text -> swift-markdown Document -> MarkdownVisitor -> [MarkdownBlock]
-> MarkdownBlockView (SwiftUI) -> native rendered output
```

### Mermaid Diagrams
```
Mermaid code block detected
-> MermaidRenderer (actor, singleton)
-> JXKit/JSContext + beautiful-mermaid.js
-> SVG string
-> SwiftDraw SVG rasterizer
-> NSImage
-> SwiftUI Image (with MagnifyGesture for pinch-to-zoom)
```

### Code Blocks
```
Code block with language tag
-> Splash SyntaxHighlighter
-> AttributedString with theme colors
-> SwiftUI Text
```

## Data Flow

1. File opened (CLI arg, drag-drop, or open dialog)
2. AppState.loadFile() reads content
3. FileWatcher starts monitoring for changes
4. Content flows to views via @Environment(AppState.self)
5. MarkdownRenderer parses on-demand in view body
6. Mermaid blocks trigger async rendering via MermaidRenderer actor

## Concurrency Model

- AppState: @MainActor (UI state)
- MermaidRenderer: actor (thread-safe JSC access + cache)
- FileWatcher: DispatchQueue + @MainActor for UI updates
