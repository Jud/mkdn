# Requirements Specification: Native LaTeX Math Rendering

**Feature ID**: native-latex-math
**Parent PRD**: [Core Markdown Rendering](../../prds/core-markdown-rendering.md) (extends rendering pipeline)
**Related PRD**: [Mermaid Re-Architect](../../prds/mermaid-rearchitect.md) (reuses overlay pattern)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-24

## 1. Feature Overview

Native LaTeX math rendering brings mathematical expression support to mkdn's Markdown viewer. Mathematical notation -- from simple inline variables to complex display equations -- is rendered as crisp, vector-resolution typography that integrates seamlessly with the document's text, theme, and visual rhythm. Expressions that cannot be rendered degrade gracefully into styled monospace, maintaining document readability without visual disruption.

## 2. Business Context

### 2.1 Problem Statement

Technical documents and LLM-generated content increasingly contain LaTeX math notation. mkdn currently renders these expressions as raw LaTeX source text, breaking the reading experience for any document containing mathematics. Users who view LLM-produced technical reports, research notes, or documentation with equations see unintelligible markup instead of the intended mathematical content.

### 2.2 Business Value

- Completes mkdn's coverage of the most common Markdown extensions used in technical writing
- Directly serves the target user persona: developers working with LLMs, whose output frequently includes LaTeX math
- Differentiates mkdn from terminal-based Markdown viewers that cannot render math
- Maintains the project's native-first philosophy: vector rendering via CoreGraphics/CoreText, no WebView, no JavaScript dependency for math
- Aligns with the charter's vision of "render beautifully" -- math should be as beautiful as the rest of the document

### 2.3 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Expression coverage | Common LaTeX math expressions (~80-85%) render correctly | Visual verification against fixture file |
| Inline baseline alignment | Inline math sits on the same baseline as surrounding text, within 1pt tolerance | Visual inspection at multiple zoom levels |
| Theme consistency | Math foreground color matches document text color in both Solarized themes | Screenshot comparison across theme switches |
| Fallback quality | Unsupported expressions display as readable monospace, not as error states | Visual verification of intentionally unsupported expressions |
| Performance | Documents with up to 50 math expressions render without perceptible delay | Subjective evaluation during daily use |
| Zero regressions | All existing tests pass; documents without math render identically | `swift test` and visual comparison |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Relationship to Feature | Priority |
|-----------|------------------------|----------|
| Developer reading LLM output | Primary consumer. Views technical documents, research summaries, and code documentation that contain inline and block math. Expects math to render correctly without any action. | Primary |
| Developer authoring Markdown | Secondary consumer. Writes documents with math and previews them. Needs confidence that the rendered output matches intent. | Secondary |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project creator (daily-driver user) | Math-heavy LLM outputs render beautifully in the same app used for all other Markdown. No context-switching to another viewer for math documents. |

## 4. Scope Definition

### 4.1 In Scope

- Detection and rendering of LaTeX math in three syntactic forms:
  - Code fences with `math`, `latex`, or `tex` language identifiers (block display)
  - Standalone `$$...$$` paragraphs (block display)
  - Inline `$...$` within paragraph text (inline display)
- Block math: centered, display-mode rendering with breathing room above and below
- Inline math: rendered at text size with precise baseline alignment to surrounding text
- Theme-aware rendering: math text color matches the active theme's foreground color, updates instantly on theme change
- Graceful fallback: expressions that fail to parse render as styled monospace with secondary text color
- Escaped dollar signs (`\$`) treated as literal dollar signs, not math delimiters
- Print support: math renders correctly in Cmd+P output
- Visual test fixture for comprehensive verification

### 4.2 Out of Scope

- Extending SwiftMath's LaTeX coverage (future: vendor and extend)
- LaTeX environments beyond math mode (`\begin{align}`, `\begin{cases}`, `\text{}` -- these are SwiftMath limitations, not feature scope)
- Structured VoiceOver accessibility for math expressions (future)
- Math-aware copy/paste (LaTeX source on clipboard) (future)
- Caching of inline math rendering for performance optimization (future)
- Editing math expressions (live preview while typing LaTeX)
- MathML or other non-LaTeX math input formats
- Math in table cells (inherits whatever inline rendering provides, but not specifically optimized)

