# Text Storage Building

## What This Is

This is the second stage of the rendering pipeline -- the one that turns structure into pixels. It takes the `[IndexedBlock]` array from the parser and produces a single `NSAttributedString` that gets displayed in a TextKit 2 `NSTextView`. Along the way, it produces metadata about where attachments live, where tables are positioned, and what the character offsets of headings are.

The text storage builder exists because macOS's text rendering stack is built on `NSAttributedString`. We chose to render the entire document as one attributed string in one text view (rather than a view-per-block approach) because it gives us native cross-block text selection, native find-in-page, native clipboard operations, and native accessibility -- all for free from TextKit 2. The tradeoff is that we have to do significant work to map our block model into the flat character stream that `NSAttributedString` expects.

## How It Works

`MarkdownTextStorageBuilder` (`mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`) is an `@MainActor` uninhabitable enum with static methods. The entry point is `build(blocks:theme:scaleFactor:isPrint:)`, which iterates through every `IndexedBlock` and dispatches to type-specific `append*` methods.

The build produces a `TextStorageResult` containing four things:

1. **`attributedString`** -- the complete `NSAttributedString` for the document
2. **`attachments`** -- an array of `AttachmentInfo` describing where placeholder `NSTextAttachment`s are positioned (for mermaid diagrams, images, math blocks, thematic breaks)
3. **`tableOverlays`** -- an array of `TableOverlayInfo` with `TableCellMap` instances for each table
4. **`headingOffsets`** -- a dictionary mapping block indices to character offsets, used by the outline navigator for scroll-to-heading

The builder has three rendering strategies depending on block type:

### Direct text blocks (headings, paragraphs, lists, blockquotes, code blocks, HTML)

These are converted to `NSAttributedString` segments with appropriate fonts, colors, and paragraph styles, then appended to the accumulating `NSMutableAttributedString`. The `convertInlineContent()` method walks `AttributedString` runs and converts `inlinePresentationIntent` attributes (bold, italic, code) to concrete `NSFont` instances via `PlatformTypeConverter`, and `.link` attributes to `NSAttributedString.Key.link` with underline styling.

Inline math is handled here too -- when `convertInlineContent()` encounters a run with the `mathExpression` attribute, it calls `renderInlineMath()` (in `MarkdownTextStorageBuilder+MathInline.swift`) which delegates to `MathRenderer` to produce an image, then wraps it in an `NSTextAttachment` with baseline alignment.

### Attachment placeholder blocks (mermaid, images, display math, thematic breaks)

These insert a transparent `NSTextAttachment` placeholder of a fixed height (100pt for content blocks, 17pt for thematic breaks). The `AttachmentInfo` struct records the block index, block type, and attachment object. Later, the `OverlayCoordinator` in the viewer layer uses this information to position SwiftUI overlay views (the actual `MermaidBlockView`, `ImageBlockView`, `MathBlockView`, `ThematicBreakView`) on top of these placeholder regions.

### Table blocks (the weird one)

Tables use neither direct text nor attachment placeholders. Instead, they write the table content as invisible inline text -- the foreground color is set to `.clear` so the characters are invisible, but they participate in NSTextView selection, find-in-page, and copy. A `TableCellMap` maps character offsets to cell positions (row, column) so the selection system knows which cells are selected. The actual visual table rendering is done by a `TableBlockView` SwiftUI overlay positioned on top of the invisible text region.

This invisible-text approach (`MarkdownTextStorageBuilder+TableInline.swift`) is genuinely clever -- it means Cmd+F finds text inside tables, Cmd+A selects table content, and Cmd+C copies table data as TSV/RTF. The alternative would have been to treat tables as opaque overlays (like mermaid blocks), but then you'd lose all text interaction.

### Block-specific rendering details

The extension files split the rendering by complexity:

- **`+Blocks.swift`** handles headings, paragraphs, code blocks (with syntax highlighting delegation), attachment placeholders, HTML blocks, blockquotes, ordered/unordered lists, and task list checkboxes. Lists support arbitrary nesting depth with increasing indentation and rotating bullet styles (bullet, circle, square, open square).

- **`+Complex.swift`** handles the blockquote and list rendering with recursive depth tracking, indent calculation, and the tab-stop-based list prefix alignment.

- **`+MathInline.swift`** handles inline `$...$` math rendering via `MathRenderer`, with baseline alignment using the `descent` value from SwiftMath's layout info.

- **`+TableInline.swift`** handles the invisible inline text generation for tables, including row height estimation, tab stop construction, and `TableCellMap` assembly.

## Why It's Like This

**Why one giant `NSAttributedString` instead of a view per block?** Cross-block text selection. Users expect to click-and-drag across headings, paragraphs, code blocks, and tables to select text. With a view-per-block architecture, you'd have to build a custom selection system that spans multiple views. With one text view, you get this for free from TextKit 2. The iOS platform layer does use view-per-block (via `LazyVStack`), because iOS users don't expect drag-to-select across blocks.

**Why `@MainActor` on the builder?** Because `NSMutableAttributedString` and `NSTextAttachment` are not `Sendable`. The builder creates these objects, so it must run on the main actor. The caller (`MarkdownPreviewView`) already runs its render task on the main actor anyway.

