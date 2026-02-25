# CLI Integration

## Overview

CLI Integration is the complete terminal-to-window pipeline that makes mkdn usable as a daily-driver Markdown viewer. It covers argument parsing via swift-argument-parser, file and directory validation, an `execv` re-launch pattern to work around NSApplication's argv handling, and Homebrew Cask distribution backed by a release script with Developer ID signing and notarization.

## User Experience

A developer runs `mkdn file.md` from their terminal. The file is validated (extension, existence, readability) and the rendered preview window appears. Multiple files and directories are accepted: `mkdn README.md docs/`. Standard flags work as expected -- `--help` prints usage, `--version` prints the semver string. Invalid input produces structured error messages on stderr with Unix exit codes (0 success, 1 user error, 2 system error) and no GUI window. Running `mkdn` with no arguments launches the app with its default welcome state. Installation is `brew tap jud/mkdn && brew install --cask mkdn`, which places `mkdn.app` in /Applications and symlinks the binary onto PATH.

## Architecture

The CLI layer lives in `mkdn/Core/CLI/` inside the `mkdnLib` target. The entry point at `mkdnEntry/main.swift` is top-level orchestration code -- `MkdnApp` is defined there without `@main` so argument parsing and validation execute before the SwiftUI lifecycle starts.

The pipeline has three phases:

1. **Parse** -- `MkdnCLI.parse()` extracts the optional `[String]` positional arguments and handles `--help`/`--version` via ArgumentParser's built-in exit mechanism.
2. **Validate** -- Each argument is routed through `FileValidator.validate(path:)` or `DirectoryValidator.validate(path:)` depending on whether the resolved path is a directory. Validation order is extension, existence, readability -- cheapest check first. Path resolution handles tilde expansion, relative paths, `..` segments, and symlinks via Foundation's `NSString.expandingTildeInPath` and `URL.resolvingSymlinksInPath()`.
3. **Re-launch** -- Validated URLs are serialized into `MKDN_LAUNCH_FILE` / `MKDN_LAUNCH_DIR` environment variables, then the process calls `execv` to re-execute itself without positional arguments. This is necessary because NSApplication interprets positional argv entries as `kAEOpenDocuments` AppleEvents, which suppresses default WindowGroup window creation. The second invocation reads the env vars into `LaunchContext` static properties and calls `MkdnApp.main()`.

## Implementation Decisions

**execv re-launch over argv stripping.** `ProcessInfo.processInfo.arguments` is cached from C `argv` before Swift code runs, so stripping `CommandLine.arguments` has no effect on NSApplication's AppleEvent processing. The `execv` pattern is the only reliable way to pass validated paths without NSApplication interference.

**LaunchContext as a static enum.** The set-once/read-once pattern between `main.swift` and `MkdnApp.init` has no concurrency concern -- the value is written before `MkdnApp.main()` and consumed once via `consumeURLs()` / `consumeDirectoryURLs()`. The `nonisolated(unsafe)` annotation satisfies Swift 6 strict concurrency.

**CLIError with exit code mapping.** A `LocalizedError` enum maps each failure mode to a Unix exit code and a structured error message prefixed with `mkdn: error:`. This keeps error formatting out of `main.swift` and makes exit codes testable.

**Homebrew Cask with `binary` stanza.** The Cask installs `mkdn.app` to /Applications and uses the `binary` stanza to symlink `mkdn.app/Contents/MacOS/mkdn` into Homebrew's bin directory. A `postflight` block strips quarantine attributes since the app is distributed outside the Mac App Store.

**Release pipeline: build, sign, notarize, publish, update tap.** `scripts/release.sh` reads the version from the current git tag, injects it into `MkdnCLI.swift` via `sed`, builds with `swift build -c release --arch arm64`, assembles the `.app` bundle (binary + SPM resource bundle + Info.plist + app icon), signs with Developer ID, submits for notarization via `notarytool`, staples the ticket, archives with `ditto`, publishes a GitHub Release with the `.zip` attached, then clones the `homebrew-mkdn` tap repo to update the Cask version and SHA256. A trap handler reverts the version injection on any failure.

## Files

| File | Role |
|------|------|
| `mkdnEntry/main.swift` | Top-level entry point: parse, validate, execv re-launch, MkdnApp.main() |
| `mkdn/Core/CLI/MkdnCLI.swift` | `ParsableCommand` struct with `[String]` files argument |
| `mkdn/Core/CLI/FileValidator.swift` | Path resolution + extension/existence/readability validation |
| `mkdn/Core/CLI/DirectoryValidator.swift` | Directory existence + readability validation (delegates path resolution to FileValidator) |
| `mkdn/Core/CLI/CLIError.swift` | Typed error enum with exit code mapping and structured messages |
| `mkdn/Core/CLI/LaunchContext.swift` | Static URL store bridging CLI parsing to SwiftUI app init |
| `Casks/mkdn.rb` | Homebrew Cask definition (version, sha256, app + binary stanzas) |
| `scripts/release.sh` | Full release pipeline: build, sign, notarize, archive, publish, update tap |

## Dependencies

| Dependency | Type | Purpose |
|------------|------|---------|
| swift-argument-parser | SPM (external) | Structured argument parsing, --help/--version generation |
| Foundation (NSString, URL, FileManager) | System framework | Path resolution, file validation |
| `gh` CLI | External tool | GitHub Release creation, asset upload |
| `codesign` / `notarytool` / `stapler` | Xcode toolchain | Developer ID signing and notarization |
| `ditto` | System tool | Archive creation preserving macOS extended attributes |
| Homebrew | External tool | Distribution channel via personal tap `jud/homebrew-mkdn` |

## Testing

Unit tests in `mkdnTests/Unit/Core/` cover each CLI component with Swift Testing (`@Suite`, `@Test`, `#expect`):

- **FileValidatorTests** -- path resolution (absolute, relative, tilde, `..` segments, symlinks), extension acceptance/rejection, existence checks, readability checks including invalid UTF-8, full pipeline validation order (extension checked before existence).
- **DirectoryValidatorTests** -- existing directory validation, tilde resolution, trailing slash handling, rejection of nonexistent paths and file paths, error message content.
- **CLIErrorTests** -- exit code mapping for each error case, error message content (extension names, resolved paths, reason strings), empty extension handling.
- **LaunchContextTests** -- empty initial state, consume-and-clear semantics for `consumeURLs()`, single and multi-URL round trips.

The release pipeline and Homebrew install cycle are verified manually via `scripts/smoke-test.sh` (tap, install, `which mkdn`, `mkdn --help`, `open -a mkdn`, uninstall).
