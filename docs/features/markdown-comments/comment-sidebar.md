# Comment sidebar + detached comments (unit 7)

**Status:** design locked; themed `warning`/`danger` tokens landed (`fd8b310`).
The animated sidebar is the next build (resume after compaction). HTML mockups
were delivered to the user (`/tmp/mkdn-themed.html` etc.); this doc is the spec.

## Term

Comments whose stored quote can't be re-located are **Detached** (not
"orphaned"). They have no place in the document, so they live in the sidebar.

## Surface

A right-docked **comment sidebar**, hotkey-toggled. The window is chrome-less
(transparent titlebar, full-bleed content), so the open affordance lives **in
the content**, not a toolbar.

**Toggle** — floating, top-right of the content (traffic lights are top-left):
- **No comments:** a circle, comment-bubble icon only.
- **Has comments:** morphs to a rounded pill = icon + **count badge** (total
  comments). Badge hidden at zero.
- Toggled by a hotkey too (mirror the directory sidebar's binding); the hotkey
  is **not shown** in the UI. Hidden while the sidebar is open.
- Open: decide whether the count/badge also hints detached (warning tint/dot) —
  default keep it a neutral count.

**Sidebar** — header `Comments` + ✕; segmented filter **All / On page /
Detached**; then:
- **On this page** (active): cards = quote chip (in `commentHighlight`) + body +
  hover "↳ jump".
- **Detached** (+count): a one-line "why" note, then cards = `warning` dashed
  treatment, chip "Detached", `was on …prefix `~~quote~~` suffix…` (quote struck,
  context muted), body, **Re-place… / Delete**.

## Theming — ALL colors from `ThemeColors`, no hardcoded hex

| Element | token |
|---|---|
| doc / card background | `background` |
| sidebar background | `backgroundSecondary` |
| borders / dividers / dashed edge | `border` (reduced opacity) |
| body text | `foreground` |
| counts, labels, "was on", close | `foregroundSecondary` |
| panel title, headings, quote-chip text | `headingColor` |
| active highlight + quote-chip fill | `commentHighlight` |
| active filter, Re-place, count badge, jump/flash | `accent` |
| Detached chip / dashed / note | `warning` |
| Delete | `danger` |

`warning`/`danger` now exist on `ThemeColors` (Solarized orange/red).

## Animation — CRITICAL: smooth slide in/out, NO content jump

Inline-codex **every** unit that touches animation. Mirror the **directory
sidebar** pattern, which already works:
- `DocumentState.isSidebarVisible` flag + toggle (see `DocumentWindow.swift`),
  `AnimationConstants.sidebarSlide` / `gentleSpring`.
- Prefer a **ZStack overlay**: the sidebar slides in over the content from the
  right; the content does **not** reflow or resize (zero-jump). Alternative:
  `HStack` + `gentleSpring` (content reflows, but smoothly) like the directory
  sidebar — overlay is safer for "no jump".
- **Do NOT** expand the NSWindow frame + animate (reverted on macOS 14, jumps —
  see MEMORY "Sidebar Toggle — Lessons Learned").

## Data + wiring

- Reads `ResolvedComments` (already has `ranges` id→NSRange, `comments(containing:)`,
  `comments(ids:)`, `orphans`). **Add** a public accessor for the *active* list —
  resolved `(id, entry, range)` — for the "On this page" section (entriesByID is
  currently private).
- **Jump:** scroll the text view to the comment's range + a brief flash. Keep it
  layout-passive (no storage edit) — a draw-based flash, not a `.backgroundColor`
  write.
- **Delete:** `DocumentState.deleteComment(id:)` (already sidecar-only, works on
  detached entries).
- **Re-place:** deferred stub (v2 — manual re-anchor onto a new selection).

## Build units (resume here)

1. `ResolvedComments` active-list accessor (`(id,entry,range)`), tested.
2. Sidebar SwiftUI view — static, themed (sections, filter, cards). Snapshot/visual.
3. Toggle morph (circle↔pill + count) + `isCommentSidebarVisible` state + hotkey.
4. **Slide animation** (overlay/`gentleSpring`) — inline-codex; verify no jump.
5. Jump-to-comment + Delete wiring; Re-place stub.
6. Dev-build verify in Solarized **Light and Dark**; confirm smooth, no jumping.