### 4.3 Assumptions

| ID | Assumption | Risk if Wrong |
|----|------------|---------------|
| A1 | SwiftMath (mgriebling/SwiftMath 3.3.0+) compiles cleanly with Swift 6 strict concurrency | May need fork or source-level patches for Sendable conformance |
| A2 | SwiftMath's `MTMathUILabel` can render to `NSImage` for inline embedding as `NSTextAttachment` | May need alternative rendering path (CoreGraphics context drawing) |
| A3 | `MTMathUILabel.sizeThatFits()` provides accurate intrinsic size for measurement | May need manual bounding box calculation from the label's layer |
| A4 | SwiftMath's error detection (`hasError` or zero intrinsic size) reliably distinguishes parseable from unparseable expressions | May need try/catch around rendering or additional heuristics |
| A5 | Inline math rendered as `NSImage` attachment achieves acceptable visual quality at all zoom levels | Vector rendering to bitmap may lose crispness at extreme zoom; may need scale-factor-aware rendering |
| A6 | The overlay coordinator pattern used for Mermaid blocks works identically for math blocks | Math blocks are simpler (no gesture handling, no async), so risk is low |

## 5. Functional Requirements

### Block Math Detection

| ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|----|----------|-----------|-------------|-----------|-------------------|
| REQ-BDET-1 | Must | All readers | Code fences with language `math`, `latex`, or `tex` are detected as block math expressions | These are the standard Markdown conventions for LaTeX code blocks | A ` ```math ` fenced block renders as a centered display equation |
| REQ-BDET-2 | Must | All readers | Standalone paragraphs consisting entirely of `$$...$$` are detected as block math expressions | `$$` delimiters are the most common LaTeX block math convention in Markdown | A paragraph containing only `$$E = mc^2$$` renders as a centered display equation |
| REQ-BDET-3 | Must | All readers | Block math detection does not trigger for `$$` used inline within a paragraph alongside other text | Prevents false positives where `$$` appears mid-sentence | A paragraph like "The cost is $$5.00 and $$10.00" does not render as math |

### Inline Math Detection

| ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|----|----------|-----------|-------------|-----------|-------------------|
| REQ-IDET-1 | Must | All readers | Text enclosed in single `$...$` within a paragraph is detected as inline math | Single-dollar delimiters are the standard LaTeX inline math convention | `$x^2$` within a sentence renders as a formatted expression |
| REQ-IDET-2 | Must | All readers | Escaped dollar signs (`\$`) are treated as literal characters, not math delimiters | Users need to write about currency or use literal dollar signs | "The price is \$5" renders with a visible dollar sign, no math |
| REQ-IDET-3 | Must | All readers | Adjacent dollar signs (`$$`) within a paragraph are not treated as inline math delimiters | Prevents conflict between inline and block detection | Double-dollar in flowing text is not misinterpreted |
| REQ-IDET-4 | Should | All readers | Empty delimiters (`$$` with no content between) do not produce math rendering | Prevents rendering artifacts from empty expressions | `$$` renders as literal text |
| REQ-IDET-5 | Must | All readers | Unclosed `$` delimiters are treated as literal text | Robustness against malformed input | A lone `$` in text renders as a dollar sign |
| REQ-IDET-6 | Should | All readers | Multiple inline math expressions within a single paragraph all render correctly | Common in technical writing | "Given $x = 1$ and $y = 2$, then $x + y = 3$" renders three expressions |

### Block Math Rendering

| ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|----|----------|-----------|-------------|-----------|-------------------|
| REQ-BRND-1 | Must | All readers | Block math renders in display mode (larger, centered) using native vector rendering | Display equations are visually distinct from inline math | Block equations appear centered with appropriate font size |
| REQ-BRND-2 | Must | All readers | Block math has appropriate vertical spacing above and below, providing breathing room | Equations need whitespace to not feel cramped against surrounding text | Visual inspection confirms comfortable spacing |
| REQ-BRND-3 | Must | All readers | Block math text color matches the active theme's foreground color | Math must feel native to the document, not foreign | In both Solarized themes, equation color matches body text color |
| REQ-BRND-4 | Must | All readers | Theme changes update block math color instantly without re-rendering the equation | CoreGraphics vector rendering allows direct color property updates | Switching themes shows immediate color change with no flicker |
| REQ-BRND-5 | Must | All readers | Block math overlay resizes dynamically to fit the rendered equation | Equations vary in size; fixed heights would crop or waste space | A tall fraction and a short expression each get appropriate height |

### Inline Math Rendering

| ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|----|----------|-----------|-------------|-----------|-------------------|
| REQ-IRND-1 | Must | All readers | Inline math renders at a size proportional to the surrounding text | Math should not tower over or shrink below adjacent text | `$x^2$` in a sentence appears at a natural size relative to the text |
| REQ-IRND-2 | Must | All readers | Inline math baseline aligns precisely with the baseline of surrounding text | Misaligned math is the most visible quality flaw in math rendering | `$x$` sits on the same baseline as the word before and after it |
| REQ-IRND-3 | Must | All readers | Inline math text color matches the surrounding text color | Color mismatch breaks the illusion of integrated rendering | In both themes, inline math is indistinguishable in color from body text |
| REQ-IRND-4 | Should | All readers | Inline math has appropriate horizontal spacing relative to adjacent text | Math should not touch adjacent words or have excessive gaps | The space between `$x^2$` and the next word feels natural |

### Fallback Rendering

| ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|----|----------|-----------|-------------|-----------|-------------------|
| REQ-FALL-1 | Must | All readers | Expressions that cannot be parsed render as the raw LaTeX source in monospace font | Partial rendering or error states are worse than showing the source | An unsupported expression like `$\begin{align}...\end{align}$` shows the LaTeX source in monospace |
| REQ-FALL-2 | Must | All readers | Fallback rendering uses a secondary/subdued text color, not an error color | Fallback is "honest, not ugly" -- it communicates limitation without alarm | Fallback text uses the theme's secondary foreground, not red or orange |
| REQ-FALL-3 | Should | All readers | Fallback rendering for block math is centered, matching the position of successful block renders | Visual consistency even in fallback state | A block math fallback appears centered, not left-aligned |
| REQ-FALL-4 | Must | All readers | No expression, regardless of content, causes a crash or hang | Robustness is non-negotiable | Malformed, empty, and adversarial LaTeX strings all degrade gracefully |

### Print Support

| ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|----|----------|-----------|-------------|-----------|-------------------|
| REQ-PRNT-1 | Should | All readers | Block math prints correctly in Cmd+P output | Overlay-based rendering does not participate in print; an alternative path is needed | Printed output shows centered display equations |
| REQ-PRNT-2 | Should | All readers | Inline math prints correctly in Cmd+P output | Inline math as NSTextAttachment should print naturally | Printed output shows inline math at correct size and position |
| REQ-PRNT-3 | Should | All readers | Printed math uses the print palette colors (black on white) | Consistent with how all other elements print | Math in printed output appears in black |

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-PERF-1 | A document with up to 50 math expressions (mix of block and inline) renders without perceptible delay on Apple Silicon | Must |
| NFR-PERF-2 | Inline math rendering does not cause visible jank during initial document layout | Must |
| NFR-PERF-3 | Theme switching with math-heavy documents feels instant (no re-render delay) | Must |

### 6.2 Security Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-SEC-1 | LaTeX input is treated as data only; no code execution path exists beyond the SwiftMath parser | Must |

### 6.3 Usability Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-USE-1 | Math rendering requires zero user configuration; it activates automatically when math syntax is detected | Must |
| NFR-USE-2 | The presence of math in a document does not alter the rendering of non-math content | Must |

### 6.4 Compliance Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-COMP-1 | SwiftMath dependency is MIT-licensed and compatible with the project's license | Must |
| NFR-COMP-2 | All new code passes SwiftLint strict mode and SwiftFormat | Must |
| NFR-COMP-3 | All new code compiles under Swift 6 strict concurrency with no warnings | Must |

## 7. User Stories

### STORY-1: Reading a Technical Document

**As a** developer viewing an LLM-generated technical report,
**I want** LaTeX math expressions to render as properly typeset mathematics,
**So that** I can read the document's mathematical content without mentally parsing raw LaTeX.

**Acceptance:**
- GIVEN a Markdown document containing `$$\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}$$`
- WHEN the document loads in mkdn
- THEN the equation renders as a centered, beautifully typeset display equation

### STORY-2: Mixed Content Reading

**As a** developer reading a document with interspersed math and prose,
**I want** inline math like `$O(n \log n)$` to blend seamlessly with surrounding text,
**So that** I can read technical prose without visual disruption from math rendering.

**Acceptance:**
- GIVEN a paragraph containing "The algorithm runs in $O(n \log n)$ time"
- WHEN the paragraph renders
- THEN `O(n log n)` appears as formatted math, baseline-aligned with the text, same color, with natural spacing

### STORY-3: Theme Switching with Math

**As a** developer who switches between Solarized Light and Dark,
**I want** math expressions to update their color instantly when I switch themes,
**So that** math always feels native to the current visual environment.

**Acceptance:**
- GIVEN a document with math expressions rendered in Solarized Dark
- WHEN I press Cmd+T to cycle themes to Solarized Light
- THEN all math expressions update their foreground color instantly to match the new theme

### STORY-4: Unsupported Expression Handling

**As a** developer viewing a document with advanced LaTeX that SwiftMath cannot parse,
**I want** those expressions to show the raw LaTeX in a tasteful monospace style,
**So that** I can still read the intended expression and the document does not look broken.

**Acceptance:**
- GIVEN a document containing an unsupported LaTeX construct
- WHEN the document renders
- THEN the expression appears as monospace text in a secondary color, not as an error or blank space

### STORY-5: Code Fence Math Blocks

**As a** developer viewing a document where math is written in code fences (` ```math `),
**I want** those blocks to render as display equations instead of code blocks,
**So that** the standard Markdown convention for math blocks is supported.

