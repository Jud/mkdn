**Status:** v3 — BUILT (Units 1–5a, 789 tests green on feature/markdown-comments).

> **IMPLEMENTATION NOTE (supersedes the anchor syntax below):** the anchors are NOT
> HTML comments. They are self-closing semantic custom elements —
> **`<mkdn-comment id="ID" edge="start"/>`** and **`edge="end"`** — because an HTML
> comment at the start of a line becomes an HTML *block* in CommonMark/GitHub and hides
> that line's text, so a line's first word couldn't be commented. The empty custom
> element parses as inline HTML everywhere (verified vs swift-markdown), renders
> invisibly, and is greppable via `mkdn-comment`. The **sidecar block stays an HTML
> comment** (`<!--mkdn-comments … -->`) since it must hide its JSON payload and, as an
> EOF block, isn't affected by the line-start issue. Everything else below (sidecar,
> TextQuote resilience, AST renders-unchanged verify, multi-ID overlap, innermost click)
> is implemented as described. Re-anchoring is conservative (unique exact match, no
> fuzzy). Deferred: save-time sidecar GC/sync, in-code-block anchor protection.

# Comment Format — Paired ID Anchors + Sidecar (invisible, resilient)

## Why (recap)

v1 single-wrap CriticMarkup `{==h==}{>>c<<}` can't comment links/code/math/styled spans
and can't nest/overlap. Goal: comment ANY rendered range, nest/overlap, persist in-file,
agent-readable, and survive round-trips — including **edits made outside mkdn** (a git
merge, another editor, or an agent rewriting prose to address the comments).

## The format

**Invisible paired HTML-comment anchors** bracket the range; **bodies + resilience data
live in one sidecar block** keyed by a generated ID.

- **Open anchor:** `<!--mkc s=k7-->`  **Close anchor:** `<!--mkc e=k7-->`
- **Example:** `The <!--mkc s=k7-->quick brown fox<!--mkc e=k7--> jumps.`
- **Nesting/overlap** by ID matching:
  `<!--mkc s=a-->foo <!--mkc s=b-->bar<!--mkc e=b--> baz<!--mkc e=a-->`.
- **Sidecar block** (end of file):
  ```
  <!--mkdn-comments
  k7:
    body: needs a citation
    quote: "quick brown fox"
    prefix: "The "
    suffix: " jumps."
  -->
  ```

HTML comments are **invisible in every markdown renderer** (GitHub, Obsidian, …), so they
survive round-trips; mkdn strips the anchors before swift-markdown parses (its existing
preprocessor path), so the text between renders as ordinary markdown. Agents read comments
by grepping `mkdn-comments` / `mkc`.

## Why this dissolves the v1 problems

- **Comment anything:** invisible anchors don't constrain wrapped content (links, code,
  math, emphasis, mid-word all work).
- **Nesting/overlap:** representable via ID matching.
- **No terminator collisions:** anchors carry only the ID; bodies live in the sidecar
  (arbitrary text, multi-line, future replies/authors/timestamps).

## Resilience (the headline pressure-test finding)

Each comment stores a **TextQuote** (exact `quote` + short `prefix`/`suffix` context) in the
sidecar. On load: if the anchor pair is intact, use it (and refresh quote/prefix/suffix from
it on write). If a marker was orphaned/half-deleted by an external edit, re-anchor
**conservatively** — exact-match `prefix+quote+suffix` in the rendered/plain text, require a
**unique** match (use last-known offset only as a tie-breaker); otherwise mark the comment
**orphaned (needs review)**. **No fuzzy "nearest-prose" matching in v1** — orphan rather than
risk highlighting the wrong text. (W3C Web Annotation / Hypothesis pattern, conservative tier.)

## Hardening (adopted from the critique, no further decision)

- **Anchor placement rules — HTML comments are invisible but NOT parse-neutral everywhere.**
  Forbid (or snap the selection off) these insertion positions, since the marker would change
  CommonMark parsing or render visibly: at the **first non-space of a line** (becomes an HTML
  *block*); inside/splitting an **emphasis/strong delimiter run** or immediately adjacent to
  `*`/`_` runs; inside **code spans/blocks**, **autolinks**, **link destinations/titles**,
  **image syntax**, **reference-definition lines**, **ATX/setext heading syntax**,
  **list markers / task checkboxes**, **table delimiter rows / pipes**, and **hard-break
  tokens**. Link *text* and table *cell text* are allowed **only when verified** (collapsed/
  shortcut reference links and no-leading-pipe first cells are start-of-line traps).
- **AST-level "renders unchanged" verify** on authoring: parse `raw` and `candidate` with the
  `mkc` comments IGNORED and compare the swift-markdown Document (node types + rendered text),
  not stripped strings — a string compare false-passes when stripping normalizes away an
  introduced parse change. This is the real safety net; reject any insertion that fails it.
