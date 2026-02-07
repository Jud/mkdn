# PRD: Terminal-Consistent Theming

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-06

## Surface Overview

Terminal-consistent theming enables mkdn to automatically select the correct Solarized variant (Dark or Light) based on the macOS system appearance setting. Today, the app has both `SolarizedDark` and `SolarizedLight` palettes defined and a manual picker/cycle mechanism (`cycleTheme()`, `ThemePickerView`), but the user must switch manually. This feature adds an **auto mode** that follows `@Environment(\.colorScheme)` so the theme matches the user's OS-level dark/light preference at launch and responds live when the system appearance changes -- exactly the way a developer's terminal already behaves with Solarized.

The user may also override auto mode and pin a specific variant. The selected preference (auto, dark, or light) persists across launches.

## Scope

### In Scope
- **Auto mode**: New default that maps macOS `ColorScheme.dark` to `SolarizedDark` and `ColorScheme.light` to `SolarizedLight`.
- **Manual override**: User can pin Dark or Light regardless of system appearance.
- **Preference persistence**: Store the user's choice (auto / dark / light) via `@AppStorage` or `UserDefaults` so it survives app restarts.
- **Live switching**: When in auto mode, respond immediately to macOS appearance changes (no restart required).
- **UI update**: Revise `ThemePickerView` and/or `cycleTheme()` to expose the three-state choice (Auto, Dark, Light).
- **Mermaid re-render**: Ensure Mermaid diagrams re-render (or use the correct cached variant) when the theme switches.

### Out of Scope
- Adding new theme families beyond Solarized.
- Auto-detecting the user's terminal emulator color scheme.
- Per-file or per-window theme overrides.
- Custom user-defined color palettes.
- Theme import/export.

## Requirements

### Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Introduce a `ThemeMode` enum with cases `.auto`, `.solarizedDark`, `.solarizedLight`. | Must |
| FR-2 | In `.auto` mode, resolve the active `AppTheme` from `@Environment(\.colorScheme)`. | Must |
| FR-3 | Persist `ThemeMode` across launches using `@AppStorage` (key: `"themeMode"`). | Must |
| FR-4 | Default new installs to `.auto`. | Must |
| FR-5 | Update `ThemePickerView` to a three-segment picker: Auto / Dark / Light. | Must |
| FR-6 | Update `cycleTheme()` to cycle through the three modes. | Must |
| FR-7 | When appearance changes at the OS level while in `.auto`, the resolved theme updates immediately across all rendered content (markdown, code blocks, Mermaid). | Must |
| FR-8 | Keyboard shortcut for theme cycling continues to work (existing binding). | Must |

### Non-Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-1 | Theme switch must feel instantaneous (< 16ms for color swap; Mermaid re-render may be async). | Must |
| NFR-2 | No flash of wrong theme at launch -- resolve mode before first paint. | Must |
| NFR-3 | Zero new dependencies. Uses only SwiftUI `colorScheme` environment value and `UserDefaults`. | Must |
| NFR-4 | Backwards-compatible: users who never touch the setting get the same Solarized Dark they had before if their OS is in dark mode (and Light if in light mode). | Should |
| NFR-5 | SwiftLint and SwiftFormat clean. | Must |

## Dependencies & Constraints

### Internal Dependencies
| Component | File(s) | Impact |
|-----------|---------|--------|
| `AppTheme` enum | `mkdn/UI/Theme/AppTheme.swift` | Add `ThemeMode` enum or extend `AppTheme` with auto-resolution logic. |
| `AppState.theme` | `mkdn/App/AppState.swift` | Change from `AppTheme` to `ThemeMode`; add computed `resolvedTheme: AppTheme`. |
| `ThemePickerView` | `mkdn/Features/Theming/ThemePickerView.swift` | Update picker to three-segment. |
| `cycleTheme()` | `mkdn/App/AppState.swift` | Cycle through `ThemeMode.allCases`. |
| `MermaidRenderer` | `mkdn/Core/Mermaid/MermaidRenderer.swift` | May need cache key that includes theme, or invalidation on theme change. |
| Views consuming `appState.theme.colors` | Multiple view files | No change needed if they read `resolvedTheme` (or `theme` is made a computed that resolves). |

### External Dependencies
None. This feature uses only built-in SwiftUI and Foundation APIs.

### Constraints
- Must remain compatible with macOS 14.0+.
- `@Observable` pattern (not `ObservableObject`) per project rules.
- `@MainActor` isolation on `AppState` must be preserved.
- The `colorScheme` environment value is only available inside SwiftUI views; the resolution bridge from environment to `AppState` needs to happen at the view layer (e.g., an `.onChange(of: colorScheme)` modifier near the root).

## Milestones

| Phase | Deliverable |
|-------|-------------|
| 1 -- Model | Add `ThemeMode` enum, update `AppState` with `themeMode` property and `resolvedTheme` computed, add `@AppStorage` persistence. |
| 2 -- Auto Resolution | Wire `colorScheme` environment to `AppState` via root-level `.onChange` modifier. Verify live switching. |
| 3 -- UI | Update `ThemePickerView` to three-segment, update `cycleTheme()`. |
| 4 -- Mermaid Cache | Ensure Mermaid cache keys include theme variant; verify re-render on switch. |
| 5 -- Test & Polish | Unit tests for `ThemeMode` resolution logic, manual QA of launch-time correctness and live switching. SwiftLint/SwiftFormat pass. |

## Open Questions

| ID | Question | Context |
|----|----------|---------|
| OQ-1 | Should the mode overlay (breathing orb transition label) display "Auto (Dark)" or just "Dark" when in auto mode? | UX clarity vs. simplicity. |
| OQ-2 | Should Mermaid diagrams animate their theme transition or simply re-render? | Design philosophy says animations deserve care, but this may be over-engineering for v1. |

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A-1 | macOS `colorScheme` environment updates synchronously when System Preferences changes appearance. | Could cause a brief flash of stale theme. Mitigation: test on macOS 14+. | Design Philosophy |
| A-2 | Mermaid SVG cache can be keyed by theme variant without excessive memory. | Two cached copies per diagram. Acceptable for typical document sizes. | Scope Guardrails |
| A-3 | Users who previously defaulted to Solarized Dark will now get auto mode, which resolves to Dark if their OS is in dark mode -- effectively no visible change. | If a user had OS in light mode but preferred Dark manually, they would see a one-time change. Low risk for personal daily-driver use. | Success Criteria |
