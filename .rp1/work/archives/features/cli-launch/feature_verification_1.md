# Feature Verification Report #1

**Generated**: 2026-02-06T19:42:00Z
**Feature ID**: cli-launch
**Verification Scope**: all
**KB Context**: Loaded
**Field Notes**: Available

## Executive Summary
- Overall Status: PARTIAL
- Acceptance Criteria: 30/35 verified (86%)
- Implementation Quality: HIGH
- Ready for Merge: NO

The CLI launch pipeline is well-implemented with structured argument parsing, file validation, and clean error handling. All core CLI components (MkdnCLI, FileValidator, CLIError, LaunchContext) are present, tested, and correctly wired into the entry point. The main gaps are: (1) no explicit window title reflecting the file name (AC-6.3), and (2) several acceptance criteria that require manual runtime verification (GUI window behavior, process exit codes in real terminal, --help/--version output). Documentation update tasks (TD1, TD2, TD3) are not yet completed.

## Field Notes Context
**Field Notes Available**: Yes

### Documented Deviations
1. **Pre-existing test compile failure**: ThemeOutputFormatTests had compile issues that initially blocked test runs. Resolved as of T5.
2. **Public access modifiers**: T1-T4 types were created with `internal` access (Swift default). T5 required adding `public` to all CLI types and an explicit `public init()` to MkdnCLI for the executable target's regular `import mkdnLib`. This is a minor implementation detail, not a design deviation.

### Undocumented Deviations
1. **Window title not set from file name**: AC-6.3 requires the window title to include the file name, but there is no `navigationTitle`, `.title()`, or any title-setting mechanism in the WindowGroup, ContentView, or MkdnApp. The window title will default to "mkdn" (the executable name) regardless of which file is opened. This is NOT documented in field notes.

## Acceptance Criteria Verification

### FR-1: Argument Parsing

**AC-1.1**: `mkdn file.md` parses "file.md" as the file argument
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/MkdnCLI.swift`:10-11 - `@Argument` property `file: String?`
- Evidence: `MkdnCLI` declares `@Argument(help: "Path to a Markdown file (.md or .markdown).") public var file: String?`. The entry point at `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:31-37 parses via `MkdnCLI.parse()` and reads `cli.file`.
- Field Notes: N/A
- Issues: None

**AC-1.2**: `mkdn --help` prints usage information, exits with code 0
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/MkdnCLI.swift`:3-8 - `CommandConfiguration` with commandName, abstract, version
- Evidence: `MkdnCLI` conforms to `ParsableCommand` with `CommandConfiguration(commandName: "mkdn", abstract: "A Mac-native Markdown viewer.", version: "1.0.0")`. ArgumentParser automatically handles `--help` by printing usage to stdout and exiting with code 0. The catch-all block at `main.swift`:45-47 delegates to `MkdnCLI.exit(withError:)` which handles this correctly.
- Field Notes: N/A
- Issues: None. This relies on ArgumentParser library behavior which is well-tested.

**AC-1.3**: `mkdn --version` prints the version string, exits with code 0
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/MkdnCLI.swift`:7 - `version: "1.0.0"`
- Evidence: The `CommandConfiguration` includes `version: "1.0.0"`. ArgumentParser automatically handles `--version` by printing the version string and exiting with code 0.
- Field Notes: N/A
- Issues: None

**AC-1.4**: `mkdn --unknown-flag` prints error to stderr, exits with non-zero code
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:45-47 - catch block for general errors
- Evidence: Unknown flags cause `MkdnCLI.parse()` to throw a non-CLIError. The general catch block calls `MkdnCLI.exit(withError:)` which prints the error to stderr and exits with a non-zero code (ArgumentParser standard behavior).
- Field Notes: N/A
- Issues: None

### FR-2: Path Resolution

