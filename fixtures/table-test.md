# Table Rendering Test

## Simple 3-Column

| Feature | Status | Notes |
|---------|--------|-------|
| Markdown rendering | Done | SwiftUI native |
| Mermaid diagrams | Done | WKWebView per diagram |
| Find bar | Done | Custom overlay |

## Wide Content

| Component | File Path | Description | Status |
|-----------|-----------|-------------|--------|
| AppSettings | mkdn/App/AppSettings.swift | Global settings and theme management | Active |
| ContentView | mkdn/App/ContentView.swift | Main document view with find bar overlay | Active |
| FindState | mkdn/Features/Viewer/ViewModels/FindState.swift | Find bar state machine | Active |
| DirectoryScanner | mkdn/Features/Directory/DirectoryScanner.swift | Recursive filesystem scanner | New |

## Minimal 2-Column

| Key | Value |
|-----|-------|
| Name | mkdn |
| Version | 0.1.0 |

## Alignment Test

| Left | Center | Right |
|:-----|:------:|------:|
| A | B | C |
| Longer text here | Short | 42 |
| X | Medium length | 1,234,567 |

## Wrapping Text

| Decision | Rationale | Trade-offs | Status |
|----------|-----------|------------|--------|
| Native SwiftUI for all UI | Ensures consistent look and feel across the app, leverages platform conventions, and avoids the complexity of bridging multiple UI frameworks | Limits flexibility for highly custom rendering; some advanced layout scenarios require AppKit fallbacks | Accepted |
| WKWebView only for Mermaid | Mermaid.js requires a full JavaScript runtime which SwiftUI cannot provide natively. Isolating each diagram in its own WKWebView prevents cross-contamination and simplifies lifecycle management | Adds memory overhead per diagram; WKWebView has noticeable cold-start latency on first load | Accepted |
| TextKit 2 for document rendering | Provides modern text layout with better performance for long documents, supports inline attachments for overlays, and enables continuous text selection across block boundaries | Less community documentation than TextKit 1; some edge cases with attachment positioning require manual layout invalidation | Accepted |
| Feature-based MVVM architecture | Organizes code by domain feature rather than technical layer, making it easier to find related files and reason about changes in isolation | Can lead to some duplication across features; shared utilities need careful placement to avoid circular dependencies | Accepted |

## 5-Column Dense

| ID | Category | Priority | Owner | Description |
|----|----------|----------|-------|-------------|
| T1 | Scanner | High | Core | Implement recursive directory scanning with configurable depth limits and file type filtering for the sidebar tree view |
| T2 | UI | Medium | Frontend | Design and build the collapsible tree view component with expand/collapse animations and keyboard navigation support |
| T3 | State | High | Core | Create the shared observable state model that synchronizes sidebar selection with the main content viewer and handles file change notifications |
| T4 | Integration | Low | QA | Write end-to-end tests covering directory open, file selection, live reload on external changes, and deep-link navigation from sidebar |

## Long Table (Sticky Header Test)

| # | File | Module | Description | Status | Priority |
|---|------|--------|-------------|--------|----------|
| 1 | AppSettings.swift | App | Global settings, theme management, scale factor persistence | Active | High |
| 2 | ContentView.swift | App | Main document view with find bar overlay and sidebar integration | Active | High |
| 3 | DocumentState.swift | App | Per-document state including file path and reload tracking | Active | High |
| 4 | DocumentState.swift | App | Per-document state including file path and reload tracking | Active | Medium |
| 5 | FindState.swift | Viewer | Find bar state machine with search, navigation, and match tracking | Active | Medium |
| 6 | MarkdownParser.swift | Core | Swift-markdown based parser producing MarkdownBlock tree | Active | High |
| 7 | MarkdownTextStorageBuilder.swift | Core | Converts MarkdownBlock tree to NSAttributedString with attachments | Active | High |
| 8 | TableColumnSizer.swift | Core | Content-aware column width computation with proportional compression | Active | Medium |
| 9 | SelectableTextView.swift | Viewer | NSViewRepresentable wrapping NSTextView with TextKit 2 for selection | Active | High |
| 10 | OverlayCoordinator.swift | Viewer | Manages overlay views at NSTextAttachment locations with sticky headers | Active | High |
| 11 | EntranceAnimator.swift | Viewer | Staggered cover-layer entrance animations for layout fragments | Active | Low |
| 12 | CodeBlockBackgroundTextView.swift | Viewer | NSTextView subclass drawing code block backgrounds and line numbers | Active | Medium |
| 13 | TableBlockView.swift | Viewer | SwiftUI table renderer with content-aware column widths | Active | Medium |
| 14 | TableHeaderView.swift | Viewer | Standalone header row for sticky header overlays | Active | Medium |
| 15 | MermaidBlockView.swift | Mermaid | WKWebView wrapper for Mermaid.js diagram rendering | Active | Medium |
| 16 | MermaidWebView.swift | Mermaid | NSViewRepresentable bridging WKWebView with scroll passthrough | Active | Medium |
| 17 | ImageBlockView.swift | Viewer | Async image loading with placeholder and error states | Active | Low |
| 18 | FindBarView.swift | Viewer | Custom find bar overlay with match count and navigation | Active | Medium |
| 19 | DirectoryScanner.swift | Directory | Recursive filesystem scanner with configurable depth and filtering | New | High |
| 20 | SidebarView.swift | Sidebar | Collapsible tree view for directory navigation | New | High |
| 21 | DirectoryContentView.swift | Sidebar | Split view integrating sidebar with document viewer | New | Medium |
| 22 | ThemeColors.swift | Theme | Color token definitions for all theme variants | Active | Medium |
| 23 | SolarizedDark.swift | Theme | Solarized Dark color palette implementation | Active | Low |
| 24 | SolarizedLight.swift | Theme | Solarized Light color palette implementation | Active | Low |
| 25 | PrintPalette.swift | Theme | High-contrast print-optimized color palette | Active | Low |

Some text after the tables to check spacing.
