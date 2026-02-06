# PRD: CLI Launch

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-06

## Surface Overview

The CLI Launch surface covers the full terminal-to-window lifecycle for mkdn. When a developer runs `mkdn file.md` from their terminal, this surface is responsible for:

1. **Argument parsing** -- extracting the file path from command-line arguments (powered by swift-argument-parser), resolving relative and absolute paths, expanding tilde (`~`)
2. **File validation** -- confirming the target file exists on disk and has a valid Markdown extension (`.md`, `.markdown`)
3. **App window launch** -- handing the validated file URL to `AppState.loadFile(at:)` and ensuring the SwiftUI window renders with the file content loaded
4. **Error handling** -- surfacing meaningful feedback when argument parsing fails, the file does not exist, or the file cannot be read

Homebrew distribution is explicitly **out of scope** for this PRD and will be addressed as a separate surface.

## Scope

### In Scope
- Single file argument: `mkdn file.md` (relative or absolute path)
- Tilde expansion (`~/docs/file.md`)
- Extension validation (`.md`, `.markdown`)
- File existence check before loading
- Error output to stderr for: missing file, invalid extension, unreadable file, no argument provided
- Integration with `AppState.loadFile(at:)` to populate the window
- Graceful launch to WelcomeView when no file argument is given
- `--version` flag (prints version and exits)
- `--help` flag (prints usage and exits)

### Out of Scope
- Homebrew installation / distribution (separate PRD)
- Multiple file arguments / glob patterns
- stdin piping (`cat file.md | mkdn`)
- Watch mode / auto-reload from CLI flag

## Requirements

### Functional Requirements

1. **Argument parsing via swift-argument-parser** -- Replace the current manual argument loop in CLIHandler with a proper `ParsableCommand`. The file path is a single optional positional argument.
2. **Path resolution** -- Resolve the file argument to an absolute URL: expand tilde (`~`), resolve relative paths against the current working directory.
3. **Extension validation** -- Accept only `.md` and `.markdown` extensions. Reject other extensions with a descriptive stderr message and non-zero exit code.
4. **File existence check** -- Verify the file exists on disk before loading. Print a descriptive error to stderr and exit non-zero if missing.
5. **AppState integration** -- On successful validation, call `AppState.loadFile(at:)` to populate the window with file content.
6. **No-argument launch** -- When no file argument is given, launch the app normally and display WelcomeView.
7. **--version flag** -- Print the app version string and exit with code 0.
8. **--help flag** -- Print usage information (provided by ArgumentParser) and exit with code 0.
9. **Error output** -- All error messages go to stderr. Errors include: file not found, invalid extension, unreadable file, and ArgumentParser validation failures.

### Non-Functional Requirements

1. **Startup speed** -- The app should launch and display the file as fast as possible. CLI argument parsing should add negligible overhead.
2. **Exit codes** -- Standard Unix conventions: 0 for success, 1 for user errors (bad args, missing file), 2 for system errors.
3. **No GUI on error** -- When a CLI error occurs (invalid file, missing file), print to stderr and exit without showing a window.

## Dependencies & Constraints

### External Dependencies (SPM)
- **swift-argument-parser** -- CLI argument parsing framework

### Internal Dependencies
- **AppState** -- `loadFile(at:)` for loading file content into the app
- **CLIHandler** -- existing handler to be refactored to use ArgumentParser
- **WelcomeView** -- fallback view for no-argument launch

### Constraints
- macOS 14.0+ / Swift 6 strict concurrency
- Two-target layout: CLI parsing in `mkdnLib`, entry point in `mkdn` executable
- `@main` SwiftUI App pattern -- argument parsing must integrate with SwiftUI lifecycle (parse before app init, or in `init()`)

## Milestones

### Phase 1: ArgumentParser Integration
- Refactor CLIHandler to use `ParsableCommand`
- Implement `--version` and `--help` flags
- Wire up the optional positional file argument

### Phase 2: Path Resolution + Validation
- Tilde expansion (`~`)
- Relative path resolution against CWD
- Extension validation (`.md`, `.markdown`)
- File existence checks
- Stderr error messages with proper exit codes (1 for user errors, 2 for system errors)

### Phase 3: SwiftUI Lifecycle Integration
- Wire parsed file URL into `AppState.loadFile(at:)` during app init
- Ensure no-argument launch falls through to WelcomeView
- Ensure CLI errors exit before showing a window (no GUI on error)

## Open Questions

- Best pattern for integrating ArgumentParser with `@main` SwiftUI App: parse in a static initializer, in `init()`, or intercept before `App.main()`?
- Should symlinks be resolved before validation, or should the target of the symlink be validated?

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A1 | swift-argument-parser integrates cleanly with SwiftUI `@main` pattern | May need custom entry point that parses args then conditionally launches the app | Will Do: CLI-launchable |
| A2 | CLI errors can exit the process before SwiftUI creates a window | SwiftUI may create a window before `init()` completes; may need `NSApplication` interception | Will Do: CLI-launchable |
| A3 | Single positional argument is sufficient for the target workflow | Users may want glob patterns or multiple files in the future | Won't Do: Multiple files |

## Discoveries

- **Codebase Discovery**: `Color.red`/`Color.blue`/`Color.green` are ambiguous between AppKit `NSColor` and SwiftUI `Color` in test targets; `Splash` module's `TokenType` must be explicitly imported for `.keyword`/`.number` member inference in `ThemeOutputFormatTests.swift`. — *Ref: [field-notes.md](archives/features/cli-launch/field-notes.md)*
- **Codebase Discovery**: Types in `mkdnLib` accessed by the `mkdn` executable target via `import mkdnLib` (not `@testable import`) require explicit `public` access modifiers; `ParsableArguments` conformance additionally requires an explicit `public init()` when the conforming type is public. — *Ref: [field-notes.md](archives/features/cli-launch/field-notes.md)*
