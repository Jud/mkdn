# Height Estimation Engine — Plan

A centralized, accurate, unit-testable model of the markdown preview's
laid-out height — computed **without** running the renderer's full-document
TextKit 2 layout. It sizes the scroll view's vertical extent up front (so the
scroller thumb is right and scrolling never drifts or snaps), and gives us one
place to validate height logic against real layout.

Motivated by the comment-sidebar viewport-resize work (`docs/features/markdown-comments/`),
where the container narrows on open and the text must reflow into a correctly
sized scroller. But the engine is a core rendering concern, reusable for
scroll-to-anchor, the scrollbar, and a future minimap.

## Why today's estimate drifts

Today's estimate lives in `CodeBlockBackgroundTextView.swift`
(`estimatedDocumentHeight(forContainerWidth:)` ~237, `refreshEstimatedHeight()`
~224). It walks the flattened `NSAttributedString` line-by-line with cheap
arithmetic. Four flaws, worst first:

1. **Attachments count as ~1 character.** Tables, images, Mermaid diagrams,
   math blocks, and thematic breaks are massively under-counted — yet their
   real pixel height already sits in `attachment.bounds.height`, set at build
   time, entirely unused. This is the dominant source of drift on rich docs.
2. **`paragraphSpacingBefore` ignored** — e.g. every heading's 24pt top margin
   is dropped.
3. **Within-paragraph `lineSpacing` (2pt/line) ignored** — accumulates over
   long wrapped paragraphs.
4. **"width-of-n" wrapping** is crude for proportional fonts; per-paragraph
   line-count error accumulates over the document.

The fix is not a better heuristic on the lossy flattened string — it's a real
model fed from where the structure actually exists.

## Design

### The model is built where the structure lives

Only the flattened `NSAttributedString` survives to estimate time (the
swift-markdown `Document` is discarded after build, `MarkdownRenderer.swift`
~36-50). But `MarkdownTextStorageBuilder` has full per-block structure as it
builds. So the builder emits a sidecar alongside `attachments` and
`headingOffsets` on `TextStorageResult` (`MarkdownTextStorageBuilder.swift:16`):

```swift
struct DocumentHeightModel {
    let blocks: [BlockHeightDescriptor]
}

struct BlockHeightDescriptor {
    let blockIndex: Int
    let kind: BlockKind
    let attributedRange: NSRange            // range in the FINAL attributed string
    let attachment: AttachmentHeightDescriptor?
}

enum AttachmentHeightDescriptor {
    case table(TableAttachmentData, attachment: NSTextAttachment)
    case image(attachment: NSTextAttachment)
    case mermaid(attachment: NSTextAttachment)
    case mathBlock(attachment: NSTextAttachment)
    case thematicBreak(attachment: NSTextAttachment)
}
```

**Key insight (don't duplicate state):** the descriptor stores only the block's
`kind` and its **range in the final, immutable `NSAttributedString`** — not a
copy of fonts/paragraph styles. Heights are measured *from that string*, so
everything the builder already encoded (heading fonts, indents, `lineSpacing`,
`paragraphSpacingBefore`, and the first-block spacing collapse at
`MarkdownTextStorageBuilder.swift:146`) is reflected automatically and can never
drift out of sync with what actually renders. `kind` is kept for the decisions
the flattened string *can't* express (which blocks are attachments, inter-block
spacing rules, width-invariance).

### The estimator

`DocumentHeightEstimator` (new, `mkdn/Core/Markdown/`) computes
`height(forContainerWidth:)` = Σ per-block heights, over shared primitives so
every height in the app flows through one implementation:

- `lineHeight(font)` → the canonical `ceil(ascender − descender + leading)`
  used everywhere today.
- `measureAttributedParagraph(range, width)` → the accuracy lever, below.
- `measureBlockAttachment(descriptor, width)` → reads `attachment.bounds.height`
  (post-settle) or the overlay metrics snapshot (mid-resize); applies the
  width-scaling rule per kind.
- `measureTableHeight(...)` → unify onto the same `boundingRect` cell
  measurement already used for print (`+TablePrint.swift:185`), retiring the
  rough `wrappingOverhead` path (`TableColumnSizer.swift:184`).

### The accuracy lever: per-paragraph `boundingRect`

Wrapping height is the bottleneck. Three options, ranked:

- (a) `charCount / avg-char-width` — today. Cheapest, least accurate.
- (b) Σ real glyph advances / width — real glyph widths, but ignores
  word-break points, so it's a lower bound.
- (c) `NSAttributedString.boundingRect(with: CGSize(width, .greatestFiniteMagnitude),
  options: [.usesLineFragmentOrigin, .usesFontLeading])` — **real Core Text
  line breaking**, per paragraph.

**Recommendation: (c).** It is *not* the full-document TextKit 2 layout that the
perf constraint forbids — it does Core Text measurement, not
`NSTextLayoutFragment` realization or viewport layout, and allocates no fragment
tree. The repo already relies on exactly this for print table cells
(`+TablePrint.swift:185`).

**The honest tradeoff (the one decision to bless):** (c) is O(document text) —
it runs Core Text line-breaking over every paragraph **once per settled width**
(never per frame). That's the same call frequency as today's settle-time walk,
just a more expensive-but-accurate measure per paragraph. For typical docs this
is sub-millisecond to low-ms; the perf escape hatch for pathological docs is
Phase 4 (analytical first pass as an interim floor, accurate pass after settle).
Given the goal is *accurate* estimates, (c) is the right tool; (b) stays in the
back pocket as a coarse fast path only if profiling demands it.

