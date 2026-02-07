# Design: terminal-consistent-theming

## Architecture Overview

This feature introduces a `ThemeMode` layer between the user's preference and the resolved `AppTheme`. The architecture follows the existing MVVM pattern with state in `AppState` and SwiftUI environment bridging.

```
User Preference (ThemeMode)  -->  Resolution Logic  -->  AppTheme (resolved)
       |                              ^                        |
  @AppStorage                   colorScheme env           .colors / .syntaxColors
  (persisted)                   (from SwiftUI)            (used by views)
```

## Design Decisions

### DD-1: ThemeMode as separate enum (not extending AppTheme)
**Decision**: Create a new `ThemeMode` enum rather than adding `.auto` to `AppTheme`.
**Rationale**: `AppTheme` represents concrete, resolved themes with `colors` and `syntaxColors` properties. Adding `.auto` to it would require handling an unresolvable case in those computed properties. Keeping `ThemeMode` separate maintains clean separation: `ThemeMode` is a user preference, `AppTheme` is a resolved configuration.

### DD-2: colorScheme bridge at ContentView level
**Decision**: Place the `@Environment(\.colorScheme)` observation and `.onChange` bridge in `ContentView`, not in `MkdnApp`.
**Rationale**: `@Environment` is only available inside `View` bodies. `ContentView` is the root view where all child views inherit the environment. Placing the bridge here ensures the colorScheme is available and updates propagate to AppState immediately.

### DD-3: @AppStorage on AppState with @ObservationIgnored
**Decision**: Use a standalone `@AppStorage` in a view or a `UserDefaults` read in AppState init, persisting via `UserDefaults.standard` directly.
**Rationale**: `@AppStorage` is a SwiftUI property wrapper designed for views. In an `@Observable` class, we use `UserDefaults.standard` for persistence and expose `themeMode` as a regular property with a `didSet` that writes to UserDefaults. This avoids conflicts between `@Observable` and `@AppStorage`.

### DD-4: Mermaid cache invalidation on theme change
**Decision**: Clear the Mermaid SVG cache when the resolved theme changes, rather than keying cache entries by theme.
**Rationale**: The Mermaid SVGs themselves don't depend on theme (they're structural diagrams). The rendering pipeline produces theme-independent SVGs. No cache change needed -- the existing `.onChange(of: appState.theme)` in `MarkdownPreviewView` already re-renders all blocks including Mermaid when theme changes. The Mermaid cache key is based on diagram source text, which is theme-independent.

### DD-5: Resolved theme as computed property
**Decision**: `AppState.theme` becomes a computed property that resolves from `themeMode` and `systemColorScheme`.
**Rationale**: All existing views already reference `appState.theme.colors` and `appState.theme.syntaxColors`. Making `theme` a computed property that resolves from `themeMode` means zero changes to consuming views. The observable system will detect changes because the underlying stored properties (`themeMode` and `systemColorScheme`) are tracked.

## Component Design

### ThemeMode (new file: `mkdn/UI/Theme/ThemeMode.swift`)
```swift
public enum ThemeMode: String, CaseIterable, Sendable {
    case auto
    case solarizedDark
    case solarizedLight

    func resolved(for colorScheme: ColorScheme) -> AppTheme {
        switch self {
        case .auto:
            colorScheme == .dark ? .solarizedDark : .solarizedLight
        case .solarizedDark:
            .solarizedDark
        case .solarizedLight:
            .solarizedLight
        }
    }

    var displayName: String {
        switch self {
        case .auto: "Auto"
        case .solarizedDark: "Dark"
        case .solarizedLight: "Light"
        }
    }
}
```

### AppState Changes
- Replace `public var theme: AppTheme = .solarizedDark` with:
  - `public var themeMode: ThemeMode` (stored, persisted via UserDefaults)
  - `public var systemColorScheme: ColorScheme = .dark` (stored, updated from view)
  - `public var theme: AppTheme` (computed from themeMode + systemColorScheme)
- Update `cycleTheme()` to cycle `ThemeMode.allCases`
- Add UserDefaults persistence in init/didSet

### ContentView Changes
- Add `@Environment(\.colorScheme) private var colorScheme`
- Add `.onChange(of: colorScheme)` to bridge system appearance to `appState.systemColorScheme`
- Add `.onAppear` to set initial `systemColorScheme`

### ThemePickerView Changes
- Bind to `appState.themeMode` instead of `appState.theme`
- Use `ThemeMode.allCases` with `displayName` labels
- Three segments: Auto / Dark / Light

### MkdnCommands Changes
- `cycleTheme()` already called; no changes needed since it's updated in AppState

## Data Flow

1. **Launch**: `AppState.init()` reads `themeMode` from `UserDefaults` (defaults to `.auto`)
2. **First paint**: `ContentView.onAppear` sets `appState.systemColorScheme` from `@Environment(\.colorScheme)`
3. **OS appearance change**: SwiftUI updates `colorScheme` env -> `.onChange` fires -> updates `appState.systemColorScheme` -> computed `theme` changes -> views re-render
4. **Manual override**: User picks Dark/Light in picker -> `themeMode` changes -> persisted to UserDefaults -> computed `theme` changes -> views re-render
5. **Cmd+T cycle**: `cycleTheme()` cycles `themeMode` through `.auto -> .solarizedDark -> .solarizedLight -> .auto`

## Test Strategy

- Unit test `ThemeMode.resolved(for:)` for all combinations
- Unit test `cycleTheme()` cycles through three modes
- Unit test persistence round-trip via UserDefaults
- Unit test default state is `.auto` mode
- Existing `AppStateTests` updated to reflect new default behavior
