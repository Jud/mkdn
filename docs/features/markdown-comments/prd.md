**Status:** Approved (v3) — green-with-changes from Codex (gpt-5.5, xhigh); all refinements folded in below. Ready to implement.

# Markdown Comments — Product Requirements

## Problem Statement

mkdn is increasingly used to review markdown *artifacts authored by AI agents* (plans, specs, docs). Today the review loop is lossy: the user reads a rendered document, but to give feedback they must switch context, describe the location in prose ("in the third paragraph, the part about deadlines…"), and hand that back to the agent. There is no way to anchor a comment to a specific span of text and no way for the comment to travel *with the document*.

The user wants a Google-Docs-style review experience that lives **inside the markdown file itself**: select text → leave a comment → the comment is persisted in the `.md` source in a self-describing format → the agent can later be told "address my comments" and read them directly from the file with no special protocol.

## Goals

**Primary:**
- Select a span of rendered text and attach a comment to it via a popover.
- Persist the comment **in the markdown source file** in a self-describing, standard format an LLM can read with zero setup.
- Render commented spans Google-Docs-style: the span is highlighted, the raw markup is hidden, and clicking the highlight reveals the comment in a popover.
- Support an agent-feedback loop: the agent reads comments by reading the raw file; resolving a comment removes its markup.

**Secondary:**
- Keep the rendered document clean — no literal `{==…==}` syntax ever visible on screen.
- Theme-aware highlight color that harmonizes with the Solarized palette in both light and dark.

## Non-Goals (v1)

- Threaded replies / multi-message conversations on a single comment.
- Author identity, timestamps, or "resolved (kept)" state — resolve = delete the markup.
- Overlapping or nested highlights on the same span.
- Comments on non-text blocks (images, tables, mermaid, math attachments).
- iOS authoring UI. Rendering of existing comments should work cross-platform; authoring may be macOS-first.
- Any comment store outside the `.md` file (no sidecar files, no database).

## Format Decision — CriticMarkup

