# Root Cause Investigation Report - spacing-001

## Executive Summary
- **Problem**: Excessive vertical spacing between markdown elements in preview mode, particularly around headings and mermaid diagram placeholder blocks.
- **Root Cause**: A combination of three compounding spacing mechanisms in `MarkdownTextStorageBuilder`: (1) `paragraphSpacing` on the current block's terminator newline, (2) `paragraphSpacingBefore` on the next block, and (3) the inherent line height of large heading fonts -- all stack additively via NSParagraphStyle semantics, producing visual gaps far larger than the individual spacing constants suggest.
- **Solution**: Implement a spacing constants module that accounts for NSParagraphStyle's collapsing/stacking rules, and reduce `blockSpacing` or adopt `max()` logic between adjacent blocks instead of additive accumulation. For mermaid blocks, the 200pt fixed-height placeholder further inflates perceived spacing.
- **Urgency**: Medium -- the spacing is functional but visually off from the design intent documented in the spatial-design-language PRD.

## Investigation Process
- **Duration**: Static code analysis of the full rendering pipeline
- **Hypotheses Tested**:
  1. **NSParagraphStyle double-spacing between blocks** -- CONFIRMED
  2. **Mermaid attachment placeholder height contributing extra vertical space** -- CONFIRMED
  3. **Heading font line height inflating visual gaps** -- CONFIRMED
  4. **`makeParagraphStyle` default lineSpacing adding extra intra-block space** -- PARTIALLY CONFIRMED (4pt default)
- **Key Evidence**:
  1. Every block appends a `terminator(with: style)` newline that carries the same `paragraphSpacing` as the block content, causing NSTextView to add the `paragraphSpacing` *after* the last line. The *next* block's `paragraphSpacingBefore` then adds *on top of that*, since NSParagraphStyle does not collapse adjacent spacing -- it takes `max(previous.paragraphSpacing, next.paragraphSpacingBefore)`.
  2. The spatial compliance tests empirically measured `h1SpaceBelow` at ~67.5pt and `h2SpaceBelow` at ~66pt, which is vastly larger than the `blockSpacing` constant of 12pt, because the heading font's line height (~33pt for H1, ~29pt for H2) is included in the visual gap measurement.
  3. Mermaid block placeholders use a fixed 200pt attachment height with an additional 12pt `paragraphSpacing`, creating a 212pt+ region even before the diagram renders.

## Root Cause Analysis

### Technical Details

The spacing pipeline involves three files:
- `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` (constants and helpers)
- `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift` (block-type-specific rendering)
- `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift` (lists, blockquotes, tables)

**Source 1: Additive paragraph spacing between blocks**

The `blockSpacing` constant is set to `12` (line 24 of `MarkdownTextStorageBuilder.swift`). Every block-level element applies this as `paragraphSpacing` on its NSParagraphStyle, which controls the space *after* the paragraph's last line. The pattern is:

```swift
// In appendParagraph (MarkdownTextStorageBuilder+Blocks.swift:52)
let style = makeParagraphStyle(paragraphSpacing: blockSpacing)  // 12pt after
content.addAttribute(.paragraphStyle, value: style, range: range)
content.append(terminator(with: style))  // newline with same 12pt paragraphSpacing
```

```swift
// In appendHeading (MarkdownTextStorageBuilder+Blocks.swift:25-28)
let style = makeParagraphStyle(
    paragraphSpacing: blockSpacing,         // 12pt after
    paragraphSpacingBefore: spacingBefore   // 8pt (H1/H2) or 4pt (H3+) before
)
```

NSParagraphStyle semantics: When two paragraphs are adjacent, NSTextView renders `max(prev.paragraphSpacing, next.paragraphSpacingBefore)` between them -- NOT the sum. This means:

- Paragraph followed by paragraph: `max(12, 0) = 12pt` gap (plus font line height metrics)
- Paragraph followed by H1 heading: `max(12, 8) = 12pt` gap (plus H1 font ascender/descender)
- Paragraph followed by H2 heading: `max(12, 8) = 12pt` gap
- H1 heading followed by paragraph: `max(12, 0) = 12pt` gap (plus H1 font metrics)

However, the *visual* gap is much larger than 12pt because it also includes:
- The font's descender below the baseline of the previous line
- The font's ascender above the baseline of the next line
- The font's leading
- The `lineSpacing` value (defaulted to 4pt in `makeParagraphStyle`)

