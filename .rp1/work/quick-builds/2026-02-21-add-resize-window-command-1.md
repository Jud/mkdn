# Quick Build: Add Resize Window Command

**Created**: 2026-02-21T00:00:00Z
**Request**: Add a resizeWindow command to the test harness and mkdn-ctl so we can programmatically set the window size for automated screenshot capture. Need both the Swift harness handler and the Python CLI command.
**Scope**: Small

## Plan

**Reasoning**: 3 files affected, 1 system (test harness), low risk -- follows the exact same pattern as all existing harness commands (e.g., scrollTo, setSidebarWidth). No new dependencies or architectural changes.
**Files Affected**:
- `mkdn/Core/TestHarness/HarnessCommand.swift` -- add `resizeWindow` case
- `mkdn/Core/TestHarness/TestHarnessHandler.swift` -- add handler that sets NSWindow frame
- `scripts/mkdn-ctl` -- add `resize` CLI command
- `docs/visual-testing-with-mkdn-ctl.md` -- document the new command

**Approach**: Add a `resizeWindow(width: Double, height: Double)` case to `HarnessCommand`. Implement `handleResizeWindow` in `TestHarnessHandler` that finds the main window and calls `setFrame(_:display:)` with the requested dimensions, preserving the current window origin. Add a `resize` subcommand to the Python `mkdn-ctl` script that accepts width and height arguments. Update the visual testing docs.
**Estimated Effort**: 1 hour

## Tasks

- [x] **T1**: Add `resizeWindow(width: Double, height: Double)` case to `HarnessCommand` enum in `HarnessCommand.swift` `[complexity:simple]`
- [x] **T2**: Add `handleResizeWindow` handler in `TestHarnessHandler.swift` -- find main window, build new frame preserving origin, call `setFrame(_:display:)`, return ok response with new dimensions `[complexity:simple]`
- [x] **T3**: Wire the new command into `TestHarnessHandler.process(_:)` switch statement `[complexity:simple]`
- [x] **T4**: Add `resize` command to `scripts/mkdn-ctl` Python CLI that sends `resizeWindow` with width/height args, and update the usage help text `[complexity:simple]`
- [x] **T5**: Add `resize` to the commands table in `docs/visual-testing-with-mkdn-ctl.md` `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Core/TestHarness/HarnessCommand.swift` | Added `resizeWindow(width:height:)` case with doc comment | Done |
| T2 | `mkdn/Core/TestHarness/TestHarnessHandler.swift` | Added `handleResizeWindow` preserving origin, calling `setFrame(_:display:)`, returning actual dimensions | Done |
| T3 | `mkdn/Core/TestHarness/TestHarnessHandler.swift` | Added `case let .resizeWindow` to `process(_:)` switch | Done |
| T4 | `scripts/mkdn-ctl` | Added `resize` command sending `resizeWindow` with width/height args, updated usage text | Done |
| T5 | `docs/visual-testing-with-mkdn-ctl.md` | Added `resize 1024 768` example to commands section | Done |

## Verification

{To be added by task-reviewer if --review flag used}
