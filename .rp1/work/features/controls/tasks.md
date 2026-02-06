# Development Tasks: Controls

**Feature ID**: controls
**Status**: In Progress
**Progress**: 58% (7 of 12 tasks)
**Estimated Effort**: 3 days
**Started**: 2026-02-06

## Overview

Replace mkdn's toolbar-based interaction model with a chrome-less, keyboard-driven control philosophy. All navigation and actions are driven by keyboard shortcuts and macOS menu bar commands. Visual feedback is delivered through a breathing orb for file-change notification and ephemeral overlays for mode transitions.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T2] - AnimationConstants and AppState extensions have no data or interface dependencies on each other
2. [T3, T4, T5, T8] - All depend on T1/T2 but not on each other: MkdnCommands calls AppState methods, BreathingOrbView reads AppState and uses AnimationConstants, ModeTransitionOverlay uses AnimationConstants, Tests verify AppState logic
3. [T6] - ContentView refactor integrates all prior components

**Dependencies:**

- T3 -> T2 (interface: commands call `switchMode(to:)` and `cycleTheme()` on AppState)
- T3 -> T1 (data: uses `AnimationConstants.themeCrossfade`)
- T4 -> T1 (data: uses `AnimationConstants.orbPulse`, `orbAppear`)
- T4 -> T2 (interface: reads `appState.isFileOutdated`, `appState.theme.colors.accent`)
- T5 -> T1 (data: uses `AnimationConstants.overlaySpringIn`, `overlayDisplayDuration`, etc.)
- T6 -> [T3, T4, T5] (build: imports and composes all new components)
- T8 -> T2 (interface: tests `cycleTheme()`, `switchMode(to:)`)

**Critical Path:** T2 -> T3 -> T6

## Task Breakdown

### Foundation

