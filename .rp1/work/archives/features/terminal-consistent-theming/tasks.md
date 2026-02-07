# Development Tasks: Terminal-Consistent Theming

**Feature ID**: terminal-consistent-theming
**Status**: In Progress
**Progress**: 100% (7 of 7 tasks)
**Estimated Effort**: 2 days
**Started**: 2026-02-06

## Overview

Introduce a `ThemeMode` layer (auto/dark/light) between user preference and the resolved `AppTheme`. In auto mode, the app follows macOS appearance via `@Environment(\.colorScheme)`. Manual overrides persist via UserDefaults. All existing theme consumers (`appState.theme.colors`, `appState.theme.syntaxColors`) continue to work unchanged through a computed property resolution.

## Task Breakdown

### Core Types

- [x] **T1**: Create `ThemeMode` enum in `mkdn/UI/Theme/ThemeMode.swift` `[complexity:simple]`

    **Reference**: [design.md#component-design](design.md#component-design)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] New file `mkdn/UI/Theme/ThemeMode.swift` exists
    - [x] `ThemeMode` enum has cases `.auto`, `.solarizedDark`, `.solarizedLight`
    - [x] Conforms to `String`, `CaseIterable`, `Sendable`
    - [x] `resolved(for:)` method returns `.solarizedDark` for `.dark` colorScheme in auto mode
    - [x] `resolved(for:)` method returns `.solarizedLight` for `.light` colorScheme in auto mode
    - [x] `resolved(for:)` method returns the fixed theme for non-auto modes regardless of colorScheme
    - [x] `displayName` computed property returns "Auto", "Dark", "Light" respectively

    **Implementation Summary**:

    - **Files**: `mkdn/UI/Theme/ThemeMode.swift`
    - **Approach**: Created enum with three cases, `resolved(for:)` method, and `displayName` computed property matching design spec exactly
    - **Deviations**: None
    - **Tests**: Covered by T6

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

### State Management

- [x] **T2**: Modify `AppState` to use `ThemeMode` with resolved computed theme and UserDefaults persistence `[complexity:medium]`

    **Reference**: [design.md#appstate-changes](design.md#appstate-changes)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] `AppState.themeMode` is a stored `ThemeMode` property (replaces direct `theme` storage)
    - [x] `AppState.systemColorScheme` is a stored `ColorScheme` property defaulting to `.dark`
    - [x] `AppState.theme` is a computed property resolving via `themeMode.resolved(for: systemColorScheme)`
    - [x] `themeMode` persists to `UserDefaults.standard` with key `"themeMode"` on every change
    - [x] `AppState.init()` reads `themeMode` from UserDefaults, defaulting to `.auto` if absent
    - [x] `cycleTheme()` cycles through `.auto -> .solarizedDark -> .solarizedLight -> .auto`
    - [x] Existing views referencing `appState.theme.colors` and `appState.theme.syntaxColors` require zero changes
    - [x] Cmd+T keyboard shortcut continues to function through updated `cycleTheme()`

    **Implementation Summary**:

    - **Files**: `mkdn/App/AppState.swift`
    - **Approach**: Replaced stored `theme` property with `themeMode` (stored, persisted via UserDefaults `didSet`) + `systemColorScheme` (stored, bridged from environment) + `theme` (computed via `themeMode.resolved(for:)`). `init()` reads persisted mode from UserDefaults with `.auto` fallback. `cycleTheme()` iterates `ThemeMode.allCases` with modular index.
    - **Deviations**: None
    - **Tests**: Covered by T7

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

### UI Integration

- [x] **T3**: Add `colorScheme` environment bridge in `ContentView` `[complexity:simple]`

    **Reference**: [design.md#contentview-changes](design.md#contentview-changes)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] `ContentView` declares `@Environment(\.colorScheme) private var colorScheme`
    - [x] `.onAppear` sets `appState.systemColorScheme` from current `colorScheme` value
    - [x] `.onChange(of: colorScheme)` updates `appState.systemColorScheme` on OS appearance change
    - [x] No flash of wrong theme on launch (initial value set before first paint completes)
    - [x] Theme updates propagate immediately to all child views (markdown, code blocks, Mermaid)

    **Implementation Summary**:

    - **Files**: `mkdn/App/ContentView.swift`
    - **Approach**: Added `@Environment(\.colorScheme)` declaration, `.onAppear` initial bridge, and `.onChange(of: colorScheme)` for live OS appearance tracking
    - **Deviations**: None
    - **Tests**: UI-level behavior; verified by integration

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

- [x] **T4**: Update `ThemePickerView` to three-segment `ThemeMode` picker `[complexity:simple]`

    **Reference**: [design.md#themepickerview-changes](design.md#themepickerview-changes)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] Picker binds to `appState.themeMode` instead of `appState.theme`
    - [x] Three segments displayed: Auto / Dark / Light (using `ThemeMode.allCases` and `displayName`)
    - [x] Selecting a segment immediately updates the resolved theme
    - [x] Picker style remains consistent with existing toolbar appearance

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Theming/ThemePickerView.swift`
    - **Approach**: Bound picker to `$state.themeMode` with `ForEach(ThemeMode.allCases)` using `displayName` labels; `.segmented` picker style
    - **Deviations**: None
    - **Tests**: UI-level behavior; verified by integration

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

### Verification and Testing

- [x] **T5**: Verify Mermaid re-render behavior on theme change `[complexity:simple]`

    **Reference**: [design.md#design-decisions](design.md#design-decisions)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] Confirm existing `.onChange(of: appState.theme)` in `MarkdownPreviewView` triggers re-render on theme change
    - [x] Mermaid SVG cache remains keyed by diagram source text (theme-independent per DD-4)
    - [x] No new cache invalidation logic needed; document verification in code comment if appropriate
    - [x] Theme switch with visible Mermaid diagram does not crash or produce stale rendering

    **Implementation Summary**:

    - **Files**: No files modified (verification-only task)
    - **Approach**: Audited `MarkdownPreviewView.swift`, `MermaidBlockView.swift`, `MermaidRenderer.swift`, and `MermaidCache.swift`. Confirmed `.onChange(of: appState.theme)` in `MarkdownPreviewView` re-renders all blocks on theme change. `MermaidBlockView` reads `appState.theme.colors` via `@Environment(AppState.self)`, so surrounding chrome (background, border) updates immediately via SwiftUI observation. Mermaid SVG cache is keyed solely by `mermaidStableHash(mermaidCode)` with no theme component, matching DD-4. SVGs are structural/theme-independent so no cache invalidation is needed.
    - **Deviations**: None
    - **Tests**: N/A (verification-only)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | N/A |

- [x] **T6**: Write unit tests for `ThemeMode` enum `[complexity:simple]`

    **Reference**: [design.md#test-strategy](design.md#test-strategy)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] Test file `mkdnTests/Unit/ThemeModeTests.swift` exists
    - [x] Tests use Swift Testing (`@Suite`, `@Test`, `#expect`)
    - [x] `resolved(for:)` tested for all 6 combinations (3 modes x 2 colorSchemes)
    - [x] `displayName` tested for all 3 cases
    - [x] `CaseIterable` count verified as 3
    - [x] `RawValue` round-trip tested for all cases

    **Implementation Summary**:

    - **Files**: `mkdnTests/Unit/ThemeModeTests.swift`
    - **Approach**: 10 tests in `@Suite("ThemeMode")`: 6 individual `resolved(for:)` tests covering all mode/colorScheme combinations, 1 displayName test covering all 3 labels, 1 CaseIterable count assertion, 1 rawValue round-trip via `allCases` loop, 1 rawValue string verification for persistence keys
    - **Deviations**: None
    - **Tests**: 10/10 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ✅ PASS |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

- [x] **T7**: Write unit tests for `AppState` theming behavior `[complexity:medium]`

    **Reference**: [design.md#test-strategy](design.md#test-strategy)

    **Effort**: 3 hours

    **Acceptance Criteria**:

    - [x] Tests verify default `themeMode` is `.auto` on fresh init (no UserDefaults entry)
    - [x] Tests verify `cycleTheme()` cycles through all three modes in correct order
    - [x] Tests verify computed `theme` resolves correctly when `themeMode` and `systemColorScheme` change
    - [x] Tests verify UserDefaults persistence round-trip (write themeMode, create new AppState, read back)
    - [x] Existing `AppStateTests` updated to reflect `.auto` default instead of previous hardcoded theme
    - [x] All tests use `@MainActor` on individual test functions (not on `@Suite` struct)

    **Implementation Summary**:

    - **Files**: `mkdnTests/Unit/Features/AppStateThemingTests.swift` (new), `mkdnTests/Unit/Features/AppStateTests.swift` (updated)
    - **Approach**: Created 8 tests in new `@Suite("AppState Theming")`: default auto mode, auto mode follows system color scheme, pinned dark ignores system scheme, pinned light ignores system scheme, cycleTheme sets overlay label with displayName, themeMode writes to UserDefaults, init restores persisted mode, init defaults to auto for invalid persisted value. Updated existing defaultState test to assert `themeMode == .auto`.
    - **Deviations**: Added an extra test for invalid UserDefaults value (graceful fallback to .auto) as a defensive edge case. Did not duplicate the cycleTheme ordering test already in ControlsTests.
    - **Tests**: 8/8 passing (new suite), all existing tests still pass

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ✅ PASS |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

## Acceptance Criteria Checklist

### Functional Requirements
- [ ] FR-1: `ThemeMode` enum exists with `.auto`, `.solarizedDark`, `.solarizedLight` cases
- [ ] FR-2: `.auto` mode resolves `AppTheme` from `@Environment(\.colorScheme)`
- [ ] FR-3: `ThemeMode` persists across launches via UserDefaults (key: `"themeMode"`)
- [ ] FR-4: New installs default to `.auto`
- [ ] FR-5: `ThemePickerView` shows three-segment picker: Auto / Dark / Light
- [ ] FR-6: `cycleTheme()` cycles through three modes
- [ ] FR-7: OS appearance change in `.auto` mode updates resolved theme immediately across all content
- [ ] FR-8: Cmd+T keyboard shortcut continues to cycle themes

### Non-Functional Requirements
- [ ] NFR-1: Theme switch feels instantaneous (< 16ms color swap)
- [ ] NFR-2: No flash of wrong theme at launch
- [ ] NFR-3: Zero new dependencies (SwiftUI colorScheme + UserDefaults only)
- [ ] NFR-4: Backwards-compatible default behavior matches OS appearance
- [ ] NFR-5: SwiftLint and SwiftFormat clean

## Definition of Done

- [ ] All 7 tasks completed
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] `swift build` succeeds
- [ ] `swift test` passes (all new and existing tests)
- [ ] `swiftlint lint` clean
- [ ] `swiftformat .` applied
- [ ] Docs updated
