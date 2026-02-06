# Development Tasks: CLI Launch

**Feature ID**: cli-launch
**Status**: In Progress
**Progress**: 70% (7 of 10 tasks)
**Estimated Effort**: 2 days
**Started**: 2026-02-06

## Overview

Replace the existing `CLIHandler` with a structured argument-parsing pipeline built on `swift-argument-parser`. Restructure `mkdnEntry/main.swift` from an `@main` SwiftUI App into top-level orchestration code that validates arguments before the SwiftUI lifecycle starts. Error cases exit cleanly to stderr without ever creating a GUI window.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T2, T3] - Independent type definitions: CLIError enum, MkdnCLI ParsableCommand, and LaunchContext are self-contained structs/enums with no cross-dependencies
2. [T4, T6] - FileValidator uses CLIError (from T1); tests validate T1+T2+T4 logic. T4 and T6 are independent of each other
3. [T5] - Entry point refactor requires all of T1-T4 plus reads LaunchContext (T3) and defines MkdnApp
4. [T7] - Cleanup of old code after new system is fully wired

**Dependencies**:

- T4 -> T1 (interface: FileValidator throws CLIError)
- T5 -> [T1, T2, T3, T4] (interface: orchestrates all CLI components)
- T6 -> [T1, T2, T4] (interface: tests validate these components)
- T7 -> T5 (sequential workflow: old code removed after replacement is wired)

**Critical Path**: T1 -> T4 -> T5 -> T7

## Task Breakdown

### Phase 1: Independent Type Definitions

