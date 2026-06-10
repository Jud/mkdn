# Viewport-First Performance Plan

**Status:** Targets A and B implemented (B1 folded into both); B2 is next.
**Targets:** (A) 60fps on the comment-rail open/close slide; (B) sub-second first paint
on document open (the `ve-access-control` doc is ~1.8s today).

**Measured (release, 700-block/210KB fixture via `scripts/make-perf-fixture` +
`mkdn-ctl open-timings`):** first paint 307ms (was 1702ms); exactly one
block-offsets pass per content generation (was 3). A 4000-block/1.2MB fixture
first-paints in ~1.1s where the baseline froze the app for 30+ seconds — the
remaining pre-paint cost is the whole-document markdown parse/render (~440ms),
kept synchronous by design (see below). The tail fully materializes in ~3.5s
against the ~1.5s validation target: a process sample shows AppKit's attribute-dictionary
uniquing table dominating the chunked build (each appended run's dictionaries
re-probe a global weak hash table that grows with every distinct
`mkdnSourceSpan` run) — exactly B2's "cache attribute dicts" lever, plus a
B2-adjacent option: drop the session's own accumulated copy and reconstruct
the final string from the live storage — every run's dictionaries currently
probe the table three times (the chunk build, the session's accumulated
append, the live-storage append), and that removes one. Also deferred to B2-time: viewport-only overlay repositioning at the
tail finish (the all-entry pass forces full-document layout once; inherited
from the normal open path).

## Core principle

Bound the work on the critical path to **the viewport**, not the document. Both the
slide animation and the document open were doing O(document) work per frame / before
first paint; the fix is the same idea in two places:

- **Slide:** the per-frame cost is the squish/unsquish of the *visible* content
  (O(viewport)); the only O(document) cost was computing the anchored line's *absolute*
  document Y by laying out the whole prefix above it every frame. Pin the top line by its
  **screen** position using viewport-local layout, and defer the exact absolute scroll
  position to settle.
- **Open:** first paint only needs the *first viewport* of blocks rendered. Everything
  else — the off-viewport render, the per-block height measure, the document map (marker
  track / minimap / comment cards), and the heading + comment anchors — is deferred to a
  cooperative async tail after first paint.

The height-estimation engine (`DocumentBlockOffsets`: Core-Text per-block Y without TextKit
layout) stays the tool for off-viewport positions; the change is *when* and *how often* we
pay for it.

---

## Target A — 60fps comment-rail slide

The slide is a 0.35s `easeInOut` ramp on `sidebarProgress` (≈21 frames @ ≤16.7ms). Profile:
~30fps, layout-bound. Per-frame `layoutViewport` (the live reflow) is already ~8ms — within
budget; the killer is `restoreSidebarResizeAnchor`'s per-frame
`ensureLayout(documentRange → anchor)` (~185 samples, O(document-above-anchor)).

### Mechanism (per frame, viewport-bounded)

Replace `restoreSidebarResizeAnchor()` with a viewport-only re-pin. Per frame in the
resize tick:

1. Set the new container width.
2. `controller.layoutViewport()` — viewport range only. **No `ensureLayout(prefix)`.**
3. Read the anchored line's current **screen** Y from the laid-out viewport:
   `screenY = fragmentY + lineY + textContainerOrigin.y − clipView.bounds.origin.y`.
4. `drift = screenY − anchor.desiredScreenY`; nudge `clipView.setBoundsOrigin(y += drift)`;
   `reflectScrolledClipView`.
5. `controller.adjustViewport(byVerticalOffset: drift)` to re-align the controller without
   forcing another full layout.
6. Reposition **visible** overlays only.

Pin by viewport-local **drift**, never absolute document Y — upstream fragments stay
estimate-backed, and any estimate shift shows up in `screenY` and is cancelled by the nudge
before display. Tighten the anchor from a fragment to a **line-level** anchor
(`textLineFragment…`) so "the line at the viewport top" is exact for wrapped paragraphs.

### Settle (once, at animation completion)

`layoutViewport()` → `refreshEstimatedHeight()` → one exact
`ensureLayout(documentRange → anchor)` → exact re-pin → final `layoutViewport()` → clear
resize state → one map rebuild. If the settle correction (accumulated upstream-estimate
error) exceeds ~4–8px, animate just that correction over ~80ms, or pre-correct from
`DocumentBlockOffsets.characterY` at the final width. **Never** reintroduce prefix layout
during the slide.

### Other O(doc) per-frame traps to kill alongside

- **`refreshCachedBlockRects()`** can `ensureLayout(0 … lastCodeBlockEnd)` after a width
  invalidation (code-block backgrounds) — an O(document-prefix) *draw-time* trap. During the
  slide, make code-block background geometry viewport-only / defer the full rect refresh to
  settle.
- **`overlayCoordinator.repositionOverlays()`** loops *all* attachment overlays from
  `tile()`; with many attachments that forces offscreen fragment layout. Reposition only
  intersecting overlays during the slide; defer the all-entry pass to settle.
- Map / scroll-spy / height estimate / card anchors stay **gesture-frozen** (already done).

### Per-frame budget (target p95 < 16.7ms)

`layoutViewport` ~8ms · anchor read + scroll nudge <1ms · visible overlay/code bg 1–3ms ·
SwiftUI sidebar with frozen map 1–3ms → **~10–15ms/frame**.

### Validation

Release builds, open + close at top/middle/deep scroll. During animation frames, signpost:
zero prefix `ensureLayout`, zero `DocumentBlockOffsets.measure`, zero `refreshEstimatedHeight`,
no code-block prefix layout, no all-overlay reposition; `layoutViewport` p95 ~8ms.

