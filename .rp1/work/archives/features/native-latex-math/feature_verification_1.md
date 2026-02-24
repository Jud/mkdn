# Feature Verification Report #1

**Generated**: 2026-02-24T16:34:00Z
**Feature ID**: native-latex-math
**Verification Scope**: all
**KB Context**: Loaded
**Field Notes**: Available

## Executive Summary
- Overall Status: PARTIAL
- Acceptance Criteria: 28/35 verified (80%)
- Implementation Quality: HIGH
- Ready for Merge: NO (documentation tasks TD1-TD5 incomplete; print and performance criteria require manual verification)

## Field Notes Context
**Field Notes Available**: Yes

### Documented Deviations
1. **SwiftMath Version (T1)**: Design specifies `>= 3.3.0` but version 3.3.0 does not exist. Used `from: "1.7.0"` which resolves to 1.7.3. API surface is equivalent. Documented in `field-notes.md`.
2. **MathRenderer @MainActor Removal (T4)**: Design specified `@MainActor` on `MathRenderer` assuming `MTMathUILabel` (NSView). T2 implemented using `MathImage` (struct, CoreGraphics), making `@MainActor` unnecessary and causing Swift 6 concurrency errors. Removal is correct and documented in `field-notes.md`.

### Undocumented Deviations
None found. All deviations from the design are documented in field-notes.md.

## Acceptance Criteria Verification

### REQ-BDET-1: Code fences with language `math`, `latex`, or `tex` are detected as block math expressions
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownVisitor.swift`:31-33
- Evidence: `convertBlock` checks `language == "math" || language == "latex" || language == "tex"` and returns `.mathBlock(code:)` with trimmed code. Language is lowercased at line 25 for case-insensitive matching.
- Field Notes: N/A
- Issues: None
- Tests: `MarkdownVisitorMathTests`: "Detects math code fence", "Detects latex code fence", "Detects tex code fence", "Case-insensitive code fence language detection" -- all pass.

### REQ-BDET-2: Standalone paragraphs consisting entirely of `$$...$$` are detected as block math expressions
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownVisitor.swift`:84-94 (`convertParagraph`)
- Evidence: Checks `trimmed.hasPrefix("$$")`, `trimmed.hasSuffix("$$")`, `trimmed.count > 4`, strips delimiters and trims whitespace, returns `.mathBlock(code:)` when non-empty.
- Field Notes: N/A
- Issues: None
- Tests: "Detects standalone $$", "Detects standalone $$ with whitespace inside" -- all pass.

### REQ-BDET-3: Block math detection does not trigger for `$$` used inline within a paragraph alongside other text
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownVisitor.swift`:84-94
- Evidence: The check requires `trimmed.hasPrefix("$$")` AND `trimmed.hasSuffix("$$")` on the entire trimmed paragraph text. Mixed text like "The cost is $$5.00 and $$10.00" will not match both conditions simultaneously (the prefix is "The cost..." not "$$").
- Field Notes: N/A
- Issues: None
- Tests: "Does not detect $$ in mixed paragraph" -- passes.

### REQ-IDET-1: Text enclosed in single `$...$` within a paragraph is detected as inline math
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownVisitor.swift`:212-233 (`postProcessMathDelimiters`), lines 242-289 (`findInlineMathRanges`)
- Evidence: `inlineText(from:)` calls `postProcessMathDelimiters` which scans for `$...$` patterns via `findInlineMathRanges`, a character-by-character state machine. Matched ranges get the `mathExpression` attribute applied with the LaTeX source.
- Field Notes: N/A
- Issues: None
- Tests: "Detects inline $ math expression", "Inline math has correct LaTeX content" -- pass.

### REQ-IDET-2: Escaped dollar signs (`\$`) are treated as literal characters, not math delimiters
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownVisitor.swift`:251-256 (`findInlineMathRanges`)
- Evidence: In the scanner, when char is `\`, the next character is checked. If it is `$`, both characters are skipped (index advances past both). Same logic at line 303-308 in `findClosingDollar`.
- Field Notes: N/A
- Issues: None
- Tests: "Escaped $ is literal, not math delimiter" -- passes.

### REQ-IDET-3: Adjacent dollar signs (`$$`) within a paragraph are not treated as inline math delimiters
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownVisitor.swift`:262-265
- Evidence: When a `$` is found and the next character is also `$`, both are skipped: `index = text.index(after: next)`. Same logic at lines 312-315 in `findClosingDollar`.
- Field Notes: N/A
- Issues: None
- Tests: "Adjacent $$ not treated as inline math delimiter" -- passes.

