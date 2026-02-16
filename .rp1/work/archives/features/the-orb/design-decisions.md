# Design Decisions: The Orb

**Feature ID**: the-orb
**Created**: 2026-02-10

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | State machine host | Computed property in TheOrbView (no separate ViewModel) | Matches existing FileChangeOrbView/DefaultHandlerHintView pattern where views compute state from environment directly. Avoids over-engineering for a simple priority computation. | Separate OrbViewModel @Observable class -- rejected as the state derivation is a pure function of existing environment objects. |
| D2 | OrbState priority encoding | Comparable via enum case ordering | Zero-cost, compiler-enforced, requires no raw values or manual comparison. Cases ordered low-to-high so `.max()` returns the highest priority. | Raw Int values -- rejected as redundant given Comparable synthesis. Dictionary lookup -- rejected as less type-safe. |
| D3 | Auto-reload timer mechanism | Task.sleep (structured concurrency) | Matches the project's concurrency model (FileWatcher uses Task, DocumentState is @MainActor). Cancellation is built into Task. | Timer.scheduledTimer -- rejected as Combine/imperative, inconsistent with async patterns. DispatchQueue.asyncAfter -- rejected for same reason. |
| D4 | File-changed orb color | Solarized orange (#cb4b16) | Requirements specify "orange." Solarized orange is the canonical warm alert color in the palette. Provides strong contrast against both dark and light Solarized backgrounds. | Solarized yellow (#b58900) -- rejected, less distinct from green. Keep existing cyan -- rejected, requirements explicitly say "orange." |
| D5 | Update-available orb color | Solarized green (#859900) | Requirements specify "green." Solarized green conveys positive/available status. Harmonizes with palette. | Solarized cyan -- rejected, too close to the old file-change color; could confuse returning users. |
| D6 | Popover auto-reload toggle widget | SwiftUI Toggle | Native macOS control, self-explanatory, compact. Fits within the existing popover layout pattern (VStack with padding). | Checkbox -- rejected, Toggle is more idiomatic SwiftUI. Text button -- rejected, less discoverable for a persistent preference. |
| D7 | Color crossfade mechanism | withAnimation(.crossfade) on @State color change | Leverages SwiftUI's built-in Color interpolation. OrbVisual already accepts color as a parameter; no visual component changes needed. | Overlay two OrbVisuals and crossfade opacity -- rejected as more complex, only needed if gradient interpolation fails (see HYP-001). |
| D8 | TheOrbView position | Bottom-right, `.frame(alignment:.bottomTrailing).padding(16)` | Matches existing FileChangeOrbView positioning in ContentView. Consistent with REQ-11 specification. | Top-right (current DefaultHandlerHintView position) -- rejected per REQ-11 which specifies bottom-right for all states. |

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| State machine pattern | Computed property, no ViewModel | Codebase pattern (FileChangeOrbView, DefaultHandlerHintView) | Existing orb views use no ViewModel; state is derived from @Environment. Introducing a ViewModel would break the established pattern. |
| Timer implementation | Task.sleep (Swift structured concurrency) | Codebase pattern (FileWatcher.swift uses Task) | The project exclusively uses Swift concurrency (Task, async/await, actors). No Combine or Timer usage exists. |
| Persistence mechanism | UserDefaults | Codebase pattern (AppSettings.swift) | AppSettings already persists `themeMode` and `hasShownDefaultHandlerHint` via UserDefaults with the exact same pattern. |
| Orange color value | Solarized orange #cb4b16 (0.796, 0.294, 0.086) | KB patterns.md + Solarized palette | Requirements specify "orange." Solarized palette has a canonical orange. Existing orb colors use Solarized-derived values. |
| Green color value | Solarized green #859900 (0.522, 0.600, 0.000) | KB patterns.md + Solarized palette | Requirements specify "green." Solarized palette has a canonical green. |
| Auto-reload toggle widget | SwiftUI Toggle | Conservative default (native macOS control) | CL-02 defers toggle widget choice. SwiftUI Toggle is the most standard, accessible, self-explanatory option. |
| Popover guard text | Include brief explanation when auto-reload is suppressed | Conservative default (clarity over minimalism) | CL-03 defers this UX detail. Brief text ("Auto-reload paused -- you have unsaved changes") aids comprehension with minimal UI cost. |
| Test framework | Swift Testing (@Suite, @Test, #expect) | KB patterns.md | Project exclusively uses Swift Testing. No XCTest. |
