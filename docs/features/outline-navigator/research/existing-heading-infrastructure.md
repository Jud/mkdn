# Existing Heading Infrastructure

**Date:** 2026-03-21
**Source:** `mkdn/Core/Markdown/MarkdownBlock.swift`, `mkdn/Core/Markdown/MarkdownRenderer.swift`

## Finding

Headings are already parsed and available as `MarkdownBlock.heading(level:text:)` within `IndexedBlock` arrays. The heading text is an `AttributedString` (preserving inline formatting like bold/code), and the level is 1-6. Each `IndexedBlock` carries an `index: Int` that maps to its position in the document, which can be used for scroll targeting via `BlockScrollTarget`.

## Evidence

From `MarkdownBlock.swift:23`:
```swift
case heading(level: Int, text: AttributedString)
```

From `MarkdownRenderer.swift:22-25`:
```swift
let blocks = visitor.visitDocument(document)
return blocks.enumerated().map { offset, element in
    IndexedBlock(index: offset, block: element, generation: generation)
}
```

The `IndexedBlock.index` is a sequential integer assigned during rendering. This is the same index used by `BlockScrollTarget.blockIndex` for programmatic scrolling in `MarkdownContentView`.

Key implication: No new parsing is needed. The heading tree can be extracted by filtering `[IndexedBlock]` for `.heading` cases and building a tree from their levels.