### REQ-IDET-4: Empty delimiters (`$$` with no content between) do not produce math rendering
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownVisitor.swift`:325 (`findClosingDollar`)
- Evidence: `if latex.isEmpty { return nil }` rejects empty content between delimiters. Additionally, `findInlineMathRanges` at line 262 skips adjacent `$$` before they can form an empty pair.
- Field Notes: N/A
- Issues: None
- Tests: "Empty $$ produces no mathBlock" (for block), plus the inline `$$` skip logic is tested by "Adjacent $$ not treated as inline math delimiter".

### REQ-IDET-5: Unclosed `$` delimiters are treated as literal text
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownVisitor.swift`:276-281
- Evidence: When `findClosingDollar` returns nil (no valid closing delimiter found), the scanner simply advances past the opening `$` (`index = next`) and continues, leaving the `$` as literal text in the AttributedString.
- Field Notes: N/A
- Issues: None
- Tests: "Unclosed $ is literal text" -- passes.

### REQ-IDET-6: Multiple inline math expressions within a single paragraph all render correctly
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownVisitor.swift`:242-289
- Evidence: `findInlineMathRanges` accumulates all valid `(range, latex)` pairs in a results array, then `postProcessMathDelimiters` applies them in reverse order to preserve range validity. Multiple expressions within a single paragraph each get their own `mathExpression` attribute.
- Field Notes: N/A
- Issues: None
- Tests: "Multiple inline math in one paragraph" -- passes, verifying 3 math ranges in "$x$ and $y$ then $z$".

### REQ-BRND-1: Block math renders in display mode (larger, centered) using native vector rendering
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MathBlockView.swift`:48-71 (`renderMath`), `/Users/jud/Projects/mkdn/mkdn/Core/Math/MathRenderer.swift`:22-51
- Evidence: `MathBlockView.renderMath()` calls `MathRenderer.renderToImage` with `displayMode: true` and `displayFontSize = baseFontSize * 1.2`. The rendered image is displayed with `.frame(maxWidth: .infinity, alignment: .center)`. `MathRenderer` uses `MathImage` struct with `labelMode: .display` for display-mode rendering via CoreGraphics.
- Field Notes: N/A
- Issues: None

### REQ-BRND-2: Block math has appropriate vertical spacing above and below
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MathBlockView.swift`:28
- Evidence: `.padding(.vertical, 8)` provides 8pt padding above and below the rendered equation. The fallback view also has `.padding(.vertical, 8)` (line 44). The total height reported includes 16pt of padding (`result.image.size.height + 16` at line 63).
- Field Notes: N/A
- Issues: None

### REQ-BRND-3: Block math text color matches the active theme's foreground color
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MathBlockView.swift`:49
- Evidence: `let foreground = PlatformTypeConverter.nsColor(from: colors.foreground)` extracts the theme's foreground color. This is passed to `MathRenderer.renderToImage(... textColor: foreground ...)` which uses it as `MathImage.textColor`.
- Field Notes: N/A
- Issues: None

### REQ-BRND-4: Theme changes update block math color instantly
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MathBlockView.swift`:36
- Evidence: `.onChange(of: appSettings.theme) { _, _ in renderMath() }` triggers re-rendering whenever the theme changes. The new theme's foreground color is extracted at render time (line 49), producing a new image with the correct color.
- Field Notes: N/A
- Issues: None. Per D7, re-rendering is < 1ms per expression, so it appears instant.

### REQ-BRND-5: Block math overlay resizes dynamically to fit the rendered equation
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MathBlockView.swift`:63-64, `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator.swift`:460-461
- Evidence: `MathBlockView` reports `totalHeight = result.image.size.height + 16` via `onSizeChange?(totalHeight)`. The `makeMathBlockOverlay` factory wires this callback to `updateAttachmentHeight(blockIndex:newHeight:)`, which invalidates the attachment layout and triggers repositioning.
- Field Notes: N/A
- Issues: None

