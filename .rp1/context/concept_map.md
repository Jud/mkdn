# Domain Concepts & Terminology

**Project**: mkdn
**Domain**: Markdown Document Viewing & Editing (macOS Native)

## Core Concepts

### MarkdownBlock
**Definition**: Enum representing all renderable block-level Markdown elements (heading, paragraph, codeBlock, mermaidBlock, mathBlock, blockquote, orderedList, unorderedList, thematicBreak, table, image, htmlBlock). Each variant carries parsed content. Uses stable DJB2 hashing for SwiftUI identity.
**Implementation**: [`mkdn/Core/Markdown/MarkdownBlock.swift`]

### IndexedBlock
**Definition**: Pairs a MarkdownBlock with its positional index in the document, producing a unique composite ID for SwiftUI view diffing.
**Implementation**: [`mkdn/Core/Markdown/MarkdownBlock.swift`]

### DocumentState
**Definition**: Per-window `@Observable` model managing a single Markdown document's lifecycle: file I/O (load/save/reload/saveAs), unsaved-changes detection, file-outdated detection via FileWatcher, view mode, and mode overlay transitions.
**Implementation**: [`mkdn/App/DocumentState.swift`]

### AppSettings
**Definition**: App-wide `@Observable` singleton managing cross-window settings: theme mode (auto/dark/light), system color scheme bridge, auto-reload preference, zoom scale factor (0.5x–3.0x), and default-handler hint state. Persisted to UserDefaults.
**Implementation**: [`mkdn/App/AppSettings.swift`]

### AppTheme
**Definition**: Enum of available visual themes (solarizedDark, solarizedLight). Provides resolved ThemeColors and SyntaxColors palettes.
**Implementation**: [`mkdn/UI/Theme/AppTheme.swift`]

### DirectoryState
**Definition**: Per-window `@Observable` model for sidebar directory navigation. Owns the file tree, expansion/selection state, sidebar layout, and DirectoryWatcher for live filesystem monitoring. Holds weak reference to DocumentState for file loading.
**Implementation**: [`mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`]

### LaunchItem
**Definition**: Discriminated union (.file or .directory) for WindowGroup routing. Determines whether a window opens as a single-file viewer or directory browser.
**Implementation**: [`mkdn/App/LaunchItem.swift`]

## Rendering Pipeline Concepts

### MarkdownVisitor
**Definition**: Walks an apple/swift-markdown Document AST and produces an array of MarkdownBlock elements. Handles block conversion, inline text styling, table conversion, and inline math delimiter detection ($...$).
**Implementation**: [`mkdn/Core/Markdown/MarkdownVisitor.swift`]

### MarkdownRenderer
**Definition**: Stateless facade that parses raw Markdown text via apple/swift-markdown into a Document, then uses MarkdownVisitor to produce IndexedBlock arrays.
**Implementation**: [`mkdn/Core/Markdown/MarkdownRenderer.swift`]

### MarkdownTextStorageBuilder
**Definition**: Converts IndexedBlock arrays into a single NSAttributedString (TextStorageResult) for NSTextView display. Handles all block types with syntax highlighting, table invisible text, and attachment placeholders.
**Implementation**: [`mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`]

### TextStorageResult
**Definition**: Output of MarkdownTextStorageBuilder: NSAttributedString + attachment info (for Mermaid/math/image blocks) + table overlay info (for native table rendering).
**Implementation**: [`mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`]

## Specialized Rendering

### SyntaxHighlightEngine
**Definition**: Stateless, thread-safe syntax highlighting engine using tree-sitter. Creates parser and query per call. Returns colored NSMutableAttributedString or nil for unsupported languages. 16 languages supported.
**Implementation**: [`mkdn/Core/Highlighting/SyntaxHighlightEngine.swift`]

### MathRenderer
**Definition**: Renders LaTeX math expressions to NSImage via SwiftMath's CoreGraphics-based MathImage. Supports display and inline modes. Returns image + baseline offset for NSTextAttachment alignment.
**Implementation**: [`mkdn/Core/Math/MathRenderer.swift`]

### TableCellMap
**Definition**: Maps character offsets in a table's invisible text to cell positions (row, column). Provides O(log n) cell lookup via binary search, range intersection for selection, and tab-delimited/RTF extraction for clipboard.
**Implementation**: [`mkdn/Core/Markdown/TableCellMap.swift`]

