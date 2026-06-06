# Brief: Comment sidebar — overlay → viewport-resize, at 60fps with no jump

## What the user wants

Today the comment sidebar **slides in over the top of the rendered text** (it's a
SwiftUI `.overlay`, so the text underneath never moves). The user wants to change
the *semantic*: when the sidebar slides in, it should **change the viewport of the
rendered text** — the text should occupy the now-narrower content area, and should
**animate smoothly to its new position/layout** rather than snapping. Hard
requirements in the user's words:

- "I don't want it to just jump. I don't want the text to jump around."
- "I want the text essentially [to move to] where it should be in the new viewport."
- "We need 60 frames per second."

So: overlay → genuine layout participant, with a buttery transition.

## Current architecture (verified file:line references)

**Sidebar mount — `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`**
- The preview is a single `SelectableTextView` (NSViewRepresentable).
- Toggle button: `.overlay(alignment: .topTrailing)` (lines 87–99), shown when
  `canShowCommentSidebar && !isCommentSidebarVisible`.
- Sidebar: `.overlay(alignment: .trailing)` (lines 100–115), `CommentSidebarView`
  with `.transition(.move(edge: .trailing))`.
- Both driven by one `.animation(motion.resolved(.sidebarSlide), value:
  documentState.isCommentSidebarVisible)` (line 116).
- The overlay sits *over* static content, so the text never reflows — that's the
  current "zero jump" trick, and exactly what the user now wants to replace.

**Sidebar view — `mkdn/Features/Viewer/Views/CommentSidebarView.swift`**
- `CommentSidebarView`, fixed `static let width: CGFloat = 300` (line 39),
  `.frame(width: Self.width)` (line 62). Right-docked, themed.

**Text view — `mkdn/Features/Viewer/Views/SelectableTextView.swift`**
- `NSScrollView` + TextKit 2 `NSTextView` (`CodeBlockBackgroundTextView`).
- `textContainer.widthTracksTextView = true` (line 157), text view
  `autoresizingMask = [.width]` (line 169), `textContainerInset = (32, 32)`
  (line 192), `isHorizontallyResizable = false` (line 193).
- **There is NO max reading width.** Text wraps edge-to-edge to the full text-view
  width minus the 32px insets. So if the content area narrows, **every line
  re-wraps.**
- `LiveResizeScrollView` (lines 386–428) already forces TextKit 2 viewport layout
  each `tile()` during window live-resize, and saves/restores `boundsOrigin`
  (point-based, not character-anchored) to limit scroll drift.

**Hosting**
- `ContentView.swift:38` — preview-only mode → `MarkdownPreviewView()` fills the
  window content area.
- `SplitEditorView.swift:13` — side-by-side mode → `MarkdownPreviewView()` is the
  right pane of a `ResizableSplitView`.
- The comment sidebar is **gated to preview-only** (`canShowCommentSidebar`): in
  split mode this view is already the half-width right pane, so the rail is
  suppressed. **So the resize behavior only needs to work in preview-only mode.**

**Animation**
- `AnimationConstants.sidebarSlide = .easeInOut(duration: 0.35)`
  (`mkdn/UI/Theme/AnimationConstants.swift:92`).
- `MotionPreference.resolved(.sidebarSlide)` returns `reducedInstant` under Reduce
  Motion (`mkdn/UI/Theme/MotionPreference.swift:96`).

## Prior art in THIS app (important — both already ship width-changes of this very text view)

1. **Left directory sidebar — `mkdn/App/DocumentWindow.swift:60–100`.** When the
   directory sidebar opens, `ContentView()` is given
   `.frame(width: geometry.size.width - sidebarOffset)` and
   `.offset(x: sidebarOffset)`, animated by
   `.animation(motion.resolved(.sidebarSlide), value: documentState.sidebarWidth)`.
   So the whole content area (including the preview NSTextView) **re-wraps when the
   left sidebar opens, and this is shipped.** Question for you: is it actually
   smooth, and can we reuse that exact pattern on the right?
2. **Split divider drag — `mkdn/Features/Editor/Views/ResizableSplitView.swift`.**
   Dragging the divider continuously changes the preview pane width, so the
   NSTextView re-wraps live every frame during the drag — apparently tolerated.

This is evidence that per-frame width changes of this TextKit 2 view are at least
*viable*. The open question is whether they're *60fps-silky* and *jump-free*, which
is a higher bar than "works."

## Key constraints / numbers

- Sidebar width: 300px. Default window width: **800px**
  (`AppSettings.swift:115`). So at the default size, opening the sidebar leaves
  **~500px** for content. The text MUST get narrower — there's no room to keep its
  width unless the window grows.
- Note from project memory: a previous attempt to expand the **NSWindow frame** to
  make room for a sidebar **jumped on macOS 14** (no `windowResizeAnchor` until
  macOS 26) and was reverted. Treat "grow the window" as high-risk/avoid.
