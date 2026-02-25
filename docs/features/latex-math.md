# LaTeX Math

## Overview

Native LaTeX math rendering for mkdn's Markdown viewer. Mathematical expressions
render as crisp, vector-resolution typography that integrates with the document's
text flow, theme colors, and zoom level. Supports inline `$...$` within paragraph
text, standalone `$$...$$` paragraphs as display equations, and code fences with
`math`/`latex`/`tex` language identifiers. Expressions that fail to parse degrade
to styled monospace -- readable, not broken.

## User Experience

Inline math (`$x^2$`) appears at text size, baseline-aligned with surrounding
prose, same foreground color. Display math (`$$\int_0^\infty ...$$` or a
` ```math ` fence) renders centered with breathing room above and below. Theme
switching updates all math instantly. Escaped dollar signs (`\$`) render as
literal characters. No user configuration required -- math activates automatically
when delimiters are detected.

Fallback for unsupported expressions: centered monospace in a secondary color for
block math, inline monospace at reduced opacity for inline math. No error states,
no blank spaces, no crashes regardless of input.

## Architecture

Three detection paths feed two rendering modes:

**Detection** (in `MarkdownVisitor`):
1. Code fences with language `math`/`latex`/`tex` produce `.mathBlock(code:)`
2. Standalone `$$...$$` paragraphs (entire paragraph) produce `.mathBlock(code:)`
3. Inline `$...$` within text adds a `mathExpression` attribute to the `AttributedString`

**Block rendering** uses the attachment-overlay pattern (same as Mermaid/images):
`MarkdownTextStorageBuilder` emits an `NSTextAttachment` placeholder,
`OverlayCoordinator` hosts an `NSHostingView<MathBlockView>`, and `MathBlockView`
calls `MathRenderer` for display-mode output. The overlay reports its rendered
height back for dynamic sizing.

**Inline rendering** embeds math as `NSTextAttachment` images within the
`NSAttributedString`. `MarkdownTextStorageBuilder+MathInline` detects the
`mathExpression` attribute on runs, renders via `MathRenderer` in text mode, and
sets `attachment.bounds` with a negative y-origin for baseline alignment.

**Print path**: inline math prints naturally via `NSTextAttachment`. Block math
renders directly into the text storage as a centered `NSTextAttachment` when
`isPrint: true`, bypassing the overlay system.

## Implementation Decisions

- **SwiftMath** (`mgriebling/SwiftMath >= 3.3.0`) for LaTeX parsing and rendering.
  Pure CoreGraphics/CoreText -- no WebView, no JavaScript. MIT licensed.
- **`MathImage` struct, not `MTMathUILabel`**: The actual implementation uses
  SwiftMath's `MathImage` value type instead of the NSView-based `MTMathUILabel`.
  This makes `MathRenderer` thread-safe without `@MainActor`.
- **Post-processing for inline detection**: swift-markdown does not parse `$`
  delimiters, so `postProcessMathDelimiters()` runs a character-by-character state
  machine on the `AttributedString` after visitor construction. Rules: `\$` is
  literal, `$$` is not inline, opening `$` + whitespace is rejected, whitespace +
  closing `$` is rejected, unclosed `$` is literal, empty delimiters are rejected.
- **Custom `AttributedStringKey`**: `MathExpressionAttribute` marks inline math
  runs with their LaTeX source, cleanly separating detection (visitor) from
  rendering (builder).
- **Overlay pattern for blocks**: consistent with Mermaid and images. Theme changes
  trigger re-render in `MathBlockView.onChange(of: appSettings.theme)` since color
  is baked into the rendered image.
- **Inline math re-renders on full `TextStorageResult` rebuild**, which already
  happens on theme change. No special handling needed.

## Files

### New
| File | Purpose |
|------|---------|
| `mkdn/Core/Math/MathRenderer.swift` | Stateless SwiftMath wrapper. `renderToImage(latex:fontSize:textColor:displayMode:)` returns `(image, baseline)?` |
| `mkdn/Core/Math/MathAttributes.swift` | `MathExpressionAttribute` -- custom `AttributedStringKey` for inline math annotation |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder+MathInline.swift` | `renderInlineMath()` -- inline math to `NSTextAttachment` with baseline alignment, monospace fallback |
| `mkdn/Features/Viewer/Views/MathBlockView.swift` | SwiftUI view for display equations. Theme/zoom reactive. Fallback to centered monospace |

### Modified
| File | Change |
|------|--------|
| `mkdn/Core/Markdown/MarkdownVisitor.swift` | Code fence detection, standalone `$$` detection, `postProcessMathDelimiters()` with `findInlineMathRanges()` state machine |
| `mkdn/Core/Markdown/MarkdownBlock.swift` | `.mathBlock(code:)` case |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` | `.mathBlock` dispatch in `appendBlock`, inline math check in `convertInlineContent` |
| `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` | `.mathBlock` in `needsOverlay`, `blocksMatch`, `createAttachmentOverlay`; `makeMathBlockOverlay` factory |
| `Package.swift` | SwiftMath dependency |

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| [mgriebling/SwiftMath](https://github.com/mgriebling/SwiftMath) | >= 3.3.0 | LaTeX parsing + CoreGraphics rendering via `MathImage` |

Internal: extends `MarkdownBlock`, `MarkdownVisitor`, `MarkdownTextStorageBuilder`,
`OverlayCoordinator`. Consumes `ThemeColors` for foreground color, `PrintPalette`
for print-path colors.

## Testing

**Unit tests** (Swift Testing, `@testable import mkdnLib`):

| Suite | File | Coverage |
|-------|------|----------|
| `MathRendererTests` | `mkdnTests/Unit/Core/MathRendererTests.swift` | Valid/invalid/empty input, baseline reporting, display vs text mode sizing, common expression coverage |
| `MarkdownVisitorMathTests` | `mkdnTests/Unit/Core/MarkdownVisitorMathTests.swift` | Code fence detection (math/latex/tex/case-insensitive), standalone `$$`, inline `$`, escaped `\$`, adjacent `$$`, unclosed `$`, whitespace rules, multiple expressions, block ID stability |
| `MarkdownTextStorageBuilderMathTests` | `mkdnTests/Unit/Core/MarkdownTextStorageBuilderMathTests.swift` | Block attachment generation, print-mode inline rendering, print centering, inline `NSTextAttachment` embedding, fallback monospace + color, `plainText` extraction, multi-block integration |

**Visual testing**: `fixtures/math-test.md` covers block fences, standalone `$$`,
inline expressions, multiple inline per paragraph, escaped dollars, unsupported
expressions (fallback), math in headings, and mixed content. Verify with
`mkdn-ctl` in both Solarized themes at multiple scroll positions.
