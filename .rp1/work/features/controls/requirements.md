# Requirements Specification: Controls

**Feature ID**: controls
**Parent PRD**: [Controls](../../prds/controls.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-06

## 1. Feature Overview

The Controls feature replaces mkdn's current toolbar-based interaction model with a chrome-less, keyboard-driven control philosophy. All navigation and actions are driven by keyboard shortcuts and macOS menu bar commands. Visual feedback is delivered through ultra-minimal indicators -- a breathing orb for file-change notification and ephemeral overlays for mode transitions -- creating a meditative, distraction-free reading and editing experience.

## 2. Business Context

### 2.1 Problem Statement

The current toolbar-based interaction model introduces persistent visual chrome that competes with the rendered Markdown content for the user's attention. For a tool designed to provide a beautiful, zen-like reading experience for developer-authored Markdown artifacts, visible UI controls are a distraction. Developers who live in the terminal already think in keyboard shortcuts; forcing them through toolbar clicks is friction that contradicts the app's design philosophy.

### 2.2 Business Value

- Reinforces mkdn's core differentiator as a "beautiful, simple" Markdown viewer that feels crafted, not assembled
- Aligns the interaction model with the target user's keyboard-centric workflow habits
- Delivers on the charter's Design Philosophy of "obsessive attention to sensory detail" through thoughtfully animated indicators
- Maximizes the content-to-chrome ratio, giving rendered Markdown the entire window

### 2.3 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Keyboard shortcut discoverability | A new user can discover mode switching (Cmd+1/Cmd+2) within 30 seconds via the menu bar | Manual usability observation |
| Daily-driver usability | The creator uses keyboard shortcuts exclusively for all mode/theme/reload operations | Self-reported usage patterns |
| Animation smoothness | All indicator and transition animations run at 60fps on macOS 14+ hardware | Instruments profiling, no dropped frames |
| Shortcut response latency | All keyboard shortcuts respond in under 50ms | Perceived instant response, profiled if needed |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Terminal Developer | Primary user. Works from the terminal, launches mkdn via CLI, reads and edits Markdown files produced by LLMs and coding agents. Thinks in keyboard shortcuts. | Primary actor for all controls requirements |
| New User | A developer trying mkdn for the first time. May not know any keyboard shortcuts. Needs a discovery path. | Actor for menu bar discoverability requirements |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project creator | Daily-driver quality; the interaction model must feel so natural that visible chrome would feel wrong |
| Terminal developers | Speed and keyboard fluency; no mouse required for core workflows |
| Aesthetic-sensitive users | Animation quality and visual polish; indicators should feel calming, not distracting |

## 4. Scope Definition

### 4.1 In Scope

- Complete removal of the toolbar from the application window
- Keyboard shortcuts as the primary interaction layer (Cmd+1, Cmd+2, Cmd+R, Cmd+O, Cmd+T)
- macOS menu bar expansion to expose all shortcuts for discoverability
- Breathing orb indicator replacing the current text-based outdated file badge
- Ephemeral overlay labels on mode transitions
- Smooth crossfade animation on theme cycling
- Centralization of all animation timing constants

### 4.2 Out of Scope

- On-screen buttons or floating action controls
- Context menus or right-click interactions
- Touch Bar support
- Custom key binding configuration or remapping
- Accessibility VoiceOver enhancements for indicators (planned as a future feature)
- Preferences window or settings UI
- Drag-and-drop visual indicators

### 4.3 Assumptions

| ID | Assumption | Risk if Wrong |
|----|------------|---------------|
| A-1 | The macOS menu bar provides sufficient discoverability for keyboard shortcuts | Users may never discover key bindings and feel lost without a toolbar |
| A-2 | A breathing-rate animation (~12 cycles/min) will feel calming rather than distracting | The orb may feel anxious or annoying; will need tuning |
| A-3 | Removing the toolbar is a net positive for the zen reading experience | Some users may prefer a visible mode toggle; the menu bar mitigates this |
| A-4 | Five keyboard shortcuts (Cmd+1/2/R/O/T) are sufficient for daily-driver use | Additional shortcuts may be needed as features grow |
| A-5 | The SwiftUI built-in animation system is sufficient for the orb glow effect | May need alternative rendering approaches for precise glow |

## 5. Functional Requirements

### FR-CTRL-001: Keyboard Shortcut Layer
- **Priority**: Must Have
- **User Type**: Terminal Developer
- **Requirement**: The user can perform all core actions via keyboard shortcuts without touching the mouse: switch to preview-only mode (Cmd+1), switch to side-by-side edit mode (Cmd+2), reload file from disk (Cmd+R), open a file (Cmd+O), and cycle theme (Cmd+T).
- **Rationale**: Terminal developers think in keyboard shortcuts. Making keyboard the primary (and only non-menu) interaction path aligns the app with its target user's muscle memory and workflow.
- **Acceptance Criteria**:
  - AC-1: Pressing Cmd+1 switches the view to preview-only mode regardless of current mode.
  - AC-2: Pressing Cmd+2 switches the view to side-by-side edit + preview mode regardless of current mode.
  - AC-3: Pressing Cmd+R reloads the current file from disk when a file is open and the file has changed.
  - AC-4: Pressing Cmd+O opens the system file picker (NSOpenPanel) filtered to Markdown files.
  - AC-5: Pressing Cmd+T cycles the theme to the next available theme (Solarized Dark to Solarized Light and back).
  - AC-6: All shortcuts respond within 50ms of keypress.

### FR-CTRL-002: Menu Bar Discoverability
- **Priority**: Must Have
- **User Type**: New User
- **Requirement**: The macOS menu bar exposes all keyboard shortcuts in standard menu groups (View, File) so that a user unfamiliar with mkdn can discover available actions by browsing the menus.
- **Rationale**: Without a toolbar, the menu bar is the only visual surface for users to learn what the app can do. Standard macOS menu placement ensures familiarity.
- **Acceptance Criteria**:
  - AC-1: A "View" menu group contains items for "Preview Mode" (Cmd+1) and "Edit Mode" (Cmd+2).
  - AC-2: A "File" menu group contains items for "Open..." (Cmd+O) and "Reload" (Cmd+R).
  - AC-3: A menu item exists for "Cycle Theme" (Cmd+T) in an appropriate menu group.
  - AC-4: Each menu item displays its keyboard shortcut in the standard macOS format (right-aligned shortcut text).
  - AC-5: Menu items are enabled/disabled appropriately (e.g., Reload is disabled when no file is open or file is current).

### FR-CTRL-003: Toolbar Removal
- **Priority**: Must Have
- **User Type**: Terminal Developer
- **Requirement**: The application window contains no toolbar, no toolbar items, and no visible UI chrome beyond the rendered Markdown content (plus the title bar).
- **Rationale**: Persistent visible controls compete with content for attention. The zen reading experience requires maximum content-to-chrome ratio.
- **Acceptance Criteria**:
  - AC-1: The application window renders no toolbar area below the title bar.
  - AC-2: The ViewModePicker component is no longer rendered in the window.
  - AC-3: All functionality previously accessible via toolbar controls remains accessible via keyboard shortcuts and menu bar items.

### FR-CTRL-004: Breathing Orb File-Change Indicator
- **Priority**: Must Have
- **User Type**: Terminal Developer
- **Requirement**: When the underlying Markdown file changes on disk, the user sees a small glowing orb appear in a corner of the content area. The orb pulses at approximately human breathing rate (~12 cycles per minute, ~5 seconds per cycle) with smooth sinusoidal opacity and scale animation. The orb has no text label.
- **Rationale**: The current text-based "outdated" badge is visually heavy and breaks the zen aesthetic. A breathing orb is a subtle, calming notification that something has changed without demanding immediate attention.
- **Acceptance Criteria**:
  - AC-1: When the file watcher detects a change on disk, a small circular orb appears in a corner of the content area.
  - AC-2: The orb has no accompanying text or label.
  - AC-3: The orb animates with a smooth pulse (opacity and/or scale variation) at approximately 12 cycles per minute.
  - AC-4: The orb is visually subtle -- it does not dominate the content area or distract from reading.
  - AC-5: The orb is visible in both Solarized Dark and Solarized Light themes.

### FR-CTRL-005: Orb Dissolve on Reload
- **Priority**: Must Have
- **User Type**: Terminal Developer
- **Requirement**: When the user reloads the file (Cmd+R), the breathing orb dissolves with a smooth fade-out and scale-down animation rather than abruptly disappearing.
- **Rationale**: Abrupt visual changes break the meditative feel. A dissolve animation acknowledges the user's action with a satisfying, physical-feeling transition.
- **Acceptance Criteria**:
  - AC-1: Pressing Cmd+R when the orb is visible causes the orb to animate out (fade and shrink).
  - AC-2: The dissolve animation completes smoothly without visual glitches.
  - AC-3: After the dissolve, the orb is fully removed from the view hierarchy (not just invisible).

### FR-CTRL-006: Ephemeral Mode Transition Overlay
- **Priority**: Should Have
- **User Type**: Terminal Developer
- **Requirement**: When the user switches between preview-only and side-by-side modes, a brief overlay label appears showing the new mode name (e.g., "Preview" or "Edit"). The overlay enters with a spring animation and exits with a fade, auto-dismissing after approximately 1.5 seconds.
- **Rationale**: Without a toolbar indicating the current mode, users need momentary confirmation that their mode switch was registered. An ephemeral overlay provides this without adding persistent chrome.
- **Acceptance Criteria**:
  - AC-1: Switching to preview-only mode displays an overlay with the text "Preview" (or similar).
  - AC-2: Switching to side-by-side mode displays an overlay with the text "Edit" (or similar).
  - AC-3: The overlay enters with a spring animation (scale/opacity spring-in).
  - AC-4: The overlay auto-dismisses after approximately 1.5 seconds without user interaction.
  - AC-5: The overlay exits with a smooth fade-out.
  - AC-6: Rapid mode switching (pressing Cmd+1 then Cmd+2 quickly) handles gracefully -- the previous overlay is replaced by the new one without visual artifacts.

### FR-CTRL-007: Smooth Theme Cycling
- **Priority**: Should Have
- **User Type**: Terminal Developer
- **Requirement**: When the user cycles the theme via Cmd+T, the color palette transition uses a smooth crossfade rather than an instant swap.
- **Rationale**: Instant color changes are jarring. A crossfade provides a polished, physical-feeling transition consistent with the app's design philosophy.
- **Acceptance Criteria**:
  - AC-1: Pressing Cmd+T transitions all colors (background, text, accents) with a smooth crossfade animation.
  - AC-2: The transition does not cause a flash of unstyled or intermediate content.
  - AC-3: Content remains readable throughout the transition.

### FR-CTRL-008: Centralized Animation Timing Constants
- **Priority**: Could Have
- **User Type**: (Internal -- developer maintaining the codebase)
- **Requirement**: All animation timing parameters (durations, spring stiffness/damping, easing curves, cycle rates) are defined in a single location, serving as the single source of truth for animation tuning across the Controls feature.
- **Rationale**: The charter's Design Philosophy demands obsessive tuning. Centralizing timing constants makes iterative tuning efficient and prevents inconsistency.
- **Acceptance Criteria**:
  - AC-1: A single file or structure defines all animation timing constants used by the breathing orb, mode overlay, and theme transition.
  - AC-2: Changing a constant in the centralized location changes the corresponding animation behavior across the app.
  - AC-3: No animation durations or curves are hardcoded outside the centralized location.

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-CTRL-001 | All animations (orb pulse, mode overlay, theme crossfade) run at 60fps on macOS 14.0+ | Must Have |
| NFR-CTRL-002 | Keyboard shortcut response latency is under 50ms | Must Have |
| NFR-CTRL-003 | The breathing orb consumes minimal CPU when idling (animation driven by the SwiftUI animation system, not manual timers) | Should Have |

### 6.2 Security Requirements

No specific security requirements for this feature. Keyboard shortcuts and menu commands operate entirely within the application sandbox.

### 6.3 Usability Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-CTRL-004 | A new user can discover how to switch modes within 30 seconds by browsing the menu bar | Must Have |
| NFR-CTRL-005 | The breathing orb is noticeable but not distracting during extended reading sessions | Must Have |
| NFR-CTRL-006 | Mode transition overlays provide clear, unambiguous confirmation of the active mode | Should Have |

### 6.4 Compliance Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-CTRL-007 | Menu bar items remain accessible to VoiceOver (no accessibility regression from toolbar removal) | Should Have |
| NFR-CTRL-008 | Keyboard shortcuts follow macOS Human Interface Guidelines for standard actions (Cmd+O for Open, Cmd+S for Save where applicable) | Must Have |

## 7. User Stories

### STORY-CTRL-001: Quick Mode Switching
- **As a** terminal developer
- **I want** to switch between preview-only and side-by-side edit modes using keyboard shortcuts
- **So that** I can transition between reading and editing without reaching for the mouse

**Acceptance Scenarios**:
- GIVEN the app is in preview-only mode WHEN I press Cmd+2 THEN the view switches to side-by-side edit + preview mode AND an ephemeral "Edit" overlay briefly appears
- GIVEN the app is in side-by-side mode WHEN I press Cmd+1 THEN the view switches to preview-only mode AND an ephemeral "Preview" overlay briefly appears

### STORY-CTRL-002: Discovering Shortcuts
- **As a** new user
- **I want** to see available actions and their keyboard shortcuts in the macOS menu bar
- **So that** I can learn mkdn's controls without consulting documentation

**Acceptance Scenarios**:
- GIVEN I am unfamiliar with mkdn WHEN I click the "View" menu THEN I see "Preview Mode" with Cmd+1 and "Edit Mode" with Cmd+2 listed
- GIVEN I am unfamiliar with mkdn WHEN I click the "File" menu THEN I see "Open..." with Cmd+O and "Reload" with Cmd+R listed

### STORY-CTRL-003: Noticing a File Change
- **As a** terminal developer
- **I want** a subtle visual indicator when the file I am viewing has changed on disk
- **So that** I know when to reload without being interrupted from reading

**Acceptance Scenarios**:
- GIVEN I am viewing a Markdown file WHEN the file changes on disk (e.g., an LLM agent writes to it) THEN a small glowing orb appears in the corner of the content area pulsing gently
- GIVEN the orb is visible WHEN I press Cmd+R THEN the file reloads with fresh content AND the orb dissolves smoothly

### STORY-CTRL-004: Cycling Themes
- **As a** terminal developer
- **I want** to cycle between Solarized Dark and Light themes with a keyboard shortcut
- **So that** I can match my viewing environment (e.g., switching from day to night) without leaving the keyboard

**Acceptance Scenarios**:
- GIVEN the current theme is Solarized Dark WHEN I press Cmd+T THEN the theme transitions smoothly to Solarized Light via a crossfade
- GIVEN the current theme is Solarized Light WHEN I press Cmd+T THEN the theme transitions smoothly to Solarized Dark via a crossfade

### STORY-CTRL-005: Chrome-Free Reading
- **As a** terminal developer
- **I want** no toolbar or visible UI controls cluttering the window
- **So that** I can focus entirely on the rendered Markdown content in a distraction-free environment

**Acceptance Scenarios**:
- GIVEN I open a Markdown file WHEN the content renders THEN there is no toolbar visible below the title bar
- GIVEN I am reading a file WHEN I look at the window THEN the only visible elements are the rendered content and (if applicable) the breathing orb indicator

## 8. Business Rules

| ID | Rule | Rationale |
|----|------|-----------|
| BR-001 | Keyboard shortcuts must be operational before the toolbar is removed | Removing the toolbar without alternative controls would leave the app non-functional for mode switching |
| BR-002 | The breathing orb must be visible in both light and dark themes | Users on either theme must be notified of file changes |
| BR-003 | Rapid repeated input (e.g., pressing Cmd+T multiple times quickly) must not cause visual artifacts or broken animation states | The app must remain visually stable under any input cadence |
| BR-004 | Menu items for context-dependent actions (Reload) must be disabled when not applicable (no file open, file is current) | Prevents user confusion from invoking no-op actions |

## 9. Dependencies & Constraints

### Internal Dependencies

| Dependency | Description | Impact |
|------------|-------------|--------|
| AppState | Central state container must support indicator visibility state, mode transition state, and theme state | Modifications required to AppState before indicator work can begin |
| FileWatcher | Existing file change detection drives the breathing orb trigger | No changes expected to FileWatcher itself; it already signals changes |
| MkdnCommands | Must be expanded with full menu structure before toolbar removal | Phase 1 prerequisite |
| ContentView | Must have toolbar modifiers removed and overlay layers added | Breaking change -- requires menu/shortcut controls to be in place first |
| OutdatedIndicator | Existing component must be redesigned entirely from text badge to breathing orb | Current implementation is replaced, not extended |
| ViewModePicker | Current toolbar component is removed from the UI | May be deleted or archived |

### External Dependencies

None. No new packages or frameworks required. All capabilities use built-in SwiftUI and AppKit APIs.

### Constraints

| Constraint | Description |
|------------|-------------|
| macOS 14.0+ | All animation APIs and SwiftUI features must be available on macOS Sonoma |
| Swift 6 concurrency | All state mutations through @MainActor-isolated AppState; animation state must respect actor isolation |
| No WKWebView | Absolute constraint. All indicators and overlays must be native SwiftUI views |
| Ordering constraint | Keyboard shortcuts and menu commands must be fully operational before toolbar removal (Phase 1 before Phase 2/3) |

## 10. Clarifications Log

| ID | Question | Resolution | Source |
|----|----------|------------|--------|
| CL-001 | What specific keyboard shortcuts should be supported? | Cmd+1 (preview), Cmd+2 (edit), Cmd+R (reload), Cmd+O (open), Cmd+T (theme cycle) | PRD FR-1 |
| CL-002 | What replaces the toolbar for mode switching? | Keyboard shortcuts + macOS menu bar | PRD Scope |
| CL-003 | What does the file-change indicator look like? | Small glowing orb, no text, pulsing at breathing rate (~12 cycles/min) | PRD FR-4, FR-5 |
| CL-004 | How does the user know what mode they are in? | Ephemeral overlay appears briefly on mode switch; no persistent mode indicator | PRD FR-7 |
| CL-005 | What themes are supported for cycling? | Solarized Dark and Solarized Light (two themes, toggle behavior) | Charter, Concept Map |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | controls.md | Exact filename match with feature ID "controls" |
| Requirements source | PRD controls.md as primary source | REQUIREMENTS parameter was empty; PRD contains comprehensive functional and non-functional requirements |
| Orb color | Deferred (open question OQ-1 in PRD) | PRD explicitly marks this as an open design question; no default assumed |
| Orb position | Fixed corner position (not configurable) | Conservative default; PRD OQ-2 asks about configurability but fixed is simpler and aligns with minimal philosophy |
| Startup animation | No startup animation | Conservative default; PRD OQ-3 is open; instant content display is simpler and more aligned with "open, render, read" workflow |
| Drag-and-drop visual indicator | No change to existing behavior | PRD OQ-4 notes existing drag-and-drop works; chrome-less philosophy suggests no additional visual indicator needed |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| Empty REQUIREMENTS parameter | Used PRD controls.md as the sole requirements source, supplemented by charter and concept map for context | PRD auto-matched by feature ID |
| Priority mapping (PRD P0/P1/P2 to MoSCoW) | P0 mapped to Must Have, P1 mapped to Should Have, P2 mapped to Could Have | Standard priority mapping convention |
| "Ephemeral overlay" label text | Used "Preview" and "Edit" as overlay labels based on PRD example text | PRD FR-7 suggests "Preview" or "Edit" |
| Mode transition overlay behavior during rapid input | Overlay replaces previous overlay without stacking or visual artifacts | Conservative default from BR-003 and PRD Phase 3 edge case testing |
| Theme cycle direction | Linear toggle between two themes (Dark to Light, Light to Dark) | Only two themes exist per concept map; cycle is effectively a toggle |
| Cmd+T menu placement | Placed under a general menu group rather than specifying exact menu name | PRD says "Cmd+T -- Cycle theme" but does not specify menu group; left flexible for implementation |
