# Field Notes: CLI Launch

## Pre-existing Test Target Compile Failure

**Discovered**: 2026-02-06 (T1/T2/T3 implementation)

The `mkdnTests` target fails to compile due to errors in `mkdnTests/Unit/Core/ThemeOutputFormatTests.swift`:

- `Color.red`, `Color.blue`, `Color.green` are ambiguous between AppKit `NSColor` and SwiftUI `Color`
- `TokenType` members (`.keyword`, `.number`) cannot be inferred -- likely the `Splash` module's `TokenType` is not imported

This blocks `swift test` entirely since all test files compile together. `swift build` for `mkdnLib` and the `mkdn` executable target succeeds.

**Impact**: Tests for T6 (FileValidator/CLIError tests) will also be blocked by this pre-existing issue unless ThemeOutputFormatTests is fixed first.

**Update (T5)**: This issue appears to have been resolved. All 77 tests (including ThemeOutputFormat suite) compile and pass as of T5 implementation.

## Public Access Modifiers for CLI Types

**Discovered**: 2026-02-06 (T5 implementation)

T1-T4 created CLI types (MkdnCLI, CLIError, FileValidator, LaunchContext) with `internal` access (Swift default). This works for tests via `@testable import mkdnLib`, but the executable target uses a regular `import mkdnLib` and cannot access internal types. T5 required adding `public` to these types and their externally-used members. Also required adding an explicit `public init()` to MkdnCLI because `ParsableArguments` protocol mandates a public init when the conforming type is public.
