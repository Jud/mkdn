# PRD: Controls

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-06

## Surface Overview

The Controls surface defines mkdn's interaction model: a chrome-less, keyboard-driven, zen-like control philosophy. The app presents no persistent toolbar, no floating buttons, and no visible UI chrome. All navigation and actions are driven by keyboard shortcuts and macOS menu bar commands. Visual feedback is delivered through ultra-minimal indicators — a breathing orb for file changes, ephemeral overlays for mode transitions — designed with the obsessive micro-detail described in the charter's Design Philosophy. The goal is a meditative reading experience where controls are felt, not seen.

This surface replaces the current toolbar-based interaction model entirely. The macOS menu bar serves as the discovery layer for users learning shortcuts, but the primary interaction path is always the keyboard.

## Scope

### In Scope

- **Remove toolbar entirely**: Eliminate `ViewModePicker` toolbar item and any toolbar modifiers from `ContentView`. The window should contain only rendered content.
- **Keyboard shortcuts as primary control layer**:
  - `Cmd+1` — Preview-only mode
  - `Cmd+2` — Side-by-side edit + preview mode
  - `Cmd+R` — Reload file from disk
  - `Cmd+O` — Open file (NSOpenPanel)
  - `Cmd+T` — Cycle theme (Solarized Dark / Light)
- **macOS menu bar as discovery layer**: Expand `MkdnCommands` to expose all keyboard shortcuts in standard macOS menu structure (View, File, etc.) so users can discover bindings through the menu.
- **Breathing orb indicator**: Redesign `OutdatedIndicator` from a badge/text indicator to a tiny glowing orb. Pulsing animation timed to human breathing rate (~12 cycles/min, ~5 seconds per cycle). No text label. Positioned in a corner of the content area. Dissolves smoothly when the user reloads.
- **Ephemeral mode transition overlays**: When switching between preview-only and side-by-side modes, display a brief overlay label (e.g., "Preview" or "Edit") that springs in and fades out. Animation uses SwiftUI spring timing for entrance and linear fade for exit.
- **Obsessive animation tuning**: Every animation — the orb pulse, the overlay transitions, mode switches, theme changes — receives the same level of care described in the charter's Design Philosophy. Timing curves, durations, and easing are tuned to feel physical and natural.

### Out of Scope

- On-screen buttons or floating action controls
- Context menus or right-click interactions (may be a future surface)
- Touch Bar support
- Custom key binding configuration or remapping
- Accessibility voiceover for indicators (future surface — important but separate)
- Preferences window or settings UI

## Requirements

### Functional Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-1 | Keyboard shortcuts are the primary interaction layer | P0 | Cmd+1/2 (modes), Cmd+R (reload), Cmd+O (open), Cmd+T (theme) |
| FR-2 | macOS menu bar exposes all shortcuts for discoverability | P0 | Expand `MkdnCommands.swift` with View, File menu groups |
| FR-3 | Toolbar is completely removed from ContentView | P0 | No `.toolbar {}` modifiers, no `ViewModePicker` in window chrome |
| FR-4 | Breathing orb replaces `OutdatedIndicator` text badge | P0 | Tiny glowing circle, corner-positioned, no text |
| FR-5 | Orb pulses at breathing rate (~12 cycles/min) | P1 | ~5s per cycle, smooth sinusoidal opacity/scale animation |
| FR-6 | Orb dissolves on reload (Cmd+R) | P0 | Fade-out + scale-down, not an abrupt hide |
| FR-7 | Ephemeral overlay appears on mode switch | P1 | Shows mode name, spring-in entrance, fade-out exit |
| FR-8 | Overlay auto-dismisses after ~1.5 seconds | P1 | No user action required to dismiss |
| FR-9 | Theme cycling via Cmd+T transitions smoothly | P1 | Crossfade between color palettes, not an instant swap |

### Non-Functional Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| NFR-1 | All animations run at 60fps on macOS 14+ | P0 | No dropped frames during orb pulse or mode transitions |
| NFR-2 | Keyboard shortcut response time < 50ms | P0 | Instant feel, no perceptible delay |
| NFR-3 | Orb indicator uses minimal CPU when idle | P1 | SwiftUI animation system, not manual timer loops |
| NFR-4 | No accessibility regressions from toolbar removal | P1 | Menu bar items remain accessible to VoiceOver |
| NFR-5 | Animation timing constants are centralized | P2 | Single source of truth for all durations/curves, easy to tune |

## Dependencies & Constraints

### Internal Dependencies

