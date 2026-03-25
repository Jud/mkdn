# Markdown Parsing

## What This Is

This is the front door of the rendering pipeline. Raw markdown text comes in, and a typed array of `MarkdownBlock` values comes out. Every character of every document that mkdn displays passes through this code first.

The parsing layer exists because we need to get from "a string the user typed" to "a structured representation we can render." Apple's swift-markdown library gives us an AST, but that AST is too low-level for our rendering needs -- it models every inline span, every list item marker, every table cell as a generic `Markup` node. We need something that maps cleanly to our rendering pipeline: a flat list of block-level elements, each carrying its content in a form the text storage builder can consume directly.

## How It Works

Three types collaborate here, and they form a strict pipeline:

```
Raw String --> MarkdownRenderer.render()
                  |
                  v
              Document(parsing:)    [swift-markdown]
                  |
                  v
              MarkdownVisitor.visitDocument()
                  |
                  v
              [MarkdownBlock]
                  |
                  v
              [IndexedBlock]        (block + position + generation)
```

**MarkdownRenderer** (`mkdn/Core/Markdown/MarkdownRenderer.swift`) is the public facade -- an uninhabitable `enum` with static methods. It does almost nothing itself: parses the string into a swift-markdown `Document`, hands it to a `MarkdownVisitor`, then wraps each resulting `MarkdownBlock` in an `IndexedBlock` with a position index and a generation counter. The generation counter is key for SwiftUI identity -- it lets the downstream views distinguish "same block, different file load" from "same block, same file."

**MarkdownVisitor** (`mkdn/Core/Markdown/MarkdownVisitor.swift`) is where the real work happens. It's a struct (not a class -- no mutable state across calls) that walks the swift-markdown AST and produces `MarkdownBlock` values. The walk is recursive: `convertBlock()` dispatches on the AST node type, and for container blocks like blockquotes and lists, it recurses into children.

The visitor handles two categories of conversion:

1. **Block-level conversion** (`convertBlock`): Maps each AST node to the right `MarkdownBlock` case. Headings, paragraphs, code blocks, blockquotes, lists, tables, thematic breaks, HTML blocks, and images all have direct mappings. Code blocks with language `"mermaid"` become `.mermaidBlock` instead of `.codeBlock`. Code blocks with language `"math"`, `"latex"`, or `"tex"` become `.mathBlock`.

2. **Inline text conversion** (`convertInline`): Walks inline children (text, emphasis, strong, strikethrough, code, links, images, line breaks) and builds an `AttributedString` with `inlinePresentationIntent` attributes for bold/italic/code and standard `.link` attributes for hyperlinks. This `AttributedString` is what the text storage builder later converts to `NSAttributedString`.

There's a critical post-processing step after inline conversion: `postProcessMathDelimiters()` scans the `AttributedString` for `$...$` patterns and marks them with a custom `mathExpression` attribute. This is how inline math like `$E=mc^2$` gets detected -- the visitor doesn't have a native AST node for it (swift-markdown doesn't parse LaTeX), so we do a text-level scan after the fact.

**MarkdownBlock** (`mkdn/Core/Markdown/MarkdownBlock.swift`) is the domain model -- a 12-case enum that represents every block type mkdn can render. It's `Identifiable`, and the `id` property uses DJB2 hashing for stability across process launches (unlike Swift's `.hashValue`, which is randomized per process). The associated types are `AttributedString` for inline content, `String` for raw code, and recursive `[MarkdownBlock]` for containers like blockquotes. `IndexedBlock` wraps a `MarkdownBlock` with a position index and generation counter for SwiftUI view identity.

## Why It's Like This

**Why not just walk the AST directly in the text storage builder?** Because the two concerns are genuinely different. The visitor's job is to decide _what_ each block is. The text storage builder's job is to decide _how_ it looks. Separating them means we can test parsing independently of rendering, and the iOS platform layer can consume the same `[MarkdownBlock]` array with a completely different rendering strategy (LazyVStack of individual views instead of a single NSAttributedString).

**Why `AttributedString` for inline content instead of a custom type?** Because `AttributedString` already carries exactly the metadata we need (bold, italic, code, links, strikethrough) via `inlinePresentationIntent`, and it composes naturally. The custom `mathExpression` attribute extends this with a standard extension point (`AttributeScopes.MathAttributes`). Building a parallel inline representation would duplicate effort for no benefit.