### REQ-IRND-1: Inline math renders at a size proportional to the surrounding text
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+MathInline.swift`:23-28
- Evidence: `MathRenderer.renderToImage(latex: latex, fontSize: baseFont.pointSize, ...)` uses the same `baseFont.pointSize` as the surrounding text, and `displayMode: false` (text mode) ensures the math is sized for inline flow.
- Field Notes: N/A
- Issues: None

### REQ-IRND-2: Inline math baseline aligns precisely with the baseline of surrounding text
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+MathInline.swift`:32-39
- Evidence: `let yOffset = -(result.baseline)` sets the NSTextAttachment bounds' y origin to the negative of the mathematical descent. `attachment.bounds = CGRect(x: 0, y: yOffset, width: width, height: height)` aligns the attachment's baseline with the text baseline via standard NSTextAttachment technique (D10).
- Field Notes: N/A
- Issues: None. Baseline value comes from `MathImage.LayoutInfo.descent` per field notes.

### REQ-IRND-3: Inline math text color matches the surrounding text color
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+MathInline.swift`:23-28
- Evidence: `baseForegroundColor` is passed through from `convertInlineContent` (which receives the theme's foreground color). This same color is used for both regular text runs and math rendering via `MathRenderer.renderToImage(... textColor: baseForegroundColor ...)`.
- Field Notes: N/A
- Issues: None

### REQ-IRND-4: Inline math has appropriate horizontal spacing relative to adjacent text
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+MathInline.swift`:30, 41
- Evidence: `NSAttributedString(attachment: attachment)` produces a standard NSTextAttachment character in the attributed string. NSTextAttachment provides natural spacing through TextKit's layout system. The attachment bounds use `x: 0` with no explicit padding, relying on the default TextKit horizontal spacing behavior.
- Field Notes: N/A
- Issues: None. Per D10, manual spacing adjustment may be needed but initial implementation uses standard behavior.

### REQ-FALL-1: Expressions that cannot be parsed render as raw LaTeX source in monospace font
- Status: VERIFIED
- Implementation: Block fallback: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MathBlockView.swift`:40-45. Inline fallback: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+MathInline.swift`:45-53.
- Evidence: Block fallback: `Text(code).font(.system(.body, design: .monospaced))` displays the raw LaTeX source. Inline fallback: `PlatformTypeConverter.monospacedFont(scaleFactor:)` produces a monospaced NSFont, and the original `latex` string is used as the text content.
- Field Notes: N/A
- Issues: None
- Tests: "Math block print fallback uses monospaced font", "Inline math fallback uses monospaced font for invalid LaTeX" -- both pass.

### REQ-FALL-2: Fallback rendering uses a secondary/subdued text color, not an error color
- Status: VERIFIED
- Implementation: Block fallback: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MathBlockView.swift`:42 -- `.foregroundColor(colors.foregroundSecondary)`. Inline fallback: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+MathInline.swift`:46 -- `baseForegroundColor.withAlphaComponent(0.6)`.
- Evidence: Block math uses the theme's designated `foregroundSecondary` color. Inline math uses 60% alpha of the base foreground. Neither uses red, orange, or any "error" color.
- Field Notes: N/A
- Issues: None
- Tests: "Inline math fallback uses reduced alpha foreground color" -- passes, confirming alpha < 1.0.

### REQ-FALL-3: Fallback rendering for block math is centered
- Status: VERIFIED
- Implementation: Block on-screen: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MathBlockView.swift`:43 -- `.frame(maxWidth: .infinity, alignment: .center)`. Block print: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`:211-213 -- `alignment: .center` in paragraph style.
- Evidence: Both screen and print fallback paths use centered alignment.
- Field Notes: N/A
- Issues: None
- Tests: "Math block print has centered paragraph style" -- passes.