**Why are code block colors carried as `NSAttributedString` attributes?** Because the code block background drawing happens in `CodeBlockBackgroundTextView.drawBackground(in:)`, which receives an `NSAttributedString` and a range but has no access to the theme or app state. The `CodeBlockAttributes.colors` attribute carries a `CodeBlockColorInfo` object (background + border colors) directly on the attributed string, so the drawing code is self-contained. Same pattern for tables with `TableAttributes.colors` and `TableColorInfo`.

**Why is the first block's top spacing zeroed out?** The `textContainerInset` on the text view already provides top padding. Without zeroing the first block's `paragraphSpacingBefore`, you'd get double padding at the top of every document. This is the kind of thing that looks like a bug if you remove it.

**Why `isPrint` mode?** Print rendering needs different treatment: math blocks render as inline images (not overlays), and table text is visible (not clear). The `isPrint` flag switches these behaviors. This was added to support Cmd+P printing via `CodeBlockBackgroundTextView`'s print interception.

## Where the Complexity Lives

**List rendering** is the most complex part of the builder. Lists can nest arbitrarily deep (ordered inside unordered inside blockquote inside ordered), each level needs correct indentation via `headIndent`/`firstLineHeadIndent`, tab stops align the bullet/number prefix with the content, and task list items use SF Symbol checkboxes as `NSTextAttachment` images with baseline alignment matching the text. The `appendListItem` method in `+Complex.swift` handles all of this.

**Table invisible text** requires careful coordinate tracking. The `TableRowContext` carries `textStartOffset` (the character position where the table starts in the overall attributed string) so that cell entries can record their character ranges relative to that offset. The `TableCellMap` then uses these ranges for selection mapping. If these offsets are wrong, table selection highlighting will be misaligned.

**Paragraph style accumulation** is where things get fragile. Every block needs its own `NSParagraphStyle` with correct `paragraphSpacing`, `paragraphSpacingBefore`, `headIndent`, `firstLineHeadIndent`, `tailIndent`, `tabStops`, and `alignment`. These styles interact -- the spacing between two blocks is the maximum of the first block's `paragraphSpacing` and the second block's `paragraphSpacingBefore`. Getting this wrong produces subtle layout shifts.

**Heading offset tracking** records the character position of each heading before it's appended. This feeds the outline navigator's scroll-to-heading feature. The offset is the position _before_ the heading text, not after, which matters for scroll alignment.

## The Grain of the Wood

If you're adding a new block type to the rendering:

1. Add a case in `appendBlock()` that dispatches to your new `append*` method
2. Choose the right strategy: direct text (most blocks), attachment placeholder (async/visual content), or invisible text (if you need text selection)
3. For direct text: use `convertInlineContent()` for inline content, `makeParagraphStyle()` for layout, and end with `terminator(with:)` for the trailing newline
4. For attachments: use `appendAttachmentBlock()` and register an `AttachmentInfo`
5. Update `plainText(from:)` for the new case

If you're adjusting spacing, the constants at the top of the file (`blockSpacing`, `codeBlockPadding`, `listItemSpacing`, etc.) are the primary controls. Changing these affects every document.

## Watch Out For

**`NSAttributedString` attribute values must be NSObject subclasses or bridged types.** That's why `CodeBlockColorInfo` and `TableColorInfo` are `NSObject` subclasses, not structs. Swift structs bridged to `NSAttributedString` attributes cause subtle enumeration failures.

**The `scaleFactor` parameter flows through everything.** It controls font sizes (the user's zoom level). If you add new text rendering and forget to pass `scaleFactor` to the font factories, your text won't respond to Cmd+/Cmd-.

**Paragraph styles are shared by reference** (they're `NSParagraphStyle` objects). If you get a style from one character and mutate it, you'll affect every character with that style. Always use `mutableCopy()` before modifying, which is why the code has `force_cast` markers where it casts to `NSMutableParagraphStyle` -- there's no Swift-safe alternative.

**The builder's output depends on the current theme.** If the theme changes, the entire attributed string must be rebuilt. There's no incremental update mechanism -- the `MarkdownPreviewView` calls `build()` again with the cached blocks and the new theme.

## Key Files

| File | What It Is |
|------|------------|
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` | Main builder: dispatch, inline content conversion, paragraph helpers, attachment placeholders |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift` | Headings, paragraphs, code blocks (with highlighting), HTML blocks, math print mode |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift` | Blockquotes and lists with recursive nesting, task list checkboxes |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder+MathInline.swift` | Inline `$...$` math to NSTextAttachment images with baseline alignment |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder+TableInline.swift` | Table invisible text, row height estimation, TableCellMap assembly |
| `mkdn/Core/Markdown/CodeBlockAttributes.swift` | Custom NSAttributedString keys for code block rendering metadata |
| `mkdn/Core/Markdown/TableAttributes.swift` | Custom NSAttributedString keys for table selection and rendering metadata |
| `mkdn/Core/Markdown/TableCellMap.swift` | Character offset to cell position mapping for table selection |
| `mkdn/Core/Markdown/TableColumnSizer.swift` | Content-aware column width computation with proportional compression |
| `mkdn/Core/Markdown/PlatformTypeConverter.swift` | Cross-platform font/color/image typealiases and bridge methods |