**Why is the visitor a struct, not a `MarkdownWalker` subclass?** Swift-markdown provides `MarkupWalker` and `MarkupRewriter` protocols, but they impose a visitor pattern that doesn't map well to our "convert and collect" pattern. A plain struct with manual `switch` dispatch is simpler, more explicit, and easier to debug. Each `convertBlock` case is self-contained.

**Why DJB2 hashing for block IDs?** Swift's `Hashable.hashValue` is randomized per process launch for security reasons. Block IDs feed into SwiftUI view identity, and randomized IDs would cause unnecessary view recreation on app restart. DJB2 is deterministic, fast, and good enough for identity (we're not doing cryptography).

## Where the Complexity Lives

**Inline math detection** is the most intricate code here. The `findInlineMathRanges()` and `findClosingDollar()` methods implement a mini-parser with specific business rules: `$` followed by whitespace isn't a delimiter; `\$` is an escaped literal; `$$` is not an inline delimiter (it's display math); empty delimiters produce no math; unclosed `$` is literal text. These rules are documented as REQ-IDET-2 through REQ-IDET-5 in the code. The tricky part is that this operates on `AttributedString`, which has its own index type -- the `attributedStringRange()` method converts between `String.Index` and `AttributedString.Index` via character offsets.

**Paragraph promotion** is subtle. When a paragraph contains exactly one child and it's an image, the paragraph gets promoted to a block-level `.image`. When a paragraph's plain text content is wrapped in `$$...$$`, it gets promoted to a `.mathBlock`. This means the _structure_ of the parsed output depends on the _content_ of inline elements, which is unusual. It's done in `convertParagraph()`.

**Table conversion** must handle column alignment (left/center/right from the markdown syntax) and map each cell's inline content through the full `inlineText()` pipeline. Column count mismatches between header and body rows are silently handled by swift-markdown itself.

## The Grain of the Wood

If you're adding a new block type, the pattern is clear:

1. Add a case to `MarkdownBlock` with appropriate associated values
2. Add a match in `MarkdownVisitor.convertBlock()` to produce it from the AST
3. Update the `id` computed property for stable identity
4. Update `MarkdownTextStorageBuilder.appendBlock()` to handle the new case
5. Update `plainText(from:)` for find-in-page and accessibility

If you're adding a new inline element, extend `convertInline()` with a new case and use `inlinePresentationIntent` or a custom `AttributeScope` attribute to carry the metadata.

## Watch Out For

**The `compactMap` in `visitDocument` silently drops unrecognized nodes.** If swift-markdown adds a new block type, it will be ignored without warning. This is intentional -- we'd rather skip unknown content than crash -- but it means new markdown features require explicit support.

**Inline math detection modifies the `AttributedString` in reverse order.** The `mathRanges.reversed()` iteration in `postProcessMathDelimiters` is critical -- replacing subranges from end to start preserves the validity of earlier ranges. Replacing from start to end would invalidate all subsequent range indices.

**The `generation` counter on `IndexedBlock` must increment on file reloads.** If two different files produce identical block content, the generation ensures SwiftUI treats them as different views. This comes from `DocumentState.loadGeneration`. If you ever see stale content after a file switch, check that the generation is incrementing.

**`MarkdownBlock.isAsync` matters for entrance animation.** The `isAsync` property marks blocks that load content asynchronously (mermaid diagrams, images). The entrance gate uses this to hold the loading indicator until async overlays have rendered. If you add a new async block type, you need to update `isAsync`.

## Key Files

| File | What It Is |
|------|------------|
| `mkdn/Core/Markdown/MarkdownRenderer.swift` | Public facade: parse text, run visitor, wrap in IndexedBlock |
| `mkdn/Core/Markdown/MarkdownVisitor.swift` | AST walker: swift-markdown nodes to MarkdownBlock, inline math detection |
| `mkdn/Core/Markdown/MarkdownBlock.swift` | Domain model: 12-case enum, IndexedBlock wrapper, ListItem, CheckboxState, DJB2 hashing |
| `mkdn/Core/Math/MathAttributes.swift` | Custom AttributeScope for `mathExpression` attribute used by inline math detection |
