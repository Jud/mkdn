# Development Tasks: Terminal-Consistent Theming

**Feature ID**: terminal-consistent-theming
**Status**: Not Started
**Progress**: 60% (3 of 5 tasks)
**Estimated Effort**: 1.5 days
**Started**: 2026-02-07

## Overview

The codebase already implements the majority of terminal-consistent theming (ThemeMode enum, AppSettings persistence, ContentView colorScheme bridge, ThemePickerView, keyboard cycling). This task set addresses the two remaining gaps: Mermaid diagram theme consistency (REQ-008) and flash prevention at launch (REQ-009). Changes are localized to four production files and three test files, with no new types or dependencies introduced.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T2] - T1 modifies AppSettings init; T2 modifies MermaidRenderer/MermaidImageStore. No shared code paths.
2. [T3] - MermaidBlockView consumes the theme-aware API that T2 defines.

**Dependencies**:

- T3 -> T2 (Interface: T3 calls the new `renderToSVG(_:theme:)` and `get(_:theme:)` APIs that T2 introduces)

**Critical Path**: T2 -> T3

## Task Breakdown

### Flash Prevention (Parallel Group 1)

- [x] **T1**: Fix AppSettings init to resolve system appearance at init time instead of defaulting to .dark `[complexity:simple]`

    **Reference**: [design.md#31-flash-prevention-t1](design.md#31-flash-prevention-t1)

    **Effort**: 1.5 hours

    **Acceptance Criteria**:

    - [x] `AppSettings.init()` reads `NSApp?.effectiveAppearance` (with fallback to `NSAppearance.currentDrawing()`) to set `systemColorScheme` before any SwiftUI body evaluation
    - [x] The hardcoded `.dark` default for `systemColorScheme` is removed
    - [x] New test in `AppSettingsTests.swift` verifies that `systemColorScheme` after init matches the test process's actual OS appearance, not a hardcoded value
    - [x] Existing AppSettings tests continue to pass without modification

    **Implementation Summary**:

    - **Files**: `mkdn/App/AppSettings.swift`, `mkdnTests/Unit/Features/AppSettingsTests.swift`
    - **Approach**: Added `import AppKit`; replaced hardcoded `.dark` default with init-time resolution via `NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()` using `bestMatch(from: [.darkAqua, .aqua])` to determine dark/light; added `initResolvesSystemAppearance` test that validates against the same OS appearance API
    - **Deviations**: None
    - **Tests**: 14/14 passing (13 existing + 1 new)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | PASS |
    | Commit | N/A |
    | Comments | PASS |

### Theme-Aware Mermaid Pipeline (Parallel Group 1)

- [x] **T2**: Add theme parameter to MermaidRenderer and MermaidImageStore APIs and include theme in cache keys `[complexity:medium]`

    **Reference**: [design.md#32-theme-aware-mermaid-cache-keys-t2](design.md#32-theme-aware-mermaid-cache-keys-t2)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [x] `MermaidRenderer.renderToSVG(_:theme:)` accepts an `AppTheme` parameter and includes `theme.rawValue` in the stable hash cache key
    - [x] `MermaidRenderer.renderToImage(_:theme:)` similarly accepts and forwards the `AppTheme` parameter
    - [x] The Mermaid JS render call passes `beautifulMermaid.THEMES['solarized-dark']` for `.solarizedDark` and `beautifulMermaid.THEMES['solarized-light']` for `.solarizedLight` (per HYP-001 validated API)
    - [x] `MermaidImageStore.get(_:theme:)` and `MermaidImageStore.store(_:theme:image:)` accept `AppTheme` and include `theme.rawValue` in the hash key
    - [x] Same Mermaid code with different themes produces different cache entries (verified by unit test)
    - [x] Existing MermaidRenderer tests updated to pass a theme parameter and continue to pass
    - [x] New `MermaidImageStoreTests` test verifies that storing an image under `.solarizedDark` and `.solarizedLight` with the same code yields two distinct retrievable entries

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Mermaid/MermaidRenderer.swift`, `mkdn/Core/Mermaid/MermaidImageStore.swift`, `mkdnTests/Unit/Core/MermaidRendererTests.swift`, `mkdnTests/Unit/Core/MermaidImageStoreTests.swift`
    - **Approach**: Added `theme: AppTheme` parameter (with `.solarizedDark` default for backward compat) to `renderToSVG`, `renderToImage`, `get`, and `store`. Cache keys now hash `code + theme.rawValue`. JS call uses `beautifulMermaid.THEMES['solarized-dark'|'solarized-light']` presets per HYP-001. Added `mermaidJSThemeKey(for:)` private helper. Updated all existing tests to pass theme explicitly; added 3 new tests (theme-aware cache keys, theme-aware image store caching, theme miss).
    - **Deviations**: JS API uses `beautifulMermaid.THEMES[key]` color preset objects instead of simple theme strings (`{theme: "dark"}`), per HYP-001 confirmation. Default parameter values added for backward compatibility during T2->T3 transition.
    - **Tests**: 32/32 passing (27 existing updated + 3 new + 2 existing unchanged)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | PASS |
    | Commit | N/A |
    | Comments | PASS |

### MermaidBlockView Theme Integration (Parallel Group 2)

- [x] **T3**: Update MermaidBlockView to re-render diagrams when the resolved theme changes `[complexity:simple]`

    **Reference**: [design.md#33-mermaidblockview-re-render-on-theme-change-t3](design.md#33-mermaidblockview-re-render-on-theme-change-t3)

    **Effort**: 2.5 hours

    **Acceptance Criteria**:

    - [x] `MermaidBlockView.init(code:)` no longer performs an init-time cache lookup (removes the `MermaidImageStore.shared.get` call from init)
    - [x] A private `TaskID` struct (Hashable, containing `code` and `theme`) is introduced and used as the `.task(id:)` value so the task re-fires when the resolved theme changes
    - [x] `renderDiagram()` passes `appSettings.theme` to both `MermaidRenderer.shared.renderToSVG(_:theme:)` and `MermaidImageStore.shared.store(_:theme:image:)`
    - [x] The `guard renderedImage == nil` early return in `renderDiagram()` is removed so that theme changes trigger a re-render even when an image from the previous theme is present
    - [x] No changes required to parent views that construct `MermaidBlockView` (init signature remains `init(code:)`)

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/MermaidBlockView.swift`
    - **Approach**: Removed init-time `MermaidImageStore.shared.get` cache lookup (environment unavailable at init); added private `TaskID` struct containing `code` and `theme`; changed `.task(id:)` to use `TaskID` so task re-fires on theme change; replaced `guard renderedImage == nil` early return with image store check using current theme, then async renderer fallback; all renderer/store calls now pass `appSettings.theme`
    - **Deviations**: None
    - **Tests**: 170/170 passing (no new tests per design -- view behavior covered by renderer/store tests and manual verification)

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

### User Docs

- [ ] **TD1**: Update modules.md - Core/Mermaid table `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Core/Mermaid table

    **KB Source**: modules.md:Core/Mermaid

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] The Core/Mermaid table in modules.md reflects that MermaidRenderer and MermaidImageStore APIs now accept a theme parameter

- [ ] **TD2**: Update architecture.md - Mermaid Diagrams pipeline `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Mermaid Diagrams pipeline

    **KB Source**: architecture.md:Mermaid Diagrams

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] The Mermaid Diagrams section in architecture.md notes that Mermaid rendering is theme-aware and cache keys include the theme variant

## Acceptance Criteria Checklist

### REQ-008: Mermaid Diagram Theme Consistency
- [ ] After a theme change, Mermaid diagrams render with colors matching the new theme.
- [ ] Cached Mermaid output for the correct variant is used if available, avoiding unnecessary re-renders.
- [ ] If no cached variant exists, an asynchronous re-render is triggered.

### REQ-009: No Flash of Wrong Theme at Launch
- [ ] In Auto mode with OS in dark mode, the first visible frame uses Solarized Dark colors.
- [ ] In Auto mode with OS in light mode, the first visible frame uses Solarized Light colors.
- [ ] In pinned mode, the first visible frame uses the pinned variant.

### Already Implemented (no tasks needed)
- [x] REQ-001: Three-State Theme Mode
- [x] REQ-002: Auto Mode Resolves from OS Appearance
- [x] REQ-003: Default to Auto Mode
- [x] REQ-004: Preference Persistence
- [x] REQ-005: Live Switching in Auto Mode
- [x] REQ-006: Updated Theme Picker UI
- [x] REQ-007: Updated Theme Cycling

## Definition of Done

- [ ] All tasks completed
- [ ] All AC verified
- [ ] Code reviewed
- [ ] Docs updated