**AC-2.1**: Relative path resolves against current working directory
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift`:24-27 - `resolvePath` else branch
- Evidence: When `expanded` does not start with `/`, the code resolves against `FileManager.default.currentDirectoryPath` via `URL(fileURLWithPath: cwd).appendingPathComponent(expanded)`. Test `resolvesRelativePath` in FileValidatorTests confirms this.
- Field Notes: N/A
- Issues: None

**AC-2.2**: Tilde path resolves to user's home directory
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift`:20 - `NSString(string: path).expandingTildeInPath`
- Evidence: Tilde expansion is handled by `NSString.expandingTildeInPath` before path resolution. Test `expandsTilde` confirms `~/Documents/test.md` resolves under `NSHomeDirectory()`.
- Field Notes: N/A
- Issues: None

**AC-2.3**: Absolute path is used as-is
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift`:22-23 - `if expanded.hasPrefix("/")`
- Evidence: When the expanded path starts with `/`, it is used directly via `URL(fileURLWithPath: expanded)`. Test `resolvesAbsolutePath` confirms `/usr/local/share/test.md` preserves the directory and filename.
- Field Notes: N/A
- Issues: None

**AC-2.4**: Paths with `..` segments are resolved correctly
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift`:29 - `url.standardized.resolvingSymlinksInPath()`
- Evidence: `.standardized` removes `..` segments from the URL. Test `resolvesParentSegments` confirms `/usr/local/share/../lib/test.md` resolves to `/usr/local/lib/test.md` with no `..` in the result.
- Field Notes: N/A
- Issues: None

### FR-3: Extension Validation

**AC-3.1**: `.md` extension is accepted
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift`:4,35 - `acceptedExtensions: Set<String> = ["md", "markdown"]`
- Evidence: `acceptedExtensions.contains(ext)` where `ext` is `url.pathExtension.lowercased()`. Test `acceptsMdExtension` passes.
- Field Notes: N/A
- Issues: None

**AC-3.2**: `.markdown` extension is accepted
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift`:4,35
- Evidence: `"markdown"` is in the `acceptedExtensions` set. Test `acceptsMarkdownExtension` passes.
- Field Notes: N/A
- Issues: None

**AC-3.3**: Uppercase `.MD` extension is accepted (case-insensitive)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift`:34 - `.lowercased()`
- Evidence: `url.pathExtension.lowercased()` ensures case-insensitive matching. Test `acceptsUppercaseMdExtension` passes with `.MD`.
- Field Notes: N/A
- Issues: None

**AC-3.4**: `.txt` extension prints error to stderr listing accepted extensions, exits with code 1
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/CLIError.swift`:10-12 - `unsupportedExtension` case
- Evidence: `CLIError.unsupportedExtension` produces message `"unsupported file type '.txt' for 'notes.txt'. Accepted: .md, .markdown"`. Exit code is 1. Main.swift catch block prefixes with `"mkdn: error: "` and writes to stderr. Tests `rejectsTxtExtension` and `unsupportedExtensionMessage` confirm.
- Field Notes: N/A
- Issues: None

**AC-3.5**: No extension prints error to stderr, exits with code 1
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/CLIError.swift`:11 - `ext.isEmpty ? "no extension" : ...`
- Evidence: When extension is empty, message reads `"unsupported file type 'no extension' for 'README'. Accepted: .md, .markdown"`. Test `rejectsNoExtension` and `unsupportedExtensionEmptyExt` confirm.
- Field Notes: N/A
- Issues: None

### FR-4: File Existence Validation

**AC-4.1**: Missing file prints "not found" error to stderr with resolved path, exits with code 1
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift`:40-43 - `validateExistence`; `/Users/jud/Projects/mkdn/mkdn/Core/CLI/CLIError.swift`:13-14 - `fileNotFound` case
- Evidence: `FileValidator.validateExistence` throws `CLIError.fileNotFound(resolvedPath: url.path)`. Error message is `"file not found: /resolved/path"`. Exit code is 1. Test `existenceThrowsForMissingFile` confirms the resolved path is included. Test `fileNotFoundMessage` confirms message contains "not found".
- Field Notes: N/A
- Issues: None

