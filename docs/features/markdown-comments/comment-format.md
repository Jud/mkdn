# Comment Format — paired id anchors + sidecar

Comments attach to source-backed ranges of rendered text and are stored in the
`.md` file itself, so they survive round-trips through other CommonMark
renderers (GitHub, Obsidian) and are readable by tools (grep `mkdn-comment`).
They can nest and overlap. Comments are anchored in the source; when an edit made
outside mkdn (a git merge, another editor, an agent rewriting prose) damages the
anchors, a conservative best-effort pass re-anchors them (see Resilience).

## On-disk format

A commented span is bracketed by an invisible **anchor pair**; the comment body
and re-anchoring data live in a single **sidecar block** keyed by id.

Anchors are self-closing custom elements (not HTML comments — an HTML comment at
the start of a line becomes an HTML *block* in CommonMark and would hide the
line, so a line's first word couldn't be commented). The empty custom element
parses as inline HTML everywhere, renders invisibly, and is greppable:

```
The <mkdn-comment id="k7" edge="start"/>quick brown fox<mkdn-comment id="k7" edge="end"/> jumps.
```

Nesting and overlap are expressed by id, including crossing pairs:

```
<mkdn-comment id="a" edge="start"/>foo <mkdn-comment id="b" edge="start"/>bar<mkdn-comment id="a" edge="end"/> baz<mkdn-comment id="b" edge="end"/>
```

The sidecar is one HTML comment at the end of the file (kept an HTML comment so
its JSON payload stays hidden; the line-start issue doesn't apply at EOF). The
JSON escapes `>` and `-`, so it can never contain `-->` or `--`:

```
<!--mkdn-comments
{"v":1,"comments":[{"id":"k7","body":"needs a citation","quote":"quick brown fox","prefix":"The ","suffix":" jumps."}]}
-->
```

A well-formed `<mkdn-comment …/>` token is reserved metadata and is stripped
wherever it appears (prose or code); don't type one literally as content.

## Processing

`preprocess` strips the anchors and the trailing sidecar, leaving the
**transformed source** — the markdown with anchors and sidecar removed — which
swift-markdown then parses and renders. It records how to map back: a segment map
from transformed-source offsets to the original raw source, and (built during
rendering) a map from positions in the rendered text to transformed-source
offsets. Together they translate a selection in the rendered text to a range in
the raw `.md`.

A comment becomes **active** one of two ways:

- **Anchor-paired:** exactly one start and one end anchor for its id (start
  before end, non-empty text between) plus a matching sidecar entry.
- **Re-anchored:** its anchors are missing or don't form a valid pair, but its
  sidecar TextQuote still resolves (see Resilience).

Half-pairs, duplicate anchor starts/ends, and empty spans don't pair; an orphaned
anchor with no recoverable sidecar entry produces no comment. (For duplicate
sidecar entries under one id, the first wins.) Either way, anchors are always
stripped from the output, and stripping is idempotent — running it over its own
output is a no-op.

The sidecar is recognized only as a decodable block at the document's trailing
position (only whitespace and HTML comments follow its close), so a mid-document
or fenced example of the block is ordinary content and is never stripped.

Rendering paints each active comment's highlight over its text and tags the range
with the comment id — a list, so overlapping comments are all recoverable at a
point. Clicking a highlight opens a stacked popover of every comment under that
point, smallest-enclosing first.

## Resilience

Each comment stores a **TextQuote** in the sidecar — the exact commented text
(`quote`) plus short `prefix`/`suffix` context. When a comment's anchor pair is
intact it's used directly. If an external edit removes or orphans the anchors,
the comment is re-anchored by searching the transformed source (the
anchor/sidecar-stripped markdown — so for a link or inline code the quote is the
markdown *source*, not just the visible text) for its `prefix+quote+suffix`. It's
recovered only when that match is **unique** and maps back to a single contiguous
raw region; a match straddling other comments' stripped anchors is intentionally
not recovered. Otherwise the comment is left orphaned rather than risk
highlighting the wrong text. There is no fuzzy matching. (A new comment's quote is
captured at creation; existing quotes aren't rewritten on save.)

## Authoring

Adding a comment inserts an anchor pair around the selection plus a sidecar entry
with a unique id (generation always terminates and never reuses an existing id),
then verifies the result before accepting it:

- **Render-neutral.** The inserted anchors must not change the document's rendered
  structure for a standard CommonMark renderer that doesn't strip them. The check
  compares a structural render signature (node structure + text, with mkdn markers
  ignored) before and after — not stripped strings, which can mask an introduced
  parse change. This rejects, e.g., a marker that would turn a line's first
  character into an HTML block, split an emphasis run, or land inside a code span.
- **Re-parses to the intended comment**, so a selection whose text happens to
  contain marker-like syntax can't silently produce a different comment.
- **Non-corruption.** Adding a comment never disturbs an existing one — a wrap
  that would change another comment's id, body, or highlighted text is rejected.

What can be commented is narrower than what's on screen: a selection must map back
to source-backed text. Plain prose maps 1:1; atomic tokens (links, inline code)
snap to the whole source token; a selection crossing existing anchors maps to the
raw span that includes them (this is how nesting/overlap is authored). Selections
that don't map cleanly — spanning more than one mapped run (e.g. across a
styled-text or paragraph boundary), or over synthetic/unmapped content such as
escapes, soft breaks, text runs containing `$` (math candidates and literal
dollar-sign prose alike), list markers, or images — aren't commentable. Degenerate selections are rejected rather than crashing.

Comment bodies and quotes can contain anything — `-->`, `--`, the marker text,
newlines, quotes, backslashes, emoji — and round-trip intact. A malformed sidecar
is left untouched rather than guessed at.

## Limitations

- **Inline code is whole-token.** Commenting inline code wraps the entire
  `` `token` `` (anchors can't live inside verbatim code without breaking
  portability); sub-range highlighting of code isn't supported.
- **Overlap re-click.** After adding a comment whose span overlaps an existing
  one, re-clicking that span opens the stacked popover rather than toggling it
  closed.
- **Sidecar relocation.** The sidecar must be the trailing block; an external tool
  that moves it mid-document detaches its comments until it's moved back.
  (Render-only — viewing never rewrites the file.)
- **Unclosed trailing code fence.** A decodable sidecar-shaped block inside an
  *unclosed* code fence at end-of-document is treated as the sidecar (recognition
  is position-based, not fence-aware). Only affects malformed input.
- **Block-level HTML** renders visibly, so anchors must stay inline; cross-block
  selections aren't commentable.
