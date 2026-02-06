# Requirements Specification: CLI Launch

**Feature ID**: cli-launch
**Parent PRD**: [CLI Launch](../../prds/cli-launch.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-06

## 1. Feature Overview

CLI Launch enables developers to open Markdown files directly from the terminal by running `mkdn file.md`. It covers the full terminal-to-window lifecycle: parsing the command-line argument, resolving and validating the file path, launching the app window with the file content loaded, and providing clear error feedback when something goes wrong. When no file argument is given, the app launches normally with a welcome screen. This feature is the primary entry point for the target user's daily workflow.

## 2. Business Context

### 2.1 Problem Statement

Developers working with LLMs and coding agents produce Markdown artifacts constantly -- documentation, specs, reports, notes. These developers work primarily from the terminal. They need a way to quickly view a Markdown file without leaving their terminal workflow. The current CLIHandler provides basic argument extraction but lacks proper argument parsing (no --help, no --version), does not report errors to the user (silently ignores invalid files), and does not prevent a GUI window from appearing when a CLI error occurs.

### 2.2 Business Value

CLI Launch is the front door to the entire mkdn experience. If launching from the terminal feels broken, slow, or confusing, the developer will not adopt mkdn as their daily-driver Markdown viewer. A polished CLI launch flow -- with proper help text, meaningful error messages, and zero wasted windows -- makes mkdn feel like a tool built by and for terminal-native developers.

### 2.3 Success Metrics

- **SM-1**: Developer can run `mkdn file.md` and see the rendered file in under 1 second (perceived wall-clock time from Enter key to visible content).
- **SM-2**: Running `mkdn nonexistent.md` prints a clear error to stderr and exits without showing any GUI window.
- **SM-3**: Running `mkdn --help` prints usage information and exits cleanly.
- **SM-4**: Running `mkdn --version` prints the version string and exits cleanly.
- **SM-5**: Running `mkdn` with no arguments launches the app with the WelcomeView.

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Terminal Developer | Primary user. Works from the terminal, runs CLI commands, produces Markdown via coding agents and LLMs. | Direct user of the CLI launch flow. Expects Unix-standard behavior (stderr for errors, exit codes, --help/--version). |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project Creator | CLI launch must feel seamless and native to a terminal workflow. This is the primary entry point and first impression of the app. |

## 4. Scope Definition

### 4.1 In Scope

- Single file argument: `mkdn file.md` (relative or absolute path)
- Tilde expansion: `mkdn ~/docs/file.md`
- Extension validation: only `.md` and `.markdown` files accepted
- File existence validation before loading
- Error output to stderr for: missing file, invalid extension, unreadable file, no argument provided (when combined with invalid flags)
- Integration with AppState to populate the window with file content
- No-argument launch: display WelcomeView
- `--version` flag: print version and exit
- `--help` flag: print usage and exit
- Proper Unix exit codes (0 success, 1 user error, 2 system error)
- No GUI window on CLI errors

### 4.2 Out of Scope

- Homebrew installation and distribution (separate PRD: homebrew-distribution)
- Multiple file arguments or glob patterns (e.g., `mkdn *.md`)
- stdin piping (e.g., `cat file.md | mkdn`)
- Watch mode or auto-reload via CLI flag
- File browser or file picker UI
- Open Recent menu integration

### 4.3 Assumptions

- A1: The developer launches mkdn from a terminal emulator where the current working directory is meaningful for resolving relative paths.
- A2: The file system is a local APFS/HFS+ volume (no network file systems or FUSE mounts need special handling).
- A3: The target file is UTF-8 encoded (consistent with AppState.loadFile which reads as UTF-8).
- A4: A single positional argument is sufficient for the target workflow of viewing one file at a time.

## 5. Functional Requirements

### FR-1: Argument Parsing (Must Have)

- **Actor**: Terminal Developer
- **Requirement**: When the developer runs `mkdn` from the terminal, the app parses command-line arguments using a structured argument parser. The file path is a single optional positional argument. The `--help` and `--version` flags are recognized.
- **Rationale**: Structured argument parsing provides automatic help text generation, consistent flag handling, and validation -- standard expectations for any CLI tool.
- **Acceptance Criteria**:
  - AC-1.1: `mkdn file.md` parses "file.md" as the file argument.
  - AC-1.2: `mkdn --help` prints usage information describing the file argument and available flags, then exits with code 0.
  - AC-1.3: `mkdn --version` prints the application version string, then exits with code 0.
  - AC-1.4: `mkdn --unknown-flag` prints an error message to stderr describing the unrecognized flag, then exits with a non-zero code.

### FR-2: Path Resolution (Must Have)

- **Actor**: Terminal Developer
- **Requirement**: When a file path argument is provided, the app resolves it to an absolute file URL. Tilde (`~`) is expanded to the user's home directory. Relative paths are resolved against the current working directory.
- **Rationale**: Developers use relative paths, tilde shortcuts, and absolute paths interchangeably in terminal workflows. The app must handle all three forms.
- **Acceptance Criteria**:
  - AC-2.1: `mkdn readme.md` (relative path) resolves against the current working directory.
  - AC-2.2: `mkdn ~/docs/notes.md` (tilde path) resolves the tilde to the user's home directory.
  - AC-2.3: `mkdn /absolute/path/to/file.md` (absolute path) is used as-is.
  - AC-2.4: Paths with `..` segments (e.g., `mkdn ../other/file.md`) are resolved correctly.

### FR-3: Extension Validation (Must Have)

- **Actor**: Terminal Developer
- **Requirement**: The app accepts only files with `.md` or `.markdown` extensions (case-insensitive). Files with other extensions are rejected with a descriptive error message.
- **Rationale**: mkdn is a Markdown-specific tool. Accepting arbitrary file types would lead to confusing rendering results. Clear rejection helps the developer understand what went wrong.
- **Acceptance Criteria**:
  - AC-3.1: `mkdn file.md` is accepted.
  - AC-3.2: `mkdn file.markdown` is accepted.
  - AC-3.3: `mkdn FILE.MD` (uppercase extension) is accepted.
  - AC-3.4: `mkdn file.txt` prints an error to stderr indicating the extension is not supported, listing accepted extensions, and exits with code 1.
  - AC-3.5: `mkdn file` (no extension) prints an error to stderr and exits with code 1.

### FR-4: File Existence Validation (Must Have)

- **Actor**: Terminal Developer
- **Requirement**: Before loading, the app verifies the resolved file exists on disk. If the file does not exist, a descriptive error message is printed to stderr including the resolved path.
- **Rationale**: A clear "file not found" error with the resolved path helps the developer diagnose typos or incorrect paths immediately.
- **Acceptance Criteria**:
  - AC-4.1: `mkdn nonexistent.md` prints an error to stderr that includes the text "not found" or "does not exist" and the resolved file path, then exits with code 1.
  - AC-4.2: The error message shows the fully resolved absolute path, so the developer can see exactly which path was checked.

### FR-5: File Readability Validation (Should Have)

- **Actor**: Terminal Developer
- **Requirement**: After confirming the file exists, the app verifies it can be read. If the file cannot be read (e.g., permission denied, not valid UTF-8), a descriptive error message is printed to stderr.
- **Rationale**: A file that exists but cannot be read is a distinct error condition. Reporting it specifically (rather than showing a blank window) helps the developer diagnose the problem.
- **Acceptance Criteria**:
  - AC-5.1: A file with no read permissions produces an error message to stderr mentioning the file cannot be read, then exits with code 2 (system error).
  - AC-5.2: A binary file with a `.md` extension that is not valid UTF-8 produces an error message to stderr, then exits with code 2.

### FR-6: App Window Launch with File Content (Must Have)

- **Actor**: Terminal Developer
- **Requirement**: When a valid Markdown file is provided, the app loads the file content into AppState and displays the rendered preview window. The window title reflects the file name.
- **Rationale**: This is the core happy path -- the developer runs `mkdn file.md` and sees their rendered Markdown.
- **Acceptance Criteria**:
  - AC-6.1: `mkdn valid-file.md` opens a window displaying the rendered Markdown content.
  - AC-6.2: The file's content is loaded into AppState (currentFileURL is set, markdownContent is populated).
  - AC-6.3: The window title includes the file name.

### FR-7: No-Argument Launch (Must Have)

- **Actor**: Terminal Developer
- **Requirement**: When the developer runs `mkdn` with no arguments, the app launches and displays the WelcomeView. No error is printed.
- **Rationale**: The app should be launchable without arguments for cases where the developer wants to use the app's UI to navigate to a file later, or simply to have it open.
- **Acceptance Criteria**:
  - AC-7.1: `mkdn` (no arguments) launches the app with the WelcomeView visible.
  - AC-7.2: No error message is printed to stderr.
  - AC-7.3: Exit code is 0 when the app eventually closes.

### FR-8: No GUI Window on CLI Error (Must Have)

- **Actor**: Terminal Developer
- **Requirement**: When a CLI error occurs (invalid extension, missing file, unreadable file), the app prints the error to stderr and exits without creating or showing any GUI window.
- **Rationale**: Showing a blank or broken window on error is jarring in a terminal workflow. The developer expects CLI errors to behave like any other CLI tool: message to stderr, non-zero exit, no side effects.
- **Acceptance Criteria**:
  - AC-8.1: `mkdn nonexistent.md` exits without any window appearing on screen.
  - AC-8.2: `mkdn file.txt` exits without any window appearing on screen.
  - AC-8.3: The process terminates after printing the error; it does not hang.

### FR-9: Exit Codes (Must Have)

- **Actor**: Terminal Developer
- **Requirement**: The app uses standard Unix exit code conventions: 0 for success (including --help and --version), 1 for user errors (bad arguments, missing file, invalid extension), 2 for system errors (unreadable file, unexpected failures).
- **Rationale**: Proper exit codes allow the developer to use mkdn in shell scripts and pipelines (e.g., `mkdn file.md && echo "opened"`).
- **Acceptance Criteria**:
  - AC-9.1: Successful file launch and normal app close returns exit code 0.
  - AC-9.2: `--help` returns exit code 0.
  - AC-9.3: `--version` returns exit code 0.
  - AC-9.4: Missing file returns exit code 1.
  - AC-9.5: Invalid extension returns exit code 1.
  - AC-9.6: Unreadable file returns exit code 2.

### FR-10: Error Message Quality (Should Have)

- **Actor**: Terminal Developer
- **Requirement**: Error messages are concise, specific, and actionable. Each error message identifies what went wrong and, where possible, suggests what to do.
- **Rationale**: Good error messages reduce friction. A developer should never have to guess why mkdn refused to open a file.
- **Acceptance Criteria**:
  - AC-10.1: File-not-found error includes the resolved absolute path.
  - AC-10.2: Invalid-extension error names the provided extension and lists the accepted extensions (`.md`, `.markdown`).
  - AC-10.3: Unreadable-file error distinguishes between permission errors and encoding errors where possible.
  - AC-10.4: Error messages are prefixed with the program name (e.g., `mkdn: error: ...`).

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

- **NFR-1**: CLI argument parsing adds negligible overhead to app startup (less than 10ms).
- **NFR-2**: The complete lifecycle from `mkdn file.md` to visible rendered content should feel instantaneous (target under 1 second perceived latency on a modern Mac).

### 6.2 Security Requirements

- **NFR-3**: The app only reads files explicitly provided by the user via the command-line argument. No implicit file access beyond the specified path.
- **NFR-4**: File paths are resolved and validated; no path traversal vulnerabilities that could cause unintended file access.

### 6.3 Usability Requirements

- **NFR-5**: `--help` output is clear and follows standard CLI conventions (usage line, argument descriptions, flag descriptions).
- **NFR-6**: Error messages are written to stderr (not stdout) so they do not interfere with output redirection.

### 6.4 Compliance Requirements

- **NFR-7**: Exit codes follow Unix conventions (0 = success, non-zero = error) for compatibility with shell scripting.

## 7. User Stories

### STORY-1: Open a Markdown File from the Terminal

**As a** Terminal Developer,
**I want** to run `mkdn file.md` from my terminal,
**So that** I can quickly preview a Markdown file without leaving my terminal workflow.

**Acceptance**:
- GIVEN a valid Markdown file exists at the specified path
- WHEN the developer runs `mkdn file.md`
- THEN the app opens a window displaying the rendered Markdown content

### STORY-2: Get Help on CLI Usage

**As a** Terminal Developer,
**I want** to run `mkdn --help` to see usage information,
**So that** I can learn the available arguments and flags without reading external documentation.

**Acceptance**:
- GIVEN the developer is unfamiliar with mkdn's CLI interface
- WHEN the developer runs `mkdn --help`
- THEN usage information is printed to stdout and the process exits with code 0

### STORY-3: Check the App Version

**As a** Terminal Developer,
**I want** to run `mkdn --version` to see the current version,
**So that** I can verify which version is installed (e.g., for bug reports or update checks).

**Acceptance**:
- GIVEN mkdn is installed
- WHEN the developer runs `mkdn --version`
- THEN the version string is printed and the process exits with code 0

### STORY-4: Handle a Missing File Gracefully

**As a** Terminal Developer,
**I want** to see a clear error message when I mistype a file path,
**So that** I can quickly correct my mistake without confusion.

**Acceptance**:
- GIVEN the specified file does not exist on disk
- WHEN the developer runs `mkdn typo.md`
- THEN an error message is printed to stderr identifying the file as not found, including the resolved path
- AND the process exits with code 1
- AND no GUI window appears

### STORY-5: Handle an Invalid File Type Gracefully

**As a** Terminal Developer,
**I want** to see a clear error message when I accidentally pass a non-Markdown file,
**So that** I understand why mkdn did not open it.

**Acceptance**:
- GIVEN the specified file has a non-Markdown extension
- WHEN the developer runs `mkdn notes.txt`
- THEN an error message is printed to stderr identifying the unsupported extension and listing accepted extensions
- AND the process exits with code 1
- AND no GUI window appears

### STORY-6: Launch Without Arguments

**As a** Terminal Developer,
**I want** to run `mkdn` with no arguments and see a welcome screen,
**So that** I can launch the app even when I do not have a specific file in mind.

**Acceptance**:
- GIVEN no file argument is provided
- WHEN the developer runs `mkdn`
- THEN the app launches and displays the WelcomeView
- AND no error message is printed

### STORY-7: Open a File Using a Relative Path

**As a** Terminal Developer,
**I want** to run `mkdn docs/readme.md` using a relative path from my current directory,
**So that** I do not have to type the full absolute path.

**Acceptance**:
- GIVEN a valid Markdown file exists at `./docs/readme.md` relative to the current working directory
- WHEN the developer runs `mkdn docs/readme.md`
- THEN the relative path is resolved against the current working directory
- AND the app opens the correct file

### STORY-8: Open a File Using Tilde Expansion

**As a** Terminal Developer,
**I want** to run `mkdn ~/notes/todo.md` using a tilde-prefixed path,
**So that** I can reference files in my home directory without typing the full path.

**Acceptance**:
- GIVEN a valid Markdown file exists at `~/notes/todo.md`
- WHEN the developer runs `mkdn ~/notes/todo.md`
- THEN the tilde is expanded to the user's home directory
- AND the app opens the correct file

## 8. Business Rules

- **BR-1**: Only files with `.md` or `.markdown` extensions (case-insensitive) are considered valid Markdown files. All other extensions are rejected.
- **BR-2**: File validation order is: (1) extension check, (2) existence check, (3) readability check. The first failing check produces the error. This ensures the most specific error message is shown.
- **BR-3**: When both `--help`/`--version` flags and a file argument are present, the flag takes precedence (standard ArgumentParser behavior).
- **BR-4**: The app opens at most one file per launch. Multiple file arguments are not supported.

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Type | Description |
|------------|------|-------------|
| AppState.loadFile(at:) | Internal | Loads file content into the app's central state. Must be called on the main actor. |
| WelcomeView | Internal | Displayed when no file argument is provided. Must already exist and be functional. |
| swift-argument-parser | External (SPM) | Provides structured CLI argument parsing, --help generation, and --version support. |

### Constraints

| Constraint | Description |
|------------|-------------|
| macOS 14.0+ | Minimum deployment target. |
| Swift 6 strict concurrency | All code must comply with Swift 6 concurrency rules. |
| Two-target layout | CLI parsing logic lives in `mkdnLib`. The executable target `mkdn` contains only the entry point. |
| SwiftUI @main lifecycle | Argument parsing must integrate with the SwiftUI app lifecycle without causing the window to appear before validation completes. |
| No WKWebView | All rendering is native SwiftUI. This constraint does not directly affect CLI launch but is a project-wide invariant. |

## 10. Clarifications Log

| # | Question | Resolution | Source |
|---|----------|------------|--------|
| 1 | Should symlinks be resolved before validation? | Conservative default: validate the symlink target (resolve symlinks before checking existence and extension). This matches standard Unix behavior where tools operate on the target of a symlink. | PRD open question, inferred from Unix conventions |
| 2 | What version string format should --version use? | Follow semantic versioning (e.g., "mkdn 1.0.0"). Exact version source to be determined during implementation. | Inferred from standard CLI conventions |
| 3 | Should the app handle files passed without an extension but with Markdown content? | No. Extension validation is a hard requirement per the PRD. Files without `.md` or `.markdown` extensions are rejected regardless of content. | PRD FR-3 |
| 4 | What happens if the file argument contains spaces? | The shell handles quoting. The app receives the already-parsed argument from CommandLine.arguments. No special handling needed. | Standard Unix/shell behavior |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | cli-launch.md | Exact filename match with feature ID "cli-launch". |
| Validation order | Extension before existence | Checking extension first avoids a filesystem call for files that would be rejected anyway. PRD lists both but does not specify order. Conservative choice prioritizes the cheapest check first. |
| Symlink handling | Resolve symlinks before validation | PRD listed this as an open question. Standard Unix tools follow symlinks by default. Conservative default aligns with user expectations. |
| Case sensitivity of extensions | Case-insensitive | PRD does not explicitly state case sensitivity. Accepting `.MD`, `.Md`, etc. is more user-friendly and conservative. |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| REQUIREMENTS input was empty | Derived all requirements from the PRD (cli-launch.md), charter, concept map (Quick View workflow), and existing source code (CLIHandler.swift, AppState.swift). | PRD + KB |
| "Meaningful feedback" for errors (PRD FR-9) not precisely defined | Specified that errors must include program name prefix, resolved path, and actionable guidance (e.g., listing accepted extensions). Modeled after standard Unix CLI error conventions. | Inferred from Unix conventions + charter target audience |
| No explicit performance target in PRD beyond "negligible overhead" | Set concrete target of <1 second perceived latency for the full open-to-render lifecycle, and <10ms for argument parsing overhead specifically. | Inferred from charter ("open, render beautifully, edit, close" workflow implies speed) |
| PRD does not specify whether --help output goes to stdout or stderr | Specified stdout for --help and --version (standard convention), stderr for errors. | Standard Unix CLI conventions |
| Current CLIHandler silently ignores invalid files | New requirements mandate explicit error messages for every failure mode. This is a behavioral change from the existing implementation. | PRD requirements override existing behavior |
