# Feature: Markdown Rendering

> Parses Markdown text into a block model, converts it to a styled NSAttributedString, and displays it in a selectable NSTextView with overlay-positioned non-text elements.

## Overview

Markdown Rendering is the core pipeline of mkdn. It takes raw Markdown text, parses it via apple/swift-markdown into an AST, walks the AST with a custom visitor to produce a typed `[MarkdownBlock]` model, then converts those blocks into a single `NSAttributedString` for display in a TextKit 2 `NSTextView`. Non-text elements (Mermaid diagrams, images, math blocks, thematic breaks) are represented as `NSTextAttachment` placeholders with SwiftUI overlay views positioned at their layout coordinates. Tables use invisible inline text for selectability with a visual SwiftUI overlay on top.

## User Experience

- Opens a Markdown file and renders it as styled, native macOS content with theme-consistent colors and typography.
- Supports headings (H1--H6), paragraphs, ordered/unordered lists (nested 4+ levels), task lists with checkboxes, blockquotes (nested), code blocks with tree-sitter syntax highlighting (16 languages), tables with column alignment and row striping, images (local and remote), thematic breaks, Mermaid diagrams, LaTeX math (inline `$...$` and block `$$`), and HTML blocks (raw monospace fallback).
- Continuous cross-block text selection via click-drag, Shift-click, Cmd+A, Cmd+C.
- Clickable links open in the system browser; relative `.md` links navigate within the app; Cmd+click opens in a new window.
- Staggered entrance animation on document load (per-layout-fragment CALayer fade + drift), respecting Reduce Motion.
- Theme switching (Solarized Dark/Light) re-renders all content instantly without re-parsing.
- Debounced re-render (150ms) during live editing in split-screen mode.

## Architecture

**Data Flow:**
```
Raw Markdown String
  -> MarkdownRenderer.parse()          [apple/swift-markdown -> Document AST]
  -> MarkdownVisitor.visitDocument()   [AST -> [MarkdownBlock]]
  -> IndexedBlock wrapping             [positional identity]
  -> MarkdownTextStorageBuilder.build() [-> NSAttributedString + AttachmentMap + TableOverlayMap]
  -> SelectableTextView                [NSTextView + TextKit 2]
  -> OverlayCoordinator                [positions Mermaid/image/math/table/HR overlays]
  -> EntranceAnimator                  [per-fragment staggered animation]
```

**Key Types:**
- `MarkdownBlock` -- enum modeling all block variants (heading, paragraph, codeBlock, mermaidBlock, mathBlock, blockquote, orderedList, unorderedList, table, image, htmlBlock, thematicBreak) with deterministic content-based IDs (DJB2 hash)
- `IndexedBlock` -- pairs a MarkdownBlock with its document position for unique SwiftUI identity
- `ListItem` -- child container holding `[MarkdownBlock]` plus optional `CheckboxState`
- `MarkdownVisitor` -- stateless struct that walks the swift-markdown AST and produces `[MarkdownBlock]`, handling inline formatting (bold, italic, code, strikethrough, links) and inline math detection (`$...$`)
- `MarkdownRenderer` -- static coordinator: parse + visit in one call
- `MarkdownTextStorageBuilder` -- converts `[IndexedBlock]` to `NSAttributedString` with `NSTextAttachment` placeholders and table overlay info
- `PlatformTypeConverter` -- SwiftUI Color/Font to NSColor/NSFont conversion
- `SelectableTextView` -- `NSViewRepresentable` wrapping a read-only, selectable `NSTextView` (TextKit 2)
- `OverlayCoordinator` -- manages lifecycle and positioning of `NSHostingView` overlays for non-text blocks, including sticky table headers
- `EntranceAnimator` -- per-layout-fragment CALayer animation for staggered document entrance
- `LinkNavigationHandler` -- classifies link URLs into local Markdown, external, or other local file destinations

**Integration Points:**
- Consumed by: `MarkdownPreviewView` (preview mode), `SplitEditorView` (live preview in editor)
- Depends on: `AppSettings` (theme, scale factor), `DocumentState` (content, file URL), `FindState` (search highlighting), `SyntaxHighlightEngine` (tree-sitter), `MathRenderer` (SwiftMath), `MermaidBlockView` (WKWebView per diagram), `ThemeColors`/`SyntaxColors` (palette)

## Implementation Decisions

1. **Single NSTextView, not per-block SwiftUI Text views**: A single TextKit 2 NSTextView replaced independent SwiftUI `Text` views to enable continuous cross-block text selection -- the only native macOS approach that provides standard selection behaviors (Shift-click, Cmd+A, Cmd+C) without reimplementation.

2. **NSTextAttachment placeholders for non-text content**: Mermaid diagrams, images, math blocks, and thematic breaks use `NSTextAttachment` placeholders in the text flow, with SwiftUI views hosted in `NSHostingView` overlays positioned at attachment layout coordinates. This lets non-text elements participate in document flow while remaining interactive.

3. **Tables as invisible inline text + overlay**: Table content is rendered as invisible (clear foreground) inline text in the NSAttributedString so it participates in selection, find, and clipboard -- while the visual rendering uses a SwiftUI `TableBlockView` overlay with proper grid layout, alignment, and styling.

