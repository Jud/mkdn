# Comment Anchoring — sidecar-only, overlay highlights, content anchoring

**Status:** In progress (clean break — see below). Pure cores landed.

## Clean break (decided 2026-06-04 — supersedes the v1/migration framing below)

The feature is greenfield (nobody depends on it), so we drop the "v1 vs v2"
distinction and the migration path entirely. There is just **comments**: sidecar
storage + content-anchored resolve + drawn-overlay highlights. No inline
`<mkdn-comment>` markers, no `reanchorRange`, no `CommentRangeResolver`, no
`CriticMarkupDocument`/segments, no migration. Stray inline markers from older
docs are still stripped on load so they never render as literal text, but their
comments are **not** auto-converted — they simply orphan (surfaced + deletable),
since v1 sidecar quotes were captured from source, not the normalized tape.

**Landed (pure cores, reviewed):** `AnchorTape` (normalized tape + builder↔normalized
maps), `CommentAnchorResolver` (deterministic resolve + `Index` + hit-test query),
`CommentSelector`/`CommentSelectorCapture` (selection → selector), shared
`CommentSidecar.contextLength`.

**Remaining units (build-new → swap → delete-old, keep green each commit):**
1. ~~Index hit-test query~~ (done).
2. **Overlay draw** — draw highlights from the resolved `Index` in the text view's
   background pass (the `CodeBlockBackgroundTextView.drawBackground` pattern), and
   stop baking `.backgroundColor`/`.mkdnCommentID`. **Layout-passive; needs visual
   verification in both themes.**
3. **Hit-test / popover** read `Index.comments(containing:)` instead of the
   `.mkdnCommentID` attribute.
4. **Authoring** — `addComment` captures a selector → sidecar upsert (no markers);
   menu gate uses `AnchorTape.normalizedRange`.
5. **Comment-only update path** — sidecar change → re-resolve + redraw, no rebuild /
   no `setAttributedString` (this is what removes the jump).
6. **Delete v1** subsystem (inline markers, `CriticMarkupDocument`, `reanchorRange`,
   `CommentRangeResolver`, baked-attribute highlighting, dual mutation) + their tests.
7. **Orphan sidebar UI** — list orphaned comments (quote + body), allow delete.

The research, format, semantics, and rendering sections below remain valid; ignore
their "v1/v2" labels (there is now one format).

---

**Original design (proposed) — codex-reviewed GREEN**

## Why

The current comment format (`comment-format.md`) wraps each commented span in
invisible inline `<mkdn-comment …/>` anchor markers *inside the document text*,
plus a sidecar at EOF. Editing the document to add/edit/delete a comment mutates
the rendered text, which forces a full `setAttributedString` rebuild. That rebuild
re-lays-out attachments and shifts content under a fixed scroll offset — the
**comment-save "jump"** we reproduced (docH swings ~1138pt mid-rebuild). Inline
markers also **can't live inside a code fence** (they'd render as literal text and
fail the render-neutrality check), so code blocks can't be commented.

This redesign removes inline markers entirely. Comments live **only** in the EOF
sidecar and anchor to their text by **content**; highlights render as a pure
**overlay** that never touches the text storage. Consequences:

- **The jump bug disappears at the root** — commenting no longer rebuilds the
  document; a highlight is just an overlay repaint.
- **Comment code** — fenced/inline code becomes commentable because we never insert
  markers into that content. (Tables/math/images are deferred — see Phasing.)
- **Cleaner round-trip** — one HTML comment at EOF, zero invisible elements in the
  prose; renders clean on GitHub/Obsidian.

## Research basis (cited)

Robust marker-free anchoring is a solved, cross-industry pattern; our riff matches
it. (Primary sources below.)

