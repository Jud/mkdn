# Quick Build: Fix Zero Window Bug

**Created**: 2026-02-07T12:00:00Z
**Request**: Fix zero-window bug when launching with file argument. Root cause: MkdnApp.init() mutates @Observable FileOpenCoordinator.shared.pendingURLs during App struct initialization, which disrupts WindowGroup's internal state machine and prevents it from creating the default window. Fix: remove the init() side effect from MkdnApp and instead have DocumentWindow read LaunchContext.fileURL directly via .task or .onAppear, OR defer the FileOpenCoordinator mutation with DispatchQueue.main.async.
**Scope**: Small

## Plan

**Reasoning**: Only 2 files need changes (main.swift, LaunchContext.swift), single system (app launch lifecycle), low risk since we are removing a side effect rather than adding complexity. DocumentWindow.swift already contains the `.task` logic that reads from FileOpenCoordinator -- it just needs to also check LaunchContext directly.

**Files Affected**:
- `mkdnEntry/main.swift` -- remove `init()` from MkdnApp struct
- `mkdn/Core/CLI/LaunchContext.swift` -- add `consumeURL()` method for one-time consumption
- `mkdn/App/DocumentWindow.swift` -- add LaunchContext.consumeURL() check in `.task` block

**Approach**: Follow the investigation report's recommended solution (Option 1). Remove the `init()` method from `MkdnApp` entirely, eliminating the `@Observable` side effect that prevents WindowGroup from creating its default window. Add a `consumeURL()` method to `LaunchContext` so the URL can be read once and cleared. Update `DocumentWindow.task` to check `LaunchContext.consumeURL()` as a fallback when `fileURL` is nil and no pending FileOpenCoordinator URLs exist. This preserves the existing runtime file-open flow (Finder, dock, AppDelegate) while fixing the CLI launch path.

**Estimated Effort**: 0.5 hours

## Tasks

- [x] **T1**: Remove the `init()` method from `MkdnApp` in `mkdnEntry/main.swift` to eliminate the `@Observable` side effect during App struct initialization `[complexity:simple]`
- [x] **T2**: Add a `consumeURL()` static method to `LaunchContext` in `mkdn/Core/CLI/LaunchContext.swift` that returns and clears `fileURL` for one-time consumption `[complexity:simple]`
- [x] **T3**: Update `DocumentWindow.task` in `mkdn/App/DocumentWindow.swift` to check `LaunchContext.consumeURL()` before checking `FileOpenCoordinator` when `fileURL` is nil, so CLI-provided URLs are loaded into the default window `[complexity:simple]`
- [x] **T4**: Build and verify the fix compiles with `swift build`, then run `swift test` to confirm no test regressions `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdnEntry/main.swift` | Removed `init()` from `MkdnApp` struct, eliminating `@Observable` mutation during App initialization | Done |
| T2 | `mkdn/Core/CLI/LaunchContext.swift` | Added `consumeURL()` static method that returns and clears `fileURL` for one-time consumption | Done |
| T3 | `mkdn/App/DocumentWindow.swift` | Added `LaunchContext.consumeURL()` check as `else if` branch before `FileOpenCoordinator` fallback in `.task` | Done |
| T4 | -- | `swift build` succeeds, all 113 tests pass (signal 5 is pre-existing `@main` teardown artifact) | Done |

## Verification

{To be added by task-reviewer if --review flag used}
