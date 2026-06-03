# Comment Format — paired id anchors + sidecar

Comments attach to any rendered range of a markdown document and are stored in
the `.md` file itself, so they survive round-trips through other CommonMark
renderers (GitHub, Obsidian) and are readable by tools (grep `mkdn-comment`).
They can nest and overlap, and they survive edits made outside mkdn (a git merge,
another editor, an agent rewriting prose).

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
JSON is escaped so it can never contain `-->` or `--`:

```
<!--mkdn-comments
{"v":1,"comments":[{"id":"k7","body":"needs a citation","quote":"quick brown fox","prefix":"The ","suffix":" jumps."}]}
-->
```

A well-formed `<mkdn-comment …/>` token is reserved metadata and is stripped
wherever it appears (prose or code); don't type one literally as content.

## Processing

`preprocess` strips the anchors and the trailing sidecar, leaving ordinary
markdown that swift-markdown parses and renders. It records a segment map
(transformed↔raw offsets) and pairs anchors into comments. A comment is **active**
only with exactly one start anchor, one end anchor (start before end, non-empty
text between), and a matching sidecar entry; orphans, half-pairs, duplicate ids,
and empty spans produce no comment, though their anchors are still stripped.
Stripping is idempotent — running it over its own output is a no-op.

The sidecar is recognized only as the document's trailing block (only whitespace
and HTML comments follow its close), so a mid-document or fenced example of the
block is ordinary content and is never stripped.

Rendering paints each active comment's highlight over its text and tags the range
with the comment id — a list, so overlapping comments are all recoverable at a
point; a click opens the innermost (smallest-enclosing) comment.

## Resilience

Each comment stores a **TextQuote** — the exact `quote` plus short `prefix`/`suffix`
context — in the sidecar. When the anchor pair is intact it's used directly (and
the quote is refreshed from it on save). If an external edit orphans or deletes a
marker, the comment is re-anchored by finding its `prefix+quote+suffix` in the
rendered text — but only on a **unique exact match**; otherwise it's left
orphaned rather than risk highlighting the wrong text. No fuzzy matching.

## Authoring

Adding a comment inserts an anchor pair around the selection plus a sidecar entry
with a unique id (generation always terminates and never reuses an existing id),
then verifies the result before accepting it:

- **Render-neutral.** The inserted anchors must not change how a standard
  CommonMark renderer (one that doesn't strip them) parses the document — compared
  at the parsed-AST level, not as stripped strings. This rejects placements that
  would turn a marker at the first non-space of a line into an HTML block, split
  an emphasis run, or land inside a code span/block, autolink, link
  destination/title, image, reference definition, heading syntax, list
  marker/checkbox, table delimiter row, or hard break.
- **Re-parses to the intended comment**, so a selection whose text happens to look
  like a marker can't silently produce a different one.
- **Non-corruption.** Adding a comment never disturbs an existing one — a wrap
  that would change another comment's id, body, or highlighted text is rejected.

A selection maps back to the exact source text it covers; atomic tokens (links,
inline code) snap to the whole token. A selection that can't map cleanly (e.g.
spanning a paragraph boundary) is simply not commentable, and a degenerate
selection is rejected rather than crashing.

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
- **Unclosed trailing code fence.** A marker block inside an *unclosed* code fence
  at end-of-document is treated as the sidecar (recognition is position-based, not
  fence-aware). Only affects malformed input.
- **Block-level HTML** renders visibly, so anchors must stay inline; cross-block
  selections aren't commentable.