- **Per-marker protection:** each anchor position is gated against protected ranges (code,
  autolinks, ref-defs) so a marker can't land inside non-rendered syntax. (Anchors are points
  → per-marker, not a span overlap like v1.)
- **Overlap = true multi-ID metadata:** the render attribute must hold a **list** of comment
  ids (ranges can overlap), and the parser must accept **crossing pairs matched by ID** (not
  stack-only nesting). Click in an overlap → innermost (smallest-enclosing) comment.
- **Orphan/duplicate/gravity rules:** an active comment requires exactly one start anchor, one
  end anchor, AND one sidecar entry; anything else is invalid. Duplicate IDs rejected.
  Boundary gravity: insertion at an anchor boundary falls OUTSIDE the comment.

## Sidecar encoding & lifecycle

- The sidecar is an HTML comment, so bodies/quotes **cannot contain `-->`** — encode as
  **versioned JSON** with `-->` made impossible (escape/encode). Version the schema.
- **Sync/GC** (on canonical save): refresh each intact comment's quote/prefix/suffix from its
  anchors; sort active entries by current source order, orphans last. **Sidecar-only** (no
  anchors) → attempt re-anchor, else keep as orphan. **Anchor-only** (no sidecar entry) →
  GC the stray anchors (or surface a missing-body diagnostic).

## Open decisions (resolved leans)

1. Markers: **HTML comments** (invisible everywhere) — chosen over custom `{>> >>}` tags.
2. Bodies: **sidecar block keyed by ID** — chosen over inline-in-tag.
3. Overlap click: open the **innermost** (smallest-enclosing) comment; chooser later if needed.

## Known exceptions (acceptable)

- Anchors can't sit *inside* a fenced code block or code span (literal there) — wrap around
  code, not inside it.
- Partial selection inside a rendered math/image attachment.
- mkdn renders *block-level* HTML visibly (its HTMLBlock path) — anchors must stay inline;
  cross-block selections need care.

## Reuse from what's built

Pipeline shape carries over (preprocess→strip→render→map→highlight; click→popover;
author→insert; SourceMap/resolver/DocumentState scaffolding). What changes: the delimiter
parsing (HTML-comment paired anchors + sidecar), the resilience layer (TextQuote), and the
hardening above. Replaces the v1 single-wrap `{==..==}{>>..<<}` preprocessor/authoring.

## Hardening contract (verified by the adversarial suites)

The adversarial-hardening pass (`adversarial-hardening-plan.md`) pins these as
tested invariants. See `mkdnTests/Unit/Core/Adversarial*.swift`.

- **Reserved markers.** A well-formed `<mkdn-comment id="…" edge="…"/>` token is
  reserved metadata and is stripped wherever it appears (prose or code) — do not
  type it literally as content. Malformed marker-like text is left verbatim.
- **Trailing-only sidecar (B3).** `<!--mkdn-comments…-->` is recognized as the
  sidecar only when it is the document's trailing block (nothing but whitespace
  after its close). A mid-document or fenced example of the block is ordinary
  content and is never stripped. `preprocess` is idempotent on its own output.
- **Bounded id generation (B1).** `uniqueID` never spins on a colliding
  generator; it bounds attempts and falls back to an anchor-safe unique id.
- **Non-corruption (B4/I4).** `wrapComment` verifies every pre-existing active
  comment survives a new wrap (id, body, highlighted text) and rejects any
  placement that would disturb one. Nested/crossing comments are allowed.
- **Overflow-safe mapping (B2/I5).** `CommentRangeResolver` rejects hostile or
  degenerate `NSRange`s (negative location, zero length, `Int.max`) without
  trapping; a resolved range's raw text always equals the selected rendered text
  (atomic tokens snap whole). Cross-paragraph / unmappable selections → nil.
- **Sidecar codec (I7).** Bodies/quotes round-trip arbitrarily (`-->`, `--`, the
  marker itself, newlines, quotes, backslashes, emoji, NUL); malformed sidecars
  decode to nil and are left intact; a future schema `v` still decodes leniently.

### Accepted limitations (documented, asserted current behavior)

- **Overlap re-click toggle.** After adding a comment whose span overlaps an
  existing one, re-clicking that span opens the stacked popover rather than
  toggling the box closed (showing the overlap is acceptable; a precise fix needs
  the post-rebuild overlap set).
- **Inline code is whole-token.** Commenting inline code wraps the entire
  `` `token` `` (anchors can't live inside verbatim code without breaking
  portability); sub-range highlighting of code is not supported.
- **Sidecar relocation.** Since the sidecar is trailing-only, an external tool
  that relocates it mid-document detaches its comments (they orphan) until it is
  moved back. Render-only; `preprocess` never mutates the file.
