# PRD: Document Outline Navigator

**Status:** Approved

## Revision History

| Date | Change | Reason |
|------|--------|--------|
| 2026-03-21 | Added comprehension-mode user stories, goals, and success metric | User feedback: outline serves document structure comprehension, not just navigation |

## Problem Statement

Users working with long Markdown documents (600-843 lines, 25-30+ headings) have no way to navigate by document structure in mkdn. The only option is manual scrolling or Cmd+F text search. Maintaining inline tables of contents is a document-level hack that pollutes the source and drifts out of sync. Outline navigation is a viewer concern -- the viewer already parses the heading tree and should expose it as a navigation tool.

> **Cross-refs:** If this section changes, MUST also update:
> - architecture.md § "Overview" (motivation)

## Goals

**Primary:**
- Provide fast, keyboard-driven navigation to any heading in a Markdown document
- Show the user's current position in the document structure (breadcrumb path)
- Give the reader a bird's-eye view of document organization (comprehension at a glance)

**Secondary:**
- Maintain mkdn's chromeless aesthetic -- zero visual footprint when not in use
- Fuzzy-filter headings for documents with many sections

## Non-Goals

- Heading anchors or deep-link URLs
- Editing or reordering headings from the outline
- Persistent outline panel or right sidebar
- iOS support (macOS-only initially)
- Changes to the Markdown parsing pipeline
- Source-code file support (outline navigator is for Markdown headings only)

## User Stories

1. **As a reader** of a long architecture document, I want to jump directly to a specific section so that I don't spend time scrolling through 800+ lines.

2. **As a reader** reviewing a document, I want to see where I currently am in the document structure so that I maintain context while scrolling.

3. **As a reader** with many sections, I want to type a few characters to filter headings so that I can find the right section quickly in a 30-heading document.

4. **As a reader**, I want to dismiss the outline with Escape and return to where I was so that the navigator doesn't disrupt my reading flow.

5. **As a reader** who uses Reduce Motion, I want the outline navigator to work correctly with minimal animation so that I can navigate comfortably.

6. **As a reader** switching between light and dark themes, I want the breadcrumb and outline to match the current theme so that the UI feels cohesive.

7. **As a reader** opening an unfamiliar document, I want to see the overall structure of the document at a glance so that I understand how it is organized before diving in.

8. **As a reader** reviewing a document I wrote, I want to quickly assess whether the document's section structure makes sense so that I can identify organizational issues (e.g., unbalanced sections, missing topics).

> **Cross-refs:** If this section changes, MUST also update:
> - architecture.md § "Testing Strategy" (test scenarios should cover these stories)

## Functional Requirements

### Heading Tree Extraction

1. **FR-1**: The system SHALL extract all headings (levels 1-6) from the rendered `[IndexedBlock]` array and build a tree structure reflecting heading hierarchy.
2. **FR-2**: Each heading node SHALL carry the plain text content, heading level, and the `IndexedBlock.index` for scroll targeting.
3. **FR-3**: The heading tree SHALL update whenever `renderedBlocks` changes (new file load or content edit).

### Breadcrumb Bar

4. **FR-4**: A breadcrumb bar SHALL appear at the top of the document view when the user scrolls past the first heading in the document.
5. **FR-5**: The breadcrumb bar SHALL display the current heading path (e.g., "Component Design > Migration Orchestrator") based on the viewport's scroll position.
6. **FR-6**: The breadcrumb bar SHALL fade out when the user scrolls back above the first heading.
7. **FR-7**: The breadcrumb bar SHALL have zero visual footprint on initial document load (invisible until scroll triggers it).
8. **FR-8**: Clicking anywhere on the breadcrumb bar SHALL open the outline HUD. The entire breadcrumb is a single click target; there are no individual segment click targets.

### Scroll-Spy

9. **FR-9**: The system SHALL track which heading the viewport is currently within by observing scroll position changes.
10. **FR-10**: The current heading SHALL be the last heading whose rendered position is at or above the viewport's top edge.
11. **FR-11**: The breadcrumb path SHALL include the full ancestor chain from the current heading up to the root (e.g., if the current heading is `### Foo` under `## Bar` under `# Top`, the path is "Top > Bar > Foo").

### Outline HUD

12. **FR-12**: Pressing Cmd+J SHALL open the outline HUD, expanding from the breadcrumb bar's position.
13. **FR-13**: The outline HUD SHALL display the full heading tree with indentation reflecting heading levels.
14. **FR-14**: The current heading (from scroll-spy) SHALL be visually highlighted in the HUD on open.
15. **FR-15**: Arrow keys (Up/Down) SHALL navigate between headings in the HUD.
16. **FR-16**: Typing characters SHALL fuzzy-filter the heading list using fzf-style matching: characters match in order but not necessarily adjacent (e.g., "morch" matches "Migration Orchestrator").
17. **FR-17**: Enter SHALL jump to the selected heading and dismiss the HUD.
18. **FR-18**: Escape SHALL dismiss the HUD without navigating.
19. **FR-19**: Clicking a heading in the HUD SHALL jump to it and dismiss the HUD.
20. **FR-20**: The HUD SHALL dismiss when clicking outside of it.
21. **FR-21**: When the HUD opens, it SHALL auto-scroll its internal heading list to the current heading (from scroll-spy) so that the user's position is immediately visible.
22. **FR-22**: The Cmd+J menu item SHALL be disabled (greyed out) when the current document has no headings.

