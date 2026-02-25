# Theming

## Overview

mkdn ships two Solarized color schemes -- Dark and Light -- and a three-state mode
selector (Auto / Dark / Light) that determines which scheme is active. Auto mode
follows the macOS system appearance in real time; pinned modes lock to a specific
variant regardless of the OS setting. The preference defaults to Auto on first
launch and persists across sessions via UserDefaults.

## User Experience

- **First launch**: Auto mode. The app matches the OS appearance with zero
  configuration. The correct variant is resolved before the first visible frame
  (no flash of wrong colors).
- **Live switching**: When the OS toggles dark/light while the app is open in Auto
  mode, all colors update immediately with a 0.35s crossfade (or 0.15s when
  Reduce Motion is active).
- **Manual override**: Pinning Dark or Light locks the variant. OS appearance
  changes are ignored until the user returns to Auto.
- **Keyboard cycling** (Cmd+T): Cycles through the three modes but skips any mode
  that resolves to the same visual output as the current one. On a dark system,
  Auto and Dark both resolve to Solarized Dark, so cycling jumps directly from
  Auto to Light (and vice versa). This prevents a no-op keypress that changes
  the mode label without changing any colors.
- **Print**: A separate `PrintPalette` (white background, black text) is applied
  automatically during Cmd+P. It is not user-selectable.

## Architecture

```
ThemeMode (.auto | .solarizedDark | .solarizedLight)
    |
    |  resolved(for: systemColorScheme) -> AppTheme
    v
AppTheme (.solarizedDark | .solarizedLight)
    |
    +-- .colors   -> ThemeColors   (13 semantic tokens)
    +-- .syntaxColors -> SyntaxColors (13 syntax tokens)
```

**Data flow**:

1. `ContentView` reads `@Environment(\.colorScheme)` and writes it to
   `AppSettings.systemColorScheme` on appear and on change.
2. `AppSettings.theme` is a computed property: `themeMode.resolved(for: systemColorScheme)`.
3. All views read `appSettings.theme.colors` / `appSettings.theme.syntaxColors`
   for rendering. SwiftUI re-evaluates bodies when the resolved theme changes.

**Flash prevention**: `AppSettings.init()` reads `NSApp.effectiveAppearance`
(falling back to `NSAppearance.currentDrawing()`) to initialize `systemColorScheme`
before the SwiftUI environment bridge fires. This ensures the first frame is
correct.

## Implementation Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Color token struct | Single `ThemeColors` populated per-variant | One struct, two static instances. Views never branch on which theme is active -- they read tokens. Adding a theme means adding one more static instance. |
| Mode persistence | `ThemeMode.rawValue` in UserDefaults (`"themeMode"` key) | Lightweight, no migration needed. Invalid stored values fall back to `.auto`. |
| Cycle skip-no-op | `cycleTheme()` walks `ThemeMode.allCases` and skips candidates whose `resolved(for:)` matches the current visual theme | Prevents a dead keypress. The user always sees a visual change on each Cmd+T press. |
| Crossfade animation | `AnimationConstants.crossfade` (0.35s easeInOut) | Long enough to perceive as a smooth transition, short enough to feel responsive. Reduce Motion substitutes `reducedCrossfade` (0.15s). |
| Init-time appearance | `NSApp.effectiveAppearance` in `AppSettings.init()` | Available by the time SwiftUI `App.init()` runs on macOS 14+. Eliminates the one-frame flash that would occur if we waited for `onAppear`. |

## Files

| File | Role |
|------|------|
| `mkdn/UI/Theme/AppTheme.swift` | `AppTheme` enum. Two cases, each mapping to a `ThemeColors` and `SyntaxColors`. |
| `mkdn/UI/Theme/ThemeMode.swift` | `ThemeMode` enum (auto/solarizedDark/solarizedLight). `resolved(for:)` maps mode + system scheme to `AppTheme`. Display names for picker UI. |
| `mkdn/UI/Theme/ThemeColors.swift` | `ThemeColors` struct (13 semantic color tokens) and `SyntaxColors` struct (13 syntax tokens). |
| `mkdn/UI/Theme/SolarizedDark.swift` | Static `ThemeColors` and `SyntaxColors` instances using Solarized Dark hex values. |
| `mkdn/UI/Theme/SolarizedLight.swift` | Static instances for Solarized Light. |
| `mkdn/UI/Theme/PrintPalette.swift` | Print-only palette. White/black, ink-efficient. Applied during Cmd+P, not user-selectable. |
| `mkdn/UI/Theme/AnimationConstants.swift` | `crossfade` (0.35s) and `reducedCrossfade` (0.15s) primitives used for theme transitions. |
| `mkdn/UI/Theme/MotionPreference.swift` | Reduce Motion resolver. Maps `.crossfade` primitive to standard or reduced animation. |
| `mkdn/App/AppSettings.swift` | `@Observable` central state. Owns `themeMode`, `systemColorScheme`, computed `theme`. Contains `cycleTheme()` with skip-no-op logic. Persists mode to UserDefaults. |
| `mkdn/App/ContentView.swift` | Bridges `@Environment(\.colorScheme)` to `AppSettings.systemColorScheme`. Wraps the update in a crossfade animation. |

## Dependencies

- **Internal**: `AppSettings` is the single source of truth. Every view that renders themed content reads `appSettings.theme`. `MkdnCommands` wires Cmd+T to `cycleTheme()`.
- **External**: None. All colors are defined inline using `SwiftUI.Color` RGB initializers. Solarized hex values come from the canonical spec (ethanschoonover.com/solarized).
- **Platform**: macOS 14.0+. Uses `NSApp.effectiveAppearance` and `NSAppearance.currentDrawing()` for init-time appearance detection.

## Testing

| Test file | Coverage |
|-----------|----------|
| `mkdnTests/Unit/UI/ThemeModeTests.swift` | `resolved(for:)` for all mode/scheme combinations. Display names. Case count. RawValue round-trip for persistence. |
| `mkdnTests/Unit/Core/ThemeTests.swift` | Both `AppTheme` cases provide populated `ThemeColors` and `SyntaxColors`. Enumerable case count. |
| `mkdnTests/Unit/Features/AppSettingsTests.swift` | Init-time appearance resolution (no hardcoded default). Auto mode follows system scheme. Pinned modes ignore system changes. `cycleTheme()` skip-no-op on dark and light systems. UserDefaults persistence round-trips for all modes. |
| `mkdnTests/Unit/Core/MermaidThemeMapperTests.swift` | Solarized-to-Mermaid color variable mapping for both themes. JSON output validity. All 26 required Mermaid keys present. Dark/light produce distinct values. |
