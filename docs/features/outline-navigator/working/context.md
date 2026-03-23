# Feature: Document Outline Navigator

## Status
- **Phase:** Approved
- **Last Updated:** 2026-03-21
- **Confidence:** High

## Current Understanding (Ground Truth)

### Feature Description

A unified breadcrumb-bar / outline-HUD component that provides document structure navigation for Markdown files. It has two visual states that are animated forms of the same element:

**State 1 — Breadcrumb Bar (resting).** A thin, chromeless bar that fades in when the user scrolls past the first heading. Displays the current heading path (e.g. "Component Design > Migration Orchestrator"). Invisible at document load; zero footprint when not needed.

**State 2 — Outline HUD (active).** Triggered by Cmd+J. The breadcrumb bar expands downward into a frosted-glass overlay (`.ultraThinMaterial`) showing the full heading tree. Keyboard-navigable with arrow keys, type-to-filter (fuzzy), Enter/click to jump, Escape to dismiss. On selection or dismiss, the HUD collapses back into the breadcrumb bar via a reverse animation.

The transition between states is a single fluid animation — the HUD grows spatially out of the breadcrumb, giving it a reason to exist in that location.

### Motivation

The user works with long architecture documents (600-843 lines, 25-30+ headings at ## and ### depth). Maintaining inline TOCs is a document-level hack; outline navigation is a viewer concern. mkdn's chromeless philosophy means this must be unobtrusive — no permanent panel, no sidebar consumption, no visual weight when not in use.

The outline serves two distinct purposes: **navigation** (jumping to a specific section) and **comprehension** (understanding the overall shape and organization of a document at a glance). A reader opening an unfamiliar document should be able to press Cmd+J and immediately see how the document is structured — how many major sections there are, how deeply nested the hierarchy goes, and where the bulk of the content lives — without needing to scroll or interact further.

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Keyboard shortcut | **Cmd+J** | Unobtrusive letter; Cmd+Shift+O is taken (Open Directory). Cmd+E, Cmd+F, Cmd+R, Cmd+T, Cmd+L all taken. |
| Overlay style | `.ultraThinMaterial` frosted glass | Doesn't push content; feels native macOS; consistent with chromeless aesthetic. |
| Placement | Top of document view, above content | Breadcrumb appears at top; HUD expands downward from it. Not a sidebar, not a panel. |
| Data source | Existing `MarkdownVisitor` heading parse | Headings already extracted as `MarkdownBlock.heading(level:text:)` in the rendering pipeline. No new parsing needed. |
| Scroll tracking | New scroll-spy mechanism | Must track which heading the viewport is currently within, to populate the breadcrumb path. |
| Breadcrumb visibility | Fade-in on scroll past first heading | Invisible on load; appears only when document has been scrolled, matching the "out of the way" philosophy. |
| Two-state model | Single component, two visual states | Not two separate views. The breadcrumb IS the HUD in collapsed form. Animation connects them spatially. |
| Navigation model | Command-palette style | Arrow keys traverse the heading tree; typing filters headings (fuzzy); Enter jumps and dismisses; Escape dismisses without navigation. |

### Constraints

1. **SwiftUI only** — no AppKit overlays beyond what's already used (NSTextView via `SelectableTextView`).
2. **`@Observable`** — all state must use the `@Observable` macro, not `ObservableObject`.
3. **Swift Testing** — unit tests use `@Test`, `#expect`, `@Suite`.
4. **SwiftLint strict mode** — must pass lint before commit.
5. **macOS 14.0+** — can use any API available in Sonoma.
6. **Accessibility** — must respect Reduce Motion (`MotionPreference`). With Reduce Motion, breadcrumb/HUD transitions should use `reducedCrossfade` or `reducedInstant` from `AnimationConstants`.
7. **Two-target layout** — all source goes in `mkdnLib` (under `mkdn/`), tests in `mkdnTests/`, tests import `@testable import mkdnLib`.
8. **No permanent screen real estate** — the feature must have zero visual footprint when not actively used.

### Scope

**In scope:**
- Heading tree extraction from already-parsed `[IndexedBlock]` (filtering `.heading` cases)
- Scroll-spy to track current heading position in the viewport
- Breadcrumb bar view (shows heading path, fades in/out based on scroll position)
- Outline HUD overlay (full heading tree, keyboard navigation, fuzzy filter)
- Breadcrumb-to-HUD expand/collapse animation
- Cmd+J keyboard shortcut registration in `MkdnCommands`
- Scroll-to-heading on selection (programmatic scroll to target heading block)
- Theme support (both Solarized Light and Solarized Dark)
- Reduce Motion support via `MotionPreference`
- Unit tests for heading tree extraction, scroll-spy logic, and filter logic

**Out of scope:**
- Heading anchors / deep-link URLs
- Editing headings from the outline
- Reordering document sections
- Persistent outline panel / right sidebar
- iOS support (macOS-only feature initially)
- Changes to the Markdown parsing pipeline itself

## Codebase Integration Points

### Existing infrastructure to leverage

| Component | Location | Relevance |
|-----------|----------|-----------|
| `MarkdownBlock.heading(level:text:)` | `mkdn/Core/Markdown/MarkdownBlock.swift:23` | Heading data already parsed; extract from `[IndexedBlock]` |
| `IndexedBlock` | `mkdn/Core/Markdown/MarkdownBlock.swift:78` | Carries block index + generation; index maps to scroll position |
| `MarkdownRenderer.render()` | `mkdn/Core/Markdown/MarkdownRenderer.swift` | Produces `[IndexedBlock]` that feeds the heading tree |
| `MarkdownPreviewView` | `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift` | Holds `renderedBlocks`; breadcrumb/HUD overlays attach here |
| `DocumentState` | `mkdn/App/DocumentState.swift` | Per-window `@Observable`; may host outline state or outline state may be standalone |
| `MkdnCommands` | `mkdn/App/MkdnCommands.swift` | Register Cmd+J shortcut here |
| `AnimationConstants` | `mkdn/UI/Theme/AnimationConstants.swift` | `springSettle`, `gentleSpring`, `fadeIn`, `fadeOut`, `quickFade`, `reducedCrossfade` |
| `MotionPreference` | `mkdn/UI/Theme/MotionPreference.swift` | Accessibility-aware animation resolution |
| `AppTheme` / `ThemeColors` | `mkdn/UI/Theme/` | Theme colors for breadcrumb/HUD styling |
| `BlockScrollTarget` | `mkdn/Core/Markdown/BlockScrollTarget.swift` | Existing programmatic scroll-to-block mechanism |
| `FindBarView` / `FindState` | `mkdn/Features/Viewer/` | Reference implementation for overlay + keyboard interaction pattern |
| `FocusedDocumentStateKey` | `mkdn/App/FocusedDocumentStateKey.swift` | Pattern for `@FocusedValue` access from menu commands |

### Taken keyboard shortcuts (confirmed from `MkdnCommands.swift`)

| Shortcut | Action |
|----------|--------|
| Cmd+W | Close window |
| Cmd+S | Save |
| Cmd+Shift+S | Save As |
| Cmd+F | Find |
| Cmd+G | Find Next |
| Cmd+Shift+G | Find Previous |
| Cmd+E | Use Selection for Find |
| Cmd+Shift+P | Page Setup |
| Cmd+P | Print |
| Cmd+O | Open File |
| Cmd+Shift+O | Open Directory |
| Cmd+R | Reload |
| Cmd++ | Zoom In |
| Cmd+- | Zoom Out |
| Cmd+0 | Actual Size |
| Cmd+Shift+L | Toggle Sidebar |
| Cmd+1 | Preview Mode |
| Cmd+2 | Edit Mode |
| Cmd+Shift+T | Cycle Theme |
| **Cmd+J** | **AVAILABLE — assigned to Outline Navigator** |

## Recent Changes & Verification Status

### [2026-03-21] Initial context brief created
- **Status:** VERIFIED
- **Impact:** Establishes ground truth for the Document Outline Navigator feature
- **Source:** User conversation — detailed verbal specification of breadcrumb bar, outline HUD, transition animation, keyboard shortcut, and design philosophy

### [2026-03-21] Revision: PRD missing comprehension-mode user stories
- **Status:** VERIFIED
- **Impact:** PRD user stories and requirements expanded to capture the "document comprehension" use case. Added two user stories (7, 8), a primary goal, and a success metric. Architecture overview and visual testing updated to reflect the dual-purpose nature (navigation + comprehension).
- **Source:** User review feedback

## Historical Context

The feature originated from the user's frustration maintaining manual tables of contents in long architecture documents (nodeup project, 600-843 line files with 25-30+ headings). The realization was that outline navigation is a viewer concern, not a document concern — the viewer already has the parsed heading tree and should expose it as a navigation tool.

The design philosophy follows mkdn's chromeless aesthetic: zero footprint when not in use, unobtrusive when visible, and spatially grounded (the HUD grows from the breadcrumb, not from nowhere). The interaction model draws from VS Code's "Go to Symbol" (Cmd+Shift+O) and Sublime Text's symbol list (Cmd+R) — a command-palette approach with keyboard navigation and fuzzy filtering.