- [x] **T1**: Create AnimationConstants with centralized timing constants for orb, overlay, and theme animations `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/UI/Theme/AnimationConstants.swift`
    - **Approach**: Created enum with static let constants for all orb, overlay, and theme animations per design spec
    - **Deviations**: None
    - **Tests**: Compile-time verification sufficient (no runtime logic)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

    **Reference**: [design.md#36-animationconstants](design.md#36-animationconstants)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] File created at `mkdn/UI/Theme/AnimationConstants.swift`
    - [x] Enum defines `orbPulse`, `orbAppear`, `orbDissolve` animation constants
    - [x] Enum defines `overlaySpringIn`, `overlayFadeOut`, `overlayDisplayDuration`, `overlayFadeOutDuration` constants
    - [x] Enum defines `themeCrossfade` animation constant
    - [x] No animation durations or curves are hardcoded outside this file (FR-CTRL-008 AC-1, AC-3)
    - [x] All constants are `static let` properties on the `AnimationConstants` enum

- [x] **T2**: Extend AppState with `cycleTheme()`, `switchMode(to:)`, and `modeOverlayLabel` property `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/App/AppState.swift`
    - **Approach**: Added `modeOverlayLabel: String?` property, `cycleTheme()` using `AppTheme.allCases` index cycling, and `switchMode(to:)` that sets both viewMode and overlay label
    - **Deviations**: None
    - **Tests**: Existing tests pass; new controls-specific tests deferred to T8

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

    **Reference**: [design.md#31-appstate-extensions](design.md#31-appstate-extensions)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] `modeOverlayLabel: String?` property added to AppState
    - [x] `cycleTheme()` method cycles through `AppTheme.allCases` wrapping around at the end (FR-CTRL-001 AC-5)
    - [x] `switchMode(to:)` method sets `viewMode` and sets `modeOverlayLabel` to "Preview" for `.previewOnly` and "Edit" for `.sideBySide`
    - [x] Existing `viewMode`, `theme`, and `isFileOutdated` properties remain unchanged
    - [x] All new state mutations are `@MainActor`-isolated

### Components and Commands

- [x] **T3**: Expand MkdnCommands with Open, Theme Cycle menu items, refine Reload disable logic, and use `switchMode(to:)` for mode changes `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/App/MkdnCommands.swift`
    - **Approach**: Renamed mode buttons to "Preview Mode"/"Edit Mode" using `switchMode(to:)`; added "Open..." (Cmd+O) with `openFile()` private helper using NSOpenPanel; added "Cycle Theme" (Cmd+T) wrapped in `withAnimation(AnimationConstants.themeCrossfade)`; refined Reload disable to also check `!appState.isFileOutdated`; added `import UniformTypeIdentifiers`
    - **Deviations**: None
    - **Tests**: No new tests (menu command behavior is SwiftUI framework; AppState logic tested in T8)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

    **Reference**: [design.md#32-mkdncommands-expansion](design.md#32-mkdncommands-expansion)

    **Effort**: 3 hours

    **Acceptance Criteria**:

    - [x] Cmd+1 switches to preview-only mode via `appState.switchMode(to: .previewOnly)` (FR-CTRL-001 AC-1)
    - [x] Cmd+2 switches to side-by-side edit mode via `appState.switchMode(to: .sideBySide)` (FR-CTRL-001 AC-2)
    - [x] Cmd+R reloads the current file when a file is open and file has changed (FR-CTRL-001 AC-3)
    - [x] Cmd+O opens NSOpenPanel filtered to Markdown files (FR-CTRL-001 AC-4)
    - [x] Cmd+T cycles theme with `withAnimation(AnimationConstants.themeCrossfade)` wrapper (FR-CTRL-007 AC-1)
    - [x] "View" menu contains "Preview Mode" (Cmd+1) and "Edit Mode" (Cmd+2) (FR-CTRL-002 AC-1)
    - [x] "File" menu contains "Open..." (Cmd+O) and "Reload" (Cmd+R) (FR-CTRL-002 AC-2)
    - [x] "Cycle Theme" (Cmd+T) menu item present in appropriate menu group (FR-CTRL-002 AC-3)
    - [x] Reload menu item disabled when no file is open OR file is not outdated (FR-CTRL-002 AC-5, BR-004)
    - [x] `openFile()` helper method extracted from removed toolbar into MkdnCommands as private method
    - [x] All menu items display keyboard shortcuts in standard macOS format (FR-CTRL-002 AC-4)

- [x] **T4**: Create BreathingOrbView component replacing OutdatedIndicator `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/UI/Components/BreathingOrbView.swift`
    - **Approach**: Created self-contained SwiftUI view with Circle, accent color fill, animated shadow/scale/opacity driven by AnimationConstants.orbPulse via withAnimation in onAppear; theme-adaptive via @Environment(AppState.self)
    - **Deviations**: None
    - **Tests**: SwiftUI view rendering -- visual verification only (per testing strategy)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

    **Reference**: [design.md#33-breathingorbview](design.md#33-breathingorbview)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] File created at `mkdn/UI/Components/BreathingOrbView.swift`
    - [x] Small circle (~10pt diameter) rendered with no text label (FR-CTRL-004 AC-1, AC-2)
    - [x] Uses theme accent color via `appState.theme.colors.accent` (FR-CTRL-004 AC-5)
    - [x] Glow effect via `.shadow(color:radius:)` with animated radius
    - [x] Pulse animation uses `AnimationConstants.orbPulse` -- sinusoidal opacity (0.4 to 1.0) and scale (0.85 to 1.0) at ~12 cycles/min (FR-CTRL-004 AC-3)
    - [x] Animation driven by SwiftUI animation system, not manual timers (NFR-CTRL-003)
    - [x] Appear animation uses `AnimationConstants.orbAppear` (fade-in over 0.5s)
    - [x] Reads `appState.isFileOutdated` via `@Environment(AppState.self)` pattern
    - [x] Orb is visually subtle and does not dominate content area (FR-CTRL-004 AC-4)

- [x] **T5**: Create ModeTransitionOverlay component for ephemeral mode labels `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/UI/Components/ModeTransitionOverlay.swift`
    - **Approach**: Created view taking label and onDismiss closure; spring-in on appear via AnimationConstants.overlaySpringIn, auto-dismiss Task sleeps for overlayDisplayDuration then fades out, calls onDismiss after overlayFadeOutDuration
    - **Deviations**: None
    - **Tests**: SwiftUI view rendering -- visual verification only (per testing strategy)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

    **Reference**: [design.md#34-modetransitionoverlay](design.md#34-modetransitionoverlay)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] File created at `mkdn/UI/Components/ModeTransitionOverlay.swift`
    - [x] Displays mode name ("Preview" or "Edit") as centered overlay text (FR-CTRL-006 AC-1, AC-2)
    - [x] Semi-transparent background using `.ultraThinMaterial` with rounded rectangle clip shape
    - [x] Font is `.title2.weight(.medium)` with `.primary` foreground style
    - [x] Appear animation uses `AnimationConstants.overlaySpringIn` -- spring scale from 0.8 + opacity from 0 (FR-CTRL-006 AC-3)
    - [x] Auto-dismisses after `AnimationConstants.overlayDisplayDuration` (~1.5s) without user interaction (FR-CTRL-006 AC-4)
    - [x] Exit animation uses `AnimationConstants.overlayFadeOut` -- smooth fade-out (FR-CTRL-006 AC-5)
    - [x] Calls `onDismiss` closure after fade-out completes to clear `modeOverlayLabel`
    - [x] Rapid switching handled via `.id()` keying in parent view -- no stacking or visual artifacts (FR-CTRL-006 AC-6, BR-003)

- [x] **T8**: Create unit tests for AppState extensions (`cycleTheme`, `switchMode`) `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdnTests/Unit/Features/ControlsTests.swift`
    - **Approach**: Created @Suite("Controls") with 5 tests covering cycleTheme cycling, switchMode state coordination, and isFileOutdated delegation; avoids DispatchSource per known signal 5 issue
    - **Deviations**: None
    - **Tests**: 5/5 passing

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

    **Reference**: [design.md#7-testing-strategy](design.md#7-testing-strategy)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] File created at `mkdnTests/Unit/Features/ControlsTests.swift`
    - [x] Uses `@testable import mkdnLib` and Swift Testing framework (`@Suite`, `@Test`, `#expect`)
    - [x] Test: `cycleTheme` toggles from dark to light
    - [x] Test: `cycleTheme` toggles from light to dark (wrap-around)
    - [x] Test: `switchMode(to: .previewOnly)` sets `viewMode` and `modeOverlayLabel` to "Preview"
    - [x] Test: `switchMode(to: .sideBySide)` sets `viewMode` and `modeOverlayLabel` to "Edit"
    - [x] Test: `isFileOutdated` reflects FileWatcher state
    - [x] All test functions use `@MainActor` annotation (not on `@Suite` struct)
    - [x] Tests do not duplicate existing `AppStateTests` coverage

### Integration

- [x] **T6**: Refactor ContentView to remove toolbar, add breathing orb and mode overlay layers, and clean up removed components `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/App/ContentView.swift`
    - **Approach**: Removed .toolbar modifier and MkdnToolbarContent struct entirely; wrapped content in ZStack with BreathingOrbView (conditional on isFileOutdated with asymmetric transition) and ModeTransitionOverlay (conditional on modeOverlayLabel, keyed by .id); preserved .onDrop and view mode animation
    - **Deviations**: None
    - **Tests**: Existing tests pass (including Controls suite 5/5); no new tests needed (view composition is visual verification)

    **Reference**: [design.md#35-contentview-refactor](design.md#35-contentview-refactor)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] `.toolbar` modifier removed entirely from ContentView (FR-CTRL-003 AC-1)
    - [x] `MkdnToolbarContent` struct removed from ContentView
    - [x] `ViewModePicker` no longer rendered in the window (FR-CTRL-003 AC-2)
    - [x] `OutdatedIndicator` usage removed from ContentView
    - [x] Content wrapped in `ZStack` for overlay layering
    - [x] `BreathingOrbView` overlaid with `.frame(maxWidth:maxHeight:alignment: .bottomTrailing)` and padding, conditional on `appState.isFileOutdated`
    - [x] Asymmetric transition for orb: insertion `.opacity` with `orbAppear`, removal `.scale.combined(with: .opacity)` with `orbDissolve` (FR-CTRL-005 AC-1, AC-2, AC-3)
    - [x] `ModeTransitionOverlay` shown conditionally when `appState.modeOverlayLabel` is non-nil, keyed by `.id(label)`
    - [x] View mode transition uses `.animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.viewMode)`
    - [x] `.onDrop` for file URLs preserved
    - [x] All functionality previously in toolbar remains accessible via keyboard shortcuts and menu bar (FR-CTRL-003 AC-3)
    - [x] `swift build` compiles successfully with all components integrated

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

### Verification Fixes

- [x] **TX-verify-fix**: Centralize hardcoded animation, delete dead code files `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/UI/Theme/AnimationConstants.swift`, `mkdn/App/ContentView.swift`, (deleted) `mkdn/UI/Components/ViewModePicker.swift`, (deleted) `mkdn/UI/Components/OutdatedIndicator.swift`
    - **Approach**: Added `viewModeTransition` constant to AnimationConstants; updated ContentView to reference it instead of hardcoded `.spring(response: 0.4, dampingFraction: 0.85)`; deleted ViewModePicker.swift and OutdatedIndicator.swift (dead code after toolbar removal)
    - **Deviations**: None
    - **Tests**: All existing tests pass (71+ tests including Controls suite 5/5)

    **Acceptance Criteria**:

    - [x] `AnimationConstants.viewModeTransition` added as `static let` (FR-CTRL-008 AC-3)
    - [x] ContentView uses `AnimationConstants.viewModeTransition` instead of hardcoded spring
    - [x] `ViewModePicker.swift` deleted (no references in active code)
    - [x] `OutdatedIndicator.swift` deleted (no references in active code)
    - [x] `swift build` compiles successfully
    - [x] `swift test` passes all tests

### User Docs

- [ ] **TD1**: Update modules.md - UI Components `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: UI Components

    **KB Source**: modules.md:UI-Components

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] BreathingOrbView and ModeTransitionOverlay added to UI Components table
    - [ ] OutdatedIndicator and ViewModePicker removed from UI Components table
    - [ ] AnimationConstants added to UI Theme table
    - [ ] Section reflects current state of codebase after controls feature

- [ ] **TD2**: Update modules.md - App Layer `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: App Layer

    **KB Source**: modules.md:App-Layer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] MkdnCommands entry updated to note expanded menu structure (Open, Theme Cycle, mode switching)
    - [ ] ContentView entry updated to reflect toolbar removal and overlay integration
    - [ ] Section reflects current state of codebase after controls feature

- [ ] **TD3**: Update architecture.md - System Overview `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: System Overview

    **KB Source**: architecture.md:System-Overview

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Toolbar reference removed from system overview diagram
    - [ ] Overlay layer (BreathingOrbView, ModeTransitionOverlay) added to UI layer description
    - [ ] Section reflects current architecture after controls feature

- [ ] **TD4**: Update patterns.md - Animation Constants pattern `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: (new section)

    **KB Source**: patterns.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New "Animation Constants Pattern" section added to patterns.md
    - [ ] Documents the centralized `AnimationConstants` enum approach
    - [ ] Includes example usage showing reference from view code
    - [ ] Anti-pattern note added: no hardcoded animation durations outside AnimationConstants

## Acceptance Criteria Checklist

### FR-CTRL-001: Keyboard Shortcut Layer
- [ ] AC-1: Cmd+1 switches to preview-only mode
- [ ] AC-2: Cmd+2 switches to side-by-side edit mode
- [ ] AC-3: Cmd+R reloads file when open and changed
- [ ] AC-4: Cmd+O opens NSOpenPanel for Markdown files
- [ ] AC-5: Cmd+T cycles theme
- [ ] AC-6: All shortcuts respond within 50ms

### FR-CTRL-002: Menu Bar Discoverability
- [ ] AC-1: View menu contains Preview Mode (Cmd+1) and Edit Mode (Cmd+2)
- [ ] AC-2: File menu contains Open... (Cmd+O) and Reload (Cmd+R)
- [ ] AC-3: Cycle Theme (Cmd+T) menu item exists
- [ ] AC-4: Each menu item displays keyboard shortcut in macOS format
- [ ] AC-5: Menu items enabled/disabled appropriately

### FR-CTRL-003: Toolbar Removal
- [ ] AC-1: No toolbar area rendered below title bar
- [ ] AC-2: ViewModePicker no longer rendered
- [ ] AC-3: All toolbar functionality accessible via shortcuts and menu bar

### FR-CTRL-004: Breathing Orb File-Change Indicator
- [ ] AC-1: Orb appears in corner when file changes on disk
- [ ] AC-2: Orb has no text label
- [ ] AC-3: Orb pulses at ~12 cycles/min
- [ ] AC-4: Orb is visually subtle
- [ ] AC-5: Orb visible in both themes

### FR-CTRL-005: Orb Dissolve on Reload
- [ ] AC-1: Cmd+R causes orb to animate out (fade + shrink)
- [ ] AC-2: Dissolve animation completes smoothly
- [ ] AC-3: Orb fully removed from view hierarchy after dissolve

### FR-CTRL-006: Ephemeral Mode Transition Overlay
- [ ] AC-1: Preview mode shows "Preview" overlay
- [ ] AC-2: Edit mode shows "Edit" overlay
- [ ] AC-3: Overlay enters with spring animation
- [ ] AC-4: Overlay auto-dismisses after ~1.5s
- [ ] AC-5: Overlay exits with smooth fade-out
- [ ] AC-6: Rapid switching handled gracefully

### FR-CTRL-007: Smooth Theme Cycling
- [ ] AC-1: Cmd+T transitions all colors with crossfade
- [ ] AC-2: No flash of unstyled content
- [ ] AC-3: Content readable throughout transition

### FR-CTRL-008: Centralized Animation Timing Constants
- [ ] AC-1: Single file defines all animation timing constants
- [ ] AC-2: Changing a constant changes corresponding animation behavior
- [ ] AC-3: No animation durations hardcoded outside centralized location

### Business Rules
- [ ] BR-001: Keyboard shortcuts operational before toolbar removal
- [ ] BR-002: Breathing orb visible in both themes
- [ ] BR-003: Rapid input causes no visual artifacts
- [ ] BR-004: Reload disabled when no file open or file is current

### Non-Functional
- [ ] NFR-CTRL-001: All animations run at 60fps on macOS 14+
- [ ] NFR-CTRL-002: Keyboard shortcut response under 50ms
- [ ] NFR-CTRL-003: Orb uses SwiftUI animation system, not manual timers

## Definition of Done

- [ ] All tasks completed
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] `swift build` compiles without errors
- [ ] `swift test` passes all tests (including new ControlsTests)
- [ ] `swiftlint lint` passes
- [ ] `swiftformat .` applied
- [ ] Docs updated (TD1-TD4)