- **W3C Web Annotation Data Model** — store a `TextQuoteSelector` (normalized exact
  quote + `prefix`/`suffix` context) as the robust primary, and a
  `TextPositionSelector` (char offsets) as a **brittle hint only** ("very brittle
  with regards to changes to the resource"). Storing **multiple selectors as
  alternatives** is explicitly sanctioned. When context still matches multiple
  sequences, the practical tiebreaker is the position hint.
  <https://www.w3.org/TR/annotation-model/>, <https://www.w3.org/TR/selectors-states/>
- **Hypothes.is** (canonical production impl) — three selectors (Range/XPath,
  TextPosition, TextQuote w/ 32-char prefix/suffix), re-anchored on load with an
  ordered cascade: exact/range fast-path → position → context-first fuzzy →
  exact-quote fuzzy. Fuzzy via diff-match-patch (Bitap); the position offset is a
  **search hint biasing toward the nearest match** (also disambiguates duplicates).
  The Range/XPath selector is DOM-specific — **we drop it**.
  <https://web.hypothes.is/blog/fuzzy-anchoring/>, <https://github.com/tilgovi/dom-anchor-text-quote>
- **Browser Text Fragments** (`#:~:text=[prefix-,]start[,end][,-suffix]`) —
  independently re-derive the same exact-quote + prefix/suffix + disambiguation
  model, but **deterministic** (normalized/boundary-aware, first match), not fuzzy.
  The two-end `start,end` range form anchors a long span without storing the whole
  quote. <https://wicg.github.io/scroll-to-text-fragment/>
- **Lessons:** pure quote anchoring orphans a real fraction as docs drift (~22% in a
  2015 Hypothes.is web corpus — far lower for a local file we own, but real), and
  diff-match-patch is **catastrophically slow on the no-match/orphan path**. Orphan
  handling and the no-match path are first-class. No one uses a hash-tree index —
  selectors are the verified answer.
  <https://arxiv.org/pdf/1512.06195>, <https://github.com/robertknight/anchor-quote>

## Stored format

Sidecar stays an HTML comment at EOF (hidden, greppable, JSON escapes `>`/`-`).
Per comment we store **selectors** instead of inline anchor pairs:

```
<!--mkdn-comments
{"v":2,"comments":[{
  "id":"k7",
  "body":"needs a citation",
  "quote":"quick brown fox",          // normalized exact text (primary anchor)
  "prefix":"The ",                      // ~32 chars normalized context (disambiguation)
  "suffix":" jumps.",                   // ~32 chars normalized context (disambiguation)
  "start":12,"end":27,                  // TextPositionSelector — HINT only (offsets into the normalized tape)
  "norm":1                              // normalization version (write/read must match)
}]}
-->
```

- `v:2` distinguishes from the v1 inline-anchor format (migration below).
- No inline `<mkdn-comment>` markers anywhere in the body.
- `start`/`end` are offsets into the **normalized rendered tape** (next section),
  used only as a hint/tiebreaker.

## What we anchor against (the key decision)

**Anchor against normalized rendered/plain text, not raw Markdown source.** This is
what the user selects, what W3C's normalization mandate points to ("remove tags,
decode entities"), and what makes code-block comments fall out naturally (anchor to
on-screen text + overlay the highlight; markup inside the span is irrelevant to the
match).

**Normalization is content-aware** (codex must-fix — global collapse/case-fold is
wrong for code):
- **Prose:** collapse whitespace runs to a single space, trim, case-fold. An agent
  **reflowing/rewrapping** a paragraph (same words, new line breaks) does **not**
  orphan; a real word change does.
- **Code (fenced/inline):** preserve whitespace and case verbatim — code is
  whitespace- and case-significant. Detected via `CodeBlockAttributes.range`
  (fenced) / `CodeBlockAttributes.inlineCode` (inline) — explicit builder tags,
  not a monospaced-font heuristic.
- **Deferred (open):** monospaced *non-code* runs — the inline-math/math-block
  **LaTeX-fallback** (render-failure path) and **raw HTML blocks** — are currently
  normalized as prose, so their case/whitespace folds (`\Delta` → `\delta`). These
  are case-significant too. When a tape consumer lands, decide whether to tag them
  verbatim; today they carry no code tag and there is no resolver yet.

**Trim is a quote-normalization step, not a tape step.** The shared normalizer
trims leading/trailing whitespace off the *extracted quote/prefix/suffix* at
write and resolve time; the global tape only collapses + case-folds (trimming the
whole tape would misalign block-boundary offsets). **Open (resolver-era):** the
tape→builder map is contiguous, so a resolved span's endpoints absorb collapsed
whitespace and excluded attachments that trail the last matched unit. If a
consumer needs tight highlight edges, switch the map from one offset-per-unit to a
per-unit (start, end) extent; not needed until a tape consumer lands.

We do **not** reuse `SourceMap` directly — it's source-centric and skips synthetic
text/attachments/math. v1 builds a new **rendered "anchor tape"**: a normalized
rendered-text string + an index mapping normalized offsets → builder `NSRange`s (so
a resolved quote → on-screen rects). Attachments/math are not on the prose tape
(deferred).

