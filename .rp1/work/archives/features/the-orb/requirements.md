# Requirements Specification: The Orb

**Feature ID**: the-orb
**Parent PRD**: [The Orb](../../prds/the-orb.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-10

## 1. Feature Overview

The Orb is a unified, stateful indicator that consolidates two existing separate UI elements -- the default handler hint and the file-change indicator -- into a single, color-coded orb fixed in the bottom-right corner of the window. The orb communicates application state through animated color transitions (violet, orange, green) and provides contextual actions via tap-to-popover interactions. When no actionable state exists, the orb is hidden entirely.

## 2. Business Context

### 2.1 Problem Statement

The current implementation uses two separate orbs positioned in different corners of the window (top-right for default handler hint, bottom-right for file change indicator). This fragmenting of attention violates the app's design philosophy of obsessive sensory detail and calm, unified feedback. Users must scan multiple screen locations to understand the application's state, and the two orbs can compete for attention or create visual clutter when both are active simultaneously.

### 2.2 Business Value

- **Simplified mental model**: Users learn one indicator mechanism instead of two, reducing cognitive load.
- **Extensible state communication**: A single prioritized state machine can accommodate future states (e.g., app updates) without adding more visual elements.
- **Design philosophy alignment**: Consolidation allows more refined animation transitions, color crossfades, and spatial consistency, reinforcing the charter's requirement for obsessive attention to sensory detail.
- **Progressive disclosure of preferences**: The auto-reload opt-in is discovered naturally within the file-changed interaction, avoiding a separate settings screen.

### 2.3 Success Metrics

- Users correctly interpret each orb color's meaning on first encounter (validated via popover content clarity).
- File-change reload workflow completes in fewer interactions than the current dual-orb design.
- No visual glitches or competing indicators during rapid state transitions.
- The auto-reload preference, once discovered and enabled, eliminates manual reload steps for unchanged files.

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Terminal-centric developer | Primary user. Opens Markdown files from the terminal, views and occasionally edits. Values aesthetics, simplicity, and minimal friction. | Interacts with all orb states: default handler prompt on first launch, file-change notifications during active use, potential update notifications in the future. |
| Power user with auto-reload preference | Subset of the primary user who works with rapidly-changing files (e.g., LLM-generated output). Wants file changes to auto-reload without intervention. | Discovers and enables the "always reload when unchanged" preference via the file-changed popover. |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project creator / daily-driver user | A calm, beautiful indicator system that communicates state without modal interruptions. The orb should feel like a living element that breathes and transitions naturally. |

## 4. Scope Definition

### 4.1 In Scope

- A single unified orb view replacing both existing indicator views.
- An enum-driven state machine with priority ordering to determine which state the orb displays.
- Color-coded states: violet (default handler prompt), orange (file changed on disk), green (update available placeholder).
- Tap-to-popover interaction with contextual actions for each state.
- An "always reload when unchanged" user preference, discovered in-context within the file-changed popover.
- Auto-reload behavior with a single-pulse acknowledgment cycle when the preference is enabled and no unsaved changes exist.
- Auto-reload guard that falls back to manual prompt when unsaved changes are present.
- Pulse cycle cancellation on user tap.
- Animated color crossfade between orb states.
- Removal of the two existing separate orb views and consolidation of overlay logic.

### 4.2 Out of Scope

- Actual app update checking infrastructure (the green state is a visual placeholder only; no update server, no version checking).
- Notification center or system alert integration.
- Sound or haptic feedback.
- Persistent always-visible orb (hidden when no actionable state).
- Badge counts or numeric indicators on the orb.
- A separate settings screen or preferences window for the auto-reload toggle (discovered in-context only).

### 4.3 Assumptions

- The existing `OrbVisual` three-layer rendering component can smoothly animate its `color` parameter via SwiftUI's built-in Color interpolation within `withAnimation`.
- A single ~5s pulse cycle (one full breathing animation) provides sufficient visual acknowledgment before auto-reloading.
- The auto-reload preference defaulting to off satisfies the charter's specification for "manual reload prompt (not auto-reload)."
- The state priority ordering (orange > violet > green) covers all realistic concurrent conditions without edge cases.

## 5. Functional Requirements

| REQ-ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|--------|----------|-----------|-------------|-----------|---------------------|
| REQ-01 | Must Have | All users | The application shall present a single unified orb indicator driven by an enum state machine with states: idle (hidden), default handler (violet), file changed (orange), and update available (green). | Replaces two separate indicators with one cohesive element, reducing visual fragmentation. | Given any combination of active states, when the orb is rendered, then exactly one orb is visible at the fixed bottom-right position (or hidden if idle), displaying the color of the highest-priority active state. |
| REQ-02 | Must Have | All users | The orb shall follow a strict priority ordering: file changed (orange) supersedes default handler (violet) supersedes update available (green) supersedes idle (hidden). | Ensures the most time-sensitive state is always surfaced. File changes require immediate attention; the default handler prompt can wait. | Given both file-changed and default-handler states are active simultaneously, when the orb is displayed, then it shows orange (file changed). When the file-changed state clears, it transitions to violet (default handler). |
| REQ-03 | Must Have | First-launch user | When the default handler prompt has not been permanently dismissed, the orb shall appear violet. Tapping it shall present a popover asking whether to make mkdn the default Markdown reader, with Yes and No options. Yes shall register the app as the default handler. Either choice shall permanently dismiss the prompt. | Provides a non-intrusive, one-time prompt that respects the user's choice without modal interruptions. | Given a first-launch user who has not responded to the default handler prompt, when the orb appears violet and the user taps it, then a popover appears with the prompt and Yes/No buttons. After tapping either button, the orb permanently stops showing the violet state across all future launches. |
| REQ-04 | Must Have | All users | When a file has changed on disk, the orb shall appear orange. Tapping it shall present a popover offering to reload the file, with Yes and No options. The popover shall also include a toggle for enabling automatic reloading. | Provides clear, contextual notification of file changes with an immediate path to reload and a discoverable path to the auto-reload preference. | Given the monitored file has changed on disk, when the user taps the orange orb, then a popover appears with reload Yes/No and an auto-reload toggle. Tapping Yes reloads the file content. The toggle persists the auto-reload preference. |
| REQ-05 | Must Have | Power user with auto-reload | When the auto-reload preference is enabled and the document has no unsaved changes, the orb shall appear orange, complete one full breathing cycle (~5 seconds), then automatically reload the file and dismiss the orb. | Eliminates manual reload friction for users who work with rapidly-changing files and have explicitly opted in to automatic behavior. | Given auto-reload is enabled and the file has no unsaved changes, when the file changes on disk, then the orb appears orange, pulses for approximately 5 seconds, reloads the file, and then becomes hidden (idle). |
| REQ-06 | Must Have | All users | A boolean "always reload when unchanged" preference shall be available, defaulting to off, persisted across launches. It shall be toggled from within the file-changed popover only. | The charter specifies manual reload as default behavior. The opt-in preference extends this without contradicting the charter. In-context discovery avoids a separate settings screen. | Given the preference does not exist, when the app launches, then the preference defaults to false. Given the preference is toggled on in the popover, when the app is restarted, then the preference retains its value. |
| REQ-07 | Must Have | Power user with unsaved changes | When the auto-reload preference is enabled but the document has unsaved changes, the orb shall ignore the auto-reload preference and present the manual reload popover instead. | Protects unsaved work from being overwritten by automatic reloading. | Given auto-reload is enabled and the user has unsaved changes, when the file changes on disk, then the orb appears orange and tapping it shows the manual reload popover (not auto-reload behavior). |
| REQ-08 | Should Have | Power user with auto-reload | If the user taps the orb during an auto-reload pulse cycle, the auto-reload timer shall be cancelled and the manual reload popover shall be presented instead. | Gives the user an escape hatch to inspect or cancel the auto-reload before it completes. | Given auto-reload is in progress (orb pulsing), when the user taps the orb, then the pulse cycle stops, the auto-reload is cancelled, and the manual reload popover appears. |
| REQ-09 | Could Have | All users (future) | The orb shall support a green state for "update available." Tapping it shall show an informational popover. No backend action is required. | Establishes the visual and interaction pattern for future update notification infrastructure without requiring the backend. | Given the green state is triggered (via placeholder mechanism), when the user taps the orb, then a popover displays "An update is available" with no actionable backend call. |
| REQ-10 | Must Have | All users | When the orb transitions between states (color changes), the transition shall be an animated crossfade rather than a hard cut. | Aligns with the charter's design philosophy of animations that feel physical and natural. A hard cut would feel jarring. | Given the orb is in violet state and a file change occurs, when the state transitions to orange, then the orb color smoothly crossfades from violet to orange over the configured animation duration. |
| REQ-11 | Must Have | All users | The orb shall be positioned at the bottom-right corner of the window with consistent padding. | Matches the current file-change orb placement, providing spatial consistency. | Given the orb is visible, when the window is any size, then the orb remains anchored to the bottom-right corner with fixed padding from the edges. |
| REQ-12 | Must Have | All users | The two existing separate orb views (FileChangeOrbView and DefaultHandlerHintView) shall be removed and replaced by the unified orb. The main content view shall reference only the single unified orb overlay. | Eliminates dead code and ensures no dual-orb rendering can occur. | Given the feature is complete, when the codebase is inspected, then FileChangeOrbView.swift and DefaultHandlerHintView.swift no longer exist, and ContentView references only TheOrbView. |

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

- The orb's state transitions and animations shall not cause dropped frames or UI thread blocking.
- Rapid file-change events during an auto-reload pulse cycle shall reset the cycle rather than queue multiple reloads, preventing cascading reload operations.
- Auto-reload timer precision is acceptable within 500ms of the animation duration (~5 seconds).

### 6.2 Security Requirements

- No security-specific requirements for this feature.
- The auto-reload preference is stored in UserDefaults (standard app sandbox behavior).

### 6.3 Usability Requirements

- All animations shall respect the macOS "Reduce Motion" accessibility setting. When Reduce Motion is enabled, continuous pulse animations shall be replaced with static opacity states, and crossfades shall use a reduced duration.
- Popover content shall be self-explanatory without requiring external documentation or a tutorial.
- The auto-reload toggle shall be clearly labeled to communicate its effect (automatic reloading of unchanged files).

### 6.4 Compliance Requirements

- Orb colors (violet, orange, green) shall maintain sufficient visual contrast against both Solarized Dark and Solarized Light theme backgrounds.
- Color values shall be derived from the Solarized palette or chosen to harmonize with it.

## 7. User Stories

| STORY-ID | User Story | Acceptance Scenario |
|----------|------------|---------------------|
| STORY-01 | As a first-launch user, I want the app to non-intrusively ask whether I would like it to be my default Markdown reader, so that I can make the choice without being interrupted by a modal dialog. | GIVEN I am opening mkdn for the first time, WHEN the app loads, THEN a violet orb appears in the bottom-right corner. WHEN I tap the orb, THEN a popover asks if I want to set mkdn as default. WHEN I choose Yes or No, THEN the violet orb never appears again on future launches. |
| STORY-02 | As a developer viewing a Markdown file, I want to be notified when the file changes on disk, so that I can decide whether to reload the latest version. | GIVEN I have a Markdown file open, WHEN the file is modified externally (e.g., by a coding agent), THEN the orb appears orange. WHEN I tap it, THEN a popover offers to reload, and I can choose Yes or No. |
| STORY-03 | As a power user who works with LLM-generated files, I want to enable automatic reloading so that file changes are reflected without manual intervention. | GIVEN I am viewing the file-changed popover, WHEN I toggle on "Always reload when unchanged," THEN the preference is saved. GIVEN the preference is enabled and I have no unsaved changes, WHEN the file changes on disk next, THEN the orb appears orange, pulses once (~5 seconds), and automatically reloads the file. |
| STORY-04 | As a user editing a file, I want auto-reload to be suppressed when I have unsaved changes, so that my work is not overwritten. | GIVEN auto-reload is enabled and I have unsaved changes, WHEN the file changes on disk, THEN the orb appears orange but does not auto-reload. WHEN I tap the orb, THEN I see the manual reload popover. |
| STORY-05 | As a user who sees the orb pulsing for auto-reload, I want to be able to cancel the auto-reload by tapping the orb, so that I can inspect the situation before the file is reloaded. | GIVEN the orb is in an auto-reload pulse cycle, WHEN I tap the orb, THEN the auto-reload is cancelled and the manual reload popover appears instead. |
| STORY-06 | As a user switching between states, I want the orb to smoothly crossfade between colors, so that the transition feels natural and not jarring. | GIVEN the orb is showing violet and a file change triggers the orange state, WHEN the state transitions, THEN the orb color smoothly crossfades from violet to orange. |
| STORY-07 | As a user with Reduce Motion enabled, I want the orb to respect my accessibility preference, so that continuous pulsing animations are replaced with static states. | GIVEN Reduce Motion is enabled in macOS System Settings, WHEN the orb is visible, THEN it does not pulse continuously and crossfades use a reduced duration. |

## 8. Business Rules

| Rule ID | Rule | Rationale |
|---------|------|-----------|
| BR-01 | The auto-reload preference shall default to off (false). | The charter explicitly specifies "manual reload prompt (not auto-reload)." Auto-reload is an opt-in extension, not default behavior. |
| BR-02 | The default handler prompt shall be shown at most once per installation lifetime. | Respects the user's initial choice. Repeated prompting would feel pushy and violate the app's design philosophy of calm interaction. |
| BR-03 | Only one orb instance shall exist per window at any time. | Prevents visual confusion from duplicate indicators and ensures the state machine is the single source of truth for what the orb displays. |
| BR-04 | When multiple states are active, the highest-priority state wins. Lower-priority states are not lost -- they surface when higher-priority states clear. | Ensures the most urgent information is always presented first, while deferred states are eventually shown. |
| BR-05 | The auto-reload preference is discoverable only through the file-changed popover; it shall not appear in a separate settings screen. | Progressive disclosure: the preference is presented in context when it is most relevant, keeping the app simple and avoiding a traditional settings UI. |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Description |
|------------|-------------|
| OrbVisual rendering component | Existing three-layer orb rendering (outer halo, mid-glow, inner core) parameterized by color. Must be reused without modification to visual structure. |
| DocumentState | Provides file-outdated status, unsaved-changes status, and reload capability. The orb reads state from this object. |
| AppSettings | Provides the existing default-handler-hint-shown flag. Must be extended with the new auto-reload preference. |
| DefaultHandlerService | Provides the ability to register as default Markdown handler and check current status. No changes needed. |
| FileWatcher | Drives file-outdated state detection via kernel-level file monitoring. No changes needed. |
| AnimationConstants | Provides animation timing values and existing orb color constants. Must be extended with new color constants for the orange and green states. |

### Constraints

- Only one TheOrbView instance per window. The state machine within the view is the sole arbiter of orb display; no external view should conditionally show or hide the orb.
- The auto-reload timer must be properly cancelled when the document is closed, the user taps the orb, or the file-outdated state clears by other means (e.g., Cmd+R reload).
- No new external dependencies (SPM packages). The feature uses only SwiftUI and existing app frameworks.
- Color constants for the new orb states must follow established naming patterns in AnimationConstants and use Solarized-derived or Solarized-harmonious values.

## 10. Clarifications Log

| ID | Question | Resolution | Source |
|----|----------|------------|--------|
| CL-01 | What triggers the green (update available) state? | Placeholder only. The triggering mechanism is deferred to future update-checking infrastructure. For now, it is a visual state that can be activated via a placeholder flag or compile-time constant for testing purposes. | PRD OQ-1 |
| CL-02 | What UI control should the "always reload" toggle use in the popover? | Deferred to design/implementation phase. The requirement specifies a toggle control within the popover; the specific widget (checkbox, switch, text link, or third button) is a UX detail. | PRD OQ-2 |
| CL-03 | Should the popover mention that auto-reload is paused due to unsaved changes? | Deferred to design/implementation phase. The requirement specifies that the manual popover is shown; whether it includes explanatory text about the auto-reload guard is a UX detail. | PRD OQ-3 |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | the-orb.md | Exact filename match with feature ID "the-orb". |
| Requirements source | Derived from PRD | No explicit REQUIREMENTS parameter was provided. All requirements were derived from the PRD and charter. |
| Auto-reload default value | Off (false) | Charter explicitly states "manual reload prompt (not auto-reload)." Defaulting to off is the conservative, charter-aligned choice. |
| Green state implementation depth | Placeholder only | PRD explicitly marks green state as "Could Have" and visual placeholder only. No backend requirements generated. |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| Toggle UI control type for auto-reload preference (PRD OQ-2) | Left as "toggle control" without specifying widget type. This is a UX/implementation detail, not a business requirement. | PRD OQ-2; WHAT-not-HOW constraint |
| Whether popover should explain auto-reload guard when unsaved changes exist (PRD OQ-3) | Left as implementation detail. The requirement specifies behavior (fall back to manual popover) but not explanatory copy. | PRD OQ-3; WHAT-not-HOW constraint |
| Green state trigger mechanism (PRD OQ-1) | Specified as placeholder with no backend. Trigger mechanism deferred to future infrastructure work. | PRD OQ-1; Out of Scope section |
| Priority of REQ-08 (pulse cancellation) | Assigned "Should Have" per PRD FR-8 priority designation. | PRD FR-8 |
| Priority of REQ-09 (green state) | Assigned "Could Have" per PRD FR-9 priority designation. | PRD FR-9 |
| Acceptance criteria measurability for animation smoothness | Defined as "crossfade" behavior (not hard cut) rather than specifying frame rates or interpolation curves, which are implementation details. | WHAT-not-HOW constraint; charter design philosophy |
