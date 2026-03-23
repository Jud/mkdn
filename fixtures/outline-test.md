# Project Architecture Overview

This document describes the overall architecture of the project, including its major components, design decisions, and implementation guidelines.

## Core Components

The core layer provides foundational building blocks that the rest of the application depends on. These components are designed to be stateless and testable in isolation.

### Rendering Engine

The rendering engine transforms raw Markdown text into structured block representations. It handles parsing, validation, and normalization of the input content.

Key responsibilities:
- Parse Markdown syntax into an abstract syntax tree
- Normalize heading levels and list indentation
- Extract metadata from frontmatter blocks
- Produce a flat array of indexed blocks for sequential rendering

```swift
enum MarkdownRenderer {
    static func render(_ text: String) -> [IndexedBlock] {
        let parser = MarkdownParser()
        let document = parser.parse(text)
        return document.blocks.enumerated().map { index, block in
            IndexedBlock(index: index, block: block)
        }
    }
}
```

### Theme System

The theme system provides consistent color palettes and typography settings across the entire application. Each theme defines foreground, background, accent, and semantic colors.

Currently supported themes:
- Solarized Light
- Solarized Dark

Both themes use the Solarized color palette by Ethan Schoonover, adapted for optimal readability in a Markdown viewing context.

## Feature Layer

The feature layer contains domain-specific modules that implement user-facing functionality. Each feature follows the MVVM pattern with observable state classes.

### Document Viewer

The document viewer is the primary feature module. It renders Markdown content using native SwiftUI views backed by an NSTextView for text layout. The viewer supports:

- Syntax-highlighted code blocks with tree-sitter grammars
- Mermaid diagram rendering via per-diagram WKWebViews
- LaTeX math rendering
- Table layout with column alignment
- Image loading with caching

### Find and Replace

The find feature provides in-document text search with keyboard navigation. It uses a floating bar overlay pattern with spring animations and supports:

- Case-sensitive and case-insensitive search
- Match highlighting in the text view
- Keyboard shortcuts for next/previous match
- Selection-based search initiation

### Document Outline Navigator

The outline navigator provides structural navigation through heading hierarchy. It has two visual modes:

1. **Breadcrumb bar** -- a thin, non-intrusive bar showing the current position in the heading hierarchy
2. **Outline HUD** -- an expanded overlay showing the complete heading tree with fuzzy filtering

The navigator is activated via Cmd+J or by clicking the breadcrumb bar.

## Application Layer

The application layer ties everything together. It manages window lifecycle, menu commands, keyboard shortcuts, and environment injection.

### Window Management

Each document window maintains its own state instances:
- `DocumentState` for document content and file operations
- `FindState` for find bar visibility and search state
- `OutlineState` for outline navigator visibility and heading tracking

### Menu Commands

Application commands are registered via SwiftUI's `Commands` protocol. Key shortcuts include:

| Shortcut | Action |
|----------|--------|
| Cmd+O | Open file |
| Cmd+F | Find in document |
| Cmd+J | Document outline |
| Cmd+1 | Preview mode |
| Cmd+2 | Edit mode |

## Design Decisions

### Why Native Text Layout?

We chose NSTextView with TextKit 2 over WKWebView for the primary content display. This decision was driven by:

1. **Performance** -- native text layout avoids the overhead of a full web engine
2. **Integration** -- direct access to the text layout manager enables features like find highlighting and scroll position tracking
3. **Memory** -- a single text view uses significantly less memory than a web view per document

The one exception is Mermaid diagram rendering, which requires a JavaScript runtime. Each diagram gets its own WKWebView instance with a click-to-focus interaction model.

### Why Observable over ObservableObject?

The project uses Swift's `@Observable` macro (introduced in iOS 17 / macOS 14) instead of the older `ObservableObject` protocol. Benefits:

- Finer-grained observation (only properties accessed in a view body trigger updates)
- No need for `@Published` property wrappers
- Cleaner syntax without `$` binding prefixes for read access
- Better performance in views that read only a subset of properties

### Why Feature-Based MVVM?

The codebase organizes code by feature rather than by layer. Each feature directory contains its views, view models, and feature-specific types. This keeps related code together and makes it easy to understand a feature's full implementation.

```
Features/
  Viewer/
    Views/
    ViewModels/
  Outline/
    Views/
    ViewModels/
  Editor/
    Views/
    ViewModels/
```

## Performance Considerations

### Scroll Performance

The text view handles documents up to tens of thousands of lines efficiently by using lazy text layout. The `NSTextLayoutManager` only computes layout for visible portions of the document, keeping scroll performance smooth.

### Heading Tree Rebuilds

The heading tree is rebuilt on every document content change. This is intentionally simple: the tree construction is O(n) where n is the number of blocks (typically under 1000), and rebuilding takes microseconds. Incremental updates would add complexity without measurable benefit.

## Future Directions

Several features are planned for future development:

- Export to HTML and PDF
- Custom theme creation
- Vim-style keyboard navigation
- Split view for comparing two documents
- Plugin system for custom block renderers

These features will follow the same architectural patterns established in the current codebase.