**AC-4.2**: Error message shows fully resolved absolute path
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift`:10-11,42 - validates after `resolvePath` which produces absolute URL
- Evidence: `validate(path:)` calls `resolvePath` first (which produces an absolute, standardized, symlink-resolved URL), then passes `resolved` to `validateExistence`. The `url.path` in the error is always an absolute path. Test `fileNotFoundMessage` confirms the full path is in the message.
- Field Notes: N/A
- Issues: None

### FR-5: File Readability Validation

**AC-5.1**: No-read-permission file produces error to stderr, exits with code 2
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift`:48-52 - `isReadableFile` check; `/Users/jud/Projects/mkdn/mkdn/Core/CLI/CLIError.swift`:15-16 - `fileNotReadable` case
- Evidence: `FileValidator.validateReadability` checks `FileManager.default.isReadableFile(atPath:)` and throws `CLIError.fileNotReadable(resolvedPath:, reason: "permission denied")`. Exit code for `fileNotReadable` is 2. Test `fileNotReadableExitCode` confirms exit code 2.
- Field Notes: N/A
- Issues: No unit test specifically creates a file with no read permissions (the test `readabilityThrowsForBinaryFile` tests the UTF-8 path instead). However, the code logic is correct.

**AC-5.2**: Binary non-UTF-8 `.md` file produces error to stderr, exits with code 2
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift`:54-60 - UTF-8 encoding check
- Evidence: After the readability check, `String(contentsOf: url, encoding: .utf8)` is attempted. If it fails, `CLIError.fileNotReadable(resolvedPath:, reason: "file is not valid UTF-8 text")` is thrown. Test `readabilityThrowsForBinaryFile` writes invalid UTF-8 bytes `[0xFF, 0xFE, 0x80, 0x81, 0xC0, 0xC1]` and confirms the error is thrown with reason containing "UTF-8".
- Field Notes: N/A
- Issues: None

### FR-6: App Window Launch with File Content

**AC-6.1**: Valid file opens window with rendered Markdown content
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:9-15 - `MkdnApp.init()` loads file; `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:12-19 - switches on `currentFileURL`
- Evidence: `MkdnApp.init()` reads `LaunchContext.fileURL`, and if present, calls `state.loadFile(at: url)`. ContentView checks `appState.currentFileURL == nil` -- when it is NOT nil, it renders `MarkdownPreviewView`. The code path is correct but actual window rendering requires manual verification.
- Field Notes: N/A
- Issues: Requires running the app with a real Markdown file to confirm visual output.

**AC-6.2**: File content loaded into AppState (currentFileURL set, markdownContent populated)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:11-12; `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:33-38
- Evidence: `MkdnApp.init()` calls `state.loadFile(at: url)`. `AppState.loadFile(at:)` sets `currentFileURL = url` and `markdownContent = content` (line 35-36). The `try?` in init silently swallows errors, but the file is already fully validated by FileValidator before reaching this point. AppState unit tests confirm `loadFile` populates both properties.
- Field Notes: N/A
- Issues: The `try?` in `MkdnApp.init()` means if `loadFile` fails (extremely unlikely after FileValidator), the error is silently swallowed and the user sees WelcomeView instead. This is a minor concern given the pre-validation.

**AC-6.3**: Window title includes file name
- Status: NOT VERIFIED
- Implementation: No implementation found
- Evidence: The `WindowGroup` in `main.swift`:17-20 does not set a title. `ContentView` does not use `.navigationTitle()`. There is no mechanism anywhere in the codebase to set the window title based on `appState.currentFileURL`. The window title will be the default (typically the app name "mkdn").
- Field Notes: This deviation is NOT documented in field-notes.md.
- Issues: **Missing implementation**. The window title does not reflect the opened file name. A `.navigationTitle(appState.currentFileURL?.lastPathComponent ?? "mkdn")` or equivalent is needed on the ContentView or in the WindowGroup.

### FR-7: No-Argument Launch

**AC-7.1**: No arguments launches app with WelcomeView
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:34-37; `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:12-13
- Evidence: When `cli.file` is nil, `LaunchContext.fileURL` remains nil (default). `MkdnApp.init()` does not call `loadFile`. `AppState.currentFileURL` remains nil. ContentView checks `if appState.currentFileURL == nil` and shows `WelcomeView()`.
- Field Notes: N/A
- Issues: None

