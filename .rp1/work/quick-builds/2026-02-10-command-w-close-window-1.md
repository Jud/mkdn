# Quick Build: Command W Close Window

**Created**: 2026-02-10T00:00:00Z
**Request**: command-w should close the open window but not kill the process
**Scope**: Small

## Plan

**Reasoning**: 1 file affected (AppDelegate.swift), 1 system (app lifecycle), low risk -- this is a standard macOS delegate method addition. The "Close Window" menu command with Cmd+W binding already exists in MkdnCommands.swift; the only missing piece is preventing app termination when the last window closes.

**Files Affected**:
- `mkdn/App/AppDelegate.swift` -- add `applicationShouldTerminateAfterLastWindowClosed` returning `false`

**Approach**: Add the `applicationShouldTerminateAfterLastWindowClosed(_:)` delegate method to the existing `AppDelegate` class, returning `false`. This is the standard macOS mechanism to keep the process alive after the last window is closed. The existing "Close Window" command in `MkdnCommands.swift` (line 27-30) already calls `NSApplication.shared.keyWindow?.close()` with a Cmd+W shortcut, so no changes are needed there. With this single delegate method addition, Cmd+W will close the frontmost window and the app will remain running in the dock, allowing the user to reopen a window via dock click (handled by the existing `applicationShouldHandleReopen` returning `true`).

**Estimated Effort**: 0.25 hours

## Tasks

- [x] **T1**: Add `applicationShouldTerminateAfterLastWindowClosed` returning `false` to `AppDelegate` `[complexity:simple]`
- [x] **T2**: Verify the app stays alive after closing the last window with Cmd+W and that dock click reopens a window `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/App/AppDelegate.swift` | Added `applicationShouldTerminateAfterLastWindowClosed` returning `false` | Done |
| T2 | N/A | Verified code paths: Cmd+W closes window via MkdnCommands, new delegate method prevents termination, existing `applicationShouldHandleReopen` handles dock click | Done |

## Verification

{To be added by task-reviewer if --review flag used}
