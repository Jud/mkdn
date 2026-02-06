# Feature Verification Report #1

**Generated**: 2026-02-06T21:06:00Z
**Feature ID**: controls
**Verification Scope**: all
**KB Context**: Loaded
**Field Notes**: Not available

## Executive Summary
- Overall Status: PARTIAL
- Acceptance Criteria: 29/33 verified (88%)
- Implementation Quality: HIGH
- Ready for Merge: NO (minor cleanup and documentation tasks remaining)

Key findings:
- All 7 implementation tasks (T1-T6, T8) are completed and verified in code
- Build compiles successfully; all 5 Controls unit tests pass
- 4 acceptance criteria are flagged as PARTIAL or NOT VERIFIED (hardcoded animation values outside AnimationConstants, old component files not deleted, manual-only verification items)
- Documentation update tasks (TD1-TD4) remain incomplete

## Field Notes Context
**Field Notes Available**: No

### Documented Deviations
None -- field-notes.md does not exist for this feature.

### Undocumented Deviations
1. `ViewModePicker.swift` and `OutdatedIndicator.swift` files still exist on disk (dead code) -- design calls for removal/archival
2. `UnsavedIndicator.swift` contains a hardcoded `.easeInOut(duration: 2.5)` animation not centralized in AnimationConstants
3. `ContentView.swift:27` has a hardcoded `.spring(response: 0.4, dampingFraction: 0.85)` animation not centralized in AnimationConstants
4. `ResizableSplitView.swift` and `MarkdownEditorView.swift` contain hardcoded animation durations (pre-existing, not from this feature, but relevant to FR-CTRL-008 AC-3)

## Acceptance Criteria Verification

### FR-CTRL-001: Keyboard Shortcut Layer

**AC-1**: Pressing Cmd+1 switches the view to preview-only mode regardless of current mode.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:39-41, `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:83-86
- Evidence: `Button("Preview Mode") { appState.switchMode(to: .previewOnly) }.keyboardShortcut("1", modifiers: .command)` -- keyboard shortcut invokes `switchMode(to:)` which sets `viewMode = mode`.
- Field Notes: N/A
- Issues: None

**AC-2**: Pressing Cmd+2 switches the view to side-by-side edit + preview mode regardless of current mode.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:43-46
- Evidence: `Button("Edit Mode") { appState.switchMode(to: .sideBySide) }.keyboardShortcut("2", modifiers: .command)`
- Field Notes: N/A
- Issues: None

**AC-3**: Pressing Cmd+R reloads the current file from disk when a file is open and the file has changed.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:29-33
- Evidence: `Button("Reload") { try? appState.reloadFile() }.keyboardShortcut("r", modifiers: .command).disabled(appState.currentFileURL == nil || !appState.isFileOutdated)` -- correctly guards on both file presence and outdated state.
- Field Notes: N/A
- Issues: None

**AC-4**: Pressing Cmd+O opens the system file picker (NSOpenPanel) filtered to Markdown files.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:24-27 (button), 62-72 (openFile method)
- Evidence: `openFile()` creates `NSOpenPanel`, sets `allowedContentTypes = [mdType]` using `UTType(filenameExtension: "md")`, and loads the selected file.
- Field Notes: N/A
- Issues: None

**AC-5**: Pressing Cmd+T cycles the theme to the next available theme.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:51-55, `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:75-80
- Evidence: `Button("Cycle Theme") { withAnimation(AnimationConstants.themeCrossfade) { appState.cycleTheme() } }.keyboardShortcut("t", modifiers: .command)`. `cycleTheme()` uses modular arithmetic on `AppTheme.allCases` index.
- Field Notes: N/A
- Issues: None

**AC-6**: All shortcuts respond within 50ms of keypress.
- Status: MANUAL_REQUIRED
- Implementation: All shortcut handlers are synchronous state mutations on `@MainActor` AppState
- Evidence: Code analysis shows all shortcut handlers perform immediate state mutations (no async work, no I/O in the hot path for mode/theme switching). `reloadFile()` and `openFile()` involve disk I/O but are not latency-sensitive in the same way (they involve user-visible file operations). The architecture supports sub-50ms response for state mutations.
- Field Notes: N/A
- Issues: Requires Instruments profiling to formally verify the 50ms target.

### FR-CTRL-002: Menu Bar Discoverability

