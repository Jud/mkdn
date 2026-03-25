# Math Rendering

## What This Is

This is the LaTeX math engine. It takes LaTeX expressions (like `\frac{a}{b}` or `E = mc^2`) and produces platform images that can be embedded in the document. There are two rendering paths: display math (block-level, centered, with full-sized operators) and inline math (text-level, smaller, baseline-aligned with surrounding text).

The math rendering layer solves a specific problem: LaTeX math notation is deeply embedded in technical writing, and rendering it correctly requires a specialized typesetting engine. We use SwiftMath, which implements TeX's math layout algorithm natively in Swift via CoreGraphics drawing commands. No web views, no network calls, no external processes -- just pure bitmap rendering that works offline and scales crisply on Retina displays.

## How It Works

The system has two files and serves two consumers:

**MathRenderer** (`mkdn/Core/Math/MathRenderer.swift`) is the rendering engine -- an uninhabitable enum with one static method: `renderToImage(latex:fontSize:textColor:displayMode:)`. It returns a tuple of `(image, baseline)` on success, or `nil` on parse failure. The implementation is remarkably small:

1. Trim whitespace and reject empty input
2. Create a SwiftMath `MathImage` with the LaTeX source, font size, text color, and mode (display vs. text)
3. Call `mathImage.asImage()` which returns `(error, image, layoutInfo)`
4. If no error and image has non-zero dimensions, return the image with `layoutInfo.descent` as the baseline

The `baseline` value is the distance from the bottom of the image to the mathematical baseline. This is critical for inline rendering -- without it, math expressions would sit on the text baseline instead of aligning with it, causing expressions like $x^2$ to float above the surrounding text.

**MathAttributes** (`mkdn/Core/Math/MathAttributes.swift`) defines a custom `AttributedStringKey` called `mathExpression` that marks ranges of `AttributedString` text as containing LaTeX source. This is the bridge between the parser and the renderer: `MarkdownVisitor` detects `$...$` delimiters and sets this attribute, then `MarkdownTextStorageBuilder` checks for it during inline content conversion and calls `MathRenderer` when found.

The `MathAttributes` uses Swift's `AttributeScope` extension mechanism with `AttributeDynamicLookup`, which provides the `content[run.range].mathExpression` property access syntax used in the text storage builder.

### The two rendering paths

**Display math** (block-level `$$...$$` or fenced `math`/`latex`/`tex` code blocks) flows through the attachment system. The parser produces a `.mathBlock(code:)`, the text storage builder inserts an attachment placeholder, and the `OverlayCoordinator` positions a `MathBlockView` over it. The `MathBlockView` calls `MathRenderer.renderToImage(displayMode: true)` directly.

There's one exception: during print mode (`isPrint: true`), display math is rendered inline in the text storage builder via `appendMathBlockInline()`, which calls `MathRenderer` directly and inserts the result as a centered `NSTextAttachment`. This avoids the overlay system, which doesn't exist in print contexts.

**Inline math** (`$...$` within paragraph text) flows through `convertInlineContent()` in the text storage builder. When it encounters a run with the `mathExpression` attribute, it calls `renderInlineMath()` which delegates to `MathRenderer.renderToImage(displayMode: false)`. The result is wrapped in an `NSTextAttachment` with carefully computed bounds:

```swift
let yOffset = -(result.baseline)
attachment.bounds = CGRect(x: 0, y: yOffset, width: width, height: height)
```

The negative `y` offset on the attachment bounds is how we achieve baseline alignment. `NSTextAttachment.bounds.origin.y` controls the vertical position relative to the text baseline. A negative value moves the attachment down, and we move it down by exactly the math baseline (descent), which aligns the mathematical baseline with the text baseline.

## Why It's Like This

**Why SwiftMath instead of MathJax/KaTeX in a web view?** Two reasons. First, inline math needs to be rendered as `NSTextAttachment` images embedded in the main text view's attributed string -- you can't embed a web view inside a character run. Second, performance: a document with 50 inline math expressions would need 50 web views for the web-based approach. SwiftMath renders each expression as a pure CoreGraphics draw call, which is fast enough to do synchronously during text storage building.

