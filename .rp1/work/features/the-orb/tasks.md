# Development Tasks: The Orb

**Feature ID**: the-orb
**Status**: In Progress
**Progress**: 27% (3 of 11 tasks)
**Estimated Effort**: 3 days
**Started**: 2026-02-10

## Overview

Consolidate `FileChangeOrbView` and `DefaultHandlerHintView` into a single unified `TheOrbView` driven by an `OrbState` enum state machine. The view reads state from `DocumentState` and `AppSettings`, resolves the highest-priority active state, renders `OrbVisual` with a state-specific color, provides tap-to-popover contextual actions per state, and supports an opt-in auto-reload timer for file changes.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T2, T3] - Independent data model / constants with no shared dependencies
2. [T4, T7] - T4 assembles the view using T1/T2/T3; T7 tests T1/T2 logic. T7 does not depend on T4.
3. [T5] - ContentView integration requires TheOrbView from T4
4. [T6] - Deletion safe only after ContentView no longer references old views

**Dependencies**:

- T4 -> [T1, T2, T3] (interface: TheOrbView uses OrbState enum, reads autoReloadEnabled, uses color constants)
- T5 -> T4 (interface: ContentView references TheOrbView)
- T6 -> T5 (sequential: old views must not be referenced before deletion)
- T7 -> [T1, T2] (interface: tests OrbState and AppSettings types)

**Critical Path**: T1 -> T4 -> T5 -> T6

## Task Breakdown

### Foundation (Parallel Group 1)