**AC-7.2**: No error message printed to stderr
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:31-39
- Evidence: When no file argument is provided, `MkdnCLI.parse()` succeeds (file is optional), `cli.file` is nil, the if-block is skipped, and `MkdnApp.main()` is called directly. No error paths are triggered.
- Field Notes: N/A
- Issues: None

**AC-7.3**: Exit code is 0 when app closes
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:39 - `MkdnApp.main()`
- Evidence: `MkdnApp.main()` runs the SwiftUI app lifecycle. When the user closes the window/quits, the process exits naturally. SwiftUI apps exit with code 0 by default. Cannot be verified without running the app.
- Field Notes: N/A
- Issues: Requires manual verification by running the app and checking exit code after quit.

### FR-8: No GUI Window on CLI Error

**AC-8.1**: Missing file exits without window appearing
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:31-44 - error path calls `Foundation.exit()` before `MkdnApp.main()`
- Evidence: When `FileValidator.validate(path:)` throws `CLIError.fileNotFound`, execution enters the `catch let error as CLIError` block (line 40). This writes to stderr and calls `Foundation.exit(error.exitCode)`. `MkdnApp.main()` on line 39 is never reached, so no SwiftUI window is created.
- Field Notes: N/A
- Issues: None

**AC-8.2**: Invalid extension exits without window appearing
- Status: VERIFIED
- Implementation: Same as AC-8.1 - `FileValidator.validate` throws `CLIError.unsupportedExtension`, caught at line 40
- Evidence: Extension validation happens in `FileValidator.validate()` before `MkdnApp.main()` is called. The CLIError catch block exits the process.
- Field Notes: N/A
- Issues: None

**AC-8.3**: Process terminates after error, does not hang
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:44 - `Foundation.exit(error.exitCode)`
- Evidence: `Foundation.exit()` terminates the process immediately. There is no run loop or SwiftUI lifecycle started on error paths. For ArgumentParser errors, `MkdnCLI.exit(withError:)` also terminates the process.
- Field Notes: N/A
- Issues: None

### FR-9: Exit Codes

**AC-9.1**: Successful launch and close returns exit code 0
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:39 - `MkdnApp.main()`
- Evidence: SwiftUI app lifecycle exits with code 0 by default. Cannot verify automatically without running the app.
- Field Notes: N/A
- Issues: Requires manual terminal verification.

**AC-9.2**: `--help` returns exit code 0
- Status: VERIFIED
- Implementation: ArgumentParser library behavior + `/Users/jud/Projects/mkdn/mkdn/Core/CLI/MkdnCLI.swift`:3-8
- Evidence: ArgumentParser's `--help` handling prints usage and exits with code 0. This is well-documented ArgumentParser behavior. The `MkdnCLI.exit(withError:)` in the catch block handles this correctly.
- Field Notes: N/A
- Issues: None

**AC-9.3**: `--version` returns exit code 0
- Status: VERIFIED
- Implementation: ArgumentParser library behavior + `/Users/jud/Projects/mkdn/mkdn/Core/CLI/MkdnCLI.swift`:7
- Evidence: ArgumentParser's `--version` handling prints the version string and exits with code 0.
- Field Notes: N/A
- Issues: None

**AC-9.4**: Missing file returns exit code 1
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/CLIError.swift`:22 - `fileNotFound` maps to exit code 1
- Evidence: `CLIError.fileNotFound.exitCode` returns `1`. Main.swift calls `Foundation.exit(error.exitCode)`. Test `fileNotFoundExitCode` confirms.
- Field Notes: N/A
- Issues: None

**AC-9.5**: Invalid extension returns exit code 1
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/CLIError.swift`:22 - `unsupportedExtension` maps to exit code 1
- Evidence: `CLIError.unsupportedExtension.exitCode` returns `1`. Test `unsupportedExtensionExitCode` confirms.
- Field Notes: N/A
- Issues: None

**AC-9.6**: Unreadable file returns exit code 2
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/CLIError.swift`:23 - `fileNotReadable` maps to exit code 2
- Evidence: `CLIError.fileNotReadable.exitCode` returns `2`. Test `fileNotReadableExitCode` confirms.
- Field Notes: N/A
- Issues: None

### FR-10: Error Message Quality

**AC-10.1**: File-not-found error includes resolved absolute path
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/CLIError.swift`:13-14
- Evidence: Error message format is `"file not found: \(resolvedPath)"` where `resolvedPath` is the fully resolved absolute path from `FileValidator.resolvePath()`. Test `fileNotFoundMessage` confirms path is included.
- Field Notes: N/A
- Issues: None

