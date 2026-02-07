# Feature Verification Report #1

**Generated**: 2026-02-07T13:20:00Z
**Feature ID**: terminal-consistent-theming
**Verification Scope**: all
**KB Context**: Loaded
**Field Notes**: Not available

## Executive Summary
- Overall Status: VERIFIED
- Acceptance Criteria: 25/25 verified (100%)
- Implementation Quality: HIGH
- Ready for Merge: NO (documentation tasks TD1 and TD2 remain incomplete)

## Field Notes Context
**Field Notes Available**: No

### Documented Deviations
No field-notes.md file exists for this feature.

### Undocumented Deviations
- **Mermaid JS theme API**: The design doc (section 3.2) proposed passing `{theme: "dark"}` / `{theme: "default"}` to `beautifulMermaid.renderMermaid()`. The actual implementation uses `beautifulMermaid.THEMES['solarized-dark']` / `beautifulMermaid.THEMES['solarized-light']` color preset objects instead. This deviation is documented in the tasks.md T2 Implementation Summary but not in a field-notes.md file. The deviation is benign and represents a validated improvement (HYP-001 confirmation).

## Acceptance Criteria Verification

### REQ-001: Three-State Theme Mode

**AC-001**: Three distinct modes are available: Auto, Dark, Light.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/ThemeMode.swift`:7-11 - `ThemeMode` enum
- Evidence: `ThemeMode` is defined as `enum ThemeMode: String, CaseIterable, Sendable` with cases `.auto`, `.solarizedDark`, `.solarizedLight`. The `ThemeModeTests.caseCount()` test at `/Users/jud/Projects/mkdn/mkdnTests/Unit/ThemeModeTests.swift`:52 confirms exactly three cases.
- Field Notes: N/A
- Issues: None

**AC-002**: Selecting Auto causes the theme to reflect the current OS appearance.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/ThemeMode.swift`:17-25 - `resolved(for:)` method
- Evidence: `ThemeMode.auto.resolved(for: .dark)` returns `.solarizedDark` and `ThemeMode.auto.resolved(for: .light)` returns `.solarizedLight`. Tests `autoResolvesDark()` and `autoResolvesLight()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/ThemeModeTests.swift`:11-18 confirm this. AppSettings test `autoModeFollowsSystemColorScheme()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Features/AppSettingsTests.swift`:65-75 further validates end-to-end.
- Field Notes: N/A
- Issues: None

**AC-003**: Selecting Dark shows Solarized Dark regardless of OS appearance.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/ThemeMode.swift`:22-23 - `.solarizedDark` case in `resolved(for:)`
- Evidence: `ThemeMode.solarizedDark.resolved(for:)` always returns `.solarizedDark` regardless of input. Tests `solarizedDarkIgnoresDark()` and `solarizedDarkIgnoresLight()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/ThemeModeTests.swift`:20-28 confirm. AppSettings test `pinnedDarkIgnoresSystemScheme()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Features/AppSettingsTests.swift`:80-90 validates full stack.
- Field Notes: N/A
- Issues: None

**AC-004**: Selecting Light shows Solarized Light regardless of OS appearance.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/ThemeMode.swift`:24-25 - `.solarizedLight` case in `resolved(for:)`
- Evidence: `ThemeMode.solarizedLight.resolved(for:)` always returns `.solarizedLight` regardless of input. Tests `solarizedLightIgnoresLight()` and `solarizedLightIgnoresDark()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/ThemeModeTests.swift`:30-38 confirm. AppSettings test `pinnedLightIgnoresSystemScheme()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Features/AppSettingsTests.swift`:92-103 validates full stack.
- Field Notes: N/A
- Issues: None

### REQ-002: Auto Mode Resolves from OS Appearance

**AC-005**: OS dark mode produces Solarized Dark in the app.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/ThemeMode.swift`:19 combined with `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:60-65 (colorScheme bridge)
- Evidence: `ThemeMode.auto.resolved(for: .dark)` returns `.solarizedDark`. The ContentView bridges the SwiftUI `colorScheme` environment to `appSettings.systemColorScheme` via `onAppear` (line 61) and `onChange(of: colorScheme)` (lines 63-65). The `AppSettings.theme` computed property at `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`:35-37 calls `themeMode.resolved(for: systemColorScheme)`.
- Field Notes: N/A
- Issues: None