Comments are stored using [CriticMarkup](http://criticmarkup.com/), a recognized plain-text convention for editorial markup in markdown:

```markdown
The deadline is {==next Friday==}{>>moved to Monday?<<} per the latest sync.
```

- `{== … ==}` — the **highlighted span** (CriticMarkup "highlight").
- `{>> … <<}` — the **comment** attached to the immediately preceding span.

**Why CriticMarkup:**
- It's plain text and self-describing — an agent reads comments by grepping `{>>`; no special instructions needed.
- It survives round-trips through git and any markdown editor.
- It co-locates the anchor text and the comment on disk, so feedback travels with the document.

**Accepted limitation:** pure CriticMarkup is one comment per span with no threading. For an agent-feedback loop ("note → fix → remove markup") this is the right bar for v1. Threading, if ever wanted, is a future extension (structured comment block or HTML anchors).

**Pipeline placement (decided):** CriticMarkup is **preprocessed out of the raw source before swift-markdown parses it** — NOT detected per-`Text`-node during `convertInline`. The preprocessor transforms `{==highlight markdown==}{>>raw body<<}` into just `highlight markdown`, recording sidecar metadata (full raw span, body span, comment id) and a **transformed↔raw offset map**. `Document(parsing:)` then sees ordinary markdown, so a highlight that contains inline styles (e.g. `{==**bold** text==}`) parses correctly and the delimiters never reach the AST. This is the key correction from review — a per-`Text`-node scanner would split `{==**bold**==}` across literal-text and `Strong` nodes and leak or drop delimiters.

## User Stories

1. **As a reviewer**, I select text in a rendered doc and type a comment in a popover, so my feedback is anchored to the exact span.
2. **As a reviewer**, I see commented spans highlighted (not raw braces), and click a highlight to read/edit/delete the comment.
3. **As a developer handing work back to an agent**, I tell the agent "address my mkdn comments" and it reads `{>>…<<}` straight from the file.
4. **As a reviewer**, I delete a comment and the highlight + markup disappear from both the view and the file (resolve = remove).
5. **As anyone opening a doc with existing CriticMarkup**, I see the highlights rendered correctly with no literal syntax leaking through.

## Functional Requirements

### Parsing (preprocessor)
- **FR-1**: A preprocessor MUST parse CriticMarkup highlight `{==text==}` immediately followed by comment `{>>body<<}` from the **raw source**, emitting (a) transformed source with the delimiters and body removed (highlight inner text retained), (b) per-comment metadata (comment id, raw full-span range, raw body range, highlight inner range), and (c) a transformed↔raw offset map.
- **FR-2**: Parsing MUST be robust to: unterminated tokens (left **literal**, no transform), a comment with no preceding highlight (orphan — see Open Questions; v1 default is to leave literal), and brace content inside the comment body.
- **FR-2a (code policy)**: The preprocessor MUST NOT transform CriticMarkup-looking text inside fenced code blocks, indented code blocks, or inline code spans. Since v1 rejects comments in code (FR-9a), stripping there would silently mutate a code sample before swift-markdown parses it. The preprocessor needs minimal code-region awareness (track fences/backtick runs/indentation) to skip these regions.
- **FR-2b (write-time delimiter safety)**: On authoring, a comment **body** containing `<<}` or selected **source** containing `==}` would break the CriticMarkup parse. v1 MUST **reject** such writes explicitly (no silent escaping).
- **FR-3**: Other CriticMarkup operators (`{++ins++}`, `{--del--}`, `{~~a~>b~~}`) are out of scope for v1 and MUST pass through as literal text without breaking parsing.

### Rendering
- **FR-4**: An annotated span MUST render with a subtle highlight background; the `{==`, `==}`, `{>>`, `<<}` delimiters and the comment body MUST NOT appear in the rendered text. (Guaranteed by FR-1 preprocessing — the AST never contains them.)
- **FR-5**: The highlight color MUST be theme-aware and muted (Solarized-harmonized) in both light and dark themes. (Pipeline change → visual verification in both themes is mandatory.)
- **FR-6**: The highlight + comment id MUST be applied as a custom attribute (`CommentAttribute`) over the highlight range in the **final builder coordinate space** (see Technical Risk), set by `MarkdownTextStorageBuilder`. The visitor/builder learn the highlight extent from the preprocessor metadata mapped through the source map.

### Interaction (read)
- **FR-7**: Clicking inside a highlighted span opens a popover showing the comment body. Click detection is a **new inline hit-test** over `CommentAttribute` at the clicked character index in `SelectableTextView` — this is distinct from the existing block-level `BlockInteractionContext` hooks, which are not sufficient.
- **FR-8**: The popover offers **Edit** (change body) and **Delete** (remove the comment — resolve).

### Authoring (write)
- **FR-9**: With a text selection active, a "Comment" action (context menu + keyboard shortcut) opens a popover with a text field. On submit, the **rendered selection `NSRange` is resolved to a raw-source `Range<String.Index>`** (via the builder source map composed with the transformed↔raw map), the span is wrapped with CriticMarkup in the source file, and the file is saved.
- **FR-9a (selection policy — reject-first)**: Selections that cannot be safely mapped MUST be **rejected** (no clamping, no splitting), with the "Comment" action disabled/greyed. Reject when the selection: crosses a block boundary; touches any attachment (inline math, table, mermaid, image); includes generated text (list bullets/numbers, checkboxes, terminator newlines); overlaps an existing comment span; or (v1) falls inside a code block/inline code. Only contiguous, fully source-backed text within a single block is writable.
- **FR-10**: Edit rewrites the `{>>…<<}` body at the recorded raw body range; Delete removes both the `{==…==}` wrapper and the `{>>…<<}` body at the recorded raw full-span range, leaving the original text intact. Both re-render.

### Degradation
- **FR-11**: A document with no comments renders exactly as today.
- **FR-12**: Rendering of existing comments MUST compile and work on iOS even if authoring is macOS-only.

## Key Technical Risk — Rendered → Source Range Mapping

The load-bearing piece (FR-9/FR-10). The on-screen `NSAttributedString` is **not** the markdown source: syntax is stripped, soft breaks become spaces, inline code/math are transformed, and `MarkdownTextStorageBuilder` *injects synthetic characters* the source never had — list bullets/numbers, terminator newlines, attachment placeholders. To wrap a *selected rendered range* with CriticMarkup we must translate the selection's `NSRange` back to a raw-source `Range<String.Index>`.

**Corrected approach (per review):**

1. **Build the map in BUILDER coordinates, not visitor coordinates.** The visitor discards AST nodes right after `convertInline`, and the final coordinate space is produced later by `MarkdownTextStorageBuilder` (which adds the synthetic characters above). A visitor-time range is therefore *not* in `NSTextView.selectedRange()` space. The map MUST be assembled as the builder emits the attributed string, and surfaced on `TextStorageResult` as a new `sourceMap` (data-model change — not optional; today `TextStorageResult` carries only attributed text, attachments, and heading offsets).

2. **`SourceRange` is an ingredient, not the answer.** swift-markdown's `SourceLocation.column` is a **UTF-8 byte** column, while `NSRange` is **UTF-16**. Backslash escapes, HTML entities, soft breaks rendered as spaces, inline code, and math replacement all break naïve offset arithmetic. The builder must record, per emitted text run, a mapping from builder UTF-16 offsets → source `String.Index`, with explicit **"no source / unsafe"** markers for synthetic and transformed regions.

3. **Compose two maps (keep them separate).** Because CriticMarkup is preprocessed out first (FR-1), the chain is: `builder output range → transformed-source range` (the builder source map, a rendering concern) → `raw-source range` (the transformed↔raw offset map, a preprocessing concern). Keep construction as two maps; expose a single **composed resolver API** to callers. The builder MUST NOT learn about raw CriticMarkup deltas directly. The resolver is **boundary-resolution**, not just per-run: it answers "does this exact UTF-16 boundary map to a transformed `String.Index`?" — escapes, entities, soft breaks, inline code, and math are either resolved per-character or marked **unsafe**.

   Source spans must survive the visitor: today `MarkdownVisitor` produces source-less `MarkdownBlock`/`AttributedString` values and the builder only receives those. Phase 1 MUST add a **`SourceSpanAttribute`** (or source-aware inline model) so transformed-source spans flow through the visitor and are consumed as the builder emits final UTF-16 ranges.

4. **Reject-first selection policy (FR-9a).** Any selection touching an "unsafe/no-source" region — attachments, synthetic bullets/newlines, transformed inline code/math, an existing comment span, or spanning blocks — is rejected outright. Only contiguous, fully source-backed single-block text is writable. This keeps v1 correct without intra-attachment heroics.

5. **No live bidirectional map.** Anchoring is at insertion time only: resolve → wrap raw span → save → re-parse/re-render. Comment identity persists via the CriticMarkup in the file, re-discovered on each parse.

6. **Explicit comment-metadata artifact.** Per-comment data (id, body, raw full-span range, raw body range) MUST live in a render artifact, e.g. `TextStorageResult.commentsByID`, NOT be rediscovered from the attributed string. The inline hit-test (FR-7) reads the `CommentAttribute` id and looks up the rest there; Edit/Delete (FR-10) use the recorded raw ranges.

**Surrounding-text anchoring** (matching by adjacent text instead of offsets) is a **fallback only** — duplicate text, emphasis, entities, and generated output make it ambiguous as a primary write path. Use it at most to validate that a resolved span's rendered text matches the selection.

## Proposed Plan (phased) — round-trip proof first

1. **Source-map spike + data model (FEASIBILITY GATE).** Build, with no UI:
   - CriticMarkup **preprocessor**: transformed source + per-comment metadata + transformed↔raw offset map, with **code-region awareness** (FR-2a) so code samples are never mutated.
   - **`SourceSpanAttribute`** (or source-aware inline model) so transformed-source spans survive the visitor into the builder.
   - **`TextStorageResult.sourceMap`** in builder coordinates + a **composed boundary-resolution resolver** API (builder UTF-16 boundary → transformed `String.Index` → raw `String.Index`, or "unsafe").
   - **`TextStorageResult.commentsByID`** artifact (FR-6/§Technical Risk pt.6).
   
   Prove the full round-trip in **unit tests**: `selection NSRange → raw-source Range<String.Index> → wrap with {==…==}{>>…<<} → re-parse → identical render + greppable {>>`. Gate tests MUST cover: UTF-16↔UTF-8 byte columns, backslash escapes, HTML entities (`&amp;`), soft breaks→spaces, **CRLF**, **emoji + combining marks**, emphasis inside a highlight, inline code/math (→ unsafe), and all FR-9a reject cases. → verify: tests pass; round-trip is byte-exact on raw source.
2. **`CriticMarkup.swift` parser hardening** — finalize edge cases from FR-2/FR-3 (unterminated, orphan, braces in body). → verify: unit tests.
3. **Highlight rendering** — apply `CommentAttribute` in builder coords; theme-aware muted background. → verify: visual capture both themes.
4. **Inline click hit-test → popover** — new attribute hit-test in `SelectableTextView` (separate from `BlockInteractionContext`); popover shows body with Edit/Delete. → verify: manual run.
5. **Authoring UI** — selection → reject-first gating (FR-9a) → "Comment" action → popover → wrap/save/re-render. → verify: end-to-end round-trip in the running app, both themes.

## Open Questions

1. **Orphan comments** (`{>>…<<}` with no preceding highlight): leave literal (v1 default), or render as a standalone margin note?
2. **Keyboard shortcut** for "Add Comment" (e.g., ⌘-⌥-M) — pick something unclaimed in `MkdnCommands`.
3. **Popover anchoring** — anchor to the highlight rect (bounding-rect for the `CommentAttribute` range), or a caret-based anchor?
4. **Code-block comments** — v1 rejects them (FR-9a). Confirm that's acceptable or whether fenced-code comments are needed early.