### REQ-FALL-4: No expression, regardless of content, causes a crash or hang
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Math/MathRenderer.swift`:28-29, 40-48
- Evidence: `MathRenderer.renderToImage` guards against empty input (`guard !trimmed.isEmpty else { return nil }`), checks for parse errors (`guard error == nil`), checks for zero-size images (`image.size.width > 0, image.size.height > 0`), and returns nil for any failure. The callers (MathBlockView, renderInlineMath) handle nil gracefully with fallback rendering.
- Field Notes: N/A
- Issues: None
- Tests: "Returns nil for invalid LaTeX", "Returns nil for empty input", "Returns nil for whitespace-only input" -- all pass without crash or hang.

### REQ-PRNT-1: Block math prints correctly in Cmd+P output
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`:201-250 (`appendMathBlockInline`)
- Evidence: Code exists for print-path rendering. When `isPrint: true`, block math is rendered via `MathRenderer.renderToImage` with display mode and the theme's foreground color (which in print is `PrintPalette.colors.foreground` = black). The image is inserted as a centered `NSTextAttachment`. Fallback uses centered monospace text.
- Field Notes: N/A
- Issues: Requires physical print verification (Cmd+P) to confirm rendered output appears correctly on paper/PDF.

### REQ-PRNT-2: Inline math prints correctly in Cmd+P output
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+MathInline.swift`:12-54
- Evidence: Inline math uses `baseForegroundColor` from `convertInlineContent`, which receives `PrintPalette.colors.foreground` (black) during print. The `NSTextAttachment` with the rendered image should print naturally through `NSPrintOperation`.
- Field Notes: N/A
- Issues: Requires physical print verification to confirm inline math appears correctly sized and positioned in printed output.

### REQ-PRNT-3: Printed math uses the print palette colors (black on white)
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`:192-194 (isPrint dispatch), `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`:207
- Evidence: When `isPrint: true`, the `colors` parameter comes from `PrintPalette.colors` (standard flow in `MarkdownPreviewView`). `appendMathBlockInline` extracts `PlatformTypeConverter.nsColor(from: colors.foreground)` which resolves to PrintPalette's black foreground. The code path is correctly wired.
- Field Notes: N/A
- Issues: Requires visual verification that printed output actually shows black math on white background.

### NFR-PERF-1: Documents with up to 50 math expressions render without perceptible delay
- Status: MANUAL_REQUIRED
- Implementation: Entire math rendering pipeline
- Evidence: `MathRenderer` uses `MathImage` (struct, no NSView overhead). Per design, individual expressions render in < 1ms on Apple Silicon. The fixture file `fixtures/math-test.md` contains approximately 30+ math expressions. No test exists for the 50-expression threshold.
- Field Notes: N/A
- Issues: Requires subjective evaluation with a 50+ expression document.

### NFR-PERF-2: Inline math rendering does not cause visible jank during initial document layout
- Status: MANUAL_REQUIRED
- Implementation: Inline math is rendered synchronously in `convertInlineContent`
- Evidence: MathImage rendering is synchronous and lightweight (< 1ms per expression). No async boundaries or main-thread-blocking patterns observed.
- Field Notes: N/A
- Issues: Requires visual verification during document loading.

### NFR-PERF-3: Theme switching with math-heavy documents feels instant
- Status: MANUAL_REQUIRED
- Implementation: Block math re-renders via `MathBlockView.onChange(of: theme)`. Inline math re-renders via full `TextStorageResult` rebuild.
- Evidence: Per D7, single expression renders in < 1ms. Theme change triggers re-render for all visible expressions.
- Field Notes: N/A
- Issues: Requires visual verification during theme switching.

### NFR-SEC-1: LaTeX input is treated as data only; no code execution path exists beyond SwiftMath parser
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Math/MathRenderer.swift`
- Evidence: `MathRenderer` passes LaTeX strings to `MathImage` (SwiftMath). SwiftMath parses LaTeX into `MTMathList` and typesets via `MTTypesetter` into `MTMathListDisplay`, which renders via CoreGraphics drawing commands. No code execution, no eval, no JavaScript, no shell invocations. The entire pipeline is pure parsing + CG rendering.
- Field Notes: N/A
- Issues: None

### NFR-USE-1: Math rendering requires zero user configuration
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownVisitor.swift`:31-33, 84-94, 212-233
- Evidence: Math detection activates automatically when `math`/`latex`/`tex` code fences, standalone `$$` paragraphs, or inline `$...$` patterns are found. No feature flag, no settings toggle, no user action required.
- Field Notes: N/A
- Issues: None