## Terminology Glossary

### Block & Inline Elements
- **Block Element**: Top-level Markdown structural unit (heading, paragraph, code block, table, etc.). Represented by the MarkdownBlock enum.
- **Inline Element**: Text-level formatting within a block (bold, italic, code, links). Rendered as AttributedString runs.
- **Attachment Placeholder**: NSTextAttachment embedded in the attributed string for blocks needing custom rendering (Mermaid, math, images). Tracked via AttachmentInfo for overlay positioning.
- **Table Overlay**: Technique where table content is stored as invisible inline text with a TableCellMap, and a separate overlay draws the visible table on top.

### Theming
- **Solarized**: The color scheme family (Ethan Schoonover's palette) used for all themes.
- **ThemeColors**: 13 semantic color slots (background, foreground, accent, code, link, heading, etc.).
- **SyntaxColors**: 13 syntax highlighting color slots (keyword, string, comment, type, etc.).
- **ThemeMode**: User preference enum (auto, solarizedDark, solarizedLight). Auto resolves based on system appearance.
- **PrintPalette**: Non-user-selectable theme with ink-efficient colors, auto-applied during Cmd+P.
- **Scale Factor**: Zoom level (0.5x–3.0x) applied to all font sizes and spacing.

### Highlighting
- **Tree-sitter**: Incremental parsing library for syntax highlighting in code blocks. 16 languages via SwiftTreeSitter bindings.
- **TokenType**: Universal syntax token category enum (13 types). Maps tree-sitter capture names to colors.
- **Highlight Query**: Tree-sitter S-expression patterns embedded as Swift string literals, mapping AST nodes to token types.

### File System
- **FileWatcher**: Per-document filesystem monitor using DispatchSource. Detects on-disk changes, paused during saves.
- **DirectoryWatcher**: Filesystem monitor for sidebar mode. Watches root + first-level subdirectories for structural changes.
- **FileTreeNode**: Value-type tree node representing a directory or Markdown file for the sidebar browser.

### Math
- **Inline Math**: LaTeX in single $...$ within paragraphs. Detected by MarkdownVisitor, rendered as NSTextAttachment images.
- **Block Math**: LaTeX in fenced code blocks (math/latex/tex) or $$...$$. Rendered as attachment placeholders, inline during print.

### Identity
- **Stable Hash**: DJB2 hash producing deterministic UInt64 values across process launches (unlike Swift's `.hashValue`). Used for MarkdownBlock identity in SwiftUI.

## Bounded Contexts

| Context | Scope | Key Concepts |
|---------|-------|-------------|
| Markdown Processing | `Core/Markdown/` | MarkdownBlock, Visitor, Renderer, TextStorageBuilder, TableCellMap |
| Syntax Highlighting | `Core/Highlighting/` | SyntaxHighlightEngine, TokenType, TreeSitterLanguageMap |
| Math Rendering | `Core/Math/` | MathRenderer, MathExpressionAttribute |
| Mermaid Diagrams | `Core/Mermaid/` | MermaidRenderState, MermaidThemeMapper, MermaidWebView |
| Theming | `UI/Theme/` | AppTheme, ThemeMode, ThemeColors, SyntaxColors, PrintPalette |
| Application State | `App/` | DocumentState, AppSettings, ViewMode, LaunchItem |
| Directory Browsing | `Core/DirectoryScanner/` + `Features/Sidebar/` | FileTreeNode, DirectoryState, DirectoryWatcher |
| CLI & Launch | `Core/CLI/` | LaunchContext, CLIError, FileValidator, DirectoryValidator |

## Cross-Cutting Concerns

- **Theme Propagation**: AppTheme resolved in AppSettings, threaded through all rendering layers
- **Scale Factor**: Applied via PlatformTypeConverter font factories across all text rendering
- **SwiftUI–AppKit Bridge**: PlatformTypeConverter + custom NSAttributedString keys carry metadata across the bridge
- **Filesystem Change Detection**: FileWatcher (per-document) and DirectoryWatcher (per-directory) via DispatchSource
- **Stable Identity**: DJB2 hashing for deterministic SwiftUI view identity
- **Print Support**: PrintPalette auto-applied; math rendered inline instead of as attachments
