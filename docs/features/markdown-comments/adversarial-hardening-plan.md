# Markdown Comments — Adversarial Hardening Plan

Goal: a **hardened, verified, releasable** commenting feature. We attack the v3
comment pipeline with adversarial + property tests, fix the real bugs they
surface, and do it **without regressing** the 793 currently-green tests.

> Codex (gpt-5.5, xhigh) pre-reviewed this plan against the source and surfaced
> four real bugs + several scope gaps; they are folded in below (see
> "Known real bugs to fix"). Resolved open questions are recorded inline.

## Surface under test

- `CriticMarkup.preprocess(_:)` — strip anchors + sidecar → `transformedSource`,
  segments, paired `CriticComment`s, re-anchored comments.
- `CriticMarkup.wrapComment / editComment / deleteComment` — authoring.
- `CriticMarkup.anchors / pairComments / reanchorRange / uniqueID` (via behavior).
- `CommentSidecar.encode / decode` — `-->`/`--`-safe JSON codec.
- `SourceMap` + `CommentRangeResolver` — builder↔transformed↔raw mapping.
- `MarkdownTextStorageBuilder.applyCommentHighlights` — highlight ranges.
- `DocumentState.add/edit/deleteComment` — exact-source-guarded mutation.

## Invariants (the spine — every test serves one)

- **I1 No crash / no hang.** Every entry point tolerates arbitrary `String`
  (and, for resolver, arbitrary `NSRange`) input without trapping, overflowing,
  infinite-looping, or `fatalError`. Includes a **bounded** `uniqueID` and an
  overflow-safe resolver.
- **I2 No false stripping, no recognized residue.** `preprocess` strips exactly
  (a) the *recognized trailing* sidecar block and (b) recognized anchor tokens.
  It must **never** strip marker-looking text it did not recognize as metadata
  (e.g. a `<!--mkdn-comments …-->` block inside a fenced code block, or a
  malformed/non-trailing one) — that is user content and must survive verbatim.
  Conversely, anything it *did* recognize leaves no residue in
  `transformedSource`.
- **I3 Render-neutral authoring.** `wrapComment` succeeds only when inserting the
  anchors does not change the CommonMark render structure (portability); a
  success round-trips to the intended comment.
- **I4 Non-corruption (HARD postcondition).** Authoring a new comment (any
  allowed selection, incl. nested/crossing) leaves **every pre-existing active
  comment** unchanged: same id, body, and highlighted text. `wrapComment` must
  *verify* this (compare prior active set ⊆ post active set) and **reject** the
  wrap otherwise — not merely assume it.
- **I5 Mapping soundness.** When `CommentRangeResolver.rawRange` returns non-nil,
  the raw slice's stripped text equals the selected rendered text; atomic spans
  snap to the whole token, never half. Hostile/degenerate `NSRange`
  (negative location, zero length, `Int.max`) returns nil, never traps.
- **I6 Algebra.** `add` then `delete` that id restores the prior active set;
  `add A; add B` ≡ `add B; add A` (active set); `edit` is last-writer-wins;
  `delete` of an absent id is a no-op; `edit` of an absent id fails cleanly.
- **I7 Sidecar codec.** `encode∘decode` round-trips arbitrary bodies/quotes
  (unicode, `-->`, `--`, newlines, quotes, backslashes, emoji); decode of
  malformed / multiple / misplaced / in-fence sidecars degrades gracefully
  (nil or the true trailing block, never crash, never the wrong entries).
  Unsupported `v` is handled deliberately (documented policy).
- **I8 Re-anchoring fidelity.** A unique quote re-anchors correctly; an ambiguous
  or absent quote stays orphaned (no fuzzy mis-anchor); a match spanning stripped
  anchors does NOT recover (conservative single-segment).
- **I9 Active-set definition.** Orphans, half-pairs, duplicate ids, empty spans,
  start-after-end, and crossing pairs resolve to exactly the spec's active set;
  recognized anchors are always stripped regardless.

## Known real bugs to fix (codex pre-review — each gets a failing test first)