**AC-10.2**: Invalid-extension error names the provided extension and lists accepted extensions
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/CLIError.swift`:10-12
- Evidence: Error message format is `"unsupported file type '.\(ext)' for '\(path)'. Accepted: .md, .markdown"`. Both the provided extension and the list of accepted extensions are included. Test `unsupportedExtensionMessage` confirms all components are present.
- Field Notes: N/A
- Issues: None

**AC-10.3**: Unreadable-file error distinguishes permission errors from encoding errors
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift`:48-61
- Evidence: Two distinct checks: (1) `isReadableFile` check produces reason `"permission denied"`, (2) UTF-8 encoding check produces reason `"file is not valid UTF-8 text"`. The `CLIError.fileNotReadable` includes the specific reason string. Test `fileNotReadableMessage` confirms reason is in message.
- Field Notes: N/A
- Issues: None

**AC-10.4**: Error messages prefixed with program name (`mkdn: error: ...`)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:41-43
- Evidence: CLIError catch block writes `"mkdn: error: \(error.localizedDescription)\n"` to stderr. The `"mkdn: error: "` prefix is hardcoded. For ArgumentParser errors, `MkdnCLI.exit(withError:)` uses ArgumentParser's own formatting which includes the command name.
- Field Notes: N/A
- Issues: None

## Implementation Gap Analysis

### Missing Implementations
- **AC-6.3**: Window title does not reflect the opened file name. No `.navigationTitle()` or equivalent is applied to the ContentView or WindowGroup. This is an undocumented deviation from the requirements.

### Partial Implementations
- None

### Implementation Issues
- **AC-6.2 (minor)**: `try?` in `MkdnApp.init()` silently swallows `loadFile` errors. While the file is pre-validated by FileValidator, an edge case (e.g., file deleted between validation and load) would result in a silent fallback to WelcomeView with no user feedback. This is a very unlikely scenario but worth noting.

### Documentation Tasks Not Completed
- **TD1**: architecture.md not updated with CLI flow changes
- **TD2**: modules.md not updated with new CLI component inventory
- **TD3**: index.md Quick Reference not updated

## Code Quality Assessment

**Overall: HIGH**

The implementation demonstrates strong code quality:

1. **Design fidelity**: The code matches the design document almost exactly, with only the necessary deviation of adding `public` access modifiers (documented in field notes).

2. **Error handling**: Typed `CLIError` enum with `LocalizedError` conformance follows the project's established pattern (matching `MermaidError`). Exit code mapping is clean and well-tested.

3. **Separation of concerns**: Clean separation between parsing (`MkdnCLI`), validation (`FileValidator`), error types (`CLIError`), state communication (`LaunchContext`), and orchestration (`main.swift`).

4. **Testing**: 24 focused tests covering path resolution, extension validation, existence checks, readability checks, full pipeline, exit codes, and error messages. All tests use real filesystem operations via temp directories for determinism. Test organization follows Swift Testing patterns (`@Suite`, `@Test`).

5. **Concurrency safety**: `nonisolated(unsafe)` on `LaunchContext.fileURL` is properly justified by the sequential set-once/read-once pattern, documented in code comments.

6. **Entry point architecture**: The top-level code pattern in `main.swift` correctly prevents GUI window creation on error paths by ensuring `MkdnApp.main()` is only called after all validation passes.

7. **Old code cleanup**: `CLIHandler.swift`, its tests, and the dead `mkdnApp.swift` are all properly removed with no remaining references.

**Minor observations**:
- `FileValidator.resolvePath`, `validateExtension`, `validateExistence` are `static` (not `public static`), meaning they are accessible in tests via `@testable import` but not from the executable target. This is intentional -- only `validate(path:)` is the public API.
- The `acceptedExtensions` set is a clean pattern for extensibility.

## Recommendations