---

## Target B — viewport-first document open

Profile (~1.8s): `MarkdownTextStorageBuilder.build` ~1.1s (whole-doc parse→one
NSAttributedString) + a **double per-block measure** ~0.5s (`refreshEstimatedHeight` and
`buildDocumentMap` each run `DocumentBlockOffsets.measure` over the whole doc).

**Do it as progressive attributed-string build + deferred metrics — not a streaming Markdown
parser.** `swift-markdown` builds a whole `Document` with document-wide semantics (footnotes,
references); prefix-only *parsing* would mis-render the first viewport and visibly change it
later. So parse fully (cheap relative to the AppKit build), but build/install/measure
progressively.

### First-paint critical path (target < ~300ms)

1. `CommentDocument.parse` (strip sidecar).
2. Markdown parse → blocks (`MarkdownRenderer.render`) — signpost; if it proves expensive,
   stage it too.
3. Pick the first chunk: enough blocks for viewport + one viewport of overdraw, time-capped.
4. Build the **prefix** `NSAttributedString`; install into the text storage.
5. Seed a **provisional** `estimatedHeightFloor` from a cheap whole-*source* heuristic
   (raw line count + `textWidth/avgGlyphWidth` wrap estimate + block-kind margins +
   attachment placeholders + 1.25–1.5× upward bias + `ceil`) — never under-estimate.
6. `layoutViewport()` → paint.

**No** whole-doc `DocumentBlockOffsets`, **no** full `AnchorTape`, **no** full comment
resolution, **no** map on the first frame.

### Cooperative async tail (after first paint)

1. Append the remaining blocks to the **same displayed** text storage in main-actor chunks
   sized by a **time budget** (≤8–12ms/slice), `beginEditing()`/`endEditing()`, appending
   **below** the viewport so the top doesn't move. The append path is owned by the text
   view / coordinator — **not** routed through SwiftUI `textStorageResult` state (that calls
   `applyNewContent`, resets selection/scroll, hides overlays, reschedules the map). Suppress
   scroll-spy / map / height refresh while `progressiveOpenTailActive`.
2. Once full storage exists, run **one** deduped `DocumentBlockOffsets` pass (B1) and feed it
   to: exact `estimatedHeightFloor`, the map, heading positions, comment-card anchors, and the
   minimap/marker bands. If that pass is still ~0.5s, chunk/yield it too.
3. Build full `AnchorTape` → resolve comments → publish `resolvedComments`, map, cards,
   minimap, breadcrumb. Run offscreen-attachment overlay setup once after the tail, not per
   chunk.

### Comment highlights in the first viewport

Sidebar cards may pop in later. **Text** highlights need an `AnchorTape`. For the fastest
GREEN, accept missing first-paint highlights. If they must appear immediately, add a
**provisional viewport-only resolver**: a partial `AnchorTape` over the prefix, resolving
*only* comments whose stored hint range lies in the prefix and whose quote matches at that
exact range + nearby prefix/suffix — for highlight draw only, replaced by full
`ResolvedComments` after the tail. **Do not** run the normal global resolver on a partial
tape (a globally ambiguous quote could become a false unique match).

### Risks

- Append on the main actor is safe but must use `beginEditing/endEditing`, never repeated
  `setAttributedString`.
- Disable/"loading"-gate selection, find, comment authoring, print, and sidebar jumps until
  the full storage + tape are ready.
- A provisional tall frame lets the user scroll into not-yet-materialized tail; append
  aggressively or clamp deep scroll until materialized.
- The full parse/render may become the next bottleneck — signpost before optimizing.

### B1 + B2 (fold in)

- **B1 (dedup the double measure)** is subsumed by "one deduped pass" above — `DocumentBlockOffsets`
  is the single source of truth for height + map + anchors, computed once per content/width
  generation (key by storage/model generation + width + attachment revision).
- **B2 (builder micro-opts)** after instrumentation: coalesce adjacent inline runs with identical
  attributes; build one mutable string + apply attribute ranges (vs many small appends); cache
  fonts/paragraph-styles/attribute dicts by style key; build `SourceMap` incrementally.

### Validation

First paint < ~300ms to first viewport; full doc ready async within ~1.5s without blocking
interaction. Count `DocumentBlockOffsets.measure` during open — GREEN = exactly one per
content/width generation.

---

## Sequencing (across both targets)

1. ~~**Instrument** open phases and slide frames with signposts~~
   (`OpenTimeline` + `getOpenTimings` / `mkdn-ctl open-timings`).
2. ~~**B1**: defer + dedup `DocumentBlockOffsets` / map to one post-first-paint pass.~~
3. ~~**A**: viewport-bounded slide re-pin (+ kill the code-block-rect and overlay traps).~~
4. ~~**B (progressive)**: progressive build/install for the first viewport + cooperative
   tail~~ — `ProgressiveTextStorageBuild` + the coordinator tail driver; threshold and
   prefix policy live in `MarkdownPreviewView`.
5. **B2**: builder micro-opts — the measured lever is the attribute-dictionary
   uniquing noted above; the whole-doc parse/render (~440ms on the 1.2MB fixture) is
   the next pre-paint cost after it.
6. *Later, only if needed:* true incremental/background Markdown parsing.

Targets A and B are largely independent and can land in either order; B1 helps both. True
incremental raw-Markdown parsing is explicitly out of the first GREEN cut — progressive
attributed-string build is the clean first step.