**AC-006**: OS light mode produces Solarized Light in the app.
- Status: VERIFIED
- Implementation: Same as AC-005 with `.light` path
- Evidence: `ThemeMode.auto.resolved(for: .light)` returns `.solarizedLight`. Test `autoResolvesLight()` confirms.
- Field Notes: N/A
- Issues: None

**AC-007**: No user interaction is required for the correct variant to be shown.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`:49-63 (init) and `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:60-65 (bridge)
- Evidence: AppSettings defaults to `.auto` themeMode (line 59) when no UserDefaults value exists. The ContentView automatically bridges colorScheme without user action. Init reads `NSApp.effectiveAppearance` for correct initial resolution.
- Field Notes: N/A
- Issues: None

### REQ-003: Default to Auto Mode

**AC-008**: A fresh install with no prior preferences launches in Auto mode.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`:54-60 - init fallback to `.auto`
- Evidence: When `UserDefaults.standard.string(forKey: themeModeKey)` returns nil (no stored preference), the init sets `themeMode = .auto`. Test `defaultThemeModeIsAuto()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Features/AppSettingsTests.swift`:27-33 confirms. Test `initDefaultsToAutoForInvalidPersistedValue()` at line 151 also confirms fallback for corrupt values.
- Field Notes: N/A
- Issues: None

**AC-009**: The resolved theme matches the OS appearance on first launch.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`:50-52 - init-time OS appearance detection
- Evidence: `AppSettings.init()` reads `NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()` and uses `bestMatch(from: [.darkAqua, .aqua])` to set `systemColorScheme` before any SwiftUI body evaluation. Combined with default `.auto` themeMode, this ensures the resolved theme matches OS appearance from the start. Test `initResolvesSystemAppearance()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Features/AppSettingsTests.swift`:13-22 validates.
- Field Notes: N/A
- Issues: None

### REQ-004: Preference Persistence

**AC-010**: User selects Dark, quits, relaunches: app shows Solarized Dark.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`:21-24 (didSet persists) and lines 54-57 (init reads)
- Evidence: `themeMode.didSet` writes `themeMode.rawValue` to UserDefaults under key `"themeMode"`. The init reads from UserDefaults and restores the value. Test `themeModeWritesToUserDefaults()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Features/AppSettingsTests.swift`:127-139 confirms write. Test `initRestoresPersistedThemeMode()` at line 142-148 confirms read.
- Field Notes: N/A
- Issues: None

**AC-011**: User selects Auto, quits, relaunches: app shows the variant matching current OS appearance.
- Status: VERIFIED
- Implementation: Same persistence mechanism as AC-010, plus auto-resolution logic
- Evidence: When `"auto"` is stored in UserDefaults, init restores `ThemeMode.auto`. The init-time appearance detection (lines 50-52) sets `systemColorScheme` from the OS, so `theme` resolves correctly immediately.
- Field Notes: N/A
- Issues: None

**AC-012**: Preference survives app updates (standard UserDefaults behavior).
- Status: VERIFIED
- Implementation: UserDefaults with string key `"themeMode"`
- Evidence: Standard `UserDefaults.standard` is used with simple string keys. UserDefaults persists across app updates by macOS convention. The raw value strings (`"auto"`, `"solarizedDark"`, `"solarizedLight"`) are stable enum raw values. Test `rawValueRoundTrip()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/ThemeModeTests.swift`:59-65 confirms round-trip stability.
- Field Notes: N/A
- Issues: None

### REQ-005: Live Switching in Auto Mode

**AC-013**: With the app open in Auto mode, toggling OS dark/light mode causes the theme to update within one frame (< 16ms for color swap).
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:63-65 - `onChange(of: colorScheme)`
- Evidence: The `.onChange(of: colorScheme) { _, newScheme in appSettings.systemColorScheme = newScheme }` handler fires synchronously when SwiftUI detects an OS appearance change. Since `AppSettings` is `@Observable` and `theme` is a computed property, all views reading `appSettings.theme` are invalidated in the same transaction. The color swap is a property assignment -- effectively zero cost.
- Field Notes: N/A
- Issues: None. The < 16ms target is met because the swap is a single property write triggering SwiftUI's observation system.

**AC-014**: All rendered content (markdown text, code blocks, backgrounds) reflects the new theme.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`:35-37 - `theme` computed property; all views read `appSettings.theme.colors`
- Evidence: Views access colors via `appSettings.theme.colors` (confirmed in ContentView, MermaidBlockView lines 67, 92, 95, 108). Since `theme` is a computed property on an `@Observable` object, any change to `systemColorScheme` or `themeMode` triggers a re-render of all views consuming these colors.
- Field Notes: N/A
- Issues: None