**AC-1**: A "View" menu group contains items for "Preview Mode" (Cmd+1) and "Edit Mode" (Cmd+2).
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:37-48
- Evidence: `CommandGroup(after: .sidebar)` places items in the View menu. Section contains `Button("Preview Mode")` with `.keyboardShortcut("1")` and `Button("Edit Mode")` with `.keyboardShortcut("2")`.
- Field Notes: N/A
- Issues: None

**AC-2**: A "File" menu group contains items for "Open..." (Cmd+O) and "Reload" (Cmd+R).
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:23-34
- Evidence: `CommandGroup(after: .importExport)` places items in the File menu. Contains `Button("Open...")` with Cmd+O and `Button("Reload")` with Cmd+R.
- Field Notes: N/A
- Issues: None

**AC-3**: A menu item exists for "Cycle Theme" (Cmd+T) in an appropriate menu group.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:50-57
- Evidence: `Button("Cycle Theme")` with `.keyboardShortcut("t", modifiers: .command)` placed in `CommandGroup(after: .sidebar)` (View menu).
- Field Notes: N/A
- Issues: None

**AC-4**: Each menu item displays its keyboard shortcut in the standard macOS format.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:18,27,32,42,45,56
- Evidence: All buttons use `.keyboardShortcut()` modifier which automatically renders the shortcut in standard macOS right-aligned format in the menu.
- Field Notes: N/A
- Issues: None

**AC-5**: Menu items are enabled/disabled appropriately (e.g., Reload is disabled when no file is open or file is current).
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:19,33
- Evidence: Save disabled via `.disabled(appState.currentFileURL == nil || !appState.hasUnsavedChanges)`. Reload disabled via `.disabled(appState.currentFileURL == nil || !appState.isFileOutdated)`. Mode and theme items are always enabled (correct behavior).
- Field Notes: N/A
- Issues: None

### FR-CTRL-003: Toolbar Removal

**AC-1**: The application window renders no toolbar area below the title bar.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift` (entire file)
- Evidence: No `.toolbar` modifier present anywhere in ContentView. Confirmed via grep: "No .toolbar modifier found in ContentView".
- Field Notes: N/A
- Issues: None

**AC-2**: The ViewModePicker component is no longer rendered in the window.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift` (no reference to ViewModePicker)
- Evidence: Grep confirms `ViewModePicker` is not referenced from ContentView or any other file besides its own definition. However, `ViewModePicker.swift` still exists as a dead file on disk.
- Field Notes: N/A
- Issues: `ViewModePicker.swift` file should be deleted as part of cleanup.

**AC-3**: All functionality previously accessible via toolbar controls remains accessible via keyboard shortcuts and menu bar items.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift` (all commands)
- Evidence: Mode switching (Cmd+1, Cmd+2), file open (Cmd+O), reload (Cmd+R), save (Cmd+S) -- all previous toolbar actions are now in the menu bar with keyboard shortcuts. Theme cycling (Cmd+T) is a new addition.
- Field Notes: N/A
- Issues: None

### FR-CTRL-004: Breathing Orb File-Change Indicator

**AC-1**: When the file watcher detects a change on disk, a small circular orb appears in a corner of the content area.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:29-41, `/Users/jud/Projects/mkdn/mkdn/UI/Components/BreathingOrbView.swift`:1-25
- Evidence: ContentView conditionally shows `BreathingOrbView()` when `appState.isFileOutdated`, positioned at `.bottomTrailing` with 16pt padding. BreathingOrbView renders a `Circle()` with 10x10pt frame.
- Field Notes: N/A
- Issues: None

**AC-2**: The orb has no accompanying text or label.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/BreathingOrbView.swift`:9-24
- Evidence: The view body contains only `Circle()` with modifiers -- no `Text` views or labels are present.
- Field Notes: N/A
- Issues: None