### Animation

23. **FR-23**: The HUD SHALL expand downward from the breadcrumb bar with a spring animation (the breadcrumb grows into the HUD).
24. **FR-24**: On dismiss, the HUD SHALL collapse back into the breadcrumb bar (reverse of the expand animation).
25. **FR-25**: With Reduce Motion enabled, transitions SHALL use `reducedCrossfade` or `reducedInstant` instead of spring animations[^animation-primitives].

### Theme & Accessibility

26. **FR-26**: The breadcrumb bar and HUD SHALL use `.ultraThinMaterial` background, matching the find bar's frosted-glass aesthetic[^find-bar-pattern].
27. **FR-27**: Text colors SHALL derive from the current `AppTheme`'s `ThemeColors` (foreground, foregroundSecondary).
28. **FR-28**: The Cmd+J shortcut SHALL be registered in `MkdnCommands` and accessible via the View menu.

> **Cross-refs:** If this section changes, MUST also update:
> - architecture.md § "Component Design" (component responsibilities map to these requirements)
> - architecture.md § "Flow Diagrams" (flows implement these requirements)

## User Experience

### Breadcrumb Bar (Resting State)

The breadcrumb bar is invisible on document load. When the user scrolls past the first heading, it fades in at the top of the content area. It shows the current heading path as text segments separated by chevrons:

```
  Component Design  ›  Migration Orchestrator
```

The bar uses `.ultraThinMaterial` with the same frosted-glass aesthetic as the find bar. It is thin and unobtrusive -- a single line of text with minimal padding. Clicking anywhere on the breadcrumb bar opens the outline HUD (the entire bar is a single click target).

### Outline HUD (Active State)

When Cmd+J is pressed, the breadcrumb bar expands downward into a larger overlay showing the full heading tree. The HUD is a scrollable list with:

- Headings indented by level (h1 flush left, h2 indented 1 level, etc.)
- The current heading highlighted with an accent background
- A text input at the top for fuzzy filtering
- Keyboard focus immediately in the filter field

```
┌─────────────────────────────────────────────┐
│ 🔍 Filter headings...                       │
├─────────────────────────────────────────────┤
│ Overview                                     │
│   System Context                             │
│   ■ Component Design                         │  ← current heading
│     Migration Orchestrator                   │
│     State Manager                            │
│     Event Bus                                │
│   Data Model                                 │
│   API Changes                                │
│   Flow Diagrams                              │
│   Error Handling                              │
│   Testing Strategy                           │
│   Implementation Plan                        │
└─────────────────────────────────────────────┘
```

The HUD is sized to fit the heading count, up to a maximum height (~60% of the viewport), beyond which it scrolls internally.

### Keyboard Interaction

| Key | Action |
|-----|--------|
| Cmd+J | Toggle outline HUD |
| Up/Down Arrow | Navigate headings |
| Characters | Filter headings (fuzzy) |
| Enter | Jump to selected heading, dismiss HUD |
| Escape | Dismiss HUD without navigating |

## Success Metrics

1. **Functional**: User can navigate from any point in a 30-heading document to any heading in under 3 seconds (Cmd+J → type 2-3 chars → Enter).
2. **Visual**: Breadcrumb bar is invisible on load, visible only when scrolled past first heading.
3. **Performance**: Heading tree extraction and scroll-spy updates complete in under 1ms for documents with 50+ headings.
4. **Accessibility**: Full functionality preserved with Reduce Motion enabled (animations degraded gracefully).
5. **Theme**: Correct rendering in both Solarized Light and Solarized Dark themes.
6. **Comprehension**: The HUD heading tree is readable as a structural overview -- indentation, heading levels, and hierarchy are immediately clear without requiring any interaction beyond opening the HUD.

## Resolved Questions

All open questions have been resolved. See `working/questions.md` for the full decision record.

1. **Breadcrumb click behavior:** Click anywhere on the breadcrumb opens the HUD. No segment-specific navigation. (→ FR-8)
2. **HUD auto-scroll to current heading:** Yes, auto-scroll on open. (→ FR-21)
3. **No headings behavior:** Disable the Cmd+J menu item. (→ FR-22)
4. **Fuzzy matching level:** Full fzf-style fuzzy matching (characters match in order, not necessarily adjacent). (→ FR-16)

## Standing Assumptions

All assumptions identified during specification were resolved through codebase research and user decisions. This plan is sound assuming:

1. **TextKit 2 lazy layout provides heading positions near the viewport.** The scroll-spy reads `layoutFragmentFrame` positions for headings at or above the viewport top. These fragments are always in the laid-out region because TextKit 2 lays out content up to and including the visible area. If a heading fragment is not yet laid out, the scroll-spy skips that update and waits for the next scroll event (documented in error handling).

2. **Heading text extracted via `String(attributedString.characters)` produces usable display text.** This pattern is already used in `MarkdownBlock.id` and is proven in the codebase.

[^animation-primitives]: [Animation Primitives](research/animation-primitives.md)
[^find-bar-pattern]: [Find Bar Overlay Pattern](research/find-bar-overlay-pattern.md)