**Acceptance:**
- GIVEN a code fence with language `math` containing `E = mc^2`
- WHEN the document renders
- THEN the expression renders as a centered display equation, not as a code block with syntax highlighting

### STORY-6: Dollar Sign Escaping

**As a** developer reading a document that mentions currency amounts,
**I want** escaped dollar signs (`\$`) to render as literal dollar signs,
**So that** the math detection does not misinterpret financial content.

**Acceptance:**
- GIVEN a paragraph containing "The total cost is \$42.00"
- WHEN the paragraph renders
- THEN "$42.00" appears as literal text, not as a math expression

### STORY-7: Printing a Document with Math

**As a** developer printing a technical document,
**I want** math expressions to appear correctly in the printed output,
**So that** printed copies are as readable as the on-screen version.

**Acceptance:**
- GIVEN a document with both block and inline math
- WHEN I print via Cmd+P
- THEN the printed output shows math in black on white, correctly positioned and sized

## 8. Business Rules

| ID | Rule | Rationale |
|----|------|-----------|
| BR-1 | Math detection is opt-in by syntax: only content within recognized delimiters (`$`, `$$`, ` ```math/latex/tex `) is processed as math | Prevents false positives on documents not intended to contain math |
| BR-2 | A single `$` followed by whitespace is not treated as a math delimiter | Reduces false positives for currency and casual dollar sign usage |
| BR-3 | Block math detection (` ```math ` and standalone `$$`) takes precedence over inline math detection | Prevents a standalone `$$...$$` paragraph from being misinterpreted as two empty inline delimiters |
| BR-4 | SwiftMath parse failure is not an error condition; it is an expected outcome for unsupported expressions | The feature promises graceful degradation, not complete coverage |
| BR-5 | Math rendering must not alter the rendering of any existing Markdown element | Zero regressions is a hard constraint |