### Over-estimate, never under

Round and bias **upward**. A slight over-estimate leaves the scroller a hair
long (harmless — you can scroll a touch past the end). An under-estimate means
content exceeds the scroller, which reintroduces exactly the thumb drift and
snap this engine exists to eliminate.

## Measurement subtleties to pin against the oracle

These are not guesses to encode — the oracle test (real TextKit 2 layout) tells
us the exact rule, and the tolerance/over-estimate bias absorbs any residual:

- **`boundingRect` width must match TextKit's usable width** — subtract the
  `textContainerInset` *and* the container's `lineFragmentPadding` (default 5pt
  per side), plus any `headIndent`/`tailIndent`, or wrapping won't match.
- **Inter-block spacing** — TextKit applies the previous block's
  `paragraphSpacing` and the next block's `paragraphSpacingBefore` at the
  boundary. Measuring a block range in isolation may not capture the leading
  spacing-before; the engine adds inter-block spacing explicitly from the
  paragraph styles, validated against the oracle.
- **Oracle is TextKit 2, not TextKit 1.** `boundingRect` is the Core Text /
  NSStringDrawing path; the renderer is TextKit 2 (`NSTextLayoutManager`). They
  agree almost always but can differ by a line in edge cases — so the test
  oracle must be the real TextKit 2 layout, and the tolerance must cover the
  residual divergence.

## Test contract

This is the "centralized to test against" payoff.

- **Oracle:** real TextKit 2 layout — `ensureLayout(for: documentRange)` then
  `usageBoundsForTextContainer` for the total; per-block via the
  `boundingRect(forCharacterRange:)` helper (`NSTextView+CommentHitTest.swift`
  ~63-100).
- **Corpus:** `fixtures/{elements,codeblocks,table,image,math,mermaid,diagrams,
  resize,showcase}.md`.
- **Widths:** 320, 480, 600, 800, 1200, plus sidebar-open widths (subtract the
  300pt rail, `CommentSidebarView.swift:39`).
- **Assertions:** per-block and total height within tolerance of the oracle.
  Tolerance is relative (≈1–2%) with a small absolute floor; estimate must be
  ≥ oracle (over-estimate bias) wherever the bias rule applies.

## Phases

Each phase is independently shippable and testable.

**Phase 1 — Engine + tests behind the current call sites.**
Builder emits `DocumentHeightModel` (block ranges + kinds + attachment refs).
Add `DocumentHeightEstimator` using per-paragraph `boundingRect` and current
`attachment.bounds`. `refreshEstimatedHeight()` still owns the frame floor
(`CodeBlockBackgroundTextView.swift:224`) but delegates to the estimator when a
model is present. Land the fixture × width oracle tests.
→ *Verify:* immediate, measurable accuracy gain (spacing, line spacing,
proportional wrapping, and block attachments all fixed); tests green; no resize
regression.

**Phase 2 — Async attachment heights + table reactivity.**
Expose an `OverlayAttachmentMetrics` snapshot from `OverlayCoordinator`
including `deferredAttachmentHeights` (`OverlayCoordinator.swift:241`). On
`updateAttachmentHeight`/`updateAttachmentSize`, invalidate that one block and
debounce a settled `refreshEstimatedHeight()`. Fix the table-overlay width
reactivity gap — `TableAttachmentView` captures a static `containerWidth`
(`OverlayCoordinator+Factories.swift:88`) unlike image/Mermaid, which use
`OverlayContainerState`.
→ *Verify:* scroller stays correct as images/Mermaid resolve and on resize over
attachment-heavy docs.

**Phase 3 — Prefix sums + per-block offsets.**
Cache per-block cumulative offsets; expose `offset(forBlockIndex:)` and
`block(atEstimatedY:)`.
→ *Verify:* unlocks accurate scroll-to-anchor, scrollbar, minimap, faster
heading estimates — each with its own test.

**Phase 4 — Performance gates.**
Only if profiling shows `boundingRect` too slow on huge docs: a coarse
analytical first pass (option b) as an interim floor, replaced by the accurate
pass after width settles.
→ *Verify:* large-doc settle time under budget; no visible thumb pop.

## Adjacent findings to fold in

- **Reuse:** unify table height onto the print-cell `boundingRect` measurement;
  retire `TableColumnSizer`'s rough `wrappingOverhead` path
  (`TableColumnSizer.swift:184`).
- **Bug (Phase 2):** tables don't reflow reactively on width change like
  images/Mermaid (`OverlayCoordinator+Factories.swift:88`).

## Open questions / risks

- `boundingRect` vs TextKit 2 divergence magnitude across the corpus — quantify
  in Phase 1; if any block is consistently off, encode a per-kind correction.
- Settle-time cost on the largest realistic doc — measure in Phase 1; Phase 4 is
  the fallback if needed.
- Integration preserves the shipped resize lifecycle (clear floor at
  sidebar/live-resize start, recompute at settle, re-pin the anchor before/after
  refresh — `CodeBlockBackgroundTextView+SidebarResize.swift:120`,
  `SelectableTextView.swift:425`); the engine swaps in at
  `refreshEstimatedHeight()` only.
```
