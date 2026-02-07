# Quick Build: Fix Foreground Activation

**Created**: 2026-02-07T00:00:00-06:00
**Request**: Fix foreground activation for real. Replace cooperative NSApp.activate() with NSApp.activate(ignoringOtherApps: true) and window.makeKeyAndOrderFront(nil) with window.orderFrontRegardless() in WindowAccessor.configureWindow().
**Scope**: Small

## Plan

**Reasoning**: This is a 1-file, 2-line change in a single system (window management) with low risk -- the replacement APIs are well-understood, still functional on macOS 15.5, and the investigation report has already validated the approach.
**Files Affected**: `mkdn/UI/Components/WindowAccessor.swift`
**Approach**: In `WindowAccessor.configureWindow()`, replace `window.makeKeyAndOrderFront(nil)` with `window.orderFrontRegardless()` to move the window in front of all other windows regardless of activation state, and replace `NSApp.activate()` with `NSApp.activate(ignoringOtherApps: true)` to force application activation instead of relying on the cooperative model that silently fails for unbundled executables launched from Terminal.
**Estimated Effort**: 0.25 hours

## Tasks

- [x] **T1**: Replace `window.makeKeyAndOrderFront(nil)` with `window.orderFrontRegardless()` and `NSApp.activate()` with `NSApp.activate(ignoringOtherApps: true)` in `WindowAccessor.configureWindow()` at `mkdn/UI/Components/WindowAccessor.swift` line 34-35 `[complexity:simple]`
- [x] **T2**: Run `swift build` to verify the project compiles cleanly with the API change `[complexity:simple]`
- [x] **T3**: Run SwiftLint and SwiftFormat to ensure no style violations are introduced `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/UI/Components/WindowAccessor.swift` | Replaced `makeKeyAndOrderFront(nil)` with `orderFrontRegardless()` and `NSApp.activate()` with `NSApp.activate(ignoringOtherApps: true)` | Done |
| T2 | -- | `swift build` completed successfully (3.17s) | Done |
| T3 | -- | SwiftFormat: 0 files reformatted. SwiftLint: 0 violations found. | Done |

## Verification

{To be added by task-reviewer if --review flag used}