- [x] **T1**: Create CLIError enum with typed error cases for unsupported extension, file not found, and file not readable `[complexity:simple]`

    **Reference**: [design.md#32-clierror](design.md#32-clierror)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] CLIError enum exists at `mkdn/Core/CLI/CLIError.swift` with cases: `unsupportedExtension(path:ext:)`, `fileNotFound(resolvedPath:)`, `fileNotReadable(resolvedPath:reason:)`
    - [x] Conforms to `LocalizedError` with descriptive `errorDescription` for each case
    - [x] `unsupportedExtension` message includes the provided extension and lists accepted extensions (.md, .markdown)
    - [x] `fileNotFound` message includes the resolved absolute path
    - [x] `fileNotReadable` message includes the resolved path and the specific reason (permission denied vs encoding)
    - [x] `exitCode` computed property returns `Int32`: 1 for user errors (unsupportedExtension, fileNotFound), 2 for system errors (fileNotReadable)

    **Implementation Summary**:

    - **Files**: `mkdn/Core/CLI/CLIError.swift`
    - **Approach**: Created CLIError enum with three cases matching design spec; LocalizedError conformance with descriptive messages; exitCode computed property mapping user errors to 1 and system errors to 2
    - **Deviations**: None
    - **Tests**: Deferred to T6

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

- [x] **T2**: Create MkdnCLI ParsableCommand with optional file argument and command configuration `[complexity:simple]`

    **Reference**: [design.md#31-mkdncli-parsablecommand](design.md#31-mkdncli-parsablecommand)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] MkdnCLI struct exists at `mkdn/Core/CLI/MkdnCLI.swift` conforming to `ParsableCommand`
    - [x] `CommandConfiguration` sets commandName to "mkdn", abstract to "A Mac-native Markdown viewer.", and version to "1.0.0"
    - [x] Single optional `@Argument` property `file: String?` with help text describing Markdown file path
    - [x] Does NOT implement `run()` -- used purely for parsing via `MkdnCLI.parse()`
    - [x] `--help` flag prints usage information and exits with code 0 (handled by ArgumentParser)
    - [x] `--version` flag prints "1.0.0" and exits with code 0 (handled by ArgumentParser)

    **Implementation Summary**:

    - **Files**: `mkdn/Core/CLI/MkdnCLI.swift`
    - **Approach**: Created ParsableCommand struct with CommandConfiguration and optional @Argument; no run() method per design
    - **Deviations**: None
    - **Tests**: Deferred to T6

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

- [x] **T3**: Create LaunchContext static URL store for CLI-to-App communication `[complexity:simple]`

    **Reference**: [design.md#34-launchcontext](design.md#34-launchcontext)

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [x] LaunchContext enum exists at `mkdn/Core/CLI/LaunchContext.swift`
    - [x] Single static property `fileURL: URL?` declared as `nonisolated(unsafe)` per project pattern
    - [x] Default value is `nil` (no-argument launch produces WelcomeView)
    - [x] Documented with comments explaining the set-once/read-once sequential access pattern

    **Implementation Summary**:

    - **Files**: `mkdn/Core/CLI/LaunchContext.swift`
    - **Approach**: Created uninhabited enum with nonisolated(unsafe) static var fileURL: URL? defaulting to nil; documented sequential access pattern in doc comments
    - **Deviations**: None
    - **Tests**: N/A (trivial static property, no logic to test per design)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

### Phase 2: Validation and Tests

- [x] **T4**: Create FileValidator with path resolution and validation pipeline (extension, existence, readability) `[complexity:medium]`

    **Reference**: [design.md#33-filevalidator](design.md#33-filevalidator)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] FileValidator enum exists at `mkdn/Core/CLI/FileValidator.swift` with static methods
    - [x] `validate(path:)` orchestrates the full pipeline: resolve -> extension -> existence -> readability, returning a validated `URL`
    - [x] `resolvePath(_:)` expands tilde via `NSString.expandingTildeInPath`, resolves relative paths against `FileManager.default.currentDirectoryPath`, resolves symlinks via `.resolvingSymlinksInPath()`
    - [x] `validateExtension(url:originalPath:)` accepts `.md` and `.markdown` (case-insensitive), throws `CLIError.unsupportedExtension` otherwise
    - [x] `validateExistence(url:)` checks `FileManager.default.fileExists`, throws `CLIError.fileNotFound` with resolved path
    - [x] `validateReadability(url:)` checks `FileManager.default.isReadableFile` and verifies UTF-8 encoding via `String(contentsOf:encoding:)`, throws `CLIError.fileNotReadable` with specific reason
    - [x] Validation order follows BR-2: extension before existence before readability

    **Implementation Summary**:

    - **Files**: `mkdn/Core/CLI/FileValidator.swift`
    - **Approach**: Created FileValidator enum with static methods matching design spec exactly; resolvePath handles tilde expansion, relative/absolute paths, and symlink resolution; validation pipeline enforces extension->existence->readability order per BR-2; acceptedExtensions stored as private static Set for clean lookup
    - **Deviations**: None
    - **Tests**: Deferred to T6

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

- [x] **T6**: Create unit tests for FileValidator and CLIError `[complexity:medium]`

    **Reference**: [design.md#7-testing-strategy](design.md#7-testing-strategy)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] `mkdnTests/Unit/Core/FileValidatorTests.swift` exists with `@Suite("FileValidator")` using Swift Testing framework
    - [x] Path resolution tests: absolute path as-is, relative path against cwd, tilde expansion, `..` segment resolution, symlink resolution
    - [x] Extension validation tests: accepts `.md`, accepts `.markdown`, accepts uppercase `.MD`, rejects `.txt` with descriptive error, rejects no-extension
    - [x] Existence validation tests: passes for existing file, throws `fileNotFound` for missing file with resolved path in message
    - [x] Readability validation tests: passes for readable UTF-8 file, throws `fileNotReadable` for unreadable file
    - [x] Full pipeline test: `validate(path:)` returns URL for valid Markdown file, checks extension before existence
    - [x] `mkdnTests/Unit/Core/CLIErrorTests.swift` exists with `@Suite("CLIError")`
    - [x] CLIError tests: exit codes (unsupportedExtension=1, fileNotFound=1, fileNotReadable=2), error messages include extension/path/reason as appropriate
    - [x] All tests use `@testable import mkdnLib`

    **Implementation Summary**:

    - **Files**: `mkdnTests/Unit/Core/FileValidatorTests.swift`, `mkdnTests/Unit/Core/CLIErrorTests.swift`
    - **Approach**: FileValidatorTests covers path resolution (5 tests), extension validation (5 tests), existence validation (2 tests), readability validation (2 tests), and full pipeline (2 tests) using temp directories with cleanup. CLIErrorTests covers exit codes (3 tests) and error message content (5 tests). All tests use real filesystem operations via temp dirs for determinism.
    - **Deviations**: None
    - **Tests**: 23/23 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | PASS |
    | Commit | N/A |
    | Comments | PASS |

### Phase 3: Entry Point Refactor

- [x] **T5**: Refactor main.swift to top-level orchestration: parse, validate, set LaunchContext, launch MkdnApp without @main `[complexity:medium]`

    **Reference**: [design.md#35-entry-point-refactor-mainswift](design.md#35-entry-point-refactor-mainswift)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] `mkdnEntry/main.swift` uses top-level code (not `@main`) to orchestrate: `MkdnCLI.parse()` -> `FileValidator.validate()` -> `LaunchContext.fileURL = url` -> `MkdnApp.main()`
    - [x] `MkdnApp` struct conforms to `App` without `@main` attribute, defined in the same file
    - [x] `MkdnApp.init()` reads `LaunchContext.fileURL` and calls `AppState.loadFile(at:)` when URL is present
    - [x] When no file argument is provided, `LaunchContext.fileURL` remains nil and WelcomeView is shown
    - [x] CLIError catch block writes `"mkdn: error: \(error.localizedDescription)\n"` to stderr and calls `Foundation.exit(error.exitCode)`
    - [x] ArgumentParser errors (--help, --version, unknown flags) are handled via `MkdnCLI.exit(withError:)` in the general catch block
    - [x] No GUI window is created on any error path -- `MkdnApp.main()` is only called after all validation passes
    - [x] Existing MkdnApp body (WindowGroup, commands, environment) is preserved in the refactored struct

    **Implementation Summary**:

    - **Files**: `mkdnEntry/main.swift`, `mkdn/Core/CLI/MkdnCLI.swift`, `mkdn/Core/CLI/CLIError.swift`, `mkdn/Core/CLI/FileValidator.swift`, `mkdn/Core/CLI/LaunchContext.swift`
    - **Approach**: Replaced @main MkdnApp with top-level do/catch orchestration that parses CLI args, validates file path, stores URL in LaunchContext, then calls MkdnApp.main(). MkdnApp.init() reads LaunchContext.fileURL and pre-loads file into AppState. Added public access modifiers to CLI types (MkdnCLI, CLIError, FileValidator, LaunchContext) so they are accessible from the executable target via `import mkdnLib`.
    - **Deviations**: Added public access modifiers to T1-T4 types; these were internal (sufficient for @testable import in tests) but needed to be public for the executable target's regular import. Also added explicit public init() to MkdnCLI as required by ParsableArguments protocol when the type is public.
    - **Tests**: 77/77 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

### Phase 4: Cleanup

- [x] **T7**: Remove old CLIHandler, its tests, and dead library-side mkdnApp.swift; update Package.swift exclude list `[complexity:simple]`

    **Reference**: [design.md#36-old-clihandler-removal](design.md#36-old-clihandler-removal)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] `mkdn/Core/CLI/CLIHandler.swift` is deleted
    - [x] `mkdnTests/Unit/Core/CLIHandlerTests.swift` is deleted
    - [x] `mkdn/App/mkdnApp.swift` (dead library-side App definition) is deleted
    - [x] `Package.swift` exclude list for mkdnLib target is updated to remove the `"App/mkdnApp.swift"` entry
    - [x] `swift build` succeeds with no compilation errors after all deletions
    - [x] `swift test` passes with no failures after all deletions
    - [x] No remaining references to `CLIHandler` anywhere in the codebase

    **Implementation Summary**:

    - **Files**: Deleted `mkdn/Core/CLI/CLIHandler.swift`, `mkdnTests/Unit/Core/CLIHandlerTests.swift`, `mkdn/App/mkdnApp.swift`; edited `Package.swift`
    - **Approach**: Deleted three dead code files (old CLIHandler, its test, and the library-side @main App definition) and removed the `exclude: ["App/mkdnApp.swift"]` entry from the mkdnLib target in Package.swift since the excluded file no longer exists
    - **Deviations**: None
    - **Tests**: 96/96 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | N/A |

### User Docs

- [ ] **TD1**: Update architecture.md - System Overview, Data Flow `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: System Overview, Data Flow

    **KB Source**: architecture.md:System Overview

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] System Overview section reflects the new pre-launch validation step in the CLI flow
    - [ ] Data Flow section includes the parse -> validate -> LaunchContext -> App pipeline
    - [ ] Old CLIHandler references are replaced with MkdnCLI + FileValidator

- [ ] **TD2**: Update modules.md - Core / CLI section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Core / CLI section

    **KB Source**: modules.md:CLI

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] CLI section lists all four new files: MkdnCLI.swift, CLIError.swift, FileValidator.swift, LaunchContext.swift
    - [ ] CLIHandler.swift entry is removed
    - [ ] Purpose descriptions accurately reflect each component's role

- [ ] **TD3**: Update index.md - Quick Reference `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/index.md`

    **Section**: Quick Reference

    **KB Source**: index.md:Quick Reference

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Entry point description updated to reflect top-level code in `mkdnEntry/main.swift` (no longer @main in mkdnApp.swift)
    - [ ] CLI pipeline entry added or updated to reference `mkdn/Core/CLI/`

## Acceptance Criteria Checklist

### FR-1: Argument Parsing
- [ ] AC-1.1: `mkdn file.md` parses "file.md" as the file argument
- [ ] AC-1.2: `mkdn --help` prints usage information, exits with code 0
- [ ] AC-1.3: `mkdn --version` prints the version string, exits with code 0
- [ ] AC-1.4: `mkdn --unknown-flag` prints error to stderr, exits with non-zero code

### FR-2: Path Resolution
- [ ] AC-2.1: Relative path resolves against current working directory
- [ ] AC-2.2: Tilde path resolves to user's home directory
- [ ] AC-2.3: Absolute path is used as-is
- [ ] AC-2.4: Paths with `..` segments are resolved correctly

### FR-3: Extension Validation
- [ ] AC-3.1: `.md` extension is accepted
- [ ] AC-3.2: `.markdown` extension is accepted
- [ ] AC-3.3: Uppercase `.MD` extension is accepted (case-insensitive)
- [ ] AC-3.4: `.txt` extension prints error to stderr listing accepted extensions, exits with code 1
- [ ] AC-3.5: No extension prints error to stderr, exits with code 1

### FR-4: File Existence Validation
- [ ] AC-4.1: Missing file prints "not found" error to stderr with resolved path, exits with code 1
- [ ] AC-4.2: Error message shows fully resolved absolute path

### FR-5: File Readability Validation
- [ ] AC-5.1: No-read-permission file produces error to stderr, exits with code 2
- [ ] AC-5.2: Binary non-UTF-8 `.md` file produces error to stderr, exits with code 2

### FR-6: App Window Launch with File Content
- [ ] AC-6.1: Valid file opens window with rendered Markdown content
- [ ] AC-6.2: File content loaded into AppState (currentFileURL set, markdownContent populated)
- [ ] AC-6.3: Window title includes file name

### FR-7: No-Argument Launch
- [ ] AC-7.1: No arguments launches app with WelcomeView
- [ ] AC-7.2: No error message printed to stderr
- [ ] AC-7.3: Exit code is 0 when app closes

### FR-8: No GUI Window on CLI Error
- [ ] AC-8.1: Missing file exits without window appearing
- [ ] AC-8.2: Invalid extension exits without window appearing
- [ ] AC-8.3: Process terminates after error, does not hang

### FR-9: Exit Codes
- [ ] AC-9.1: Successful launch and close returns exit code 0
- [ ] AC-9.2: `--help` returns exit code 0
- [ ] AC-9.3: `--version` returns exit code 0
- [ ] AC-9.4: Missing file returns exit code 1
- [ ] AC-9.5: Invalid extension returns exit code 1
- [ ] AC-9.6: Unreadable file returns exit code 2

### FR-10: Error Message Quality
- [ ] AC-10.1: File-not-found error includes resolved absolute path
- [ ] AC-10.2: Invalid-extension error names the provided extension and lists accepted extensions
- [ ] AC-10.3: Unreadable-file error distinguishes permission errors from encoding errors
- [ ] AC-10.4: Error messages prefixed with program name (`mkdn: error: ...`)

## Definition of Done

- [ ] All tasks completed
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] `swift build` succeeds
- [ ] `swift test` passes (all existing + new tests)
- [ ] `swiftlint lint` passes
- [ ] `swiftformat .` applied
- [ ] Docs updated
