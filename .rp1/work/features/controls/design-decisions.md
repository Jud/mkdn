# Design Decisions: Controls

**Feature ID**: controls
**Created**: 2026-02-06

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | Overlay state management approach | `modeOverlayLabel: String?` property on AppState | Follows existing pattern of AppState as single source of truth. A nil value means no overlay; non-nil provides both visibility signal and display text. Simple, testable, no new state objects needed. | Separate `isOverlayVisible: Bool` + `overlayText: String` (more properties, same effect); dedicated OverlayState object (over-engineering for two fields); view-local @State only (not testable, not accessible from commands) |
| D2 | Rapid input handling for mode overlay | SwiftUI `.id(label)` keying on the overlay view | When the label changes, SwiftUI destroys and recreates the view, naturally cancelling the previous Task.sleep dismiss timer. Zero manual cancellation logic. Handles BR-003 (rapid input stability) with no edge cases. | Manual Task cancellation with stored task references (complex, error-prone); debounce timer (adds delay to first input); overlay queue (over-complex for ephemeral labels) |
| D3 | Breathing orb animation driver | SwiftUI `.animation(.easeInOut(duration:).repeatForever(autoreverses: true))` | Driven entirely by the SwiftUI animation system, not manual timers. Ensures 60fps performance (NFR-CTRL-001), minimal CPU usage (NFR-CTRL-003), and correct behavior during app backgrounding. Satisfies assumption A-5. | CADisplayLink + manual interpolation (lower-level, more code, leaves SwiftUI's declarative model); Timer-based manual animation (CPU-heavy, janky) |
| D4 | Theme crossfade implementation | `withAnimation(AnimationConstants.themeCrossfade)` wrapping `cycleTheme()` at the call site | SwiftUI natively interpolates Color values during animations. Wrapping the state mutation in `withAnimation` propagates the crossfade to all views reading theme colors. Zero changes to theme files or view code. | Per-view `.animation()` modifiers (scattered, hard to maintain); Custom transition modifier (unnecessary complexity); Snapshot-based crossfade (non-trivial, over-engineered) |
| D5 | Breathing orb color | Theme accent color (`appState.theme.colors.accent`) | Adapts automatically to both Solarized Dark (blue) and Solarized Light (blue) themes, satisfying AC-5 of FR-CTRL-004. Using the theme's own accent color ensures visual coherence. PRD left this as open question OQ-1; accent color is the most harmonious default. | Fixed orange (current OutdatedIndicator color -- too aggressive for zen aesthetic); Fixed green (arbitrary); Theme-specific orb colors (unnecessary complexity for two themes with the same accent) |
| D6 | Breathing orb position | Bottom-right corner with 16pt padding | Bottom-right is the least intrusive position for a reading-focused app (content flows top-to-bottom, left-to-right). PRD left this as open question OQ-2; fixed position is simpler and aligns with minimal philosophy. | Top-right (competes with title bar); Bottom-left (less conventional); Configurable position (out of scope per requirements) |
| D7 | Animation constants file location | `mkdn/UI/Theme/AnimationConstants.swift` | Theme directory already contains visual configuration (colors). Animation timing is visual configuration. Follows the existing pattern of `UI/Theme/` for app-wide visual constants. | `mkdn/App/` (not visual config); `mkdn/Core/` (not core logic); new `mkdn/UI/Animation/` directory (unnecessary new directory for a single file) |
| D8 | Open file logic placement | Private method on MkdnCommands | NSOpenPanel logic was previously in MkdnToolbarContent. With toolbar removal, MkdnCommands is the sole invocation site for Cmd+O. Keeping the logic co-located with its only caller follows YAGNI. | Static helper on AppState (AppState should not present UI); Standalone utility function (no reuse site to justify extraction) |

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| Animation framework | SwiftUI built-in animation system | KB patterns.md (SwiftUI-only constraint), codebase (existing `.spring()` usage in ContentView) | No external animation libraries. SwiftUI animation APIs on macOS 14+ are sufficient for all required effects (pulse, spring, crossfade). |
| State management for new properties | Properties on existing AppState | KB patterns.md (@Observable pattern), codebase (AppState is single state container) | Follows established pattern. No new state objects or view models needed. |
| Orb color | Theme accent color (adaptive) | Codebase (ThemeColors.accent exists), conservative default | Requirements left this as open question. Accent color is harmonious and theme-adaptive. |
| Orb position | Fixed bottom-right corner | Conservative default | Requirements left this as open question. Fixed position is simpler than configurable. |
| Overlay dismiss mechanism | Task.sleep + SwiftUI .id() keying | Codebase (Task.sleep pattern used in FileWatcher.resumeAfterSave), conservative default | Existing project already uses async Task.sleep for timed state transitions. .id() keying is idiomatic SwiftUI. |
| Menu group placement for Cmd+T | View menu (alongside mode switching) | macOS HIG (theme is a view concern), conservative default | Requirements did not specify menu group. View menu is standard for appearance-related commands. |
| Reload disable condition | Disabled when `currentFileURL == nil OR !isFileOutdated` | Requirements FR-CTRL-002 AC-5 | Requirements explicitly state "disabled when no file is open or file is current." Current code only checks for nil URL. |
| Test framework | Swift Testing (@Test, #expect, @Suite) | KB patterns.md, codebase (all existing tests use Swift Testing) | Follows established project testing pattern. |
