# Comment sidebar + detached comments

**Status:** shipped on `feature/comment-anchoring-v2`. This describes the shipped
interaction model.

## Term

Comments whose stored quote can't be re-located are **Detached** (not
"orphaned"). They have no place in the document, so they live in the sidebar.

## Surface

A right-docked **comment sidebar**, toggled by ⌘⇧C (markdown, preview-only) or a
floating affordance. The window is chrome-less (transparent titlebar, full-bleed
content), so the open affordance lives **in the content**, not a toolbar. It
mounts as a trailing overlay on the markdown preview, so opening it never
reflows the text.

**Toggle** — floating, top-right of the content (traffic lights are top-left):
- **No comments:** a circle, comment-bubble icon only.
- **Has comments:** morphs (gentle spring) to a rounded pill = icon + **count
  badge** (total comments). Badge hidden at zero.
- Toggled by ⌘⇧C too; the hotkey is **not shown** in the UI. Hidden while the
  sidebar is open.

**Sidebar** — header `Comments` + ✕; segmented filter **All / Detached** (the
selector slides between segments):
- **All:** on-page comments first, then detached below.
- **Detached:** only the detached comments, under a `Detached (n)` header + a
  one-line "why" note.
- **On-page card:** quote chip (in `commentHighlight`) + body. The whole card is
  a button (pointer cursor on hover).
- **Detached card:** `warning` dashed treatment, a "Detached" chip,
  `was on …prefix `~~quote~~` suffix…` (quote struck, context muted), body, and
  **Delete**.

## Interaction

- **Hover an on-page card** → its span in the document eases into a bold accent
  emphasis: a crossfade from the resting highlight into an accent fill + outline,
  drawn layout-passively (no storage edit, so locating never relayouts). A
  wrapped span draws as one connected highlight. Moving off clears it.
- **Click an on-page card** → smooth-scrolls the span into view. The sidebar
  stays open and the hover keeps the span emphasized — there's no separate flash.
- **Delete** (detached cards) → `DocumentState.deleteComment(id:)` (sidecar-only;
  the card fades out).

## Theming — all colors from `ThemeColors`, no hardcoded hex

| Element | token |
|---|---|
| doc / card background | `background` |
| sidebar background | `backgroundSecondary` |
| borders / dividers / dashed edge | `border` (reduced opacity) |
| body text | `foreground` |
| counts, labels, "was on", close | `foregroundSecondary` |
| panel title, headings, quote-chip text | `headingColor` |
| resting comment highlight + quote-chip fill | `commentHighlight` |
| active filter, count badge, hover emphasis | `accent` |
| Detached chip / dashed / note | `warning` |
| Delete | `danger` |

## Animation

- **Slide:** the sidebar uses a `.move(edge: .trailing)` transition and the
  toggle a `.opacity` transition, driven by `.animation(sidebarSlide, value:
  isCommentSidebarVisible)`. The overlay slides over static content — nothing
  reflows or resizes (zero jump). NOT NSWindow frame expansion (reverted on
  macOS 14 — see MEMORY "Sidebar Toggle — Lessons Learned").
- **Card add/remove, filter switch:** animated (`quickShift`); deleting fades the
  card out, the filter selector slides via `matchedGeometryEffect`.
- **Hover emphasis + smooth scroll:** the document-side emphasis crossfade and
  the smooth scroll are manual per-frame ramps (`makeFrameRamp`) — the highlight
  is drawn in `draw(_:)` (not layer-backed), and the scroll must keep TextKit 2's
  viewport range current each frame or the layout-passive draw blanks out. Both
  honor Reduce Motion.

## Implementation

- **Views:** `CommentSidebarView` / `CommentSidebarToggle`, mounted as overlays
  in `MarkdownPreviewView` (gated to `DocumentState.canShowCommentSidebar`).
- **Data:** `ResolvedComments.active` (resolved `(id, entry, range)` in document
  order) + `.orphans`, mapped to `CommentSidebarItem`s.
- **Document side:** `CodeBlockBackgroundTextView.setHoveredComment` (emphasis),
  `scrollComment(to:)` (smooth scroll), `drawCommentHighlights` (the draw).
- **State:** `DocumentState.isCommentSidebarVisible` + `canShowCommentSidebar`.

Re-place (manual re-anchor of a detached comment onto a new selection) is not
implemented — detached cards only offer Delete.
