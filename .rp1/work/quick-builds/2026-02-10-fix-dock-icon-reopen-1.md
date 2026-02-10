# Quick Build: Fix Dock Icon Reopen

**Created**: 2026-02-10T00:00:00Z
**Request**: The orb (dock icon) does not seem clickable when you hover over it - the dock icon should show a pointer cursor and be clickable to reopen the app window. The icon is set programmatically via NSApp.applicationIconImage in AppDelegate.swift. applicationShouldHandleReopen already returns true. The issue is likely that the dock icon doesn't behave like a proper app icon for click interaction.
**Scope**: Small

## Plan

**Reasoning**: 1-2 files affected (AppDelegate.swift primarily), 1 system (AppKit lifecycle), low risk -- standard NSApplicationDelegate dock-click handling pattern.

**Files Affected**:
- `mkdn/App/AppDelegate.swift`

**Approach**: The root cause is that `applicationShouldHandleReopen(_:hasVisibleWindows:)` unconditionally returns `true`, which tells macOS "the delegate will handle window reopening" -- but the delegate takes no action. When all windows are closed and the user clicks the dock icon, nothing happens because the system defers to the delegate, which does nothing. The fix is to return `false` when `hasVisibleWindows` is `false`, allowing SwiftUI's `WindowGroup` to handle creating a new default window (which will show the WelcomeView). When windows are already visible, we should activate the app and bring the existing window forward. Additionally, the activation policy `.regular` is already set correctly, so the dock icon itself should be functional -- the issue is purely about the reopen behavior.

**Estimated Effort**: 0.5 hours

## Tasks

- [x] **T1**: In `AppDelegate.applicationShouldHandleReopen(_:hasVisibleWindows:)`, when `hasVisibleWindows` is `true`, activate the app and bring the frontmost window to focus, then return `true`; when `hasVisibleWindows` is `false`, return `false` to let the system (SwiftUI WindowGroup) create a new default window `[complexity:simple]`
- [x] **T2**: Verify the fix builds cleanly with `swift build`, confirm no SwiftLint or SwiftFormat violations `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/App/AppDelegate.swift` | Fixed `applicationShouldHandleReopen`: when windows visible, activate app and bring key window forward (return `true`); when no windows, return `false` to let SwiftUI WindowGroup create a new default window | Done |
| T2 | (none) | Verified: `swift build` succeeds, SwiftFormat clean, SwiftLint 0 violations | Done |

## Verification

{To be added by task-reviewer if --review flag used}