4. **Inline math via post-processing**: The visitor post-processes `$...$` delimiters after inline text assembly, tagging matching ranges with a custom `mathExpression` attribute. The text storage builder then renders these as `NSTextAttachment` images (SwiftMath) with baseline alignment.

5. **Deterministic block IDs (DJB2)**: Block identity uses a stable DJB2 hash of content rather than Swift's non-deterministic `.hashValue`, ensuring consistent diffing across process launches. `IndexedBlock` prepends the position index for uniqueness when content repeats.

6. **Visitor produces Foundation `AttributedString`, builder converts to `NSAttributedString`**: The visitor operates in the SwiftUI/Foundation layer with `AttributedString` for inline formatting. The text storage builder converts to `NSAttributedString` with platform-native `NSFont`/`NSColor` attributes, keeping parsing decoupled from rendering technology.

7. **Syntax highlighting via tree-sitter (16 languages)**: Code blocks use `SyntaxHighlightEngine` (tree-sitter based) for multi-language highlighting, replacing the earlier Swift-only Splash approach. Unsupported languages fall back to themed monospace.

## Files

| File | Role |
|------|------|
| `mkdn/Core/Markdown/MarkdownBlock.swift` | Block model enum, IndexedBlock, ListItem, CheckboxState, DJB2 hash |
| `mkdn/Core/Markdown/MarkdownVisitor.swift` | AST walker: block conversion, inline formatting, math delimiter detection |
| `mkdn/Core/Markdown/MarkdownRenderer.swift` | Static coordinator: parse + visit |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` | NSAttributedString builder: public API, block dispatch, inline conversion, helpers |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift` | Heading, paragraph, code block, attachment, HTML block rendering |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift` | Blockquote, ordered/unordered list, task list checkbox rendering |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder+TableInline.swift` | Table invisible-text + overlay info generation |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder+MathInline.swift` | Inline math -> NSTextAttachment image rendering |
| `mkdn/Core/Markdown/PlatformTypeConverter.swift` | SwiftUI Color/Font to NSColor/NSFont conversion |
| `mkdn/Core/Markdown/LinkNavigationHandler.swift` | Link URL classification and relative path resolution |
| `mkdn/Core/Markdown/CodeBlockAttributes.swift` | Custom NSAttributedString keys for code block background drawing |
| `mkdn/Core/Markdown/TableAttributes.swift` | Custom NSAttributedString keys for table range tracking |
| `mkdn/Core/Markdown/TableColumnSizer.swift` | Table column width calculation |
| `mkdn/Core/Markdown/TableCellMap.swift` | Table cell geometry mapping for selection/find |
| `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift` | SwiftUI orchestrator: debounced render, theme/scale change, wires SelectableTextView |
| `mkdn/Features/Viewer/Views/SelectableTextView.swift` | NSViewRepresentable: NSTextView + TextKit 2, theme application, find highlighting |
| `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` | Overlay lifecycle, positioning, attachment height updates |
| `mkdn/Features/Viewer/Views/OverlayCoordinator+TableOverlays.swift` | Table overlay creation and sticky header positioning |
| `mkdn/Features/Viewer/Views/OverlayCoordinator+Observation.swift` | Layout/scroll change observation for overlay repositioning |
| `mkdn/Features/Viewer/Views/OverlayCoordinator+TableHeights.swift` | Table height estimation and dynamic resizing |
| `mkdn/Features/Viewer/Views/EntranceAnimator.swift` | Per-layout-fragment CALayer entrance animation |

## Dependencies

- **External**: apple/swift-markdown (parsing), SwiftTreeSitter (syntax highlighting), SwiftMath (LaTeX rendering), Mermaid.js via WKWebView (diagram rendering)
- **Internal**: `AppSettings` (theme, scale), `DocumentState` (content, file URL), `FindState` (search), `ThemeColors`/`SyntaxColors` (palette), `AnimationConstants` (timing), `MotionPreference` (Reduce Motion)

## Testing

| Test File | Coverage |
|-----------|----------|
| `mkdnTests/Unit/Core/MarkdownRendererTests.swift` | Parsing all block types, heading levels, empty input, deterministic IDs |
| `mkdnTests/Unit/Core/MarkdownVisitorTests.swift` | Image blocks, strikethrough, table alignment, combined inline formatting, HTML blocks, links (URL/styling/text), nested lists (4 levels), task list checkboxes, edge cases |
| `mkdnTests/Unit/Core/MarkdownBlockTests.swift` | ListItem ID stability, IndexedBlock uniqueness and determinism |
| `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTests.swift` | Per-block-type NSAttributedString output (fonts, colors, paragraph styles, attachments), inline style preservation (bold, italic, code, links, strikethrough), block separation, multi-block plain text extraction, both themes |
| `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTableTests.swift` | Table inline text generation, cell mapping, selection integration |
| `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTests+PrintPalette.swift` | Print-specific palette rendering |
| `mkdnTests/Unit/Core/MarkdownTextStorageBuilderMathTests.swift` | Inline and block math rendering in text storage |
| `mkdnTests/Unit/Core/MarkdownVisitorMathTests.swift` | Math delimiter detection, escaped dollars, edge cases |
| `mkdnTests/Unit/Core/PlatformTypeConverterTests.swift` | Font mapping correctness, color conversion, paragraph style properties |
