# Requirements Specification: Terminal-Consistent Theming

**Feature ID**: terminal-consistent-theming
**Parent PRD**: [Terminal-Consistent Theming](../../prds/terminal-consistent-theming.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-07

## 1. Feature Overview

Terminal-consistent theming makes mkdn automatically match its Solarized color scheme to the user's macOS system appearance (dark or light), just as a properly configured terminal emulator would. The app defaults to automatic mode on first launch, responds instantly when the user toggles system appearance, and allows manual override to pin a specific variant. The chosen preference persists across launches.

## 2. Business Context

### 2.1 Problem Statement

Developers who use mkdn alongside their terminal expect visual consistency -- when the OS is in dark mode, every tool should be dark; when in light mode, everything should be light. Today, mkdn requires manual theme switching, which breaks the seamless flow between terminal and viewer and forces the user to make a conscious, repeated decision that their OS has already made for them.

### 2.2 Business Value

- Eliminates a friction point in the daily-driver workflow the project's success criteria depend on.
- Makes the app feel like a natural extension of the terminal environment rather than a separate tool with its own appearance settings.
- Reduces cognitive overhead: the user never thinks about theming unless they want to override it.

### 2.3 Success Metrics

| Metric | Target |
|--------|--------|
| Default experience correctness | New installs show the Solarized variant matching the current OS appearance with zero user action. |
| Live switching reliability | Theme updates within one frame (< 16ms for color swap) when the OS appearance changes while the app is running. |
| No flash of wrong theme | The correct variant is resolved before the first visible frame on every launch. |
| Override persistence | A user who pins Dark, quits, and relaunches sees Dark regardless of OS appearance. |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Terminal-centric developer | Primary user. Works from the terminal, launches mkdn via CLI, expects visual consistency with their terminal's Solarized theme. | Primary beneficiary of auto mode. |
| Appearance-preference user | A developer who prefers one Solarized variant regardless of OS setting (e.g., always Dark even in daytime). | Uses manual override to pin a variant. |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project creator / daily-driver user | The app must feel seamless in a terminal workflow. Theming should "just work" without thought. |

## 4. Scope Definition

### 4.1 In Scope

- Automatic theme mode that follows macOS system appearance (dark -> Solarized Dark, light -> Solarized Light).
- Manual override allowing the user to pin Solarized Dark or Solarized Light regardless of OS appearance.
- Three-state preference: Auto, Dark, Light.
- Persistence of the selected mode across app launches.
- Live, immediate response to OS appearance changes while in auto mode.
- Updated theme picker UI exposing the three-state choice.
- Updated theme cycling (keyboard shortcut) to cycle through the three modes.
- Mermaid diagram re-rendering (or correct cached variant selection) when the resolved theme changes.

### 4.2 Out of Scope

- Adding theme families beyond Solarized (e.g., Nord, Dracula).
- Auto-detecting the user's terminal emulator color scheme directly (the OS appearance is the proxy).
- Per-file or per-window theme overrides.
- Custom user-defined color palettes.
- Theme import/export.
- Animated transitions between theme variants for Mermaid diagrams (deferred to future consideration).

### 4.3 Assumptions

| ID | Assumption | Risk if Wrong |
|----|------------|---------------|
| A-1 | The macOS `colorScheme` environment value updates synchronously when System Preferences changes appearance. | A brief flash of the stale theme variant could appear. Mitigated by testing on macOS 14+. |
| A-2 | Caching Mermaid SVG output keyed by theme variant does not cause excessive memory use. | Two cached copies per diagram is acceptable for typical document sizes. |
| A-3 | Users who previously defaulted to Solarized Dark will get auto mode, which resolves to Dark if their OS is in dark mode -- effectively no visible change. | If a user had OS in light mode but manually preferred Dark, they will see a one-time switch to Light. Low risk given the personal daily-driver use case. |

## 5. Functional Requirements

### REQ-001: Three-State Theme Mode
- **Priority**: Must Have
- **User Type**: All users
- **Requirement**: The app must support three theme modes: Auto (follows OS appearance), Solarized Dark (always dark), and Solarized Light (always light).
- **Rationale**: Users need both automatic behavior and the ability to override when their preference diverges from the OS setting.
- **Acceptance Criteria**:
  - [ ] Three distinct modes are available: Auto, Dark, Light.
  - [ ] Selecting Auto causes the theme to reflect the current OS appearance.
  - [ ] Selecting Dark shows Solarized Dark regardless of OS appearance.
  - [ ] Selecting Light shows Solarized Light regardless of OS appearance.

### REQ-002: Auto Mode Resolves from OS Appearance
- **Priority**: Must Have
- **User Type**: Terminal-centric developer
- **Requirement**: When in Auto mode, the app must resolve Solarized Dark when the OS is in dark mode and Solarized Light when the OS is in light mode.
- **Rationale**: Terminal-consistent theming means matching the OS-level appearance, which is what a developer's terminal already does with Solarized.
- **Acceptance Criteria**:
  - [ ] OS dark mode produces Solarized Dark in the app.
  - [ ] OS light mode produces Solarized Light in the app.
  - [ ] No user interaction is required for the correct variant to be shown.

### REQ-003: Default to Auto Mode
- **Priority**: Must Have
- **User Type**: All users (new installs)
- **Requirement**: On first launch (no stored preference), the app must default to Auto mode.
- **Rationale**: The "just works" experience requires no configuration on first use. The app should match the OS from the very first frame.
- **Acceptance Criteria**:
  - [ ] A fresh install with no prior preferences launches in Auto mode.
  - [ ] The resolved theme matches the OS appearance on first launch.

### REQ-004: Preference Persistence
- **Priority**: Must Have
- **User Type**: All users
- **Requirement**: The selected theme mode (Auto, Dark, or Light) must persist across app launches.
- **Rationale**: Users who override the default expect their choice to be remembered.
- **Acceptance Criteria**:
  - [ ] User selects Dark, quits, relaunches: app shows Solarized Dark.
  - [ ] User selects Auto, quits, relaunches: app shows the variant matching current OS appearance.
  - [ ] Preference survives app updates (standard UserDefaults behavior).

### REQ-005: Live Switching in Auto Mode
- **Priority**: Must Have
- **User Type**: Terminal-centric developer
- **Requirement**: When in Auto mode, the app must respond immediately to OS appearance changes without requiring a restart or manual action.
- **Rationale**: Developers toggle system appearance and expect all apps to follow instantly. mkdn must behave like a native Mac app.
- **Acceptance Criteria**:
  - [ ] With the app open in Auto mode, toggling OS dark/light mode causes the theme to update within one frame (< 16ms for color swap).
  - [ ] All rendered content (markdown text, code blocks, backgrounds) reflects the new theme.
  - [ ] No restart, reload, or user action is required.

### REQ-006: Updated Theme Picker UI
- **Priority**: Must Have
- **User Type**: All users
- **Requirement**: The theme picker must expose the three-state choice (Auto, Dark, Light) in a clear, minimal UI.
- **Rationale**: Users need a discoverable way to switch modes and see which mode is active.
- **Acceptance Criteria**:
  - [ ] The picker displays three options: Auto, Dark, Light.
  - [ ] The currently active mode is visually indicated.
  - [ ] Selecting a mode takes effect immediately.

### REQ-007: Updated Theme Cycling
- **Priority**: Must Have
- **User Type**: Keyboard-focused developer
- **Requirement**: The existing keyboard shortcut for theme cycling must cycle through the three modes (Auto -> Dark -> Light -> Auto).
- **Rationale**: Keyboard-centric users rely on shortcuts rather than UI pickers. The existing binding must continue to work and cover the new three-state model.
- **Acceptance Criteria**:
  - [ ] The existing keyboard shortcut cycles through Auto, Dark, Light in order.
  - [ ] Each press advances to the next mode.
  - [ ] The cycle wraps from Light back to Auto.

### REQ-008: Mermaid Diagram Theme Consistency
- **Priority**: Must Have
- **User Type**: All users
- **Requirement**: When the resolved theme changes (via auto mode switching or manual override), Mermaid diagrams must display using the correct theme variant.
- **Rationale**: A theme switch that updates text and backgrounds but leaves Mermaid diagrams in the old colors creates visual inconsistency.
- **Acceptance Criteria**:
  - [ ] After a theme change, Mermaid diagrams render with colors matching the new theme.
  - [ ] Cached Mermaid output for the correct variant is used if available, avoiding unnecessary re-renders.
  - [ ] If no cached variant exists, an asynchronous re-render is triggered.

### REQ-009: No Flash of Wrong Theme at Launch
- **Priority**: Must Have
- **User Type**: All users
- **Requirement**: The app must resolve the correct theme variant before the first visible frame on launch.
- **Rationale**: A momentary flash of the wrong color scheme is jarring and breaks the perception of quality. The charter's design philosophy demands obsessive attention to sensory detail.
- **Acceptance Criteria**:
  - [ ] In Auto mode with OS in dark mode, the first visible frame uses Solarized Dark colors.
  - [ ] In Auto mode with OS in light mode, the first visible frame uses Solarized Light colors.
  - [ ] In pinned mode, the first visible frame uses the pinned variant.

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| Requirement | Target |
|-------------|--------|
| Color swap on theme change | < 16ms (within a single frame at 60fps) |
| Mermaid re-render on theme change | May be asynchronous; should complete within a reasonable time but is not required to be instantaneous. |
| Launch-time theme resolution | Before first paint -- no perceptible delay. |

### 6.2 Security Requirements

No specific security requirements for this feature. Theme preference is stored in standard UserDefaults (no sensitive data).

### 6.3 Usability Requirements

| Requirement | Description |
|-------------|-------------|
| Discoverability | The three-state picker must be easy to find within the existing theme UI. |
| Feedback | Switching modes provides immediate visual feedback via the theme change itself. |
| Keyboard accessibility | Theme cycling via keyboard shortcut must continue to work. |
| Clarity of "Auto" | The user must understand that "Auto" means "follows OS appearance." |

### 6.4 Compliance Requirements

- Must remain compatible with macOS 14.0+.
- No new external dependencies.
- Must pass SwiftLint strict mode and SwiftFormat.

## 7. User Stories

### STORY-001: Automatic Theme Matching
- **As a** terminal-centric developer
- **I want** mkdn to automatically match my OS dark/light appearance
- **So that** the viewer looks consistent with my terminal without any manual configuration.

**Acceptance Scenarios**:
- GIVEN the OS is in dark mode AND the app is set to Auto mode, WHEN the app launches, THEN Solarized Dark is displayed.
- GIVEN the OS is in light mode AND the app is set to Auto mode, WHEN the app launches, THEN Solarized Light is displayed.
- GIVEN the app is running in Auto mode, WHEN the user toggles OS appearance from dark to light, THEN the app immediately switches to Solarized Light.

### STORY-002: Manual Theme Override
- **As a** developer who prefers a specific Solarized variant
- **I want** to pin Dark or Light regardless of my OS appearance
- **So that** I always see my preferred variant even if my OS appearance changes.

**Acceptance Scenarios**:
- GIVEN the user selects Dark mode, WHEN the OS is in light mode, THEN the app displays Solarized Dark.
- GIVEN the user selects Light mode, WHEN the OS is in dark mode, THEN the app displays Solarized Light.
- GIVEN the user has pinned Dark, WHEN the user quits and relaunches, THEN Solarized Dark is displayed.

### STORY-003: Theme Cycling via Keyboard
- **As a** keyboard-focused developer
- **I want** to cycle through Auto, Dark, and Light with a keyboard shortcut
- **So that** I can quickly switch themes without reaching for the mouse.

**Acceptance Scenarios**:
- GIVEN the current mode is Auto, WHEN the user presses the theme cycle shortcut, THEN the mode changes to Dark.
- GIVEN the current mode is Dark, WHEN the user presses the theme cycle shortcut, THEN the mode changes to Light.
- GIVEN the current mode is Light, WHEN the user presses the theme cycle shortcut, THEN the mode changes to Auto.

### STORY-004: Mermaid Diagrams Follow Theme
- **As a** developer reviewing a document with Mermaid diagrams
- **I want** diagrams to update their colors when the theme changes
- **So that** the entire document looks visually consistent after a theme switch.

**Acceptance Scenarios**:
- GIVEN a document with a Mermaid flowchart is displayed in Solarized Dark, WHEN the theme switches to Solarized Light, THEN the flowchart re-renders with Solarized Light colors.
- GIVEN a cached Light variant exists, WHEN the theme switches to Light, THEN the cached version is used without re-rendering.

## 8. Business Rules

| Rule ID | Rule | Rationale |
|---------|------|-----------|
| BR-001 | Auto mode always resolves based on the current macOS system appearance at the moment of resolution. | The "terminal-consistent" promise means real-time parity with the OS setting. |
| BR-002 | Manual override takes absolute precedence over OS appearance. | User intent must be respected -- if they pinned Dark, Dark is shown regardless of OS changes. |
| BR-003 | New installs default to Auto mode. | The "just works" principle. Users should not need to configure anything to get the expected behavior. |
| BR-004 | Theme preference is a single global setting, not per-file or per-window. | Scope constraint from the PRD. Simplifies the model and matches user expectations for a lightweight viewer. |

## 9. Dependencies & Constraints

### Internal Dependencies

| Dependency | Description |
|------------|-------------|
| AppTheme enum and ThemeColors | The existing Solarized Dark and Light palettes must be in place. They are (SolarizedDark.swift, SolarizedLight.swift). |
| AppState central state | The theme mode and resolved theme must be managed here, consistent with the project's central state pattern. |
| ThemePickerView | The existing picker UI must be updated (not replaced) to accommodate the three-state model. |
| cycleTheme() | The existing cycling function must be updated to cycle through three modes. |
| MermaidRenderer cache | The Mermaid cache must account for theme variant to ensure correct diagram colors after a theme switch. |
| Views consuming theme colors | All views that read theme colors must receive the correct resolved colors after a mode change. |

### External Dependencies

None. This feature uses only built-in macOS/SwiftUI/Foundation APIs.

### Constraints

- macOS 14.0+ compatibility required.
- `@Observable` pattern (not `ObservableObject`) per project rules.
- `@MainActor` isolation on AppState must be preserved.
- The `colorScheme` environment value is only available inside SwiftUI views; the bridge from environment to AppState must happen at the view layer.

## 10. Clarifications Log

| ID | Question | Resolution | Source |
|----|----------|------------|--------|
| CL-001 | Should the mode overlay display "Auto (Dark)" or just "Dark" when in auto mode? | Deferred -- noted as open question from PRD (OQ-1). No requirement generated; UX decision to be made during design. | PRD OQ-1 |
| CL-002 | Should Mermaid diagrams animate their theme transition? | Out of scope for this feature. Simple re-render is sufficient. Animated transitions may be considered in a future enhancement. | PRD OQ-2, Scope |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | terminal-consistent-theming.md | Exact filename match with the feature ID. |
| Requirements source | PRD + Charter (no additional REQUIREMENTS param provided) | The REQUIREMENTS parameter was empty; the PRD provides comprehensive functional and non-functional requirements. |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| Theme cycle order (Auto -> Dark -> Light vs. other orderings) | Auto -> Dark -> Light -> Auto. Follows the natural order of the ThemeMode enum as described in the PRD. | PRD FR-6 |
| Whether "Auto" label is self-explanatory to users | Assumed yes for the target user (terminal-centric developers familiar with OS appearance settings). No additional explanation UI required. | Charter target user profile |
| Mermaid re-render strategy on theme change | Use cached variant if available; trigger async re-render if not. No animated transition. | PRD OQ-2 (conservative default: simple re-render) |
| Backwards compatibility for existing users | Auto mode resolves identically to the user's prior experience if their OS appearance matches their previous manual choice. One-time visible change possible for users whose OS and manual choice diverged. Accepted as low risk. | PRD A-3, Charter success criteria |
| Flash-prevention strategy specifics | Required as a must-have NFR. Implementation details (how to resolve before first paint) left to architecture/design phase. | PRD NFR-2 |