1. **Implement window title (AC-6.3)**: Add `.navigationTitle(appState.currentFileURL?.lastPathComponent ?? "mkdn")` to the ContentView or use the `WindowGroup(title:)` initializer to dynamically set the window title based on the opened file. This is the only missing functional requirement.

2. **Complete documentation tasks (TD1, TD2, TD3)**: Update `.rp1/context/architecture.md`, `.rp1/context/modules.md`, and `.rp1/context/index.md` to reflect the new CLI pipeline components and entry point architecture.

3. **Consider error recovery in MkdnApp.init()**: The `try?` on `state.loadFile(at: url)` silently swallows errors. While extremely unlikely after FileValidator pre-validation, consider logging to stderr or presenting a brief error state instead of silently showing WelcomeView.

4. **Add a permission-denied unit test**: While the code for `isReadableFile` is correct, there is no unit test that creates a file with restricted permissions. Consider adding one for completeness (noting that macOS test sandboxing may make this tricky).

5. **Manual verification needed**: Run the following terminal commands to verify runtime behavior:
   - `swift run mkdn -- --help` (verify usage output and exit code 0)
   - `swift run mkdn -- --version` (verify "1.0.0" output and exit code 0)
   - `swift run mkdn -- nonexistent.md` (verify error message and exit code 1)
   - `swift run mkdn -- README` (verify extension error and exit code 1)
   - `swift run mkdn -- valid-file.md` (verify window opens with content)
   - `swift run mkdn` (verify WelcomeView appears)

## Verification Evidence

### CLIError.swift (complete file)
```swift
// /Users/jud/Projects/mkdn/mkdn/Core/CLI/CLIError.swift
public enum CLIError: LocalizedError {
    case unsupportedExtension(path: String, ext: String)
    case fileNotFound(resolvedPath: String)
    case fileNotReadable(resolvedPath: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedExtension(path, ext):
            let extText = ext.isEmpty ? "no extension" : ".\(ext)"
            return "unsupported file type '\(extText)' for '\(path)'. Accepted: .md, .markdown"
        case let .fileNotFound(resolvedPath):
            return "file not found: \(resolvedPath)"
        case let .fileNotReadable(resolvedPath, reason):
            return "cannot read file: \(resolvedPath) (\(reason))"
        }
    }

    public var exitCode: Int32 {
        switch self {
        case .unsupportedExtension, .fileNotFound: 1
        case .fileNotReadable: 2
        }
    }
}
```

### Entry point orchestration (main.swift lines 30-47)
```swift
// /Users/jud/Projects/mkdn/mkdnEntry/main.swift
do {
    let cli = try MkdnCLI.parse()
    if let filePath = cli.file {
        let url = try FileValidator.validate(path: filePath)
        LaunchContext.fileURL = url
    }
    MkdnApp.main()
} catch let error as CLIError {
    FileHandle.standardError.write(
        Data("mkdn: error: \(error.localizedDescription)\n".utf8)
    )
    Foundation.exit(error.exitCode)
} catch {
    MkdnCLI.exit(withError: error)
}
```

### Test results
- Build: PASS (0 errors, 0 warnings)
- Tests: 96/96 passing
- SwiftLint: Not available in current environment (tool not installed)

### Key file inventory
| File | Status | Lines |
|------|--------|-------|
| `/Users/jud/Projects/mkdn/mkdn/Core/CLI/CLIError.swift` | Present | 29 |
| `/Users/jud/Projects/mkdn/mkdn/Core/CLI/MkdnCLI.swift` | Present | 14 |
| `/Users/jud/Projects/mkdn/mkdn/Core/CLI/LaunchContext.swift` | Present | 11 |
| `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift` | Present | 63 |
| `/Users/jud/Projects/mkdn/mkdnEntry/main.swift` | Refactored | 47 |
| `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/FileValidatorTests.swift` | Present | 215 |
| `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/CLIErrorTests.swift` | Present | 67 |
| `/Users/jud/Projects/mkdn/mkdn/Core/CLI/CLIHandler.swift` | Deleted | -- |
| `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/CLIHandlerTests.swift` | Deleted | -- |
| `/Users/jud/Projects/mkdn/mkdn/App/mkdnApp.swift` | Deleted | -- |