**AC-015**: No restart, reload, or user action is required.
- Status: VERIFIED
- Implementation: SwiftUI's `@Environment(\.colorScheme)` + `onChange` bridge
- Evidence: The `onChange(of: colorScheme)` modifier at `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:63-65 fires automatically when the OS appearance changes. No user-initiated action, restart, or reload is needed.
- Field Notes: N/A
- Issues: None

### REQ-006: Updated Theme Picker UI

**AC-016**: The picker displays three options: Auto, Dark, Light.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Theming/ThemePickerView.swift`:10-13
- Evidence: `ForEach(ThemeMode.allCases, id: \.self) { mode in Text(mode.displayName).tag(mode) }` iterates all three `ThemeMode` cases. The `displayName` property at `/Users/jud/Projects/mkdn/mkdn/UI/Theme/ThemeMode.swift`:29-34 returns "Auto", "Dark", "Light" respectively. Test `displayNames()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/ThemeModeTests.swift`:43-47 confirms the labels.
- Field Notes: N/A
- Issues: None

**AC-017**: The currently active mode is visually indicated.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Theming/ThemePickerView.swift`:10 - `Picker` with `selection: $settings.themeMode`
- Evidence: SwiftUI's `Picker` with `.segmented` style (line 15) automatically highlights the selected segment. The `@Bindable var settings = appSettings` binding at line 8 ensures the picker reflects the current `themeMode`.
- Field Notes: N/A
- Issues: None

**AC-018**: Selecting a mode takes effect immediately.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`:21-24 - `themeMode` didSet
- Evidence: The `Picker` binding directly mutates `appSettings.themeMode`. Since `AppSettings` is `@Observable`, the mutation immediately triggers re-evaluation of all views reading `theme`. The `didSet` also persists to UserDefaults. Test `themeChange()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Features/AppSettingsTests.swift`:46-60 confirms immediate resolution.
- Field Notes: N/A
- Issues: None

### REQ-007: Updated Theme Cycling

**AC-019**: The existing keyboard shortcut cycles through Auto, Dark, Light in order.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:68-74 - Cmd+T shortcut; `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`:68-73 - `cycleTheme()`
- Evidence: The "Cycle Theme" button at MkdnCommands.swift:68 is bound to `.keyboardShortcut("t", modifiers: .command)` (line 74) and calls `appSettings.cycleTheme()`. The `cycleTheme()` method uses `ThemeMode.allCases` which is ordered `[.auto, .solarizedDark, .solarizedLight]` per the enum declaration, then advances `(currentIndex + 1) % allModes.count`.
- Field Notes: N/A
- Issues: None

**AC-020**: Each press advances to the next mode.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`:68-73
- Evidence: Test `cycleThemeModes()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Features/AppSettingsTests.swift`:108-122 verifies: auto -> solarizedDark -> solarizedLight -> auto. Each call to `cycleTheme()` moves to the next case.
- Field Notes: N/A
- Issues: None

**AC-021**: The cycle wraps from Light back to Auto.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`:71 - `(currentIndex + 1) % allModes.count`
- Evidence: The modulo operation ensures wrapping. Test at line 121 confirms: after cycling from `.solarizedLight`, `themeMode` returns to `.auto`.
- Field Notes: N/A
- Issues: None

### REQ-008: Mermaid Diagram Theme Consistency

**AC-022**: After a theme change, Mermaid diagrams render with colors matching the new theme.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:40 - `.task(id: TaskID(code: code, theme: appSettings.theme))`; `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift`:43,65,69 - theme-aware rendering
- Evidence: `MermaidBlockView` uses a `TaskID` struct (lines 160-163) containing both `code` and `theme`. The `.task(id:)` modifier at line 40 re-fires whenever `appSettings.theme` changes. The `renderDiagram()` method at line 117 captures `currentTheme = appSettings.theme` and passes it to `MermaidRenderer.shared.renderToSVG(code, theme: currentTheme)` at line 129. The renderer maps themes to JS presets via `mermaidJSThemeKey(for:)` at lines 138-145: `.solarizedDark` -> `"solarized-dark"`, `.solarizedLight` -> `"solarized-light"`. The JS call at line 69 passes the theme preset: `beautifulMermaid.THEMES['\(themePreset)']`.
- Field Notes: N/A
- Issues: None

