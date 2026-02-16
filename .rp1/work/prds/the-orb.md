# PRD: The Orb

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-10

## Surface Overview

The Orb is a unified, stateful indicator system that replaces the current two separate orbs (DefaultHandlerHintView at top-right and FileChangeOrbView at bottom-right) with a single orb fixed in the bottom-right corner of the window. The orb communicates application state through color transitions:

- **Violet** -- Default app handler prompt (shown once on first launch, permanently dismissed after user responds)
- **Subtle orange** -- File changed on disk, offering reload with an in-context option to enable automatic reloading
- **Green** -- App update available (placeholder for future infrastructure)
- **Hidden** -- No actionable state; the orb is not visible

The existing `OrbVisual` three-layer rendering (outer halo, mid-glow, inner core) is reused with animated color crossfades between states. The orb occupies a single fixed position (bottom-right, `padding(8)`) and transitions between states based on a priority hierarchy.

## Scope

### In Scope

- **Unified orb component** (`TheOrbView`) replacing `FileChangeOrbView` and `DefaultHandlerHintView` with a single state-machine-driven view
- **Color-coded states**: violet (default handler), orange (file changed), green (update placeholder)
- **Tap-to-popover interaction** with contextual actions per state
- **State priority**: file-change (orange) supersedes default-handler (violet) supersedes update (green)
- **"Always reload when no unsaved changes" user preference** persisted in UserDefaults, toggled from within the file-changed popover
- **Auto-reload with single-pulse acknowledgment**: when the preference is enabled and `hasUnsavedChanges == false`, the orb appears orange, completes one full breathing cycle (~5s), then auto-reloads and dismisses
- **Animated color crossfade** when transitioning between orb states
- **Removal of old views**: delete `FileChangeOrbView.swift` and `DefaultHandlerHintView.swift`; consolidate `ContentView.swift` orb logic into a single overlay

### Out of Scope

- Actual app update checking infrastructure (green state is visual placeholder only -- no update server, no version checking)
- Notification center or system alert integration
- Sound or haptic feedback
- Orb as a persistent always-visible element (hidden when no actionable state)
- Badge counts or numeric indicators on the orb
- Settings screen or preferences window for the auto-reload toggle (discovered in-context only)

## Requirements

### Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Single `TheOrbView` component with an enum-driven state machine: `.idle` (hidden), `.defaultHandler` (violet), `.fileChanged` (orange), `.updateAvailable` (green) | Must |
| FR-2 | State priority ordering: `.fileChanged` > `.defaultHandler` > `.updateAvailable` > `.idle`. The highest-priority active state determines the orb's appearance. | Must |
| FR-3 | **Violet state**: tap shows popover asking "Would you like to make mkdn your default Markdown reader?" with Yes/No buttons. Yes calls `DefaultHandlerService.registerAsDefault()`. Either choice permanently dismisses via `AppSettings.hasShownDefaultHandlerHint`. | Must |
| FR-4 | **Orange state (manual reload)**: tap shows popover "This file has changed. Would you like to reload?" with Yes/No buttons. Yes calls `documentState.reloadFile()`. Popover includes an "Always reload when unchanged" toggle for FR-6. | Must |
| FR-5 | **Orange state (auto-reload)**: when the auto-reload preference is enabled and `documentState.hasUnsavedChanges == false`, the orb appears orange, completes one full breathing cycle (~5s based on `AnimationConstants.breathe`), then calls `documentState.reloadFile()` and dismisses automatically. | Must |
| FR-6 | **"Always reload" preference**: a new `Bool` property on `AppSettings`, persisted to UserDefaults. Toggled via a control inside the file-changed popover (FR-4). When enabled, file changes trigger auto-reload (FR-5) instead of manual prompt (FR-4), provided there are no unsaved changes. | Must |
| FR-7 | **Auto-reload guard**: if `documentState.hasUnsavedChanges == true`, the auto-reload preference is ignored and the orb falls back to manual reload behavior (FR-4), protecting unsaved work. | Must |
| FR-8 | **Pulse cycle cancellation**: if the user taps the orb during an auto-reload pulse cycle (FR-5), cancel the auto-reload timer and present the manual popover (FR-4) instead. | Should |
| FR-9 | **Green state (placeholder)**: orb appears green when triggered. Tap shows informational popover (e.g., "An update is available."). No backend action. Triggering mechanism is a placeholder for future update-checking infrastructure. | Could |
| FR-10 | **Color crossfade**: animated transition between orb colors when state changes, using `AnimationConstants.crossfade` timing. | Must |
| FR-11 | Orb positioned fixed bottom-right with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)` and `.padding(8)`, tight to the corner to avoid overlapping page content. | Must |
| FR-12 | Remove `FileChangeOrbView.swift` and `DefaultHandlerHintView.swift`. Update `ContentView.swift` to use the single unified `TheOrbView` overlay. | Must |

### Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| NFR-1 | All animations respect `accessibilityReduceMotion`. When Reduce Motion is enabled, continuous pulse animations are replaced with static opacity states, and crossfades use `AnimationConstants.reducedCrossfade` (0.15s). |
| NFR-2 | Color transitions render correctly in both Solarized Dark and Solarized Light themes. The orange and green orb colors must be chosen for sufficient contrast against both theme backgrounds. |
| NFR-3 | Reuses existing `OrbVisual` three-layer rendering component. No new visual primitives are introduced; the orb's appearance is controlled solely by the `color` parameter passed to `OrbVisual`. |
| NFR-4 | Auto-reload pulse timing derived from `AnimationConstants.breathe` (2.5s half-cycle). One full cycle = ~5s. Timer precision is not critical but should be within 500ms of the animation duration. |
| NFR-5 | State transitions must handle rapid file-change events gracefully. If the file changes multiple times during a pulse cycle, the orb resets its cycle rather than queuing multiple reloads. |

## Dependencies & Constraints

### Dependencies

| Dependency | Type | Purpose |
|------------|------|---------|
| `OrbVisual.swift` | Internal component | Three-layer orb rendering (halo, mid-glow, inner core). Already parameterized by `color`, `isPulsing`, `isHaloExpanded`. |
| `DocumentState` | Internal state | Provides `isFileOutdated`, `hasUnsavedChanges`, `reloadFile()`, `loadFile(at:)`. The orb reads state from here. |
| `AppSettings` | Internal state | Provides `hasShownDefaultHandlerHint` (existing). Must be extended with new `alwaysReloadWhenUnchanged` Bool property. |
| `DefaultHandlerService` | Internal service | Provides `registerAsDefault()` and `isDefault()` for the violet state action. No changes needed. |
| `FileWatcher` | Internal service | Drives `DocumentState.isFileOutdated` via kernel-level `DispatchSource`. No changes needed. |
| `AnimationConstants` | Internal constants | Provides `breathe`, `haloBloom`, `fadeIn`, `fadeOut`, `crossfade`, `orbGlowColor`, `fileChangeOrbColor`. Must be extended with new orange and green color constants. |

### Constraints

- **Single orb instance**: only one `TheOrbView` exists per window. The state machine must be the sole arbiter of what the orb displays; no external view should conditionally show/hide the orb (that logic moves inside `TheOrbView`).
- **Timer lifecycle**: the auto-reload timer (FR-5) must be cancelled when the document is closed, when the user taps the orb, or when the file-outdated state clears (e.g., user reloads via Cmd+R).
- **Color constant naming**: new orb colors must follow the established pattern in `AnimationConstants` (e.g., `orbFileChangedColor`, `orbUpdateColor`) with Solarized-derived values.
- **No new dependencies**: this feature uses only existing frameworks (SwiftUI, AppKit for `NSCursor`). No new SPM packages.
- **Charter alignment**: the charter specifies "subtle outdated indicator with manual reload prompt (not auto-reload)." The auto-reload preference is an opt-in extension of this design, not a default behavior. The preference defaults to `false`.

## Milestones & Timeline

| Phase | Milestone | Deliverables | Estimated Effort |
|-------|-----------|-------------|------------------|
| Phase 1: Core Unification | Unified orb with state machine | New `TheOrbView` with `.idle`, `.defaultHandler`, `.fileChanged` states; orb state machine enum; violet and orange popover interactions (FR-1 through FR-4, FR-11); removal of old views (FR-12); `ContentView` updated | 3-4 hours |
| Phase 2: Auto-Reload | Single-pulse auto-reload behavior | `AppSettings.alwaysReloadWhenUnchanged` property (FR-6); auto-reload pulse cycle with timer (FR-5); unsaved changes guard (FR-7); pulse cancellation on tap (FR-8); toggle in file-changed popover | 2-3 hours |
| Phase 3: Polish & Placeholder | Color crossfade + green state | Animated color transitions between states (FR-10); green update placeholder state (FR-9); new color constants in `AnimationConstants`; Reduce Motion testing (NFR-1); theme testing (NFR-2) | 1-2 hours |

No external deadlines. Phases can be implemented incrementally.

## Open Questions

| ID | Question | Context |
|----|----------|---------|
| OQ-1 | What triggers the green (update available) state? This is a placeholder -- should it be driven by a future `UpdateService`, a manual flag, or a compile-time constant for testing? | FR-9 specifies placeholder only |
| OQ-2 | Should the "always reload" toggle in the popover be a checkbox, a small text link ("Always reload"), or a third button alongside Yes/No? | UX detail for FR-4/FR-6 |
| OQ-3 | When the auto-reload preference is enabled and the user has unsaved changes, should the popover mention that auto-reload is paused because of unsaved changes? | FR-7 guard behavior communication |

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A1 | `OrbVisual` can smoothly animate its `color` parameter via SwiftUI's built-in `Color` interpolation when wrapped in `withAnimation` | Color transition may appear as a hard cut rather than a crossfade; would need a custom interpolation or two-orb crossfade approach | Design Philosophy: obsessive sensory detail |
| A2 | A single ~5s pulse cycle provides sufficient visual acknowledgment before auto-reloading | Users may miss the flash and be confused by content changing; may need a longer pulse or a brief post-reload indicator | Charter: calm feedback, no modal alerts |
| A3 | The auto-reload preference defaulting to `false` satisfies the charter's "manual reload prompt" requirement | If users expect auto-reload out of the box, the preference discovery path (inside the popover) may be too hidden | Charter: file-change detection with manual reload prompt |
| A4 | State priority (orange > violet > green) covers all realistic concurrent conditions without edge cases | Rapid state changes (e.g., file changes during default-handler popover) could cause visual glitches if transitions are not debounced | Design Philosophy: animations feel physical and natural |