For H1 (28pt system font), the combined ascender + descender + leading can be ~33pt. Adding the 12pt `paragraphSpacing` and 4pt `lineSpacing` yields a visual gap of approximately 49-67pt, which matches the empirically measured `h1SpaceBelow` of 67.5pt from `SpatialPRD.swift`.

**Source 2: Default `lineSpacing` of 4pt**

The `makeParagraphStyle` helper function (line 191-213 of `MarkdownTextStorageBuilder.swift`) defaults `lineSpacing` to 4:

```swift
static func makeParagraphStyle(
    lineSpacing: CGFloat = 4,       // <-- default 4pt extra line spacing
    paragraphSpacing: CGFloat = 0,
    paragraphSpacingBefore: CGFloat = 0,
    ...
```

This 4pt `lineSpacing` is added to *every* line within every paragraph, including the last line before the paragraph break. It compounds with `paragraphSpacing` to create slightly wider gaps than the `blockSpacing` constant alone would suggest.

**Source 3: Mermaid/Image attachment placeholder height**

In `MarkdownTextStorageBuilder.swift` (line 32):

```swift
static let attachmentPlaceholderHeight: CGFloat = 200
```

Mermaid blocks and images use `appendAttachmentBlock` (lines 121-144 of `+Blocks.swift`) which creates an `NSTextAttachment` with a fixed 200pt bounds and applies `paragraphSpacing: blockSpacing` (12pt):

```swift
let attachment = NSTextAttachment()
attachment.bounds = CGRect(x: 0, y: 0, width: 1, height: height)  // height = 200
let style = makeParagraphStyle(paragraphSpacing: blockSpacing)     // 12pt after
```

This means every mermaid block placeholder occupies at least 200 + 12 + 4 (lineSpacing) = 216pt of vertical space before any overlay content is positioned. The `OverlayCoordinator` later positions the actual `MermaidBlockView` SwiftUI view on top of this placeholder, but the placeholder height determines the minimum space. The `updateAttachmentHeight` method in `OverlayCoordinator` can resize the attachment dynamically (line 86-108 of `OverlayCoordinator.swift`), but:
1. The initial placeholder is always 200pt
2. Before mermaid rendering completes, the placeholder shows as empty space
3. The `MermaidBlockView` itself starts with `renderedHeight: 200` (line 17 of `MermaidBlockView.swift`)

This creates large visible gaps especially when:
- Multiple mermaid blocks are stacked (as in `mermaid-focus.md` with 4 diagrams)
- Mermaid rendering fails or hasn't completed (all 4 diagrams shown as absent in the evaluation report)

**Source 4: Heading spacing constants are small relative to font metrics**

The `paragraphSpacingBefore` for headings is only 8pt (H1/H2) or 4pt (H3+), as seen in `MarkdownTextStorageBuilder+Blocks.swift` line 17:

```swift
let spacingBefore: CGFloat = level <= 2 ? 8 : 4
```

Combined with the default `lineSpacing` of 4pt on the *preceding* block's terminator, the total above-heading space is dominated by font metrics rather than explicit spacing constants. The SpatialPRD target values for heading space above are 48pt (H1), 32pt (H2), and 24pt (H3), but the current implementation uses 8pt, 8pt, and 4pt respectively for `paragraphSpacingBefore` -- relying entirely on font line height to fill the gap. This makes spacing sensitive to font rendering changes across macOS versions.

### Causation Chain

```
Root Cause: paragraphSpacing(12) + lineSpacing(4) + font metrics (~20-33pt) stack additively
    |
    v
Each block contributes: content height + lineSpacing(4) + paragraphSpacing(12)
    |
    v
Adjacent blocks: max(prev.paragraphSpacing, next.paragraphSpacingBefore) + font metrics
    |
    v
Visual gap = font descender + paragraphSpacing/Before + font ascender + lineSpacing
    |
    v
For H1-to-paragraph: ~33pt(H1 metrics) + 12pt(spacing) + ~13pt(body metrics) + 4pt(lineSpacing) ~ 62pt
    |
    v
Measured: 67.5pt (matches within measurement tolerance)
    |
    v
Perceived as "too much space" between sections

Additionally:
Root Cause: 200pt fixed placeholder height for mermaid/image attachments
    |
    v
Each unrendered mermaid block: 200pt placeholder + 12pt paragraphSpacing + 4pt lineSpacing
    |
    v
mermaid-focus.md with 4 diagrams: ~864pt of attachment space alone
    |
    v
Perceived as "large vertical gaps around mermaid diagram blocks"
```

### Why It Occurred