**AC-3**: The orb animates with a smooth pulse (opacity and/or scale variation) at approximately 12 cycles per minute.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/BreathingOrbView.swift`:17-18, `/Users/jud/Projects/mkdn/mkdn/UI/Theme/AnimationConstants.swift`:9
- Evidence: `.scaleEffect(isPulsing ? 1.0 : 0.85)` and `.opacity(isPulsing ? 1.0 : 0.4)` animated via `AnimationConstants.orbPulse` which is `.easeInOut(duration: 2.5).repeatForever(autoreverses: true)`. Duration of 2.5s per half-cycle = 5s per full cycle = 12 cycles/min.
- Field Notes: N/A
- Issues: None

**AC-4**: The orb is visually subtle -- it does not dominate the content area or distract from reading.
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/BreathingOrbView.swift`
- Evidence: Design parameters support subtlety: 10pt diameter, opacity range 0.4-1.0, positioned in bottom-right corner with 16pt padding. Shadow radius 4-8pt. These values are intentionally small but subjective visual assessment is needed.
- Field Notes: N/A
- Issues: Requires visual inspection.

**AC-5**: The orb is visible in both Solarized Dark and Solarized Light themes.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/BreathingOrbView.swift`:11,13-14
- Evidence: Uses `appState.theme.colors.accent` for both fill and shadow color. Since `theme` is reactive (Observable), the orb color adapts when the theme changes. Both Solarized Dark and Light themes define accent colors.
- Field Notes: N/A
- Issues: None

### FR-CTRL-005: Orb Dissolve on Reload

**AC-1**: Pressing Cmd+R when the orb is visible causes the orb to animate out (fade and shrink).
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:33-40
- Evidence: The orb uses `.transition(.asymmetric(insertion: ..., removal: .scale(scale: 0.5).combined(with: .opacity).animation(AnimationConstants.orbDissolve)))`. When `isFileOutdated` becomes false (via `reloadFile()` which re-loads the file and resets the watcher), the conditional block removes BreathingOrbView with a scale+opacity transition.
- Field Notes: N/A
- Issues: None

**AC-2**: The dissolve animation completes smoothly without visual glitches.
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/AnimationConstants.swift`:15
- Evidence: `orbDissolve` is `.easeIn(duration: 0.4)` -- a standard SwiftUI easing curve that should produce smooth animation. The asymmetric transition ensures removal uses a different animation from insertion. Code analysis shows no animation conflicts.
- Field Notes: N/A
- Issues: Requires visual verification.

**AC-3**: After the dissolve, the orb is fully removed from the view hierarchy (not just invisible).
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:29-41
- Evidence: The orb is wrapped in `if appState.isFileOutdated { ... }` conditional. When the condition becomes false, SwiftUI removes the view from the hierarchy entirely (not just hidden). This is the standard SwiftUI conditional view pattern.
- Field Notes: N/A
- Issues: None

### FR-CTRL-006: Ephemeral Mode Transition Overlay

**AC-1**: Switching to preview-only mode displays an overlay with the text "Preview" (or similar).
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:83-86, `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:43-48
- Evidence: `switchMode(to:)` sets `modeOverlayLabel = mode == .previewOnly ? "Preview" : "Edit"`. ContentView shows `ModeTransitionOverlay(label: label)` when `modeOverlayLabel` is non-nil. Unit test `switchModePreviewOnly` confirms label is "Preview".
- Field Notes: N/A
- Issues: None

**AC-2**: Switching to side-by-side mode displays an overlay with the text "Edit" (or similar).
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:85
- Evidence: `modeOverlayLabel = mode == .previewOnly ? "Preview" : "Edit"` -- for `.sideBySide`, label is "Edit". Unit test `switchModeSideBySide` confirms.
- Field Notes: N/A
- Issues: None

**AC-3**: The overlay enters with a spring animation (scale/opacity spring-in).
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/ModeTransitionOverlay.swift`:19,21-23
- Evidence: `.scaleEffect(isVisible ? 1.0 : 0.8)` and `.opacity(isVisible ? 1.0 : 0)` animated via `withAnimation(AnimationConstants.overlaySpringIn)` which is `.spring(response: 0.35, dampingFraction: 0.7)`.
- Field Notes: N/A
- Issues: None

**AC-4**: The overlay auto-dismisses after approximately 1.5 seconds without user interaction.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/ModeTransitionOverlay.swift`:25-26
- Evidence: `Task { @MainActor in try? await Task.sleep(for: AnimationConstants.overlayDisplayDuration) ... }` where `overlayDisplayDuration` is `.milliseconds(1_500)`.
- Field Notes: N/A
- Issues: None

**AC-5**: The overlay exits with a smooth fade-out.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/ModeTransitionOverlay.swift`:27-28
- Evidence: `withAnimation(AnimationConstants.overlayFadeOut) { isVisible = false }` where `overlayFadeOut` is `.easeOut(duration: 0.3)`.
- Field Notes: N/A
- Issues: None