## 9. Dependencies & Constraints

### External Dependencies

| Dependency | Version | Purpose | Risk |
|------------|---------|---------|------|
| [mgriebling/SwiftMath](https://github.com/mgriebling/SwiftMath) | >= 3.3.0 | LaTeX math parsing and vector rendering via `MTMathUILabel` | Medium -- Swift 6 compatibility needs verification; package is actively maintained |

### Internal Dependencies

| Component | Relationship |
|-----------|-------------|
| MarkdownBlock enum | Extended with new `.mathBlock` case |
| MarkdownVisitor | Extended with three detection paths |
| MarkdownTextStorageBuilder | Extended for block dispatch and inline rendering |
| OverlayCoordinator | Extended for block math overlay lifecycle |
| MarkdownBlockView | Extended for SwiftUI math block rendering path |
| ThemeColors | Consumed for math foreground color |
| PrintPalette | Consumed for print-path math color |

### Constraints

- SwiftMath's `MTMathUILabel` is an NSView (AppKit); must be wrapped in `NSViewRepresentable` for SwiftUI and rendered to `NSImage` for inline embedding
- Inline math rendered as bitmap (`NSImage` via `NSTextAttachment`) loses vector quality at extreme zoom levels -- acceptable tradeoff given current zoom range (0.5x-3.0x)
- SwiftMath covers approximately 80-85% of common LaTeX math expressions; the remaining 15-20% will trigger fallback rendering
- Block math uses the overlay pattern, meaning overlays are not present during print -- an alternative print-time rendering path is needed

## 10. Clarifications Log

| Item | Question | Resolution | Source |
|------|----------|------------|--------|
| Math in headings | Should `$...$` in headings render as inline math? | Yes, inline math detection applies to all inline content contexts, including headings, list items, and blockquotes | Implementation plan specifies inline detection in `convertInline` which runs for all inline contexts |
| Math in tables | Should `$...$` in table cells render as inline math? | Yes, follows naturally from inline detection, but not specifically optimized | Scope section: "inherits whatever inline rendering provides" |
| Display vs text mode | How does MTMathUILabel distinguish display and inline rendering? | Display mode uses larger operators and centered layout; inline mode uses text-sized operators | SwiftMath API: `MTMathUILabel` has a `labelMode` property (.display vs .text) |
| WKWebView constraint | Does math rendering violate the WKWebView-only-for-Mermaid constraint? | No -- SwiftMath is a pure native library using CoreGraphics/CoreText, no WebView involved | SwiftMath renders via CG drawing commands, not web technology |
| Concurrent rendering | Can inline math images be rendered on a background thread? | MTMathUILabel is an NSView and must be created/rendered on @MainActor | AppKit constraint; mitigated by fast rendering speed of individual expressions |

---

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD association | core-markdown-rendering (primary), mermaid-rearchitect (secondary) | Math extends the markdown rendering pipeline directly; overlay pattern is borrowed from Mermaid architecture. No dedicated math PRD exists. |
| Fixture location | `fixtures/math-test.md` | Follows existing convention (`fixtures/table-test.md`, etc.) from the visual testing workflow |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| "Beauty and elegance" (vague quality term) | Translated to measurable criteria: baseline alignment within 1pt, color matching theme foreground exactly, centered block math with proportional spacing | Requirements design philosophy section + charter design philosophy |
| "Near-perfect in form" (vague quality term) | Interpreted as: expressions SwiftMath can render must have correct typography -- proper spacing, sizing, and alignment. Not interpreted as: SwiftMath must handle all LaTeX. | Requirements input: "What we render should be near-perfect" |
| "Breathing room" for block math (undefined spacing) | Deferred to implementation: appropriate vertical padding above and below display equations, consistent with existing block element spacing in the renderer | Existing spatial patterns in mkdn (code blocks, Mermaid blocks have established spacing conventions) |
| Inline math horizontal spacing | Deferred to implementation: NSTextAttachment natural spacing, with possible manual adjustment if needed | Standard NSTextAttachment behavior provides baseline spacing; fine-tuning is an implementation detail |
| "Tasteful" fallback (subjective) | Monospace font + theme secondary foreground color + no error iconography | Requirements input: "styled raw LaTeX in monospace (not an error, just honest)" |
| Math in headings/lists/blockquotes | Supported via inline detection in all inline contexts | Implementation plan specifies `convertInline` handles all inline contexts; fixture includes math in headings, lists, blockquotes |
| Maximum expressions per document | 50 as a performance target (not a hard limit) | Conservative estimate based on typical LLM output document length |
| SwiftMath version constraint | >= 3.3.0 | Implementation plan specifies this version |
| Block math `$$` detection scope | Only standalone paragraphs (entire paragraph is `$$...$$`) | Implementation plan: check in `convertParagraph` before inline path, requires the trimmed text to start and end with `$$` |