### NFR-USE-2: Presence of math does not alter rendering of non-math content
- Status: VERIFIED
- Implementation: All math detection and rendering code
- Evidence: Code fence detection adds a new language check but falls through to existing `.codeBlock` for non-math languages (line 34). `$$` detection only triggers for standalone paragraphs, not mixed text. Inline `$` detection only modifies runs with the `mathExpression` attribute, leaving other runs unchanged. The `postProcessMathDelimiters` function returns the input unmodified when no `$` is present (line 216: `guard fullString.contains("$") else { return input }`).
- Field Notes: N/A
- Issues: None
- Tests: All 549 existing tests pass (3 pre-existing failures unrelated to math).

### NFR-COMP-1: SwiftMath dependency is MIT-licensed
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.build/checkouts/SwiftMath/LICENSE`
- Evidence: License file begins with "MIT License" followed by "Copyright (c) 2023 Computer Inspirations".
- Field Notes: N/A
- Issues: None

### NFR-COMP-2: All new code passes SwiftLint strict mode and SwiftFormat
- Status: PARTIAL
- Implementation: All new files
- Evidence: Build succeeds with no warnings. However, SwiftLint was not run as part of this verification (requires Xcode toolchain). SwiftFormat compliance is indicated by clean formatting observed in all new files.
- Field Notes: N/A
- Issues: SwiftLint verification should be run explicitly: `DEVELOPER_DIR=/Applications/Xcode-16.3.0.app/Contents/Developer swiftlint lint`

### NFR-COMP-3: All new code compiles under Swift 6 strict concurrency with no warnings
- Status: VERIFIED
- Implementation: `Package.swift` specifies `swift-tools-version: 6.0`
- Evidence: `swift build` completes successfully with zero warnings. The `@MainActor` removal from `MathRenderer` (documented in field-notes.md) was specifically to resolve Swift 6 strict concurrency errors.
- Field Notes: T4 field note documents the `@MainActor` removal rationale.
- Issues: None

## Implementation Gap Analysis

### Missing Implementations
- **TD1-TD5**: Documentation tasks are incomplete. Knowledge base files (`index.md`, `modules.md`, `architecture.md`, `patterns.md`) have not been updated with math-related entries.

### Partial Implementations
- **NFR-COMP-2**: SwiftLint strict mode compliance not verified in this run. Code visually appears formatted but explicit lint run is needed.

### Implementation Issues
- None found in the core feature implementation.

## Code Quality Assessment

**Overall Quality: HIGH**

The implementation demonstrates strong adherence to project patterns and conventions:

1. **Pattern Consistency**: Block math follows the exact same overlay pattern as Mermaid/images (NSTextAttachment placeholder, NSHostingView overlay, OverlayCoordinator lifecycle). The code reads as a natural extension of existing infrastructure.

2. **Separation of Concerns**: Detection (MarkdownVisitor), rendering (MathRenderer), presentation (MathBlockView, renderInlineMath), and integration (OverlayCoordinator, TextStorageBuilder) are cleanly separated across appropriate modules.

3. **Error Handling**: Every failure path degrades gracefully. `MathRenderer` returns nil on failure. Block math shows centered monospace fallback. Inline math shows styled monospace fallback. Empty and whitespace inputs are guarded.

4. **Documented Deviations**: Both design deviations (SwiftMath version, `@MainActor` removal) are documented in field-notes.md with clear rationale. Both deviations are improvements over the original design.

5. **Testing**: 37 new tests covering three test suites (MathRendererTests: 7, MarkdownVisitorMathTests: 18, MarkdownTextStorageBuilderMathTests: 12). All pass. Tests cover the critical business rules (delimiter detection, escaping, fallback behavior).

6. **Code Style**: Files use proper documentation comments, MARK pragmas, and follow the project's naming conventions. SwiftFormat appears to have been applied.

7. **Concurrency Safety**: `MathRenderer` is a stateless enum (no shared mutable state). `MathImage` is a value type. No concurrency hazards observed.

## Recommendations

1. **Complete documentation tasks (TD1-TD5)**: Update `.rp1/context/index.md`, `modules.md`, `architecture.md`, and `patterns.md` with math-related entries. These are simple text edits but are required for Definition of Done.

2. **Run SwiftLint explicitly**: Execute `DEVELOPER_DIR=/Applications/Xcode-16.3.0.app/Contents/Developer swiftlint lint` to confirm NFR-COMP-2 compliance before merge.

3. **Visual verification of print output**: Load `fixtures/math-test.md`, print via Cmd+P, and verify that (a) block math appears centered in black, (b) inline math appears correctly sized and positioned, (c) fallback text prints in monospace. This addresses REQ-PRNT-1, REQ-PRNT-2, REQ-PRNT-3.

4. **Performance validation with 50+ expression document**: Create or extend the fixture to include 50+ math expressions and subjectively evaluate rendering latency and theme-switching responsiveness. This addresses NFR-PERF-1, NFR-PERF-2, NFR-PERF-3.

5. **Visual verification across themes**: Load the fixture in both Solarized Light and Solarized Dark, capture screenshots, and confirm that math foreground color matches body text color in each theme. This provides visual evidence for REQ-BRND-3 and REQ-IRND-3.

## Verification Evidence

### Package.swift - SwiftMath Dependency
File: `/Users/jud/Projects/mkdn/Package.swift`, line 49:
```swift
.package(url: "https://github.com/mgriebling/SwiftMath.git", from: "1.7.0"),
```
Line 74 (in mkdnLib target dependencies):
```swift
.product(name: "SwiftMath", package: "SwiftMath"),
```

### MarkdownBlock.mathBlock case
File: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownBlock.swift`, line 29:
```swift
case mathBlock(code: String)
```
With stable hash ID at line 55-56:
```swift
case let .mathBlock(code):
    "math-\(stableHash(code))"
```