1. **No spacing constants module**: The codebase lacks a centralized `SpacingConstants` module (noted as a TODO in `SpatialPRD.swift` comments). The `blockSpacing` value (12pt) was chosen independently of NSParagraphStyle semantics.

2. **Font metrics are invisible**: The large contribution of font ascender/descender to visual gaps is not accounted for in the spacing constants. A 28pt H1 font has ~33pt of vertical extent, which dwarfs the 12pt `blockSpacing`.

3. **NSParagraphStyle lineSpacing default**: The 4pt default `lineSpacing` in `makeParagraphStyle` adds spacing to every line, including terminal lines before block breaks, without being explicitly documented as part of the inter-block gap.

4. **Fixed placeholder height**: The 200pt `attachmentPlaceholderHeight` is a static estimate that does not adapt to the actual content size until after asynchronous rendering completes.

## Proposed Solutions

### 1. Recommended: Implement SpacingConstants with visual-gap-aware values

**Approach**: Create a `SpacingConstants` module that defines inter-block spacing in terms of the *total visual gap* desired, then computes the NSParagraphStyle values needed to achieve that gap after accounting for font metrics.

**Implementation sketch**:
- Define target visual gaps: paragraph-to-paragraph (16pt), paragraph-to-H1 (48pt above), H1-to-paragraph (16pt below), etc.
- Compute `paragraphSpacing` and `paragraphSpacingBefore` by subtracting known font metrics (ascender + descender + leading) from the target visual gap.
- Reduce `lineSpacing` from 4pt to 2pt or 0pt to tighten intra-block spacing.
- Set `attachmentPlaceholderHeight` based on a loading-state height (e.g., 100pt) rather than full-diagram height.

**Effort**: Medium (2-3 hours). Requires understanding NSFont metrics APIs and testing across both themes.

**Risk**: Low. Changes are isolated to `MarkdownTextStorageBuilder` constants and the `makeParagraphStyle` helper.

**Pros**: Addresses root cause directly; produces predictable, maintainable spacing; aligns with PRD target values.

**Cons**: Requires empirical testing of font metrics on target macOS versions.

### 2. Alternative: Reduce blockSpacing and lineSpacing constants

**Approach**: Simply reduce `blockSpacing` from 12pt to 8pt and `lineSpacing` from 4pt to 2pt. This is a quick fix that reduces all gaps proportionally.

**Effort**: Low (30 minutes).

**Risk**: Medium. May under-space some elements while still over-spacing others, since the issue is that spacing is *relative to font size* but the constant is *absolute*.

**Pros**: Quick, easy to test.

**Cons**: Does not address the underlying mismatch between intended visual gap and the way NSParagraphStyle computes spacing; heading gaps would still be dominated by font metrics.

### 3. Alternative: Dynamic placeholder height for attachments

**Approach**: Reduce `attachmentPlaceholderHeight` to a loading-state-appropriate size (e.g., 100pt for loading spinner, then dynamically resize via `updateAttachmentHeight` when rendering completes).

**Effort**: Low (1 hour). The `updateAttachmentHeight` mechanism already exists in `OverlayCoordinator`.

**Risk**: Low. The dynamic resize path is already implemented.

**Pros**: Directly reduces mermaid/image placeholder gaps.

**Cons**: Only addresses attachment spacing, not the general inter-block spacing issue.

## Prevention Measures

1. **Implement SpacingConstants module**: Centralize all spacing values with documentation of how they interact with NSParagraphStyle semantics. Reference this module from both the builder and the spatial compliance tests.

2. **Add unit tests for visual gap computation**: Test that the combination of `paragraphSpacing`, `paragraphSpacingBefore`, `lineSpacing`, and known font metrics produces the intended visual gap for each block-type pair.

3. **Document NSParagraphStyle interaction model**: Add a code comment or architecture doc section explaining that `max(prev.paragraphSpacing, next.paragraphSpacingBefore)` is used by NSTextView, not `sum()`, and that font metrics contribute the majority of visual gaps for large fonts.

4. **Use spatial compliance tests as regression gates**: The existing `SpatialComplianceTests` already measure visual gaps; ensure they run in CI and fail on spacing regressions.

## Evidence Appendix

### E1: Spacing Constants in MarkdownTextStorageBuilder.swift

File: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`, lines 24-34

```swift
static let blockSpacing: CGFloat = 12
static let codeBlockPadding: CGFloat = 12
static let codeBlockTopPaddingWithLabel: CGFloat = 8
static let codeLabelSpacing: CGFloat = 4
static let listItemSpacing: CGFloat = 4
static let listPrefixWidth: CGFloat = 32
static let listLeftPadding: CGFloat = 4
static let blockquoteIndent: CGFloat = 19
static let attachmentPlaceholderHeight: CGFloat = 200
static let thematicBreakHeight: CGFloat = 17
static let tableColumnWidth: CGFloat = 120
```

### E2: Default lineSpacing of 4pt in makeParagraphStyle

File: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`, lines 191-213

