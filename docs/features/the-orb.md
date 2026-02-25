# The Orb

## Overview

The Orb is a unified, color-coded indicator anchored to the bottom-right corner of the window. It consolidates two previously separate UI elements -- the default-handler hint and the file-change indicator -- into a single stateful orb driven by a priority-ordered enum state machine. When no actionable state exists, the orb is hidden entirely. States communicate through color (violet for default handler, orange for file changed) and a breathing animation. Each state provides contextual actions via a tap-to-popover interaction.

## User Experience

- **Idle**: Orb is hidden. No visual presence.
- **Default handler (violet)**: Appears on first launch if mkdn is not the default Markdown reader. Tap opens a popover asking to register as default. Either choice (Yes/No) permanently dismisses the prompt.
- **File changed (orange)**: Appears when the open file is modified on disk. Tap opens a popover with reload Yes/No and an "Always reload when unchanged" toggle.
- **Auto-reload**: When the toggle is enabled and no unsaved changes exist, the orb appears orange, pulses through one breathing cycle (~5 seconds), then reloads automatically. Tapping during the pulse cancels auto-reload and shows the manual popover. If unsaved changes exist, auto-reload is suppressed and the manual popover is shown instead.
- **Priority ordering**: File changed (orange) always supersedes default handler (violet). Lower-priority states surface once higher-priority ones clear.
- **Transitions**: Color changes between states use animated crossfades. Appearance and disappearance use asymmetric transitions (fade-in on entry, scale-down + fade on removal).

## Architecture

The feature follows the project's self-contained SwiftUI component pattern -- no separate ViewModel. `TheOrbView` reads from `DocumentState` and `AppSettings` via `@Environment`, computes the highest-priority active state, and delegates rendering to the reusable `OrbVisual` three-layer component.

```
DocumentState ──┐
                 ├──▶ TheOrbView (state resolution, popover dispatch, auto-reload timer)
AppSettings ────┘          │
                           ▼
                       OrbVisual (outer halo, mid glow, inner core)
```

State resolution is a computed property that collects active states into an array and returns `.max()` (exploiting `Comparable` synthesis from enum case ordering). The auto-reload timer uses structured concurrency (`Task.sleep`) with cancellation on tap, disappear, or state change.

## Implementation Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| State machine host | Computed property in TheOrbView | Matches existing component patterns; state derivation is a pure function of environment objects. |
| Priority encoding | `Comparable` via enum case ordering (idle < defaultHandler < fileChanged) | Zero-cost, compiler-enforced. `.max()` returns the winner. |
| Auto-reload timer | `Task.sleep(for: .seconds(5))` | Structured concurrency with built-in cancellation. Consistent with the project's async patterns. |
| File-changed color | Solarized orange (`#cb4b16`) | Strong contrast on both themes. Signals urgency without alarm. |
| Default-handler color | Solarized violet (`#6c71c4`) | Calm, informational tone. Existing orb color. |
| Popover auto-reload control | SwiftUI `Toggle` with `.switch` style | Native, discoverable, compact. Progressive disclosure -- no separate settings screen. |
| Color crossfade | `withAnimation(.crossfade)` on `@State` color | SwiftUI interpolates Color within RadialGradient fills. No need to overlay two OrbVisuals. |
| Reduce Motion | Continuous pulse replaced with static opacity; crossfade uses reduced duration | Respects `accessibilityReduceMotion` environment value. |

## Files

**Core components:**
- `mkdn/UI/Components/OrbState.swift` -- Enum: `idle`, `defaultHandler`, `fileChanged`. Comparable, color mapping, visibility flag.
- `mkdn/UI/Components/TheOrbView.swift` -- Unified view: state resolution, popover dispatch per state, auto-reload Task timer, color crossfade, hover cursor, Reduce Motion integration.
- `mkdn/UI/Components/OrbVisual.swift` -- Reusable three-layer orb renderer (outer halo, mid glow, inner core). Parameterized by color, isPulsing, isHaloExpanded.

**Supporting components:**
- `mkdn/UI/Components/PulsingSpinner.swift` -- Mermaid loading indicator reusing the orb breathing aesthetic.
- `mkdn/UI/Components/UnsavedIndicator.swift` -- Breathing dot for unsaved-changes status (separate from The Orb).

**Modified during implementation:**
- `mkdn/App/AppSettings.swift` -- Added `autoReloadEnabled` Bool (UserDefaults-backed, defaults to false).
- `mkdn/UI/Theme/AnimationConstants.swift` -- Added `orbFileChangedColor` (orange) alongside existing `orbDefaultHandlerColor` (violet).
- `mkdn/App/ContentView.swift` -- Replaced two separate orb overlays with single `TheOrbView()`.

## Dependencies

| Dependency | Role |
|------------|------|
| `DocumentState` | Provides `isFileOutdated`, `hasUnsavedChanges`, `reloadFile()` |
| `AppSettings` | Provides `hasShownDefaultHandlerHint`, `autoReloadEnabled` |
| `DefaultHandlerService` | Checks/registers default Markdown handler |
| `FileWatcher` | Kernel-level file monitoring driving `isFileOutdated` |
| `AnimationConstants` | Color constants, animation primitives (`breathe`, `crossfade`, `haloBloom`) |
| `MotionPreference` | Resolves animation variants based on Reduce Motion setting |

No external SPM dependencies. Pure SwiftUI + existing app frameworks.

## Testing

**Unit tests** (`mkdnTests/Unit/UI/OrbStateTests.swift`):
- Priority ordering: `fileChanged > defaultHandler > idle`.
- `max()` resolution returns highest-priority state; empty array yields nil (falls back to `.idle`).
- Visibility: only `idle` returns `isVisible == false`.
- Color mapping: each state returns its correct `AnimationConstants` color; non-idle states have distinct colors.

**Not tested** (framework behavior): SwiftUI popover presentation, `withAnimation` color interpolation, `Task.sleep` cancellation mechanics, `UserDefaults` persistence.

**Visual verification**: Load a fixture, trigger file-change via external edit, capture screenshots in both Solarized themes to confirm orb color contrast, breathing animation, and popover layout.
