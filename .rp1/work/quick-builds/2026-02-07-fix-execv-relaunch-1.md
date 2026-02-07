# Quick Build: Fix Execv Relaunch

**Created**: 2026-02-07T00:00:00Z
**Request**: Implement execv() re-execution pattern in mkdnEntry/main.swift to fix the zero-window bug when launching with a file argument. Root cause: NSApplication interprets positional CLI args as kAEOpenDocuments AppleEvents, suppressing SwiftUI default WindowGroup window creation. ProcessInfo.processinfo.arguments is cached from C argv before any Swift code runs, so CommandLine.arguments stripping is ineffective. Solution: When a positional file argument is detected, save the validated file path to MKDN_LAUNCH_FILE env var and execv() the binary without the file argument. The re-launched process reads the env var into LaunchContext.fileURL and proceeds normally with a clean argv. Also remove the now-unnecessary CommandLine.arguments stripping and the NSApplication.shared.setActivationPolicy(.regular) pre-init call (Evidence 8 showed it prevents AppDelegate lifecycle methods from firing). Key files: mkdnEntry/main.swift (primary changes), mkdn/App/AppDelegate.swift (may need cleanup of the three-layer activation workaround since it was solving a symptom not the cause).
**Scope**: Small

## Plan

**Reasoning**: 2 files changed (mkdnEntry/main.swift primary, mkdn/App/AppDelegate.swift cleanup review), 1 system (CLI entry/launch), low risk (solution experimentally validated per investigation report Evidence 5). Fits well within the Small scope boundary.

**Files Affected**:
- `mkdnEntry/main.swift` -- primary changes: add execv re-execution, remove CommandLine.arguments stripping, remove NSApplication.shared.setActivationPolicy(.regular) pre-init
- `mkdn/App/AppDelegate.swift` -- review/cleanup: the three-layer activation workaround from commit 4ff743a was solving a symptom (no window to activate) not the cause. With execv fix, AppDelegate should be clean (it already is in current state -- the workaround appears to have been already cleaned up, current AppDelegate is minimal).

**Approach**: Restructure `mkdnEntry/main.swift` to detect the MKDN_LAUNCH_FILE environment variable first. If present, this is a re-launched process: unset the env var, set LaunchContext.fileURL from it, and call MkdnApp.main(). If not present, parse CLI arguments normally. When a file argument is detected, validate the path, set MKDN_LAUNCH_FILE env var with the resolved absolute path, and execv() the binary with only argv[0] (no file argument). The re-launched process gets a clean argv that NSApplication will not misinterpret as a kAEOpenDocuments event. Remove the ineffective `CommandLine.arguments = [CommandLine.arguments[0]]` line. Remove `NSApplication.shared.setActivationPolicy(.regular)` pre-init call since Evidence 8 shows it prevents AppDelegate lifecycle methods from firing -- SwiftUI's own NSApplication initialization handles activation policy correctly.

**Estimated Effort**: 1 hour

## Tasks

- [x] **T1**: Rewrite `mkdnEntry/main.swift` to add MKDN_LAUNCH_FILE env var check at top level -- if env var is set, unset it, set LaunchContext.fileURL, and call MkdnApp.main() directly (the re-launched clean-argv path) `[complexity:medium]`
- [x] **T2**: Add execv() re-execution in the file-argument branch -- after FileValidator.validate(), set MKDN_LAUNCH_FILE env var to the resolved absolute path and execv() the binary with only argv[0]. Remove the now-unnecessary CommandLine.arguments stripping and NSApplication.shared.setActivationPolicy(.regular) pre-init call `[complexity:medium]`
- [x] **T3**: Review mkdn/App/AppDelegate.swift for any remaining workaround code from the three-layer activation fix (commit 4ff743a) and clean up if present. Verify the minimal AppDelegate is correct for the execv approach `[complexity:simple]`
- [x] **T4**: Build and manually test both launch paths: `swift run mkdn` (no-arg, should show welcome window) and `swift run mkdn README.md` (file-arg, should show file content in window). Run `swift test` to ensure no regressions `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdnEntry/main.swift` | Added env var check at top level: if MKDN_LAUNCH_FILE is set, unset it, set LaunchContext.fileURL from the path, call MkdnApp.main() directly | Done |
| T2 | `mkdnEntry/main.swift` | Added execv() re-execution in file-arg branch: validate path, set env var, execv with clean argv. Removed CommandLine.arguments stripping and NSApplication.shared.setActivationPolicy(.regular) pre-init | Done |
| T3 | `mkdn/App/AppDelegate.swift` | Reviewed -- no three-layer workaround code present. Current minimal AppDelegate is correct for execv approach | Done |
| T4 | -- | Build succeeds, all test suites pass, lint clean | Done |

## Verification

{To be added by task-reviewer if --review flag used}