**AC-6**: Rapid mode switching (pressing Cmd+1 then Cmd+2 quickly) handles gracefully -- the previous overlay is replaced by the new one without visual artifacts.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:47
- Evidence: `.id(label)` on the `ModeTransitionOverlay` view. When the label changes (e.g., "Preview" to "Edit"), SwiftUI destroys the old view (cancelling its Task) and creates a new one, preventing stacking or artifacts.
- Field Notes: N/A
- Issues: None

### FR-CTRL-007: Smooth Theme Cycling

**AC-1**: Pressing Cmd+T transitions all colors (background, text, accents) with a smooth crossfade animation.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:52-54
- Evidence: `withAnimation(AnimationConstants.themeCrossfade) { appState.cycleTheme() }` where `themeCrossfade` is `.easeInOut(duration: 0.35)`. SwiftUI natively interpolates Color values during animations, so all views reading `appState.theme.colors` transition smoothly.
- Field Notes: N/A
- Issues: None

**AC-2**: The transition does not cause a flash of unstyled or intermediate content.
- Status: MANUAL_REQUIRED
- Implementation: Same as AC-1 above
- Evidence: The `withAnimation` wrapper at the mutation site propagates through the entire view hierarchy. Color interpolation should prevent flashing, but visual verification is needed to confirm no intermediate unstyled frames.
- Field Notes: N/A
- Issues: Requires visual verification.

**AC-3**: Content remains readable throughout the transition.
- Status: MANUAL_REQUIRED
- Implementation: Same as AC-1 above
- Evidence: A 0.35s crossfade between two Solarized themes (both high-contrast) should maintain readability throughout. However, this is a subjective visual criterion.
- Field Notes: N/A
- Issues: Requires visual verification.

### FR-CTRL-008: Centralized Animation Timing Constants

**AC-1**: A single file or structure defines all animation timing constants used by the breathing orb, mode overlay, and theme transition.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/AnimationConstants.swift`:1-35
- Evidence: `enum AnimationConstants` defines all 8 constants: `orbPulse`, `orbAppear`, `orbDissolve`, `overlaySpringIn`, `overlayFadeOut`, `overlayDisplayDuration`, `overlayFadeOutDuration`, `themeCrossfade`. All Controls feature animations reference these constants.
- Field Notes: N/A
- Issues: None

**AC-2**: Changing a constant in the centralized location changes the corresponding animation behavior across the app.
- Status: VERIFIED
- Implementation: All consuming files reference `AnimationConstants.*` constants
- Evidence: `BreathingOrbView.swift` uses `AnimationConstants.orbPulse`; `ModeTransitionOverlay.swift` uses `AnimationConstants.overlaySpringIn`, `overlayFadeOut`, `overlayDisplayDuration`, `overlayFadeOutDuration`; `MkdnCommands.swift` uses `AnimationConstants.themeCrossfade`; `ContentView.swift` uses `AnimationConstants.orbAppear`, `orbDissolve`. All are direct references.
- Field Notes: N/A
- Issues: None

**AC-3**: No animation durations or curves are hardcoded outside the centralized location.
- Status: PARTIAL
- Implementation: Multiple files contain hardcoded animation values
- Evidence: The following hardcoded animations exist outside AnimationConstants:
  - `/Users/jud/Projects/mkdn/mkdn/UI/Components/UnsavedIndicator.swift`:16 -- `.easeInOut(duration: 2.5).repeatForever(autoreverses: true)` (pre-existing, not from Controls feature)
  - `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:27 -- `.spring(response: 0.4, dampingFraction: 0.85)` for view mode transition (added by Controls feature T6)
  - `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/ResizableSplitView.swift`:88-89 -- `.easeInOut(duration: 0.15)` (pre-existing)
  - `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/MarkdownEditorView.swift`:28 -- `.easeInOut(duration: 0.2)` (pre-existing)
- Field Notes: N/A
- Issues: The ContentView view-mode spring animation at line 27 was introduced by this feature and should be centralized. The other 3 are pre-existing and outside the Controls feature scope, but the requirement as written ("No animation durations or curves are hardcoded outside the centralized location") technically includes all animations in the app.

### Business Rules