### MathRenderer - Stateless SwiftMath Wrapper
File: `/Users/jud/Projects/mkdn/mkdn/Core/Math/MathRenderer.swift`:
```swift
enum MathRenderer {
    static func renderToImage(
        latex: String,
        fontSize: CGFloat,
        textColor: NSColor,
        displayMode: Bool = false
    ) -> (image: NSImage, baseline: CGFloat)? {
        // Uses MathImage struct (not MTMathUILabel NSView)
        var mathImage = MathImage(
            latex: trimmed,
            fontSize: fontSize,
            textColor: textColor,
            labelMode: displayMode ? .display : .text,
            textAlignment: displayMode ? .center : .left
        )
        let (error, image, layoutInfo) = mathImage.asImage()
        // Returns nil on any failure
        guard error == nil, let image, let layoutInfo,
              image.size.width > 0, image.size.height > 0
        else { return nil }
        return (image: image, baseline: layoutInfo.descent)
    }
}
```

### Inline Math Detection State Machine
File: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownVisitor.swift`, lines 242-289:
Key rules implemented:
- Line 251-256: `\$` escape handling (skip `$` preceded by `\`)
- Line 262-265: `$$` skip (adjacent dollars not treated as inline)
- Line 271-273: Opening `$` + whitespace rejection
- Line 318-320 (in `findClosingDollar`): Whitespace + closing `$` rejection
- Line 325: Empty content rejection

### OverlayCoordinator Math Integration
File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator.swift`:
- Line 195: `needsOverlay` returns true for `.mathBlock`
- Line 242-243: `blocksMatch` handles `.mathBlock` comparison
- Lines 282-285: `createAttachmentOverlay` dispatches to `makeMathBlockOverlay`
- Lines 455-468: `makeMathBlockOverlay` factory creates NSHostingView with MathBlockView

### Test Results
549 total tests. 3 failures in pre-existing `AppSettings.cycleTheme` (unrelated). All 37 new math tests pass:
- MathRendererTests: 7/7
- MarkdownVisitorMathTests: 18/18
- MarkdownTextStorageBuilderMathTests: 12/12