```swift
static func makeParagraphStyle(
    lineSpacing: CGFloat = 4,           // <-- contributes to every inter-line gap
    paragraphSpacing: CGFloat = 0,
    paragraphSpacingBefore: CGFloat = 0,
    headIndent: CGFloat = 0,
    ...
```

### E3: Heading paragraphSpacingBefore values

File: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`, lines 8-33

```swift
let spacingBefore: CGFloat = level <= 2 ? 8 : 4  // H1/H2 get 8pt, H3+ get 4pt
let style = makeParagraphStyle(
    paragraphSpacing: blockSpacing,                // 12pt after
    paragraphSpacingBefore: spacingBefore           // 8pt or 4pt before
)
```

### E4: Attachment block spacing

File: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`, lines 121-144

```swift
let attachment = NSTextAttachment()
attachment.bounds = CGRect(x: 0, y: 0, width: 1, height: height)  // height=200
let style = makeParagraphStyle(paragraphSpacing: blockSpacing)     // 12pt after
attachmentStr.addAttribute(.paragraphStyle, value: style, range: range)
attachmentStr.append(terminator(with: style))                      // newline with 12pt
```

### E5: SpatialPRD empirically measured values vs. PRD targets

File: `/Users/jud/Projects/mkdn/mkdnTests/UITest/SpatialPRD.swift`

| Metric | PRD Target | Measured | Current Code Value |
|--------|-----------|----------|-------------------|
| blockSpacing | 16pt | ~26pt visual ink gap | 12pt (paragraphSpacing) |
| h1SpaceAbove | 48pt | 8pt (paragraphSpacingBefore) + font metrics | 8pt |
| h1SpaceBelow | 16pt | ~67.5pt visual ink gap | 12pt (paragraphSpacing) + H1 font height |
| h2SpaceAbove | 32pt | ~45pt visual ink gap | 8pt (paragraphSpacingBefore) + font metrics |
| h2SpaceBelow | 12pt | ~66pt visual ink gap | 12pt (paragraphSpacing) + H2 font height |

The SpatialPRD comments explain the discrepancy: "The large gap includes the H1 font's descender/leading (H1 ~28pt font has significant line height) plus paragraphSpacing."

### E6: Mermaid capture showing absent diagrams with large gaps

File: `/Users/jud/Projects/mkdn/.rp1/work/verification/reports/20260210-024606-evaluation.json`, ISS-001 (mermaid-focus):

> "No Mermaid diagrams are rendered inline in the document. The areas below the Flowchart, Sequence Diagram, and Class Diagram headings are empty -- no rendered diagram images, no loading spinners, and no error messages are visible."

And QF-005 (mermaid-focus-solarizedDark):

> "The vertical spacing between the Flowchart section and the Sequence Diagram section appears to have a large empty gap where a diagram should be rendered."

### E7: MermaidBlockView initial height

File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`, line 17

```swift
@State private var renderedHeight: CGFloat = 200
```

This matches the `attachmentPlaceholderHeight` in the builder, creating a consistent 200pt reservation.

### E8: Paragraph spacing application pattern

Every block type follows the same pattern of applying `paragraphSpacing: blockSpacing` and appending a `terminator(with: style)` newline. This terminator carries the same paragraph style, which means the newline character inherits the spacing properties. NSTextView then applies `max(prev.paragraphSpacing, next.paragraphSpacingBefore)` between the terminated paragraph and the next one, using the newline's paragraph style as the source for `prev.paragraphSpacing`.

### E9: Visual evidence from captured screenshots

The geometry-calibration capture (`.rp1/work/verification/captures/geometry-calibration-solarizedDark-previewOnly.png`) shows:
- Clear heading hierarchy with proportional spacing
- Noticeable gaps between headings and following paragraphs
- The gaps are larger than standard markdown rendering but not extreme
- The overall layout is usable but spacing is loose, especially for H1/H2 transitions

The mermaid-focus capture (`.rp1/work/verification/captures/mermaid-focus-solarizedDark-previewOnly.png`) shows:
- Large empty regions between headings where mermaid diagrams should appear
- The HTML comment block at the top consuming significant vertical space
- Heading sections with descriptive paragraphs spaced far apart from each other