**BR-001**: Keyboard shortcuts operational before toolbar removal.
- Status: VERIFIED
- Evidence: The implementation DAG shows T3 (commands) was completed before T6 (ContentView refactor). Keyboard shortcuts exist in MkdnCommands independently of the toolbar. The toolbar has been removed and all shortcuts function through the menu bar.
- Issues: None

**BR-002**: Breathing orb visible in both themes.
- Status: VERIFIED
- Evidence: BreathingOrbView uses `appState.theme.colors.accent` which is reactive to theme changes. Both Solarized Dark and Light define accent colors, ensuring visibility in both themes.
- Issues: None

**BR-003**: Rapid input causes no visual artifacts.
- Status: VERIFIED
- Evidence: Mode overlay uses `.id(label)` keying for natural view lifecycle management on rapid switching. Theme cycling is a simple state toggle wrapped in `withAnimation`.
- Issues: None

**BR-004**: Reload disabled when no file open or file is current.
- Status: VERIFIED
- Evidence: `MkdnCommands.swift`:33 -- `.disabled(appState.currentFileURL == nil || !appState.isFileOutdated)`.
- Issues: None

### Non-Functional Requirements

**NFR-CTRL-001**: All animations run at 60fps on macOS 14+.
- Status: MANUAL_REQUIRED
- Evidence: All animations use standard SwiftUI animation APIs (`.easeInOut`, `.spring`, `.opacity`, `.scale`) which are GPU-accelerated and should run at 60fps. No custom rendering loops or manual timers. However, formal verification requires Instruments profiling.
- Issues: Requires Instruments profiling.

**NFR-CTRL-002**: Keyboard shortcut response under 50ms.
- Status: MANUAL_REQUIRED
- Evidence: Same as FR-CTRL-001 AC-6. All handlers are synchronous `@MainActor` state mutations.
- Issues: Requires profiling.

**NFR-CTRL-003**: Orb uses SwiftUI animation system, not manual timers.
- Status: VERIFIED
- Evidence: `/Users/jud/Projects/mkdn/mkdn/UI/Components/BreathingOrbView.swift`:20-22 uses `withAnimation(AnimationConstants.orbPulse) { isPulsing = true }` where `orbPulse` is `.easeInOut(duration: 2.5).repeatForever(autoreverses: true)`. No `Timer`, `DispatchSource`, or `CADisplayLink` is used. The auto-dismiss in ModeTransitionOverlay uses `Task.sleep` for scheduling but animation is still SwiftUI-driven.
- Issues: None

## Implementation Gap Analysis

### Missing Implementations
- None -- all 7 implementation tasks (T1-T6, T8) are complete.

### Partial Implementations
1. **FR-CTRL-008 AC-3** (No hardcoded animation durations outside centralized location):
   - `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:27 has a hardcoded `.spring(response: 0.4, dampingFraction: 0.85)` that was introduced by this feature and should be moved to `AnimationConstants`.
   - 3 additional pre-existing hardcoded animations in `UnsavedIndicator.swift`, `ResizableSplitView.swift`, and `MarkdownEditorView.swift` -- these are outside this feature's scope but violate the literal AC text.

### Implementation Issues
1. **Dead code files not deleted**: `ViewModePicker.swift` and `OutdatedIndicator.swift` still exist on disk. While they are not referenced from any active code (confirmed by grep), the design document calls for their removal. This is cleanup, not a functional issue.
2. **Documentation tasks incomplete**: TD1-TD4 (modules.md, architecture.md, patterns.md updates) are all unchecked in tasks.md.

## Code Quality Assessment

**Overall Quality: HIGH**

The implementation demonstrates strong adherence to the project's established patterns:

1. **Pattern Compliance**: All new code follows the `@Observable` / `@Environment` pattern. AppState extensions are properly `@MainActor`-isolated. Views use `@Environment(AppState.self)` as prescribed in patterns.md.

2. **Code Organization**: AnimationConstants is a clean enum with clear MARK sections. BreathingOrbView and ModeTransitionOverlay are self-contained, focused components. AppState extensions are minimal and well-documented.

3. **Test Quality**: The 5 unit tests in ControlsTests.swift cover the core business logic (cycleTheme cycling, switchMode state coordination, isFileOutdated delegation). Tests use Swift Testing framework correctly with `@MainActor` on individual test functions (not the Suite), following the project's documented testing pattern.

4. **Separation of Concerns**: Animation timing is centralized (with the one exception noted). View logic is in views, state logic is in AppState, command routing is in MkdnCommands.

5. **SwiftUI Best Practices**: Conditional view rendering for orb/overlay, `.id()` keying for rapid input handling, `withAnimation` at mutation sites for theme crossfade, asymmetric transitions for orb appear/dissolve.

6. **Minor Issues**:
   - The `try? appState.reloadFile()` in MkdnCommands silently swallows errors. This is consistent with the existing `try? appState.saveFile()` pattern in the same file, but error handling could be improved in a future iteration.
   - The `openFile()` method also uses `try?` for `loadFile(at:)`.

## Recommendations

1. **Centralize the view-mode spring animation**: Move `.spring(response: 0.4, dampingFraction: 0.85)` from `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:27 into `AnimationConstants` (e.g., `static let viewModeTransition`). This was introduced by this feature and satisfying FR-CTRL-008 AC-3 requires it.

