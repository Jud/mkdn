# Feature Blueprints

Concise specifications for every feature mkdn ships. Each blueprint documents how the feature works, its architecture, and key implementation decisions -- enough to understand, maintain, or rebuild the feature.

## Rendering Pipeline

- [Markdown Rendering](markdown-rendering.md) -- Core parsing and display via TextKit 2
- [Syntax Highlighting](syntax-highlighting.md) -- Tree-sitter code coloring (16 languages)
- [Mermaid Diagrams](mermaid-diagrams.md) -- WKWebView diagram rendering
- [LaTeX Math](latex-math.md) -- Native math expression rendering
- [Tables](tables.md) -- Smart layout with cross-cell selection

## User Interface

- [Theming](theming.md) -- Solarized Dark/Light with auto mode
- [Animation System](animation-system.md) -- Motion primitives and accessibility
- [Print Support](print-support.md) -- Ink-efficient print palette
- [The Orb](the-orb.md) -- Unified state indicator
- [Find in Page](find-in-page.md) -- Custom search overlay
- [App Shell](app-shell.md) -- Window chrome, zoom, keyboard controls

## Features

- [Split Editor](split-editor.md) -- Side-by-side editing with live preview
- [Directory Sidebar](directory-sidebar.md) -- Folder browsing

## Infrastructure

- [CLI Integration](cli-integration.md) -- Terminal launch and Homebrew distribution
- [File Management](file-management.md) -- File open, watch, drag-drop, links
- [Test Harness](test-harness.md) -- Automated visual testing via Unix socket