- [x] **T1**: Create `OrbState` enum with cases, Comparable conformance, color mapping, and visibility `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/UI/Components/OrbState.swift`
    - **Approach**: Created enum with 4 cases ordered low-to-high (idle, updateAvailable, defaultHandler, fileChanged) for Comparable synthesis. Added isVisible and color computed properties per design spec.
    - **Deviations**: None
    - **Tests**: Deferred to T7

    **Reference**: [design.md#31-orbstate-enum](design.md#31-orbstate-enum)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] `OrbState` enum created at `mkdn/UI/Components/OrbState.swift` with cases: `idle`, `updateAvailable`, `defaultHandler`, `fileChanged` (ordered low-to-high for Comparable synthesis)
    - [x] Conforms to `Comparable` via natural enum case ordering so `.max()` returns the highest-priority state
    - [x] `isVisible` computed property returns `false` for `.idle`, `true` for all other cases
    - [x] `color` computed property returns the correct `AnimationConstants` color for each state
    - [x] Priority ordering: `fileChanged > defaultHandler > updateAvailable > idle`

- [x] **T2**: Add `autoReloadEnabled` Bool property to `AppSettings` with UserDefaults persistence `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/App/AppSettings.swift`
    - **Approach**: Added private key constant, Bool property with didSet persistence, and UserDefaults read in init(). Exact pattern match with hasShownDefaultHandlerHint.
    - **Deviations**: None
    - **Tests**: Existing AppSettings tests pass; new autoReload tests deferred to T7

    **Reference**: [design.md#34-appsettings-extension](design.md#34-appsettings-extension)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] `autoReloadEnabled` Bool property added to `AppSettings` in `mkdn/App/AppSettings.swift`
    - [x] Defaults to `false` when no UserDefaults value exists
    - [x] Persists to UserDefaults on `didSet` using a private key constant
    - [x] Initializes from UserDefaults in `init()`, matching the existing `hasShownDefaultHandlerHint` pattern
    - [x] Follows the exact code pattern shown in design.md section 3.4

- [x] **T3**: Add orb color constants to `AnimationConstants` and rename/deprecate old color names `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/UI/Theme/AnimationConstants.swift`
    - **Approach**: Renamed orbGlowColor to orbDefaultHandlerColor, replaced fileChangeOrbColor (cyan) with orbFileChangedColor (Solarized orange), added orbUpdateAvailableColor (Solarized green). Added deprecated computed-property aliases for both old names in Legacy Aliases section.
    - **Deviations**: None
    - **Tests**: 162/162 passing

    **Reference**: [design.md#35-new-color-constants](design.md#35-new-color-constants)

    **Effort**: 1.5 hours

    **Acceptance Criteria**:

    - [x] `orbFileChangedColor` added as Solarized orange (`Color(red: 0.796, green: 0.294, blue: 0.086)`) in `mkdn/UI/Theme/AnimationConstants.swift`
    - [x] `orbUpdateAvailableColor` added as Solarized green (`Color(red: 0.522, green: 0.600, blue: 0.000)`)
    - [x] Existing `orbGlowColor` renamed to `orbDefaultHandlerColor` (Solarized violet)
    - [x] Deprecated alias added for `orbGlowColor` pointing to `orbDefaultHandlerColor`
    - [x] Deprecated alias added for `fileChangeOrbColor` (if it exists) pointing to `orbFileChangedColor`
    - [x] All new constants placed under a `// MARK: - Orb Colors` section

### Assembly (Parallel Group 2)

- [ ] **T4**: Create `TheOrbView` with state resolution, OrbVisual delegation, per-state popovers, auto-reload timer, color crossfade, and transitions `[complexity:complex]`

    **Reference**: [design.md#32-state-resolution-logic](design.md#32-state-resolution-logic)

    **Effort**: 10 hours

    **Acceptance Criteria**:

    - [ ] `TheOrbView` created at `mkdn/UI/Components/TheOrbView.swift`
    - [ ] Reads `DocumentState` and `AppSettings` from `@Environment`
    - [ ] `activeState` computed property resolves highest-priority state using `[OrbState].max() ?? .idle` per design section 3.2
    - [ ] Delegates rendering to existing `OrbVisual` component, passing `currentColor` as the color parameter
    - [ ] Color crossfade: `@State var currentColor` updated via `withAnimation(motion.resolved(.crossfade))` in `onChange(of: activeState)` per design section 3.6
    - [ ] Per-state popover content: defaultHandler (register prompt with Yes/No), fileChanged (reload Yes/No + auto-reload Toggle), updateAvailable (informational text) per design section 3.7
    - [ ] Auto-reload timer: `@State private var autoReloadTask: Task<Void, Never>?` starts when `activeState == .fileChanged && appSettings.autoReloadEnabled && !documentState.hasUnsavedChanges` per design section 3.3
    - [ ] Auto-reload duration: `Task.sleep(for: .seconds(5))` (one breathe cycle)
    - [ ] Timer cancelled on: user tap (show manual popover), view disappear, state change away from fileChanged
    - [ ] Timer reset on: new file-change event during active countdown via `onChange(of: documentState.isFileOutdated)`
    - [ ] Unsaved changes guard: auto-reload suppressed when `documentState.hasUnsavedChanges`, falls back to manual popover
    - [ ] Hover feedback via `.hoverScale()` matching existing orb pattern
    - [ ] `MotionPreference` integration: resolves all animation primitives, guards continuous animations with `allowsContinuousAnimation`
    - [ ] Visibility: hidden when `activeState == .idle` with appropriate transition animation
    - [ ] Positioning: bottom-right with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(16)` per design section 3.8

- [ ] **T7**: Create unit tests for `OrbState` priority ordering, color mapping, visibility, and `AppSettings.autoReloadEnabled` `[complexity:medium]`

    **Reference**: [design.md#73-unit-tests](design.md#73-unit-tests)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [ ] `OrbStateTests` suite created at `mkdnTests/Unit/UI/OrbStateTests.swift` using `@Suite` and `@Test`
    - [ ] Test: priority ordering confirms `fileChanged > defaultHandler > updateAvailable > idle`
    - [ ] Test: `[.defaultHandler, .fileChanged].max()` returns `.fileChanged`
    - [ ] Test: `OrbState.idle.isVisible` returns `false`; all other cases return `true`
    - [ ] Test: each state's `color` property returns the expected `AnimationConstants` color constant
    - [ ] AppSettings tests at `mkdnTests/Unit/App/AppSettingsTests.swift` (new or modify existing)
    - [ ] Test: `autoReloadEnabled` defaults to `false` on fresh init
    - [ ] Test: `autoReloadEnabled` persists value across init cycles via UserDefaults
    - [ ] All tests use `@testable import mkdnLib`, Swift Testing framework (`#expect`)

### Integration (Parallel Group 3)

- [ ] **T5**: Replace `FileChangeOrbView` and `DefaultHandlerHintView` overlay blocks in `ContentView` with single `TheOrbView` `[complexity:simple]`

    **Reference**: [design.md#38-contentview-integration](design.md#38-contentview-integration)

    **Effort**: 1.5 hours

    **Acceptance Criteria**:

    - [ ] `FileChangeOrbView` conditional overlay block removed from `ContentView` in `mkdn/App/ContentView.swift`
    - [ ] `DefaultHandlerHintView` conditional overlay block removed from `ContentView`
    - [ ] Single `TheOrbView()` overlay added to the ZStack, replacing both removed blocks
    - [ ] No conditional visibility logic for the orb in ContentView (TheOrbView handles visibility internally)
    - [ ] `ModeTransitionOverlay` overlay remains unchanged
    - [ ] App builds and runs with the unified orb displaying correctly

### Cleanup (Parallel Group 4)

- [ ] **T6**: Delete `FileChangeOrbView.swift` and `DefaultHandlerHintView.swift` `[complexity:simple]`

    **Reference**: [design.md#component-design](design.md#component-design)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [ ] `mkdn/UI/Components/FileChangeOrbView.swift` deleted from the project
    - [ ] `mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift` deleted from the project
    - [ ] No remaining references to `FileChangeOrbView` or `DefaultHandlerHintView` in the codebase (verified via project-wide search)
    - [ ] Project compiles cleanly with no missing-file errors
    - [ ] SwiftLint passes with no errors

### User Docs

- [ ] **TD1**: Update modules.md UI Components - Replace FileChangeOrbView and DefaultHandlerHintView entries with TheOrbView and OrbState `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: UI Components

    **KB Source**: modules.md:UI Components

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] FileChangeOrbView entry removed from UI Components table
    - [ ] TheOrbView and OrbState entries added with accurate descriptions
    - [ ] DefaultHandlerHintView entry removed (was in Features layer, not UI Components -- verify location)

- [ ] **TD2**: Update modules.md App Layer - Document autoReloadEnabled property on AppSettings `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: App Layer

    **KB Source**: modules.md:App Layer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] AppSettings entry in App Layer updated to mention autoReloadEnabled property

- [ ] **TD3**: Update patterns.md Animation Pattern - Add orbFileChangedColor and orbUpdateAvailableColor to orb colors documentation `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: Animation Pattern

    **KB Source**: patterns.md:Animation Pattern

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New orb color constants documented in the Animation Pattern section
    - [ ] Deprecated aliases noted

- [ ] **TD4**: Update architecture.md System Overview - Replace separate indicator views with TheOrbView in system diagram `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: System Overview

    **KB Source**: architecture.md:System Overview

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] System diagram updated to show TheOrbView instead of FileChangeOrbView and DefaultHandlerHintView
    - [ ] No broken references to removed views

## Acceptance Criteria Checklist

- [ ] **REQ-01**: Single unified orb indicator driven by enum state machine with states: idle (hidden), default handler (violet), file changed (orange), update available (green). Exactly one orb visible at bottom-right, displaying highest-priority active state color.
- [ ] **REQ-02**: Priority ordering: file changed (orange) > default handler (violet) > update available (green) > idle (hidden). When file-changed clears, transitions to next highest.
- [ ] **REQ-03**: Violet orb appears when default handler prompt not dismissed. Tap shows popover with Yes/No. Either choice permanently dismisses prompt across all future launches.
- [ ] **REQ-04**: Orange orb appears when file changed on disk. Tap shows popover with reload Yes/No and auto-reload toggle. Yes reloads file. Toggle persists preference.
- [ ] **REQ-05**: When auto-reload enabled and no unsaved changes, orb appears orange, pulses ~5 seconds, auto-reloads file, then becomes hidden.
- [ ] **REQ-06**: Auto-reload preference defaults to off, persisted across launches, toggled only from file-changed popover.
- [ ] **REQ-07**: When auto-reload enabled but unsaved changes exist, auto-reload suppressed; manual popover shown instead.
- [ ] **REQ-08**: Tapping orb during auto-reload pulse cancels timer and shows manual reload popover.
- [ ] **REQ-09**: Green state for "update available" with informational popover (placeholder, no backend).
- [ ] **REQ-10**: Color transitions between states are animated crossfades, not hard cuts.
- [ ] **REQ-11**: Orb positioned at bottom-right corner with consistent padding at any window size.
- [ ] **REQ-12**: FileChangeOrbView.swift and DefaultHandlerHintView.swift removed; ContentView references only TheOrbView.

## Definition of Done

- [ ] All tasks completed
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] Docs updated