- **B1 `uniqueID` can infinite-loop** ([CriticMarkup.swift:613]): if the
  `idGenerator` keeps returning a used id (e.g. fixed `{ "c1" }` when `c1`
  exists) the `while used.contains(id)` loop never terminates. Fix: bound the
  attempts; on exhaustion fall back to a guaranteed-unique id. (Also makes
  `CommentFixture`'s fixed-id helper hang-proof.)
- **B2 `CommentRangeResolver.rawRange` integer overflow** ([CommentRangeResolver.swift:13]):
  `nsRange.location + nsRange.length` overflows before any guard with
  `NSRange(location: .max, length: 1)`. Fix: guard `location >= 0`, `length > 0`,
  and addition overflow up front → nil.
- **B3 Sidecar stripped from non-trailing / in-fence position** ([CommentSidecar.swift:84],
  [CriticMarkup.swift:146]): `decode` takes the last `<!--mkdn-comments` anywhere
  (incl. inside a code fence) and `preprocess` strips that range, deleting
  user-visible content. Fix: recognize the sidecar only as a genuine **trailing**
  block (nothing but whitespace after its `-->`); otherwise treat as ordinary
  content (I2). Pin the policy with tests.
- **B4 I4 not enforced**: `wrapComment` verifies only the new id
  ([CriticMarkup.swift:467]). Fix: add the explicit pre/post active-set
  preservation check and reject on violation.

## Threat model — adversarial input categories

- **A. Malformed anchors:** missing/extra `id`/`edge`; `>`/`<` inside the tag;
  start-without-end and vice-versa; duplicate start ids; start after end; same
  span adjacent (empty); anchors inside inline code / fenced code / HTML blocks;
  anchors at start-of-line / heading / list-marker / table / emphasis
  boundaries; thousands of anchors; literal `<mkdn-comment …>` a user typed.
- **B. Sidecar pathologies:** absent; malformed/truncated JSON; multiple blocks;
  block not at EOF; block inside a code fence; unknown/extra JSON keys; wrong
  `v`; empty `comments`; orphan entries / anchorless ids; duplicate ids; body or
  quote containing `-->`, `--`, `<!--mkdn-comments`, newlines, backslashes,
  quotes, unicode, very long text.
- **C. Unicode / encoding:** emoji & surrogate-pair scalars; combining marks; ZWJ;
  RTL; CRLF vs LF vs CR; NUL; BOM; ids with unicode / spaces / quotes; multi-byte
  text in the commented span and in prefix/suffix.
- **D. Structural & support matrix:** empty / whitespace-only doc; only-anchors;
  only-sidecar; doc that is exactly the sidecar; comment spanning block
  boundaries; comment over the whole document; comment over link / inline-code /
  math / image / autolink / table / HTML / code block. **Define support status:**
  which targets are commentable vs explicitly *unmappable* (resolver returns nil,
  no crash); assert that contract.
- **E. Authoring fuzz:** random document + random sequence of add/edit/delete;
  invariants re-checked after every op.
- **F. Mapping fuzz:** random rendered document; random builder ranges (incl.
  hostile `NSRange`); resolve; assert I5.

## Work-loop units (each a logical commit; tests-first)

> Discipline: run the **full** suite after every change. Pin current behavior
> with a **characterization test first** before altering anything we might
> "harden", so a behavior change is a deliberate, reviewed test diff — this is
> how we avoid silent regressions. Each fix traces to a failing assertion; no
> opportunistic refactors. Use **both** an enumerated hostile corpus (named CI
> cases) **and** seeded-PRNG fuzz; every failing seed becomes a named corpus case.

- **U0 — Harness & determinism.** `AdversarialSupport.swift`: seeded SplitMix64
  PRNG, `randomMarkdown(seed:)`, `randomCommentOps(seed:)`, and assertions
  `assertNoResidue`, `assertActiveSet(equals:)`, `assertRoundTrips`,
  `assertMappingSound`, plus an **enumerated hostile corpus** that already
  includes B1–B3 shapes and cats A/B/C/D. Verify: harness compiles; corpus +
  seed fuzz run (RED where bugs exist — expected — documented as the baseline).

- **U1 — Sidecar codec + stripping policy (I2, I7; B3; cat B).** Round-trip fuzz
  of hostile bodies/quotes; malformed/truncated/multiple/misplaced/in-fence
  sidecars; unknown keys / `v` policy / dup ids. **Fix B3** (trailing-only
  recognition) and define the `v` policy. Verify I2/I7.

- **U2 — Anchor parsing adversarial (I2, I9; cat A).** Malformed/crossing/nested/
  start-after-end/empty-span anchors; anchors in code/HTML; SOL/heading/list/
  table/emphasis placement; literal user-typed anchor text; large-N. Assert the
  active set and no-residue. Fix real bugs.

- **U3 — Authoring safety & non-corruption (I3, I4, I6; B1, B4; cat A/D).**
  **Fix B4** (non-corruption hard postcondition in `wrapComment`) and **B1**
  (bounded `uniqueID`). wrapComment render-neutrality across placements; explicit
  non-corruption test; add/edit/delete algebra + order-independence;
  partial-crossing & whole-doc selections; selection over link/code/math.

- **U4 — Mapping soundness & re-anchoring (I5, I8; B2; cat D/F).** **Fix B2**
  (overflow-safe resolver). SourceMap + resolver fuzz proving I5; atomic-token
  snapping; cross-segment authoring maps to the enclosing span; the support
  matrix (unmappable targets → nil); re-anchoring unique vs ambiguous vs
  cross-anchor (stays orphaned).

- **U5 — Unicode / encoding sweep (cat C).** Re-run U1–U4 invariants with
  emoji/combining/ZWJ/RTL/CRLF/CR/NUL/BOM payloads in commented text, ids, and
  bodies. Fix any String.Index/UTF-16 boundary bug surfaced.

- **U6 — Property / fuzz integration (I1; cat E/F).** Deterministic combined
  fuzz over a fixed seed list: build a random document, apply a random op
  sequence, assert I1/I2/I4/I6/I9 after each op; render and assert I5 on random +
  hostile selections. Catch-all for unknown-unknowns; failing seeds → corpus.

- **U7 — Hardening + release ceremony.** Land any remaining real-bug fixes
  (each test-guarded), confirm 793 + all new tests green, then `/code-review
  --fix` over the whole chunk + codex (gpt-5.5, xhigh). Update
  `comment-format-v2.md` with the support matrix + accepted limitations.

## Risk controls — "don't break everything while hardening"

1. **Regression guard:** the 793 existing tests stay green at every commit; the
   full suite runs after each change.
2. **Characterize before changing:** pin current behavior with a test before
   altering it; behavior changes are explicit, reviewed test diffs.
3. **Surgical fixes only:** each fix traces to a failing invariant; no
   opportunistic refactors in a hardening commit.
4. **No silent contract changes:** public signatures stay stable unless a fix
   demands it, and then it's called out. Document `wrapComment`'s precondition
   that `range` must be a valid `Range<String.Index>` into `raw` (foreign
   indices are UB; `DocumentState` enforces this via exact-source equality).
5. **Accepted limitations are documented, not "fixed" by accident:** e.g. the
   overlap re-click-toggle edge — assert its CURRENT behavior so it can't
   regress, leave it documented.
6. **Triage every red:** each failing adversarial test is classified *real bug*
   (fix) vs *acceptable/by-design* (assert current behavior + note), never just
   deleted.

## Definition of done (releasable)

- Categories A–F covered; every invariant I1–I9 has explicit assertions; B1–B4
  fixed with regression tests.
- Deterministic fuzz (≥ a few hundred seeds) + the enumerated hostile corpus
  green: no crash, no hang, no false stripping, no wrong mapping, no corruption.
- All pre-existing tests still green; new tests green.
- `/code-review` + codex green over the hardening chunk.
- Support matrix + known limitations documented in `comment-format-v2.md`.

## Resolved open questions (from codex pre-review)

- **Q1:** I4 was only incidental → now a HARD postcondition (B4), affordable
  since `wrapComment` already parses.
- **Q2:** Real hang in `uniqueID` (B1); `anchors()`/`reanchorRange()` terminate
  but `reanchorRange` is O(occurrences) on repeated text — add a perf-sanity
  test, no correctness fix needed.
- **Q3:** No direct emoji/surrogate I5 bug found (units stay consistent via
  `String.Index`), but Unicode coverage is thin → U5 adds it.
- **Q4:** Use **both** enumerated corpus (CI clarity, named regressions) and
  seeded PRNG fuzz; persist failing seeds as corpus cases.
- **Q5:** Added — hostile `NSRange` (B2), `v` version policy, code-fence/trailing
  sidecar policy (B3), the support matrix for code/image/table/HTML targets, and
  the `wrapComment` foreign-index precondition note.
