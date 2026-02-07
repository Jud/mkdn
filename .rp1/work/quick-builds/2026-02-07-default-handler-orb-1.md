# Quick Build: Default Handler Orb

**Created**: 2026-02-07T00:00:00Z
**Request**: Replace the current "set as default markdown reader" prompt/banner with a small pulsing blue orb indicator. The orb should use the app's accent blue color and have a subtle pulsing animation. When clicked, it shows a confirmation dialog: "Would you like to make mkdn your default Markdown reader?" with Yes/No buttons. If the user clicks No, the orb disappears permanently (the hint is marked as shown). The user can still access "Make Default Markdown Reader" from the File menu. If Yes, set as default and dismiss. The orb should be small and unobtrusive, not a banner.
**Scope**: Small

## Plan

**Reasoning**: 3 files affected (DefaultHandlerHintView.swift, ContentView.swift, AnimationConstants.swift), 1 system (DefaultHandler UI), low risk (UI-only refactor, no service logic changes). The existing BreathingOrbView already establishes the pulsing orb pattern in the codebase, so this follows an established visual convention.

**Files Affected**:
- `mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift` -- rewrite from banner to small pulsing orb with popover/confirmation dialog
- `mkdn/App/ContentView.swift` -- change alignment from `.top` to an unobtrusive corner position (e.g., `.topTrailing`) and adjust padding
- `mkdn/UI/Theme/AnimationConstants.swift` -- add a `defaultHandlerOrbPulse` constant (or reuse `orbPulse`)

**Approach**: Rewrite `DefaultHandlerHintView` to render as a small pulsing circle (similar to the existing `BreathingOrbView`) using the accent color. Add a `.popover` or `.confirmationDialog` modifier that appears on click, presenting "Would you like to make mkdn your default Markdown reader?" with Yes and No buttons. Yes calls `DefaultHandlerService.registerAsDefault()` and marks the hint as shown. No marks the hint as shown (permanently dismissing the orb). Update `ContentView` to position the orb in a corner rather than as a top-aligned banner. The existing `BreathingOrbView` is used for file-change indication and should not be modified; the default handler orb will be self-contained within `DefaultHandlerHintView`.

**Estimated Effort**: 1.5 hours

## Tasks

- [x] **T1**: Rewrite `DefaultHandlerHintView` to render a small pulsing accent-colored orb (10pt circle with pulse animation matching `BreathingOrbView` style) instead of the HStack banner. Add `@State private var showDialog = false` and attach a `.popover` on click with the confirmation question and Yes/No buttons. Yes calls `DefaultHandlerService.registerAsDefault()` then `markHintShown()`. No calls `markHintShown()`. Remove all banner-related code (hintContent, confirmationContent, dismissAfterDelay). `[complexity:medium]`
- [x] **T2**: Update `ContentView.swift` to position the `DefaultHandlerHintView` orb in a small, unobtrusive corner (e.g., `.topTrailing` with modest padding) instead of the current `.top` full-width alignment. `[complexity:simple]`
- [x] **T3**: Verify animation constants -- decide whether to reuse `AnimationConstants.orbPulse` for the default handler orb or add a dedicated constant. Add `defaultHandlerOrbPulse` to `AnimationConstants.swift` if a different timing is desired. `[complexity:simple]`
- [x] **T4**: Run `swift build`, `swift test`, SwiftLint, and SwiftFormat to verify no regressions. Confirm the File menu "Set as Default Markdown App" command in `MkdnCommands.swift` still works independently of the orb. `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift` | Rewrote from HStack banner to 10pt pulsing Circle with .popover for Yes/No confirmation dialog; removed hintContent, confirmationContent, dismissAfterDelay | Done |
| T2 | `mkdn/App/ContentView.swift` | Changed alignment from `.top` to `.topTrailing` with `.padding(.top, 8)` and `.padding(.trailing, 12)` | Done |
| T3 | `mkdn/UI/Theme/AnimationConstants.swift` | Added dedicated `defaultHandlerOrbPulse` constant (same 2.5s easeInOut cadence as `orbPulse`, independently tunable) | Done |
| T4 | N/A | Build passes, all tests pass, SwiftLint clean, SwiftFormat clean, File menu command verified independent | Done |

## Verification

{To be added by task-reviewer if --review flag used}