**Why is `MathRenderer` a synchronous, stateless enum?** Because math rendering is computationally simple (it's just layout + CoreGraphics path drawing) and doesn't require any external state. SwiftMath's `MathImage` is a value type, and `asImage()` is a pure function. There's no benefit to caching -- each expression renders in under a millisecond, and caching would require invalidation on font size or color changes.

**Why return `nil` instead of throwing on parse failure?** Because invalid LaTeX is expected -- users type partial expressions, use unsupported commands, or make typos. The callers handle `nil` gracefully: inline math falls back to monospace text at 60% opacity, display math shows a monospace placeholder. Throwing would require try/catch boilerplate at every call site for a non-exceptional case.

## Where the Complexity Lives

The MathRenderer itself is trivially simple. The complexity lives at the boundaries:

**Inline math detection** (in `MarkdownVisitor`) is where the hard parsing happens. The `findInlineMathRanges` scanner has to handle escaped dollars (`\$`), display math delimiters (`$$`), whitespace-adjacent dollars (not delimiters), empty delimiters (no math), and unclosed delimiters (literal text). This logic is documented in the markdown parsing doc.

**Baseline alignment** in `renderInlineMath()` (in `MarkdownTextStorageBuilder+MathInline.swift`) is subtle. The `yOffset = -(result.baseline)` formula looks simple, but getting it wrong by even a point makes math expressions visually jump up or down relative to surrounding text. The SwiftMath `layoutInfo.descent` value is the correct input here -- it's the distance from the bottom of the rendered image to the mathematical baseline, which is exactly the offset needed for `NSTextAttachment.bounds.origin.y`.

**The fallback rendering** when `MathRenderer` returns `nil` uses a monospace font at 60% opacity (`baseForegroundColor.withAlphaComponent(0.6)`). This makes invalid LaTeX visible but clearly distinguished from rendered math, so users know something went wrong without the app crashing or showing blank space.

## The Grain of the Wood

This is one of the most stable parts of the codebase. The math renderer has had exactly 5 commits in its history, most of which were cross-platform migration changes. If you're extending it:

- To support a new LaTeX feature, you're really asking for a SwiftMath update, not a mkdn change. The renderer delegates all typesetting to SwiftMath.
- To add a new rendering target (e.g., SVG export), you'd add another static method to `MathRenderer` alongside `renderToImage`.
- To adjust sizing or colors, the parameters are passed in by the caller. The renderer itself has no opinions about appearance.

## Watch Out For

**The `MathImage` struct is not `Sendable`.** The `asImage()` method does CoreGraphics drawing, which must happen on the calling thread's graphics context. In practice this doesn't matter because the text storage builder runs on `@MainActor`, but don't try to move math rendering to a background task.

**Empty or whitespace-only LaTeX returns `nil`.** The `guard !trimmed.isEmpty` check at the top of `renderToImage` prevents SwiftMath from receiving degenerate input. This is important because SwiftMath's behavior on empty strings is undefined.

**Display mode vs text mode affects operator sizing.** In display mode, operators like `\sum` and `\int` render at full size with limits above and below. In text mode, they're compressed to match the surrounding text height with limits as superscript/subscript. The caller chooses the mode -- display for block-level math, text for inline.

**The `descent` value from SwiftMath is the key to alignment.** If SwiftMath ever changes how it reports `layoutInfo.descent`, inline math alignment will break across the entire app. This value is currently used directly as the `NSTextAttachment.bounds.origin.y` offset (negated).

## Key Files

| File | What It Is |
|------|------------|
| `mkdn/Core/Math/MathRenderer.swift` | LaTeX to platform image via SwiftMath, with baseline reporting |
| `mkdn/Core/Math/MathAttributes.swift` | Custom `AttributeStringKey` for marking inline math ranges |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder+MathInline.swift` | Inline math rendering: attachment creation with baseline alignment |
| `mkdn/Core/Markdown/MarkdownVisitor.swift` | Inline math detection: `$...$` delimiter scanning and `mathExpression` attribute setting |
| `mkdn/Features/Viewer/Views/MathBlockView.swift` | Display math overlay view: calls MathRenderer for block-level expressions |
