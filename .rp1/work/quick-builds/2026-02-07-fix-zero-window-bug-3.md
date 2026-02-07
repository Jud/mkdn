# Quick Build: Fix Zero Window Bug

**Created**: 2026-02-07T00:00:00-06:00
**Request**: Fix zero-window bug by stripping CLI arguments after parsing so SwiftUI/NSApplication don't reprocess them. Two changes: (1) In mkdnEntry/main.swift add CommandLine.arguments reset after CLI parsing, before MkdnApp.main(). (2) In mkdn/App/AppDelegate.swift remove applicationDidFinishLaunching and its supporting methods since the workaround is no longer needed.
**Scope**: Small

## Plan

**Reasoning**: Only 2 files affected, 1 system (app startup), low risk since the root cause is well-understood (extra CLI arguments interfere with WindowGroup(for: URL.self) default window creation) and the fix is surgical. The AppDelegate workaround removal is safe because WindowAccessor.swift already handles window activation.
**Files Affected**: mkdnEntry/main.swift, mkdn/App/AppDelegate.swift
**Approach**: In main.swift, insert `CommandLine.arguments = [CommandLine.arguments[0]]` after MkdnCLI.parse() extracts the file path and before MkdnApp.main() runs, so SwiftUI only sees the bare executable name and creates its default window normally. In AppDelegate.swift, remove the applicationDidFinishLaunching method, the activateApp helper, the removeWindowObserver helper, and the windowObserver property -- all of which were a three-layer workaround for the zero-window symptom. Keep application(_:open:) and applicationShouldHandleReopen.
**Estimated Effort**: 0.5 hours

## Tasks

- [x] **T1**: In `mkdnEntry/main.swift`, add `CommandLine.arguments = [CommandLine.arguments[0]]` on the line immediately after the `if let filePath` block and before `NSApplication.shared.setActivationPolicy(.regular)`, so SwiftUI never sees the extra file argument `[complexity:simple]`
- [x] **T2**: In `mkdn/App/AppDelegate.swift`, remove the `windowObserver` property, `applicationDidFinishLaunching(_:)`, `activateApp()`, and `removeWindowObserver()` methods while keeping `application(_:open:)` and `applicationShouldHandleReopen(_:hasVisibleWindows:)` `[complexity:simple]`
- [x] **T3**: Optionally remove the temporary startup debug logging in `mkdnEntry/main.swift` (the `/tmp/mkdn-debug.log` writes) since the bug is resolved `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdnEntry/main.swift`, `Package.swift` | Added `CommandLine.arguments = [CommandLine.arguments[0]]` after CLI parsing. Required `swiftLanguageMode(.v5)` on executable target because the setter is obsoleted in Swift 6 (deprecated warning only in Swift 5 mode). | Done |
| T2 | `mkdn/App/AppDelegate.swift` | Removed `windowObserver`, `applicationDidFinishLaunching`, `activateApp()`, `removeWindowObserver()`. Kept `application(_:open:)` and `applicationShouldHandleReopen`. | Done |
| T3 | `mkdnEntry/main.swift` | Removed all `/tmp/mkdn-debug.log` debug logging (3 write sites + file creation). | Done |

## Verification

{To be added by task-reviewer if --review flag used}
