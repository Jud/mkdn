# PRD: block-rendering-fix

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-07

## Overview

Two related rendering bugs in mkdn's Markdown preview pipeline cause code blocks and other content to render as invisible empty areas:

1. **Duplicate MarkdownBlock IDs**: The `thematicBreak` case in `MarkdownBlock.id` always returns the static string `"hr"`. In a document with multiple thematic breaks (`---`), all produce identical IDs. Since `MarkdownPreviewView` uses `ForEach(..., id: \.element.id)`, SwiftUI's diffing algorithm corrupts the view hierarchy -- blocks sharing an ID become invisible or render incorrectly. The `blockAppeared` dictionary (used for stagger animations) is also keyed on `block.id`, so duplicates corrupt animation state.

2. **Missing foreground color on whitespace runs**: `ThemeOutputFormat.Builder.addWhitespace(_:)` appends an `AttributedString` without setting `.foregroundColor`. When SwiftUI's `Text` view renders the resulting `AttributedString` from Splash syntax highlighting, whitespace runs inherit no color, which can cause visual artifacts in Swift code blocks -- specifically, runs adjacent to whitespace may lose their intended color or render inconsistently.

### Root Cause Evidence

- `MarkdownBlock.swift:47` -- `case .thematicBreak: "hr"` (static, no content-based uniqueness)
- `ThemeOutputFormat.swift:31-33` -- `addWhitespace` creates `AttributedString(whitespace)` without `.foregroundColor`
- `MarkdownPreviewView.swift:31` -- `ForEach(Array(renderedBlocks.enumerated()), id: \.element.id)` relies on unique IDs
- `MarkdownPreviewView.swift:33-34` -- `blockAppeared[block.id]` dictionary keyed on potentially-duplicate IDs

## Scope

### In Scope

- Fix `MarkdownBlock.id` so that every block produces a unique ID within a document, including `thematicBreak` and any other content-identical blocks (e.g., two identical paragraphs). Incorporate positional or ordinal information to disambiguate.
- Fix `ThemeOutputFormat.Builder.addWhitespace()` to set `.foregroundColor = plainTextColor` on the whitespace `AttributedString`, matching the behavior of `addPlainText()` and `addToken()`.
- Add or update unit tests covering both fixes.

### Out of Scope

- Mermaid rendering pipeline
- FileWatcher
- Editor views
- CLI / Argument Parser
- UI components (MarkdownBlockView, CodeBlockView view hierarchy)
- MarkdownVisitor parsing logic (only consuming the produced blocks)
- Theme color palette changes
- No new external dependencies

## Requirements

### FR-1: Unique Block IDs

Every `MarkdownBlock.id` must be unique within a single rendered document. The fix must incorporate positional or ordinal information so that multiple thematic breaks (or any content-identical blocks) produce distinct IDs. IDs must remain deterministic -- same content at the same position must produce the same ID across re-renders for SwiftUI diffing to work correctly.

### FR-2: Whitespace Foreground Color

`ThemeOutputFormat.Builder.addWhitespace()` must set `.foregroundColor` on the `AttributedString` run to match `plainTextColor`, ensuring whitespace runs do not break foreground color continuity in syntax-highlighted code blocks.

### FR-3: Block ID Uniqueness Tests

Unit tests must verify that parsing a document with multiple thematic breaks produces `MarkdownBlock` values with distinct IDs. Tests should also cover duplicate paragraphs and other potentially-colliding block types.

### FR-4: Whitespace Color Tests

Unit tests must verify that `ThemeOutputFormat` output has `.foregroundColor` set on every run, including whitespace runs. The existing test in `ThemeOutputFormatTests` that asserts `foregroundColor == nil` for whitespace must be updated to assert `foregroundColor == plainTextColor`.

## Dependencies & Constraints

### Internal Dependencies

| File | Role |
|------|------|
| `mkdn/Core/Markdown/MarkdownBlock.swift` | Core of duplicate ID bug (line 47: `case .thematicBreak: "hr"`) |
| `mkdn/Core/Markdown/ThemeOutputFormat.swift` | Whitespace color bug (line 31-33: `addWhitespace` without foregroundColor) |
| `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift` | Consumer of block IDs via ForEach and `blockAppeared` dictionary |
| `mkdn/Core/Markdown/MarkdownRenderer.swift` | Coordinator between visitor and consumers; may host dedup post-processing |

### External Dependencies

| Package | Relevance |
|---------|-----------|
| [Splash](https://github.com/JohnSundell/Splash) | Defines `OutputFormat`/`OutputBuilder` protocol; `addWhitespace` signature unchanged |
| [swift-markdown](https://github.com/apple/swift-markdown) | Upstream AST types walked by `MarkdownVisitor` |

### Constraints

- Block IDs must remain deterministic (same content at same position = same ID across re-renders) for SwiftUI diffing
- Positional info in IDs changes the `Identifiable` contract; consumers adapt automatically since they key on the `id` string
- Splash `OutputBuilder` protocol signature unchanged; fix is purely internal (adding foregroundColor to the AttributedString)
- No new external dependencies required
- No protocol-level changes

## Timeline

### Phase 1: Fix MarkdownBlock.id uniqueness

Change `thematicBreak` (and any content-identical blocks) to use positional/ordinal IDs so `ForEach` never receives duplicates. This may involve post-processing the rendered block array in `MarkdownRenderer.render()` to append occurrence suffixes, or incorporating index information during rendering.

### Phase 2: Fix ThemeOutputFormat.addWhitespace color

Add `foregroundColor = plainTextColor` to the whitespace `AttributedString` in `addWhitespace()`.

### Phase 3: Tests and verification

Unit tests for block ID uniqueness (multiple thematicBreaks produce distinct IDs) and whitespace color assertion. Run full test suite, SwiftLint, and SwiftFormat.

## Discoveries

- **Codebase Discovery**: `PreviewViewModel.swift` consumes `MarkdownRenderer.render()` but appears to have no references from any other file; it may be dead code yet still requires type updates when the renderer API changes. -- *Ref: [field-notes.md](archives/features/block-rendering-fix/field-notes.md)*
