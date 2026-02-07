# Requirements: terminal-consistent-theming

**Source PRD**: `.rp1/work/prds/terminal-consistent-theming.md`
**Status**: Approved

## Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Introduce a `ThemeMode` enum with cases `.auto`, `.solarizedDark`, `.solarizedLight`. | Must |
| FR-2 | In `.auto` mode, resolve the active `AppTheme` from `@Environment(\.colorScheme)`. | Must |
| FR-3 | Persist `ThemeMode` across launches using `@AppStorage` (key: `"themeMode"`). | Must |
| FR-4 | Default new installs to `.auto`. | Must |
| FR-5 | Update `ThemePickerView` to a three-segment picker: Auto / Dark / Light. | Must |
| FR-6 | Update `cycleTheme()` to cycle through the three modes. | Must |
| FR-7 | When appearance changes at OS level while in `.auto`, resolved theme updates immediately across all rendered content (markdown, code blocks, Mermaid). | Must |
| FR-8 | Keyboard shortcut for theme cycling continues to work (existing Cmd+T binding). | Must |

## Non-Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-1 | Theme switch must feel instantaneous (< 16ms for color swap; Mermaid re-render may be async). | Must |
| NFR-2 | No flash of wrong theme at launch -- resolve mode before first paint. | Must |
| NFR-3 | Zero new dependencies. Uses only SwiftUI `colorScheme` environment value and `UserDefaults`. | Must |
| NFR-4 | Backwards-compatible: users who never touch the setting get the same Solarized variant they had before matching their OS appearance. | Should |
| NFR-5 | SwiftLint and SwiftFormat clean. | Must |

## User Stories

1. As a user, I want the app to automatically match my macOS dark/light appearance so I don't have to configure themes manually.
2. As a user, I want to pin a specific theme (Dark or Light) regardless of my system appearance.
3. As a user, I want my theme preference to persist across app restarts.
4. As a user, I want the theme to switch live when I change my macOS appearance without restarting the app.
5. As a user, I want to cycle through theme modes with Cmd+T.

## Scope Boundaries

### In Scope
- ThemeMode enum (auto/dark/light)
- Auto-resolution from macOS colorScheme
- @AppStorage persistence
- ThemePickerView update to three-segment
- cycleTheme() update to cycle three modes
- Mermaid cache invalidation on theme change
- Live switching on OS appearance change

### Out of Scope
- New theme families beyond Solarized
- Terminal emulator color scheme detection
- Per-file/per-window theme overrides
- Custom user-defined color palettes
- Theme import/export

## Affected Components

| Component | File | Change Type |
|-----------|------|-------------|
| ThemeMode enum | `mkdn/UI/Theme/ThemeMode.swift` (new) | New file |
| AppState | `mkdn/App/AppState.swift` | Modify: themeMode + resolvedTheme |
| AppTheme | `mkdn/UI/Theme/AppTheme.swift` | No change needed |
| ThemePickerView | `mkdn/Features/Theming/ThemePickerView.swift` | Modify: three-segment picker |
| ContentView | `mkdn/App/ContentView.swift` | Modify: colorScheme bridge |
| MkdnApp (entry) | `mkdnEntry/main.swift` | Possibly: colorScheme bridge at root |
| MermaidRenderer | `mkdn/Core/Mermaid/MermaidRenderer.swift` | Review: cache key includes theme |
| Tests | `mkdnTests/Unit/` | New + modified test files |