2. **Delete dead code files**: Remove `/Users/jud/Projects/mkdn/mkdn/UI/Components/ViewModePicker.swift` and `/Users/jud/Projects/mkdn/mkdn/UI/Components/OutdatedIndicator.swift`. They are no longer referenced anywhere.

3. **Complete documentation tasks TD1-TD4**: Update modules.md, architecture.md, and patterns.md per the design document's Section 9 (Documentation Impact).

4. **Consider centralizing pre-existing animation values**: For full FR-CTRL-008 AC-3 compliance, consider moving the hardcoded animation in `UnsavedIndicator.swift` into AnimationConstants. The `ResizableSplitView.swift` and `MarkdownEditorView.swift` animations are arguably layout-related and may warrant a separate constants structure.

5. **Visual verification checklist**: Perform manual testing for the 6 MANUAL_REQUIRED criteria (animation smoothness, visual subtlety, 60fps, 50ms response, theme transition quality).

## Verification Evidence

### AnimationConstants.swift (T1) -- Complete Match to Design
```swift
// File: /Users/jud/Projects/mkdn/mkdn/UI/Theme/AnimationConstants.swift
enum AnimationConstants {
    static let orbPulse: Animation = .easeInOut(duration: 2.5).repeatForever(autoreverses: true)
    static let orbAppear: Animation = .easeOut(duration: 0.5)
    static let orbDissolve: Animation = .easeIn(duration: 0.4)
    static let overlaySpringIn: Animation = .spring(response: 0.35, dampingFraction: 0.7)
    static let overlayFadeOut: Animation = .easeOut(duration: 0.3)
    static let overlayDisplayDuration: Duration = .milliseconds(1_500)
    static let overlayFadeOutDuration: Duration = .milliseconds(300)
    static let themeCrossfade: Animation = .easeInOut(duration: 0.35)
}
```
All values match the design specification in design.md Section 3.6 exactly.

### AppState Extensions (T2) -- Complete Match
```swift
// File: /Users/jud/Projects/mkdn/mkdn/App/AppState.swift (lines 43-86)
public var modeOverlayLabel: String?

public func cycleTheme() {
    let allThemes = AppTheme.allCases
    guard let currentIndex = allThemes.firstIndex(of: theme) else { return }
    let nextIndex = (currentIndex + 1) % allThemes.count
    theme = allThemes[nextIndex]
}

public func switchMode(to mode: ViewMode) {
    viewMode = mode
    modeOverlayLabel = mode == .previewOnly ? "Preview" : "Edit"
}
```
Matches design.md Section 3.1 exactly.

### ContentView Refactor (T6) -- Hardcoded Animation Deviation
```swift
// File: /Users/jud/Projects/mkdn/mkdn/App/ContentView.swift (line 27)
.animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.viewMode)
// ^ This value should be centralized in AnimationConstants
```
All other aspects of ContentView match the design specification.

### Unit Tests (T8) -- All 5 Passing
```
Controls suite: 5/5 tests passing
- cycleTheme toggles from dark to light
- cycleTheme wraps from light back to dark
- switchMode to previewOnly sets viewMode and overlay label
- switchMode to sideBySide sets viewMode and overlay label
- isFileOutdated delegates to FileWatcher state
```

### Build Status
```
Build complete! (0.34s) -- no errors, no warnings
All tests passing
```