- Min deployment: macOS 14.

## The technical tensions to solve (this is the crux)

Moving from overlay to a real layout participant introduces three distinct risks,
and a naive HStack hits all three:

1. **Per-frame re-layout cost.** TextKit 2 re-wrapping the visible viewport on every
   animation frame for 0.35s — does it hold 60fps for large documents? (The
   `LiveResizeScrollView` viewport-layout trick exists precisely because TextKit 2
   otherwise defers off-viewport layout.)
2. **Horizontal reflow churn.** Because text is full-width (no reading column),
   narrowing the width moves *every line's wrap point*. The text doesn't just
   translate — it visibly re-flows. This may look busy rather than "moving to where
   it should be."
3. **Vertical scroll jump.** Re-wrapping changes paragraph heights, so the total
   height of content *above* the viewport changes. If the user is scrolled into the
   middle of the doc, the point-based scroll offset now lands on a different line →
   the visible text **jumps vertically**. The existing `boundsOrigin` save/restore
   is point-based and won't fix this. A character-anchored scroll-preserve (capture
   the layout location at the top of the viewport before the width change, re-scroll
   to it after relayout) is likely required.

## Candidate strategies (weigh these; propose better if you see one)

- **S1 — Honest reflow (HStack / frame-resize, like the directory sidebar).** Pull
  the sidebar out of the overlay; lay out `[ preview | sidebar ]` so the preview's
  width animates from full → full−300. Reuse the `DocumentWindow` frame+offset
  pattern. Must add character-anchored scroll preservation to kill the vertical jump
  (#3), and must verify 60fps (#1). Faithful to "change the viewport," but lives with
  horizontal churn (#2).
- **S2 — Reading-column slide (zero-reflow when wide).** Introduce a max reading
  width for the preview content (centered column, e.g. ~700px). Opening the sidebar
  re-centers the column inside the narrower content area. When
  `windowWidth − 300 − insets ≥ columnWidth`, the column width is *unchanged* → the
  text **purely translates** (cheap layer move) → no re-wrap, no vertical jump,
  trivially 60fps, and it literally "moves to where it should be." BUT at the default
  800px window, 800−300 = 500 < 700, so the column still shrinks/re-wraps unless the
  column max is small. So S2 only buys zero-reflow on wide windows; narrow windows
  still need an S1-style fallback. It's also a visible product change (reading
  margins for everyone).
- **S3 — Translate-then-settle.** During the 0.35s, apply a cheap layer translation
  (no re-wrap) to slide the text; do a single synchronous re-wrap to the final width
  at animation end. Hides per-frame cost, but full-width text translated left leaves
  a gap/clip, and the end-snap re-wrap can itself read as a jump. Probably inferior;
  evaluate and likely reject.

## What we need from you (Codex)

Produce a **concrete implementation plan**, not just prose. Specifically:

1. **Pick a strategy** (S1 / S2 / S3 / hybrid) and justify it against the three
   tensions and the 60fps + no-jump bar. If the honest answer is "the only way to
   truly hit zero-jump + 60fps is a reading column (S2), and that's a product
   decision," say so plainly — we'll take that back to the user.
2. **Exact view-tree changes**: where the HStack/frame-resize goes (inside
   `MarkdownPreviewView` vs hoisted), how the toggle is handled, how the existing
   `.overlay`+`.transition` is replaced, and how `canShowCommentSidebar` /
   preview-only gating is preserved.
3. **Scroll-anchor preservation**: the precise TextKit 2 mechanism to capture the
   top-of-viewport anchor before the width change and restore it after relayout
   (APIs: `NSTextLayoutManager`, `textViewportLayoutController`,
   `NSTextLocation`/`enumerateTextLayoutFragments`), and where to hook it relative to
   the SwiftUI animation.
4. **60fps mechanism**: how to drive the width animation so TextKit 2 re-lays the
   viewport each frame without deferring (reuse `LiveResizeScrollView`'s
   `layoutViewport()` approach? a `CADisplayLink`/timer-driven width? a SwiftUI
   `Animatable` modifier that bridges to the NSTextView?). Concrete enough to build.
5. **Overlay interaction**: comment highlight overlays, the comment popover, and the
   `OverlayCoordinator`-positioned attachments (Mermaid/images) must re-position
   correctly as the width animates (see `OverlayCoordinator.repositionOverlays()`).
   Note any hooks needed.
6. **Reduce Motion**: behavior when `sidebarSlide` resolves to `reducedInstant`.
7. **Risks & verification**: what could regress, and how to verify 60fps + zero
   vertical jump (the project verifies sidebar smoothness via 60fps frame capture in
   both Solarized themes — see the `comment-sidebar-overlay-slide` memory).

You can read any file in the repo. Build: `swift build`. Tests:
`swift test`. The relevant files are all under `mkdn/Features/Viewer/Views/` and
`mkdn/App/`. Please ground the plan in the actual code, citing file:line.
