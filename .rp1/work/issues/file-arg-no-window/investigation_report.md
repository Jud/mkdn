# Root Cause Investigation Report - file-arg-no-window

## Executive Summary
- **Problem**: When launching `mkdn` with a file argument (`swift run mkdn README.md`), no window is created. Without a file argument, the window appears normally.
- **Root Cause**: `NSApplication` automatically interprets positional command-line arguments (those not prefixed with `--` or `-`) as files to open, converting them to `kAEOpenDocuments` AppleEvents. This suppresses SwiftUI's default `WindowGroup` window creation because the system expects the file-open event handler to manage window creation instead. Since `ProcessInfo.processInfo.arguments` is cached at process startup before any user code runs, the existing `CommandLine.arguments` stripping approach has no effect.
- **Solution**: Re-execute the process via `execv()` without the file argument, passing the file path through an environment variable. This gives the re-launched process a clean `argv` that NSApplication does not misinterpret.
- **Urgency**: Critical. The app is completely non-functional for CLI file-opening workflows.

## Investigation Process
- **Duration**: Single session
- **Hypotheses Tested**:
  1. **`LaunchContext.fileURL` assignment causes `@Observable` side effect** -- REJECTED. Commenting out `LaunchContext.fileURL = url` still produced 0 windows. `LaunchContext` is a plain static var, not `@Observable`. (Note: previous investigation v3 identified a different `@Observable` side effect in `MkdnApp.init()` that WAS present and WAS fixed in commit 1200c4d, but the bug persists.)
  2. **`MkdnCLI.parse()` or `FileValidator.validate()` has a side effect** -- REJECTED. Commenting out the entire file handling block (lines 31-34) still produced 0 windows.
  3. **`CommandLine.arguments` stripping is failing** -- PARTIALLY CONFIRMED. Stripping works at the `CommandLine` level but does NOT affect `ProcessInfo.processInfo.arguments`, which is what NSApplication/SwiftUI reads.
  4. **`WindowGroup(for: URL.self)` specifically prevents default window creation** -- REJECTED. Replacing with a plain `WindowGroup { ... }` still produced 0 windows.
  5. **`.handlesExternalEvents(matching: [])` blocks window creation** -- REJECTED. Removing it still produced 0 windows.
  6. **NSApplication interprets positional argv as file-open events** -- CONFIRMED. See root cause analysis.
- **Key Evidence**:
  1. Passing ANY positional argument (`README.md`, `hello`, `nonexistent.md`, `Package.swift`) causes 0 windows
  2. Passing flag-style arguments (`--file README.md`, `--some-random-flag`) causes 1 window
  3. Removing ALL user code and just calling `MkdnApp.main()` still produces 0 windows when a positional arg is present
  4. `applicationWillFinishLaunching` logs show `ProcessInfo.arguments` always contains the original argv regardless of `CommandLine.arguments` stripping
  5. `execv()` re-execution with clean argv produces 1 window with successful file loading

## Root Cause Analysis

### Technical Details

**The issue is in how macOS `NSApplication` processes command-line arguments during `finishLaunching()`.**

