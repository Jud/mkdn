# Comment anchoring v2 — deferred follow-ups

Running list of items intentionally punted during the v2 build, with the reason
and the unit/era where each should land. Add to this as more units defer work;
clear items as they ship.

## From the parse/resolve units

- **Sidecar separator whitespace (writer idempotency).** `CommentDocument.parse`
  strips only the sidecar block's marker range (`<!--mkdn-comments … -->`), so the
  `\n\n` the writer inserts before it stays in `body`. Harmless for rendering and
  consistent for parsed-body comparison, but the **authoring/comment-only-update
  unit** must manage that separator idempotently — append/rewrite the sidecar
  without growing trailing blank lines across save cycles, and base the
  "stripped body unchanged?" rebuild-skip on the *parsed* body, not raw text.

## From unit 1 (AnchorTape)

- **Monospaced non-code runs are normalized as prose.** The inline-math /
  math-block **LaTeX render-failure fallback** and **raw HTML blocks** carry no
  code tag, so the tape case-folds and whitespace-collapses them (`\Delta` →
  `\delta`). They are case/whitespace-significant. *Decide when a tape consumer
  lands:* tag them verbatim (a builder-level `isVerbatim`/`preservesText` signal,
  set in `MathInline.swift` + the two `Blocks.swift` fallback paths) or accept
  prose-folding for these rare render-failure paths. No resolver consumes the tape
  yet, so there is no live bug today.

- **Tight highlight edges (tape→builder map is contiguous).** A resolved span's
  endpoints absorb collapsed whitespace and excluded attachment runs that trail
  the last matched unit, so a highlight can extend slightly past the matched text
  at a boundary. *Resolver-era fix:* switch the offset map from one
  offset-per-normalized-unit to a per-unit `(start, end)` builder extent. Cosmetic
  until an overlay consumer exists.

- **Global trim is a quote-normalization step, not a tape step.** The shared
  normalizer must trim leading/trailing whitespace off the extracted
  quote/prefix/suffix at write and resolve time. The global tape deliberately does
  not trim (that would misalign block-boundary offsets). *Land this in the shared
  normalizer used by the authoring + resolver units.*

- **Invariant lock (optional).** Inline-code verbatim-ness now depends on a single
  tag site (`MarkdownTextStorageBuilder.convertInlineContent`). If a future path
  produces inline code without routing through it, the tape silently normalizes it
  as prose. Consider a builder-level test asserting every inline-code run carries
  `CodeBlockAttributes.inlineCode`.