| Component | File | Impact |
|-----------|------|--------|
| AppState | `mkdn/App/AppState.swift` | Add properties for indicator visibility, mode transition state |
| MkdnCommands | `mkdn/App/MkdnCommands.swift` | Expand with full View/File menu groups and keyboard shortcuts |
| ContentView | `mkdn/App/ContentView.swift` | Remove all `.toolbar {}` modifiers, add overlay layers for orb and mode label |
| OutdatedIndicator | `mkdn/UI/Components/OutdatedIndicator.swift` | Redesign entirely — badge becomes breathing orb |
| ViewModePicker | `mkdn/UI/Components/ViewModePicker.swift` | Remove or repurpose (no longer rendered in toolbar) |

### Framework Dependencies

| Framework | Usage |
|-----------|-------|
| SwiftUI Animations | Spring timing, opacity/scale keyframe animations for orb and overlays |
| SwiftUI `.keyboardShortcut()` | Binding Cmd+key combinations to menu commands |
| AppKit NSOpenPanel | File open dialog (existing, no change) |

### External Dependencies

None. No new SPM packages required. All animation and control behavior uses built-in SwiftUI and AppKit APIs.

### Constraints

- **macOS 14.0+**: Minimum deployment target. Animation APIs must be available on Sonoma.
- **Swift 6 concurrency**: All state mutations through `@MainActor`-isolated `AppState`. Animation state must respect actor isolation.
- **No WKWebView**: Absolute constraint from charter. All indicators and overlays are native SwiftUI views.
- **Toolbar removal is a breaking change**: The current `ViewModePicker` toolbar item is the only way to switch modes today. Keyboard shortcuts and menu commands must be in place *before* the toolbar is removed. This dictates Phase 1 ordering.

## Milestones & Timeline

### Phase 1: Foundation
**Goal**: Replace toolbar with keyboard + menu controls. App remains fully functional with no toolbar.

| Task | Description |
|------|-------------|
| 1.1 | Expand `MkdnCommands` with View menu (Cmd+1, Cmd+2), File menu (Cmd+O, Cmd+R), and Theme menu (Cmd+T) |
| 1.2 | Wire all keyboard shortcuts to `AppState` actions |
| 1.3 | Remove `.toolbar {}` from `ContentView` and delete or archive `ViewModePicker` |
| 1.4 | Verify all functionality is accessible via keyboard and menu bar |

### Phase 2: Zen Indicators
**Goal**: Introduce breathing orb and ephemeral overlays.

| Task | Description |
|------|-------------|
| 2.1 | Redesign `OutdatedIndicator` as breathing orb — glowing circle with sinusoidal pulse animation (~12 cycles/min) |
| 2.2 | Position orb in content area corner, no text label |
| 2.3 | Implement dissolve animation on reload |
| 2.4 | Build ephemeral mode transition overlay — spring-in, auto-dismiss after ~1.5s, fade-out |
| 2.5 | Add smooth crossfade for theme cycling |

### Phase 3: Polish
**Goal**: Obsessive animation tuning. Every detail receives the care described in the Design Philosophy.

| Task | Description |
|------|-------------|
| 3.1 | Centralize all animation timing constants (durations, curves, spring parameters) |
| 3.2 | Tune orb glow color, size, opacity range, and pulse curve until it feels like breathing |
| 3.3 | Tune overlay spring stiffness, damping, and fade duration until mode switches feel physical |
| 3.4 | Test edge cases: rapid mode switching, reload during animation, theme change during orb pulse |
| 3.5 | Verify 60fps on target hardware, profile animation performance |
| 3.6 | Evaluate discoverability — can a new user figure out Cmd+1/2 within 30 seconds via the menu bar? |

## Open Questions

| ID | Question | Impact | Status |
|----|----------|--------|--------|
| OQ-1 | What color should the breathing orb be? (Orange was mentioned, but should it match or contrast the active theme?) | Visual design | Open |
| OQ-2 | Should the orb position be configurable (corner preference) or fixed? | Implementation complexity | Open |
| OQ-3 | Should there be a subtle startup animation or should the app open instantly into content? | First-run experience | Open |
| OQ-4 | How should drag-and-drop file opening interact with the chrome-less philosophy? (Currently supported, no visual indicator needed?) | Interaction design | Open |

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A-1 | macOS menu bar provides sufficient discoverability for keyboard shortcuts | Users may never discover key bindings and feel lost | Scope Guardrails |
| A-2 | Breathing-rate animation (~12 cycles/min) will feel calming rather than distracting | Orb may feel anxious or annoying; will need tuning | Design Philosophy |
| A-3 | Removing the toolbar is a net positive for the zen experience | Some users may prefer visible mode toggle; menu bar mitigates this | Design Philosophy |
| A-4 | SwiftUI's built-in animation system is sufficient for the orb glow effect | May need custom `TimelineView` or `Canvas` for precise glow rendering | Success Criteria |
| A-5 | Five keyboard shortcuts (Cmd+1/2/R/O/T) are enough for daily-driver use | May need additional shortcuts as features grow | Success Criteria |