When an NSApplication (including SwiftUI apps) starts, `NSApplication.finishLaunching()` examines `ProcessInfo.processInfo.arguments` for positional arguments that look like file paths. For each such argument, it creates an `kAEOpenDocuments` AppleEvent and delivers it to the application. Critically, when a file-open event is pending during launch, NSApplication (and SwiftUI's scene management built on top of it) **skips the default window creation** because it expects the file-open handler to create the appropriate window.

**File**: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`

The previous fix (commit e0e2aca) attempted to solve this by stripping `CommandLine.arguments`:

```swift
CommandLine.arguments = [CommandLine.arguments[0]]
```

This does not work because:

1. `ProcessInfo.processInfo.arguments` is a **read-only** computed property that reads from the C `argv` cached at process initialization time (before any user Swift code runs).
2. Setting `CommandLine.arguments` modifies a separate Swift-level copy but does NOT affect `ProcessInfo.processInfo.arguments`.
3. `NSApplication` reads from `ProcessInfo.processInfo.arguments`, not from `CommandLine.arguments`.

Even nulling `CommandLine.unsafeArgv[1]` (the C pointer) and setting `CommandLine.argc = 1` has no effect because `ProcessInfo` has already captured and cached the arguments.

### Causation Chain

```
Process launched: mkdn README.md
  --> C argv = [".../mkdn", "README.md"]
  --> Swift runtime initializes ProcessInfo with C argv (cached immediately)
  --> main.swift top-level code runs
  --> CommandLine.arguments = [CommandLine.arguments[0]] -- INEFFECTIVE
      (ProcessInfo.processInfo.arguments still = [".../mkdn", "README.md"])
  --> MkdnApp.main() called
  --> SwiftUI creates NSApplication (or uses existing one)
  --> NSApplication.finishLaunching() runs
  --> NSApplication reads ProcessInfo.processInfo.arguments
  --> Finds positional arg "README.md" (not prefixed with -)
  --> Converts it to kAEOpenDocuments AppleEvent
  --> SwiftUI scene system sees pending file-open event
  --> SwiftUI SKIPS default WindowGroup window creation
      (expects file-open handler to create windows)
  --> application(_:open:) is NOT called (SwiftUI intercepts the event)
  --> No window is created by anyone
  --> Result: app runs with dock icon but zero windows
```

### Why It Works Without Arguments

When no positional arguments are present, NSApplication finds nothing to convert to file-open events. With no pending events, SwiftUI creates the default `WindowGroup` window with `fileURL = nil`. The `DocumentWindow.task` fires, finds no `LaunchContext.fileURL`, and shows the welcome screen.

### Why Flag Arguments Work

Arguments prefixed with `-` or `--` (like `--file README.md`) are ignored by NSApplication's file-open detection because they follow the POSIX convention for option flags. Only "bare" positional arguments are interpreted as file paths.

### Why Previous Fixes Failed

1. **Commit 1200c4d** (Remove `@Observable` side effect from `MkdnApp.init()`): This fixed a real but separate bug. The `init()` was mutating `FileOpenCoordinator.shared.pendingURLs`, which is `@Observable`. This DID interfere with window creation. But fixing it revealed the UNDERLYING issue: NSApplication's argv interpretation, which was always present but masked by the `@Observable` bug.

2. **Commit e0e2aca** (Strip `CommandLine.arguments`): Correct diagnosis (file argument causes the problem) but ineffective solution (`CommandLine.arguments` stripping doesn't affect `ProcessInfo.processInfo.arguments`).

3. **Commit 4ff743a** (Three-layer window activation): Correct solution for a third, separate problem (activation timing), but completely irrelevant when no window exists to activate.

## Proposed Solutions

### 1. Recommended: `execv()` re-execution (Medium effort, proven effective)

When a positional file argument is detected, save the file path to an environment variable and `execv()` the process without the argument. The re-launched process has a clean `argv` that NSApplication does not misinterpret.

```swift
// main.swift
let args = ProcessInfo.processInfo.arguments

// Check for re-launched process (env var set by previous exec)
if let envFile = ProcessInfo.processInfo.environment["MKDN_LAUNCH_FILE"] {
    unsetenv("MKDN_LAUNCH_FILE")
    let url = URL(fileURLWithPath: envFile)
    LaunchContext.fileURL = url.standardized.resolvingSymlinksInPath()
    NSApplication.shared.setActivationPolicy(.regular)
    MkdnApp.main()
} else {
    // Parse CLI normally
    let cli = try MkdnCLI.parse()

    if let filePath = cli.file {
        let url = try FileValidator.validate(path: filePath)
        // Re-exec without the file argument
        setenv("MKDN_LAUNCH_FILE", url.path, 1)
        let execPath = args[0]
        let cPath = strdup(execPath)
        let argv: [UnsafeMutablePointer<CChar>?] = [cPath, nil]
        argv.withUnsafeBufferPointer { buf in
            execv(execPath, buf.baseAddress)
        }
        // execv only returns on failure
        perror("execv")
        exit(1)
    }

    CommandLine.arguments = [CommandLine.arguments[0]]
    NSApplication.shared.setActivationPolicy(.regular)
    MkdnApp.main()
}
```

**Effort**: ~30 minutes (including edge cases: error handling, cwd preservation)
**Risk**: Low. `execv()` replaces the process in-place (same PID). Validated experimentally: window count = 1, file loaded successfully with content length = 9613, 82 markdown blocks rendered.
**Pros**: Definitively solves the problem. No timing dependencies. Clean architecture.
**Cons**: Slightly unusual pattern (`execv` in a GUI app). Adds ~10ms startup latency for file-open launches. Must preserve cwd for relative paths.

### 2. Alternative A: Use flag-style argument (`--file`) instead of positional (Low effort)

Change `MkdnCLI` to use `@Option` instead of `@Argument`:

```swift
public struct MkdnCLI: ParsableCommand {
    @Option(name: .shortAndLong, help: "Path to a Markdown file")
    public var file: String?
}
```

Usage: `mkdn --file README.md` or `mkdn -f README.md`

**Effort**: ~10 minutes
**Risk**: Low.
**Pros**: Simplest fix. Flag-style args are not interpreted by NSApplication.
**Cons**: Changes the CLI API from `mkdn file.md` to `mkdn --file file.md`. Less ergonomic for users expecting standard Unix behavior.

### 3. Alternative B: Use `NSApplication` subclass to intercept argument processing (Medium effort)

Create a custom `NSApplication` subclass that overrides the open-file argument processing. Register it before SwiftUI takes over.

**Effort**: ~45 minutes
**Risk**: Medium. Requires understanding NSApplication internals. May break across macOS versions.
**Pros**: No `execv`, no CLI API change.
**Cons**: Fragile. Relies on undocumented NSApplication behavior.

### 4. Alternative C: Use environment variable from the start (Low effort, changes CLI pattern)

Instead of a positional arg, the launcher always passes the file via env var:

```bash
# Shell wrapper or alias
MKDN_FILE=README.md mkdn
```

**Effort**: ~15 minutes
**Risk**: Low.
**Pros**: Simple, no re-exec needed.
**Cons**: Non-standard CLI usage. Requires wrapper script for ergonomic use.

### 5. Alternative D: Use `open` command for file-arg launches (Workaround)

For bundled `.app` distributions, use the `open` command which routes through Launch Services:

```bash
open -a mkdn README.md
```

**Effort**: ~0 minutes (documentation only)
**Risk**: N/A
**Pros**: Works with existing code (Launch Services handles file-open events differently than raw argv).
**Cons**: Only works with `.app` bundles, not `swift run` or bare binary. Not a code fix.

## Prevention Measures

1. **Never pass file paths as positional CLI arguments to SwiftUI apps.** NSApplication interprets positional arguments as files to open. Use flag-style arguments (`--file`, `-f`) or environment variables for file paths in SwiftUI apps.

2. **Test CLI file opening with bare binary, not just `open` command.** The `open` command uses Launch Services which handles file-open events differently. Always test with `.build/debug/mkdn file.md` to catch argv-related issues.

3. **Document the NSApplication argv behavior.** Add a code comment in `main.swift` explaining why `execv` re-execution is needed, referencing this investigation report.

4. **Add integration test.** Create a test that runs `.build/debug/mkdn README.md`, waits 3 seconds, checks window count via AppleScript, and asserts window count >= 1.

## Evidence Appendix

### Evidence 1: ANY positional argument causes 0 windows

```
.build/debug/mkdn README.md     -> 0 windows
.build/debug/mkdn nonexistent.md -> 0 windows
.build/debug/mkdn Package.swift  -> 0 windows
.build/debug/mkdn hello          -> 0 windows
.build/debug/mkdn                -> 1 window
.build/debug/mkdn --some-flag    -> 1 window
.build/debug/mkdn --file README  -> 1 window
```

### Evidence 2: Completely stripped main.swift still fails

With main.swift reduced to:
```swift
NSApplication.shared.setActivationPolicy(.regular)
MkdnApp.main()
```
Result: `mkdn README.md` -> 0 windows, `mkdn` -> 1 window.

### Evidence 3: ProcessInfo.arguments is immutable

After setting `CommandLine.arguments = [CommandLine.arguments[0]]`, nulling `CommandLine.unsafeArgv[1]`, and setting `CommandLine.argc = 1`:
```
ProcessInfo.processInfo.arguments = [".../mkdn", "README.md"]
```
The original argv is cached before user code runs.

### Evidence 4: NSApplication generates openFiles event

With `applicationWillFinishLaunching` logging enabled and `application(_:openFiles:)` implemented:
```
[applicationWillFinishLaunching] ProcessInfo.arguments=[".../mkdn", "README.md"]
[application(_:openFiles:)] filenames=["README.md"]
[applicationDidFinishLaunching]
Window count: 0
```

NSApplication converts the positional "README.md" to an openFiles delegate call between willFinish and didFinish. No window is created.

### Evidence 5: execv re-execution produces working window

With `execv()` re-execution (passing file via env var):
```
[applicationWillFinishLaunching] ProcessInfo.arguments=[".../mkdn"]
[DOC-WIN] body evaluated, fileURL=nil
[applicationDidFinishLaunching]
[DOC-WIN] .task fired, fileURL=nil
[DOC-WIN] loading from LaunchContext: file:///Users/jud/Projects/mkdn/README.md
[DOC-WIN] after load: currentFileURL=Optional(file:///.../README.md), content length=9613
Window count: 1
```

Clean argv -> no file-open event -> default window created -> LaunchContext consumed -> file loaded successfully.

### Evidence 6: WindowGroup(for: URL.self) is NOT the specific cause

Replacing `WindowGroup(for: URL.self)` with plain `WindowGroup { ... }` still produces 0 windows with a positional argument. The issue is at the NSApplication/argv level, not the WindowGroup type.

### Evidence 7: .handlesExternalEvents(matching: []) is NOT the cause

Removing `.handlesExternalEvents(matching: [])` still produces 0 windows with a positional argument.

### Evidence 8: NSApplication.shared pre-initialization affects delegate wiring

Calling `NSApplication.shared.setActivationPolicy(.regular)` before `MkdnApp.main()` prevents the AppDelegate from receiving `applicationWillFinishLaunching` and `applicationDidFinishLaunching` calls. Without the pre-init, these delegate methods are called normally. This is relevant for the fix design but is NOT the root cause of the 0-windows issue.