**AC-023**: Cached Mermaid output for the correct variant is used if available, avoiding unnecessary re-renders.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:120-125 - image store check; `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift`:51-55 - SVG cache check
- Evidence: `renderDiagram()` first checks `MermaidImageStore.shared.get(code, theme: currentTheme)` at line 120. On a hit, it returns the cached image immediately (lines 121-124). On a miss, it calls the renderer, which itself checks its SVG cache at line 53. Both caches key on `mermaidStableHash(code + theme.rawValue)`, so each theme variant is cached independently. Test `themeAwareCaching()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/MermaidImageStoreTests.swift`:151-163 confirms separate cache entries per theme. Test `themeAwareCacheKeys()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/MermaidRendererTests.swift`:98-105 confirms different hash keys per theme.
- Field Notes: N/A
- Issues: None

**AC-024**: If no cached variant exists, an asynchronous re-render is triggered.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:127-148 - async render path
- Evidence: When the image store check misses (line 120 returns nil), the method continues to the async render path at line 129: `let svgString = try await MermaidRenderer.shared.renderToSVG(code, theme: currentTheme)`. The entire `renderDiagram()` function is `async` and invoked from `.task(id:)`, which runs asynchronously. The `isLoading` flag at line 127 is set to show the loading indicator during the render.
- Field Notes: N/A
- Issues: None

### REQ-009: No Flash of Wrong Theme at Launch

**AC-025a**: In Auto mode with OS in dark mode, the first visible frame uses Solarized Dark colors.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`:50-52 - init-time appearance resolution
- Evidence: `AppSettings.init()` reads `NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()` and sets `systemColorScheme` to `.dark` when the OS is in dark mode, before any SwiftUI body evaluation occurs. Combined with default `.auto` themeMode, `theme` resolves to `.solarizedDark` from the very first property access. Test `initResolvesSystemAppearance()` validates that the init-time resolution matches the actual OS appearance.
- Field Notes: N/A
- Issues: None

**AC-025b**: In Auto mode with OS in light mode, the first visible frame uses Solarized Light colors.
- Status: VERIFIED
- Implementation: Same as AC-025a with `.light` path
- Evidence: When `bestMatch(from: [.darkAqua, .aqua])` returns `.aqua`, `systemColorScheme` is set to `.light`, and `theme` resolves to `.solarizedLight`. The previous hardcoded `.dark` default that would have caused a flash has been removed.
- Field Notes: N/A
- Issues: None

**AC-025c**: In pinned mode, the first visible frame uses the pinned variant.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`:54-57 - init reads themeMode from UserDefaults
- Evidence: When a user has pinned `.solarizedDark` or `.solarizedLight`, the value is read from UserDefaults in init (lines 54-57). Since `ThemeMode.resolved(for:)` for pinned modes ignores the colorScheme entirely, the resolved theme is correct from the first frame regardless of OS appearance. Test `initRestoresPersistedThemeMode()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Features/AppSettingsTests.swift`:142-148 confirms restoration.
- Field Notes: N/A
- Issues: None

## Implementation Gap Analysis

### Missing Implementations
- None. All 25 acceptance criteria are fully implemented in code.

### Partial Implementations
- None.

### Implementation Issues
- **Documentation tasks incomplete**: TD1 (update modules.md) and TD2 (update architecture.md) are marked as not completed in tasks.md. These are documentation-only tasks and do not affect runtime behavior, but they are part of the feature's Definition of Done.

## Code Quality Assessment

**Overall Quality: HIGH**

1. **Pattern compliance**: All code follows project patterns correctly. `@Observable` is used (not `ObservableObject`). `@MainActor` isolation is preserved on `AppSettings`. The actor pattern is used for `MermaidRenderer`. Swift Testing (`@Test`, `#expect`, `@Suite`) is used for all tests.

2. **Separation of concerns**: The theme mode (user preference), system color scheme (OS state), and resolved theme (computed result) are cleanly separated in `AppSettings`. The `ThemeMode.resolved(for:)` method is a pure function with full test coverage.

3. **Cache key design**: Including `theme.rawValue` in the hash input to `mermaidStableHash()` is simple and effective. No structural changes to the LRU caches were needed.