> **Prototype before locking:** exactly how emphasis/links/inline-code inside a span
> normalize on the tape. The write-time and read-time normalizer MUST be one shared
> function (divergence is the current pipeline's #1 anchoring bug class).

## Anchoring semantics (the behavior contract)

- **Edit above/below → comment survives.** Located by content, not position; offset
  is only a hint. Inserting/deleting/reflowing elsewhere never orphans.
- **Edit the commented span → comment orphans** (v1, deterministic). A comment is
  *about* specific text; if that text changed, drop it rather than mis-place it.
  (v2 fuzzy can re-attach through small edits — deferred.)
- **Duplicate quote → disambiguate** by `prefix`/`suffix` context, then by nearest
  `start` hint. Context is **soft** (disambiguation only), never a hard match
  requirement — so editing surrounding text can't orphan.
- **Orphans are surfaced, never silent.** A comment whose quote can't be located is
  shown in the sidebar as *orphaned* with its stored quote + body, to re-place or
  delete. Never silently dropped, never mis-placed.

## Why code blocks can't be commented today (and how v2 fixes it)

Code-block text is built with font + syntax colors but **no `mkdnSourceSpan`** —
only prose runs get a source span (via the visitor's `linearSpan`/`atomicSpan`).
So `commentableSelectionRange()` → `SourceMap.sourceUTF16Range` finds no mapping
for a code selection and the gate rejects it; the "Add Comment…" item never
appears. v2 removes this dependency: comments anchor against the normalized
rendered **anchor tape**, which includes *all* visible text (code kept verbatim),
so code spans are anchorable without per-run source spans — and the highlight is
drawn, so there's no inline marker to break a fence.

## Rendering

Highlights move from a built-in `.backgroundColor`/`.mkdnCommentID` attribute (baked
into the attributed string at build time) to a **resolved-range index** + a
**background-pass draw** in the text view (the way `CodeBlockBackgroundTextView`
already draws code-block backgrounds in `drawBackground(in:)`). Drawn **under** the
text — not a topmost view tinting over glyphs — so selection and glyphs read right.

- The resolved-range index (comment id → builder `NSRange`s) is the single source
  for: highlight drawing, **hit-testing** (replacing the `.mkdnCommentID` read in
  `commentInfo(at:)`), and the **overlap badge** sweep.
- Add/edit/delete updates the sidecar and **repaints from the index** — no
  `setAttributedString`, no attachment re-layout, no rebuild, no jump.

**Comment-only update path (codex must-fix).** A sidecar change still mutates
`markdownContent`, which today triggers a full re-render in `MarkdownPreviewView`.
v1 must detect "only the sidecar changed — stripped/rendered body identical" and
take a comment-only path: re-resolve selectors + repaint the overlay, **skipping
`renderAndBuild`/`setAttributedString` entirely.**

Overlap/nesting falls out of resolved ranges (paint all; click a point → stacked
popover, smallest span first — unchanged UX; verified against current crossing-pair
stacking).

**The draw path MUST be layout-passive (codex — this is the crux that makes the
jump go away rather than relocate):** a plain `needsDisplay` is *display*
invalidation, not *layout* invalidation, so drawing highlights without a storage
edit does not trigger the attachment-height settle. But only if the draw never
forces offscreen layout. So:
- resolve/draw only ranges intersecting the **visible viewport / dirtyRect**;
- never call `ensureLayout` / `boundingRect(forCharacterRange:)` /
  `.ensuresLayout` enumeration over off-screen comment ranges during a repaint;
- do **not** invalidate the code-block rect cache on a comment-only change —
  `refreshCachedBlockRects()` force-lays-out from the document start through the
  last code block.
- pre-build de-risk: at the bottom of a long doc, `setNeedsDisplay(visibleRect)`
  repeatedly with no storage edit and confirm `docH` stays put.

**Move find-match highlights and the footnote pulse to drawing too.** Both are the
same trigger class today (live `.backgroundColor` edits on a redraw). For the
invariant "a visual highlight change never moves layout," they should also become
draws off an index rather than storage attributes. (Folds the v1 find/rebuild
fallback + pulse-cancel carve-outs away entirely.)

## Phasing

**v1 — core (this work-loop). Scope = ordinary rendered *text* runs: prose AND
fenced/inline code. Tables, math, images, thematic breaks are DEFERRED** (they're
SwiftUI attachment overlays, not text ranges — they need per-attachment anchoring).
- Sidecar `v:2` model (quote + prefix/suffix + position hint + norm version +
  resolved/orphan state); drop inline markers.
- Normalized rendered **anchor tape** (content-aware); shared write/read normalizer.
- **Deterministic** resolve: locate normalized quote; 1 → anchor; 0 → orphan; >1 →
  disambiguate by context then nearest hint; hard orphan on tie/no-match.
- Highlight via resolved-range index + background-pass draw; hit-test + overlap
  badges read the index.
- **Comment-only update path** (no rebuild on sidecar change).
- Authoring: selection `NSRange` → rendered selector → sidecar upsert (no raw-source
  wrapping); commentable now includes code spans.
- Orphan rows in the sidebar (visible + deletable — required for deterministic v1 to
  be shippable).
- Migration: resolve intact v1 pairs, recapture rendered selectors, strip markers on
  next save, **carry unrecoverable v1 entries forward as explicit orphans**.

**v2 — robust/fuzzy (later):**
- Fuzzy re-anchoring (context-first → exact-quote), **error budget proportional to
  quote length** (~10–20% edit distance), so a small edit to the span re-attaches
  instead of orphaning. **Bound the no-match path** (the perf trap).
- Two-end range anchors for long spans.
- Per-attachment anchoring → comments on tables/math/images.

**v3 — live + beyond (later):**
- In-app (side-by-side editor) edit tracking: follow the comment through edits to
  the highlighted text and rewrite the stored quote/offset instead of orphaning.

## Migration

On load, if a doc has v1 inline anchors: resolve intact anchor pairs to their
ranges, **recapture v2 rendered selectors from the built text** (the v1 fallback
matches transformed *source*, not the new rendered tape — so recapture rather than
copy), and on the next save **strip the inline markers** and write the `v:2`
sidecar. Any v1 entry that can't be resolved is **carried forward as an explicit
orphan** (with its stored quote/body) — never dropped. Stripping is idempotent; a v2
doc has no markers to strip.

## Edge cases / open questions

- Rendered-vs-source normalization details (prototype; see above).
- Error budget for **code/tables** specifically (v2) — code is duplicated and
  whitespace-sensitive; stricter budget + heavier hint reliance.
- Whitespace/case normalization exact rules — lock with tests so write- and
  read-time normalizers never diverge.
- Orphan re-attach UX (v1 shows + deletes; manual re-place is v2+).
- Empirical orphan rate + re-anchor latency on representative docs (benchmark once v1
  exists).

## v1 work breakdown (codex-reviewed; work-loop units)

1. **Sidecar v2 model** — `id, body, quote, prefix, suffix, start, end, norm,
   state(resolved|orphan)`; decode/encode + round-trip tests.
2. **Parsing split** — strip sidecar/legacy markers → render body → build the
   rendered anchor tape (+ offset→builder-NSRange index).
3. **Deterministic resolver** — normalized exact quote, context scoring, nearest
   position hint, hard orphan on tie/no-match.
4. **Authoring** — selection `NSRange` → rendered selector → sidecar upsert; drop
   raw-source wrapping + render-neutrality machinery.
5. **Comment-only update path** — mutate sidecar in `markdownContent`, re-resolve +
   repaint, no `setAttributedString` when rendered body unchanged.
6. **Overlay rendering + index** — background-pass highlight rects, hover repaint,
   point hit-test, overlap sweep/badges — all reading the resolved-range index.
7. **Migration** — pair legacy anchors, recapture rendered selectors, preserve
   unresolved as orphans, strip legacy markers only on v2 write.
8. **Orphan sidebar UI** — list orphaned comments (quote + body), allow delete.

Sequencing: 1→2→3 unlock the model; 6 (overlay) can land before 5 (comment-only
path) using the existing rebuild, then 5 removes the rebuild; 7+8 close migration +
UX. Each is a work-loop unit.

## Test plan

- Unit: normalized match — unique anchor; duplicate disambiguated by context;
  duplicate disambiguated by hint; orphan on quote-edit; **survives** edits
  above/below and paragraph reflow.
- Unit: v1→v2 migration produces equivalent resolved ranges; round-trips; preserves
  unresolved as orphans.
- Harness/integration: add a comment on visible prose **and inside a code block**;
  assert overlay highlight lands and **no `setAttributedString`/rebuild occurred**
  (scrollY drift ≤ 1pt, attachment identities unchanged).
- Regression: the comment-save **jump** is gone (frame-capture viewport stable).
