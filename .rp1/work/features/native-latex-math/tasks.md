# Development Tasks: Native LaTeX Math Rendering

**Feature ID**: native-latex-math
**Status**: Not Started
**Progress**: 25% (3 of 12 tasks)
**Estimated Effort**: 4 days
**Started**: 2026-02-24

## Overview

Add native LaTeX math rendering to mkdn's Markdown viewer with three detection paths (code fences, standalone `$$`, inline `$`) and two rendering modes (block overlay, inline attachment). SwiftMath provides the typesetting engine. Expressions that fail to parse degrade to styled monospace. Block math uses the attachment-overlay pattern (like Mermaid/images), inline math embeds as `NSTextAttachment` images within the `NSAttributedString`.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1] - Foundation (no dependencies)
2. [T2, T3] - MathRenderer and MarkdownVisitor detection (both depend only on T1)
3. [T4] - TextStorageBuilder integration (depends on T2 + T3)
4. [T5] - MathBlockView + OverlayCoordinator (depends on T2 + T4)
5. [T6] - Print support (depends on T4)
6. [T7] - Tests + fixture (depends on T3 + T4 + T5 + T6)

**Dependencies**:

- T2 -> T1 (build: SwiftMath dependency must be available)
- T3 -> T1 (data: needs .mathBlock case + math attribute definition)
- T4 -> [T2, T3] (interface: needs MathRenderer API + visitor detection output)
- T5 -> [T2, T4] (interface: needs MathRenderer + block dispatch in builder)
- T6 -> T4 (data: extends builder's isPrint path for .mathBlock)
- T7 -> [T3, T4, T5, T6] (sequential: tests require all feature code)

**Critical Path**: T1 -> T2 -> T4 -> T5 -> T7

## Task Breakdown

### Foundation

- [x] **T1**: Add SwiftMath dependency and extend data model with `.mathBlock` case and inline math attribute `[complexity:simple]`

    **Reference**: [design.md#t1-foundation---packageswift--data-model](design.md#t1-foundation---packageswift--data-model)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] `Package.swift` includes `mgriebling/SwiftMath` (>= 1.7.0) in dependencies and `mkdnLib` target
    - [x] `MarkdownBlock` enum has `.mathBlock(code: String)` case with stable `id` using `stableHash`
    - [x] `MathAttributes.swift` exists in `mkdn/Core/Math/` with `MathExpressionAttribute` as a custom `AttributedString.Key`
    - [x] `AttributeScopes.MathAttributes` and `AttributeDynamicLookup` subscript are defined
    - [x] `plainText(from:)` in the builder handles the new `.mathBlock` case
    - [x] `swift build` succeeds with no errors or warnings

    **Implementation Summary**:

    - **Files**: `Package.swift`, `mkdn/Core/Markdown/MarkdownBlock.swift`, `mkdn/Core/Math/MathAttributes.swift` (new), `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`, `mkdn/Features/Viewer/Views/MarkdownBlockView.swift`
    - **Approach**: Added SwiftMath 1.7.0+ dependency, extended MarkdownBlock enum with .mathBlock case, created MathExpressionAttribute as custom AttributedString.Key, added .mathBlock handling to all exhaustive switch statements (appendBlock, plainText, MarkdownBlockView body)
    - **Deviations**: SwiftMath version is 1.7.0+ (not 3.3.0+ as in design) because version 3.3.0 does not exist; latest available is 1.7.3
    - **Tests**: 509/512 passing (3 pre-existing failures in AppSettings.cycleTheme unrelated to this change)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

### MathRenderer and Detection (Parallel)

- [x] **T2**: Implement MathRenderer as a stateless SwiftMath wrapper that renders LaTeX to NSImage with baseline reporting `[complexity:medium]`

    **Reference**: [design.md#33-mathrenderer-coremath](design.md#33-mathrenderer-coremath)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] `MathRenderer.swift` exists in `mkdn/Core/Math/` as `@MainActor enum MathRenderer`
    - [x] `renderToImage(latex:fontSize:textColor:displayMode:)` returns `(image: NSImage, baseline: CGFloat)?`
    - [x] Valid LaTeX expressions (e.g., `x^2`, `\frac{a}{b}`) return non-nil with positive image dimensions
    - [x] Invalid/unparseable LaTeX returns nil (no crash, no hang)
    - [x] Display mode (`displayMode: true`) produces different sizing than text mode
    - [x] Images render at screen backing scale factor for crisp output
    - [x] Baseline offset is reported from `MTMathUILabel.descent`

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Math/MathRenderer.swift` (new)
    - **Approach**: Uses SwiftMath's `MathImage` struct (lightweight, non-view API) instead of the heavier `MTMathUILabel` NSView. `MathImage.asImage()` returns both the rendered NSImage and a `LayoutInfo` containing ascent/descent. The NSImage uses `NSImage(size:flipped:)` draw handler for resolution-independent rendering (crisp on Retina without manual scale factor management).
    - **Deviations**: Uses `MathImage.LayoutInfo.descent` instead of `MTMathUILabel.descent` as specified in design. Both read from the same underlying `MTMathListDisplay.descent` value. `MathImage` is a value type (struct) avoiding NSView lifecycle overhead.
    - **Tests**: 509/512 passing (3 pre-existing failures in AppSettings.cycleTheme unrelated to this change)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T3**: Add three math detection paths to MarkdownVisitor: code fences, standalone `$$`, and inline `$` `[complexity:medium]`

    **Reference**: [design.md#32-detection-logic-markdownvisitor](design.md#32-detection-logic-markdownvisitor)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] Code fences with language `math`, `latex`, or `tex` produce `.mathBlock(code:)` instead of `.codeBlock`
    - [x] Standalone paragraphs consisting entirely of `$$...$$` produce `.mathBlock(code:)` with delimiters stripped
    - [x] `$$` mixed with other text in a paragraph does NOT trigger block math detection (stays `.paragraph`)
    - [x] Inline `$...$` patterns within paragraph text produce `mathExpression` attribute on the AttributedString
    - [x] Escaped `\$` is treated as literal text, not a math delimiter
    - [x] Adjacent `$$` is not treated as an inline math delimiter
    - [x] `$` followed by whitespace is not treated as an opening delimiter
    - [x] Whitespace followed by closing `$` is not treated as a closing delimiter
    - [x] Unclosed `$` is treated as literal text
    - [x] Empty delimiters (`$$` with nothing between) produce no math
    - [x] Multiple inline math expressions in one paragraph all have correct `mathExpression` attributes
    - [x] `postProcessMathDelimiters()` and `findInlineMathRanges(in:)` are implemented as described

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/MarkdownVisitor.swift`
    - **Approach**: Three detection paths added: (1) code fence detection extends CodeBlock handler for `math`/`latex`/`tex` languages; (2) standalone `$$` detection in `convertParagraph` checks if trimmed paragraph text starts and ends with `$$` with content between; (3) inline `$...$` detection via `postProcessMathDelimiters()` called from `inlineText(from:)` with a character-by-character state machine scanner (`findInlineMathRanges`/`findClosingDollar`) that respects all business rules (escaped `\$`, `$$` skip, whitespace adjacency, unclosed literal, empty rejection). Matched ranges are replaced in reverse order with `mathExpression`-attributed segments.
    - **Deviations**: None
    - **Tests**: 509/512 passing (3 pre-existing failures in AppSettings.cycleTheme unrelated to this change)

### TextStorageBuilder Integration

- [ ] **T4**: Wire math blocks and inline math through MarkdownTextStorageBuilder with attachment placeholders and NSTextAttachment rendering `[complexity:medium]`

    **Reference**: [design.md#35-inline-math-rendering](design.md#35-inline-math-rendering)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] `.mathBlock` dispatches to `appendAttachmentPlaceholder` in screen mode (same as `.mermaidBlock`)
    - [ ] `.mathBlock` dispatches to `appendMathBlockInline` in print mode (`isPrint: true`)
    - [ ] `MarkdownTextStorageBuilder+MathInline.swift` exists with `renderInlineMath` static method
    - [ ] `convertInlineContent` checks for `mathExpression` attribute before existing run processing
    - [ ] Inline math renders to `NSTextAttachment` with correct baseline alignment via negative `bounds.origin.y`
    - [ ] Failed inline math renders as monospace text with secondary (0.6 alpha) foreground color
    - [ ] `AttachmentInfo` is produced for `.mathBlock` blocks (consumed by OverlayCoordinator)

### Block Math Overlay

- [ ] **T5**: Create MathBlockView and extend OverlayCoordinator to host math block overlays `[complexity:medium]`

    **Reference**: [design.md#34-block-math-rendering](design.md#34-block-math-rendering)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [ ] `MathBlockView.swift` exists in `mkdn/Features/Viewer/Views/` as a SwiftUI view
    - [ ] `MathBlockView` renders display-mode math centered with vertical padding (8pt)
    - [ ] `MathBlockView` reports size changes via `onSizeChange` callback for dynamic overlay height
    - [ ] `MathBlockView` re-renders on theme change (`onChange(of: appSettings.theme)`)
    - [ ] `MathBlockView` re-renders on zoom change (`onChange(of: appSettings.scaleFactor)`)
    - [ ] Failed expressions display as centered monospace fallback with secondary foreground color
    - [ ] `OverlayCoordinator.needsOverlay` returns true for `.mathBlock`
    - [ ] `OverlayCoordinator.createAttachmentOverlay` creates `NSHostingView<MathBlockView>` for `.mathBlock`
    - [ ] `OverlayCoordinator.blocksMatch` handles `.mathBlock` comparison
    - [ ] `makeMathBlockOverlay` factory method wires `onSizeChange` to `updateAttachmentHeight`

### Print Support

- [ ] **T6**: Implement block math print rendering as centered NSTextAttachment in the isPrint path `[complexity:simple]`

    **Reference**: [design.md#36-print-support](design.md#36-print-support)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [ ] `appendMathBlockInline` renders math via `MathRenderer.renderToImage` with `PrintPalette.colors.foreground` (black)
    - [ ] Rendered image is inserted as a centered `NSTextAttachment` with appropriate paragraph style
    - [ ] Failed expressions fall back to centered monospace text in print palette colors
    - [ ] Inline math prints correctly (inherits print palette colors from `convertInlineContent` call chain)
    - [ ] `swift build` succeeds; no print-path compilation errors

### Tests and Fixture

- [ ] **T7**: Create comprehensive test fixture and unit tests for math detection, rendering, and integration `[complexity:medium]`

    **Reference**: [design.md#7-testing-strategy](design.md#7-testing-strategy)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] `fixtures/math-test.md` exists with coverage for: code fence math, standalone `$$`, inline `$`, multiple inline, escaped dollars, fallback expressions, math in headings, mixed content
    - [ ] `MathRendererTests.swift` exists in `mkdnTests/Unit/Core/` with tests: renders simple expression, returns nil for invalid LaTeX, reports positive baseline, respects display mode
    - [ ] `MarkdownVisitorMathTests.swift` exists with tests: detects math/latex/tex code fences, detects standalone `$$`, does not detect `$$` in mixed paragraph, detects inline `$`, escaped `$` is literal, adjacent `$$` not treated as inline, unclosed `$` is literal, multiple inline math, empty delimiters produce no math
    - [ ] `MarkdownTextStorageBuilderMathTests.swift` exists with tests: math block produces attachment, math block print produces inline image, inline math produces attachment in text, inline math fallback produces monospace text
    - [ ] All tests use Swift Testing (`@Test`, `#expect`, `@Suite`)
    - [ ] `swift test` passes with all new tests green

### User Docs

- [ ] **TD1**: Update `.rp1/context/index.md` Quick Reference - add `mkdn/Core/Math/` entry `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/index.md`

    **Section**: Quick Reference

    **KB Source**: index.md:Quick Reference

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Quick Reference section includes `mkdn/Core/Math/` entry with purpose description

- [ ] **TD2**: Update `.rp1/context/modules.md` Core Layer - add Math module inventory `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Core Layer

    **KB Source**: modules.md:Core Layer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Core Layer section includes Math subsection with MathRenderer.swift and MathAttributes.swift entries

- [ ] **TD3**: Update `.rp1/context/modules.md` Dependencies - add SwiftMath dependency `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Dependencies

    **KB Source**: modules.md:Dependencies

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Dependencies table includes SwiftMath (mgriebling/SwiftMath) with purpose and usage

- [ ] **TD4**: Update `.rp1/context/architecture.md` Rendering Pipeline - add Math pipeline diagram `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Rendering Pipeline

    **KB Source**: architecture.md:Markdown

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Rendering Pipeline section includes Math subsection documenting both block and inline math data flows

- [ ] **TD5**: Update `.rp1/context/patterns.md` - add inline math rendering pattern `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: (new section)

    **KB Source**: patterns.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New section documents the inline math NSTextAttachment pattern with baseline alignment technique

## Acceptance Criteria Checklist

### Block Math Detection
- [ ] Code fences with language `math`, `latex`, or `tex` are detected as block math expressions (REQ-BDET-1)
- [ ] Standalone paragraphs consisting entirely of `$$...$$` are detected as block math expressions (REQ-BDET-2)
- [ ] Block math detection does not trigger for `$$` used inline within a paragraph alongside other text (REQ-BDET-3)

### Inline Math Detection
- [ ] Text enclosed in single `$...$` within a paragraph is detected as inline math (REQ-IDET-1)
- [ ] Escaped dollar signs (`\$`) are treated as literal characters, not math delimiters (REQ-IDET-2)
- [ ] Adjacent dollar signs (`$$`) within a paragraph are not treated as inline math delimiters (REQ-IDET-3)
- [ ] Empty delimiters (`$$` with no content between) do not produce math rendering (REQ-IDET-4)
- [ ] Unclosed `$` delimiters are treated as literal text (REQ-IDET-5)
- [ ] Multiple inline math expressions within a single paragraph all render correctly (REQ-IDET-6)

### Block Math Rendering
- [ ] Block math renders in display mode (larger, centered) using native vector rendering (REQ-BRND-1)
- [ ] Block math has appropriate vertical spacing above and below (REQ-BRND-2)
- [ ] Block math text color matches the active theme's foreground color (REQ-BRND-3)
- [ ] Theme changes update block math color instantly (REQ-BRND-4)
- [ ] Block math overlay resizes dynamically to fit the rendered equation (REQ-BRND-5)

### Inline Math Rendering
- [ ] Inline math renders at a size proportional to the surrounding text (REQ-IRND-1)
- [ ] Inline math baseline aligns precisely with the baseline of surrounding text (REQ-IRND-2)
- [ ] Inline math text color matches the surrounding text color (REQ-IRND-3)
- [ ] Inline math has appropriate horizontal spacing relative to adjacent text (REQ-IRND-4)

### Fallback Rendering
- [ ] Expressions that cannot be parsed render as raw LaTeX source in monospace font (REQ-FALL-1)
- [ ] Fallback rendering uses a secondary/subdued text color, not an error color (REQ-FALL-2)
- [ ] Fallback rendering for block math is centered (REQ-FALL-3)
- [ ] No expression, regardless of content, causes a crash or hang (REQ-FALL-4)

### Print Support
- [ ] Block math prints correctly in Cmd+P output (REQ-PRNT-1)
- [ ] Inline math prints correctly in Cmd+P output (REQ-PRNT-2)
- [ ] Printed math uses the print palette colors (black on white) (REQ-PRNT-3)

### Non-Functional
- [ ] Documents with up to 50 math expressions render without perceptible delay (NFR-PERF-1)
- [ ] Inline math rendering does not cause visible jank during initial document layout (NFR-PERF-2)
- [ ] Theme switching with math-heavy documents feels instant (NFR-PERF-3)
- [ ] LaTeX input is treated as data only; no code execution path exists beyond SwiftMath parser (NFR-SEC-1)
- [ ] Math rendering requires zero user configuration (NFR-USE-1)
- [ ] Presence of math does not alter rendering of non-math content (NFR-USE-2)
- [ ] SwiftMath dependency is MIT-licensed (NFR-COMP-1)
- [ ] All new code passes SwiftLint strict mode and SwiftFormat (NFR-COMP-2)
- [ ] All new code compiles under Swift 6 strict concurrency with no warnings (NFR-COMP-3)

## Definition of Done

- [ ] All tasks completed
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] Docs updated
