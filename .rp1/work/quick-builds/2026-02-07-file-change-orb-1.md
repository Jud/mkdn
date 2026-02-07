# Quick Build: File Change Orb

**Created**: 2026-02-07T20:29:46Z
**Request**: When there are changes to a file, show a glowing orb indicator. This orb should match the style of the existing default-handler orb (the one that asks if you want to be the default markdown viewer). The file-change orb should supersede the default-handler orb if both would be shown at the same time. The file-change orb should have a slightly different color to indicate that there are changes to the file that could be reloaded. When clicked, it should show a menu/prompt that says "There are changes to this file. Would you like to reload?"
**Scope**: Medium

## Plan

**Reasoning**: 4 files modified (ContentView, AnimationConstants, BreathingOrbView or new view, and possibly DocumentState for reload hookup), 1 system (UI layer), low risk since the file-change detection (`isFileOutdated`) and reload (`reloadFile()`) infrastructure already exist. The existing `DefaultHandlerHintView` provides a near-identical interaction pattern (orb + popover) to replicate.

**Files Affected**:
- `mkdn/UI/Components/BreathingOrbView.swift` -- refactor to accept a configurable color, or create a new `FileChangeOrbView.swift` that reuses the orb visual pattern
- `mkdn/App/ContentView.swift` -- replace raw `BreathingOrbView` with the new interactive file-change orb; add supersession logic so file-change orb hides the default-handler orb
- `mkdn/UI/Theme/AnimationConstants.swift` -- add a distinct `fileChangeOrbColor` constant (e.g., Solarized cyan or green to contrast with the violet default-handler orb)

**Approach**: Create a new `FileChangeOrbView` modeled on `DefaultHandlerHintView` -- same orb visual structure (outer halo, mid glow, inner core) but with a distinct color (Solarized cyan #2aa198 to complement the existing violet). The view will use a tap gesture to present a popover asking "There are changes to this file. Would you like to reload?" with Yes/No buttons. On "Yes", call `documentState.reloadFile()`. In `ContentView`, replace the current non-interactive `BreathingOrbView` with `FileChangeOrbView` in the same bottom-trailing position, and add logic so that when `isFileOutdated` is true the default-handler orb is hidden (supersession).

**Estimated Effort**: 2-3 hours

## Tasks

- [x] **T1**: Add `fileChangeOrbColor` constant to `AnimationConstants.swift` using Solarized cyan (#2aa198) and a `fileChangeOrbPulse` animation constant `[complexity:simple]`
- [x] **T2**: Create `mkdn/UI/Components/FileChangeOrbView.swift` -- a new view mirroring `DefaultHandlerHintView` structure (orb visual + tap gesture + popover) but using the file-change color, with popover text "There are changes to this file. Would you like to reload?" and Yes/No buttons that call `documentState.reloadFile()` on confirmation `[complexity:medium]`
- [x] **T3**: Update `ContentView.swift` to replace the current `BreathingOrbView` usage (lines 32-44) with the new `FileChangeOrbView`, and add supersession logic so the default-handler hint (lines 53-59) is hidden when `documentState.isFileOutdated` is true `[complexity:simple]`
- [x] **T4**: Remove or deprecate the now-unused `BreathingOrbView.swift` since its functionality is fully replaced by `FileChangeOrbView` `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/UI/Theme/AnimationConstants.swift` | Added `fileChangeOrbColor` (Solarized cyan #2aa198) and `fileChangeOrbPulse` animation constant | Done |
| T2 | `mkdn/UI/Components/FileChangeOrbView.swift` | Created new view mirroring DefaultHandlerHintView structure with cyan orb, tap-to-popover reload prompt, Yes/No buttons calling `documentState.reloadFile()` | Done |
| T3 | `mkdn/App/ContentView.swift` | Replaced `BreathingOrbView` with `FileChangeOrbView`; added `!documentState.isFileOutdated` condition to default-handler hint for supersession | Done |
| T4 | `mkdn/UI/Components/BreathingOrbView.swift` | Removed file entirely -- functionality fully replaced by FileChangeOrbView | Done |

## Verification

{To be added by task-reviewer if --review flag used}
