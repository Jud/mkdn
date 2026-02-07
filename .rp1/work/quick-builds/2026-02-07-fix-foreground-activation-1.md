# Quick Build: Fix Foreground Activation

**Created**: 2026-02-07T00:00:00Z
**Request**: Fix app not coming to foreground on launch. Root cause: NSApp.activate() in AppDelegate.applicationDidFinishLaunching fires before SwiftUI WindowGroup creates NSWindow. Fix: move activation to WindowAccessor.configureWindow() where NSWindow is guaranteed to exist -- add window.makeKeyAndOrderFront(nil) and NSApp.activate(). Remove redundant activate() from AppDelegate.
**Scope**: Small

## Plan

**Reasoning**: 2 files affected, 1 system (app lifecycle/window management), low risk. The root cause is well-understood from the investigation report -- a timing mismatch between NSApp.activate() and SwiftUI window creation.
**Files Affected**: mkdn/App/AppDelegate.swift, mkdn/UI/Components/WindowAccessor.swift
**Approach**: Add window.makeKeyAndOrderFront(nil) and NSApp.activate() to WindowAccessorView.configureWindow(_:), which fires when the NSWindow is guaranteed to exist. Remove the now-redundant NSApp.activate() from AppDelegate.applicationDidFinishLaunching. The applicationDidFinishLaunching method becomes empty and can either be removed entirely or left as a no-op stub.
**Estimated Effort**: 0.5 hours

## Tasks

- [x] **T1**: Add `window.makeKeyAndOrderFront(nil)` and `NSApp.activate()` to `WindowAccessorView.configureWindow(_:)` in `mkdn/UI/Components/WindowAccessor.swift` after the existing chrome configuration lines `[complexity:simple]`
- [x] **T2**: Remove the `NSApp.activate()` call from `AppDelegate.applicationDidFinishLaunching(_:)` in `mkdn/App/AppDelegate.swift`, leaving the method body empty or removing the method entirely if no other logic remains `[complexity:simple]`
- [x] **T3**: Build, lint, and format to verify no regressions: `swift build && DEVELOPER_DIR=/Applications/Xcode-16.3.0.app/Contents/Developer swiftlint lint && swiftformat .` `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/UI/Components/WindowAccessor.swift` | Added `window.makeKeyAndOrderFront(nil)` and `NSApp.activate()` after chrome config in `configureWindow(_:)` | Done |
| T2 | `mkdn/App/AppDelegate.swift` | Removed `applicationDidFinishLaunching(_:)` method entirely (only contained redundant `NSApp.activate()`) | Done |
| T3 | N/A | Build passes, lint 0 violations, format clean, 115/115 tests pass | Done |

## Verification

{To be added by task-reviewer if --review flag used}
