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

## From the v1 deletion

- **Orphaned source-map chain (own removal pass).** `CommentRangeResolver` was the
  only reader of `SourceMap`/`SourceSpanAttribute` (`mkdnSourceSpan`) and the
  visitor's `linearSpan`/`atomicSpan`/`protected` machinery. With it deleted, that
  whole chain is now write-only: `TextStorageResult.sourceMap` is built on every
  render and read by nobody, and the visitor still computes + writes source spans
  for nothing. ~157 lines + per-render cost. Remove it as a focused unit (cascades:
  SourceMap → SourceSpanAttribute → visitor spans → the builder's `.mkdnSourceSpan`
  write → the `AnchorTape` doc-comment contrast with `SourceMap`). Verify no other
  feature (syntax highlighting, headings) reads it first.



- **Adversarial corpus/fuzzing over the new path.** The v1 deletion removed the
  inline-marker adversarial corpus + property/mapping/authoring fuzz suites (they
  exercised CriticMarkup parse invariants over inline-marker documents). The
  surviving `CommentSidecar`/`CommentDocument` robustness is covered by
  `AdversarialSidecarTests` (salvaged: hostile payloads, shadow markers, malformed,
  future schema) + the unit suites. If broader fuzzing is wanted, re-add a corpus
  over `CommentDocument.parse` → `CommentAnchorResolver.resolveAll` (random bodies +
  sidecars, assert no crash / no residue / resolved ranges in bounds).

## From the authoring swap

- **Sidecar escaping is not string-aware.** `CommentSidecar.escape` replaces every
  `>`/`-` in the encoded JSON (to neutralize `-->`/`--`), including a bare numeric
  minus. The writer never emits negatives (start/end are tape offsets ≥0, norm=1;
  the resolver rejects negative hints), so this can't corrupt our output — but a
  hand-edited sidecar with e.g. `"start":-1` would re-encode as invalid JSON
  (`-1` outside a string) on the next write and lose the block. Make escaping
  string-aware (only escape inside string values, or only the `-->` sequence).

## From the draw + consumer swap

- **Feature is non-functional in production until authoring is swapped.** The draw
  resolves sidecar entries through `CommentAnchorResolver`, which orphans entries
  with `norm == nil`. Authoring still writes v1 entries (via `CriticMarkup.wrapComment`,
  no `norm`/normalized quote), so freshly-added and existing comments orphan and
  don't draw. The **authoring swap unit** (capture → sidecar upsert with `norm`)
  makes the feature work end-to-end; the draw is verified for resolved entries.
- **Per-hover badge recompute (optimization).** Hover only changes the highlight
  fill color, but `setHoveredComment` → `setNeedsDisplay` → `viewWillDraw` recomputes
  all overlap clusters each time. Bounded/negligible for typical docs; gate the
  badge refresh behind a "ranges changed" dirty flag if it ever matters.

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