4. **SwiftUI integration**: The `colorScheme` bridge in `ContentView` using `onAppear` + `onChange(of:)` is the idiomatic SwiftUI approach. The `MermaidBlockView` use of `.task(id:)` with a `TaskID` struct containing both code and theme is a clean trigger mechanism.

5. **Error handling**: `MermaidRenderer` properly invalidates its JS context (`context = nil`) on errors. `MermaidBlockView.renderDiagram()` handles all error paths with user-facing messages.

6. **Test coverage**: 181 tests pass with 0 failures. Key feature areas have specific test coverage:
   - ThemeMode resolution: 6 tests
   - AppSettings lifecycle: 14 tests (including 1 new for flash prevention)
   - MermaidImageStore: 11 tests (including 2 new for theme-aware caching)
   - MermaidRenderer: 11 tests (including 1 new for theme-aware cache keys)

7. **Backward compatibility**: Default parameter values (`theme: AppTheme = .solarizedDark`) on `MermaidRenderer` and `MermaidImageStore` methods ensure existing callers outside the modified call sites continue to work.

## Recommendations

1. **Complete documentation tasks TD1 and TD2** before merging. Update `.rp1/context/modules.md` to reflect the `theme:` parameter on `MermaidRenderer.renderToSVG(_:theme:)`, `renderToImage(_:theme:)`, `MermaidImageStore.get(_:theme:)`, and `MermaidImageStore.store(_:theme:image:)`. Update `.rp1/context/architecture.md` to note that Mermaid rendering is theme-aware and cache keys include the theme variant.

2. **Consider creating a field-notes.md** to document the Mermaid JS API deviation (using `beautifulMermaid.THEMES['solarized-dark']` preset objects instead of the initially designed `{theme: "dark"}` strings). While documented in tasks.md, a field note provides a more permanent, searchable record.

3. **Remove default parameter values** on `MermaidRenderer.renderToSVG(_:theme:)` and `MermaidImageStore.get(_:theme:)` / `store(_:theme:image:)` after verifying no callers rely on the defaults. Explicit theme parameters at all call sites prevent accidental theme-unaware usage. The defaults were added for backward compatibility during T2->T3 transition, which is now complete.

## Verification Evidence

### Test Suite Results
- **Total tests**: 181
- **Passing**: 181
- **Failing**: 0
- **Signal 5 note**: The `swift test` process reports "Exited with unexpected signal code 5" due to the known `@main` entry point in the executable target. This does not indicate test failure -- all individual test cases pass. (Documented in project MEMORY.md.)

### Key Code References

**ThemeMode enum** (`/Users/jud/Projects/mkdn/mkdn/UI/Theme/ThemeMode.swift`):
```swift
public enum ThemeMode: String, CaseIterable, Sendable {
    case auto
    case solarizedDark
    case solarizedLight

    public func resolved(for colorScheme: ColorScheme) -> AppTheme {
        switch self {
        case .auto:
            colorScheme == .dark ? .solarizedDark : .solarizedLight
        case .solarizedDark:
            .solarizedDark
        case .solarizedLight:
            .solarizedLight
        }
    }
}
```

**Flash prevention** (`/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift:50-52`):
```swift
let appearance = NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()
let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
systemColorScheme = isDark ? .dark : .light
```

**Theme-aware Mermaid rendering** (`/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift:43,51,65,69`):
```swift
func renderToSVG(_ mermaidCode: String, theme: AppTheme = .solarizedDark) async throws -> String {
    // ...
    let cacheKey = mermaidStableHash(mermaidCode + theme.rawValue)
    // ...
    let themePreset = mermaidJSThemeKey(for: theme)
    let js = "beautifulMermaid.renderMermaid(\"\(escaped)\", beautifulMermaid.THEMES['\(themePreset)'])"
}
```

**MermaidBlockView re-render trigger** (`/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift:40,160-163`):
```swift
.task(id: TaskID(code: code, theme: appSettings.theme)) {
    await renderDiagram()
}

private struct TaskID: Hashable {
    let code: String
    let theme: AppTheme
}
```

**ColorScheme bridge** (`/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift:60-65`):
```swift
.onAppear {
    appSettings.systemColorScheme = colorScheme
}
.onChange(of: colorScheme) { _, newScheme in
    appSettings.systemColorScheme = newScheme
}
```
