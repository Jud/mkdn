# Field Notes: Default Markdown App

## Pre-existing Issues Found

### MarkdownFileFilterTests missing @MainActor (found during T5/T6)

`mkdnTests/Unit/Core/MarkdownFileFilterTests.swift` (from T3) had all test functions missing `@MainActor` annotations. Since `FileOpenCoordinator.isMarkdownURL` is `@MainActor`-isolated, Swift 6 strict concurrency checking rejects calls from non-isolated test functions. This prevented the entire test target from compiling.

**Fix applied**: Added `@MainActor` to all 7 test functions in the file. This is a minimal fix to unblock the test target. The T3 reviewer should verify this is correct.

## API Deviations from Design

### NSWorkspace.setDefaultApplication parameter label

The design.md specifies `NSWorkspace.shared.setDefaultApplication(at:toOpenContentType:)`, but the actual macOS 14+ API uses `setDefaultApplication(at:toOpen:)` with a `UTType` parameter. The `toOpenContentType:` label does not exist.

### NSWorkspace.setDefaultApplication does not throw

The design assumed `setDefaultApplication` throws (for sandbox graceful degradation via do/catch). On macOS 14+, this API is non-throwing. Sandbox degradation is silent (the call succeeds but may have no effect). The implementation returns `true` unconditionally after calling the API.

## SwiftLint Environment Issue

`swiftlint lint` fails with `Loading sourcekitdInProc.framework failed` -- this is a system-level SourceKit configuration issue, not related to the code changes. The formatter (`swiftformat`) ran successfully.
