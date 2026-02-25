# Test Harness

## Overview

A two-process automation system that lets external clients drive a running mkdn instance through a Unix domain socket. The app launches with `--test-harness`, binds a socket at `/tmp/mkdn-test-harness-{pid}.sock`, and accepts newline-delimited JSON commands for file loading, theme switching, scrolling, window capture (CGWindowListCreateImage), frame sequence capture (ScreenCaptureKit SCStream), and window introspection. A parent PID watchdog ensures no orphaned processes survive if the caller dies. The primary client is `scripts/mkdn-ctl`, a Python CLI that wraps the socket protocol for interactive and scripted use.

## User Experience

Launch the app with the harness enabled, then drive it from any process that can connect to a Unix socket:

```bash
swift run mkdn --test-harness                   # launch
scripts/mkdn-ctl ping                           # verify connection
scripts/mkdn-ctl load fixtures/table-test.md    # load a file (waits for render)
scripts/mkdn-ctl theme solarizedDark            # switch theme (waits for render)
scripts/mkdn-ctl capture /tmp/shot.png          # screenshot the window
scripts/mkdn-ctl scroll 500                     # scroll to y=500pt
scripts/mkdn-ctl info                           # window geometry + theme + file
scripts/mkdn-ctl quit                           # terminate the app
```

In test harness mode the app launches as an accessory process (no Dock icon, no focus steal). Commands that mutate visual state (`loadFile`, `setTheme`, `cycleTheme`, `switchMode`) block until the SwiftUI render pass completes via `RenderCompletionSignal`, so a capture taken immediately after is deterministic.

## Architecture

**Server side** (`TestHarnessServer`): A singleton that binds an `AF_UNIX` stream socket on a background `DispatchQueue`. Each client connection is handled synchronously: read newline-delimited bytes, decode a `HarnessCommand`, dispatch to `TestHarnessHandler` on `@MainActor` via an `AsyncBridge` (semaphore-based sync/async bridge), encode the `HarnessResponse`, and write it back with a trailing newline. One connection per command; the client connects, sends, receives, and disconnects.

**Command dispatch** (`TestHarnessHandler`): A `@MainActor` enum that holds weak references to `AppSettings`, `DocumentState`, and `DirectoryState`. Switches on the `HarnessCommand` case and calls the appropriate AppKit/SwiftUI APIs directly. File and theme commands use the two-phase `RenderCompletionSignal` pattern: `prepareForRender()` before the state mutation, `awaitPreparedRender()` after, with a 10-second timeout that throws `HarnessError.renderTimeout`.

**Render signal** (`RenderCompletionSignal`): A `@MainActor` singleton with a latch mechanism that eliminates the race between signal emission and continuation installation. `SelectableTextView.Coordinator.updateNSView` calls `signalRenderComplete()` after applying text content. The two-phase API polls for 512ms (32 iterations at 16ms) before falling back to a `CheckedContinuation`, covering the window where SwiftUI processes view updates.

**Capture paths**: Static screenshots use `CGWindowListCreateImage` targeting the window by ID (no need to be frontmost, Retina resolution via `.bestResolution`). Frame sequences use `ScreenCaptureKit SCStream` with `SCContentFilter(desktopIndependentWindow:)` for hardware-accelerated capture at 30-60 fps; frames are written as numbered PNGs on a dedicated serial I/O queue with `DispatchGroup` synchronization. A lightweight "quick capture" alternative uses `CGWindowListCreateImage` on a `DispatchSourceTimer` for cases where ScreenCaptureKit permission is unavailable.

**Parent PID watchdog** (`TestHarnessMode.startWatchdog`): Polls `kill(parentPID, 0)` every 2 seconds on a utility-QoS queue. When the parent is gone, terminates the app via `NSApplication.shared.terminate(nil)`.

## Implementation Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| IPC mechanism | Unix domain socket, line-delimited JSON | Simple, debuggable, language-agnostic; any process that can write to a socket can drive the app |
| Sync bridge | `DispatchSemaphore` wrapping `@MainActor async` | Socket loop runs on a background queue; must block for the MainActor response before writing back |
| Render wait strategy | Latch + 512ms polling + continuation fallback | Eliminates signal race without architectural coupling to the SwiftUI render pipeline |
| Static capture API | `CGWindowListCreateImage` | Does not require Screen Recording permission for the app's own windows; works when the window is occluded |
| Frame capture API | ScreenCaptureKit `SCStream` | Hardware-accelerated, configurable FPS, per-window filter; required for animation verification |
| Quick capture fallback | `CGWindowListCreateImage` on a `DispatchSourceTimer` | Simpler permission model when SCStream is unavailable; sufficient for scroll animation capture |
| Socket path convention | `/tmp/mkdn-test-harness-{pid}.sock` | Predictable from the launched process's PID; no coordination file needed; unique per instance |
| Orphan prevention | Parent PID watchdog | Guarantees cleanup if the test runner crashes or is killed |
| Process presentation | Accessory app (no Dock icon) | Prevents focus theft and Dock clutter during automated runs |

## Files

**`mkdn/Core/TestHarness/`** (app-side, 8 files):
- `TestHarnessServer.swift` -- Socket lifecycle, client handling, JSON encode/decode, `AsyncBridge`.
- `TestHarnessHandler.swift` -- `@MainActor` command dispatch for all 20+ command cases. Weak refs to app state.
- `HarnessCommand.swift` -- `Codable` enum with cases for every command. `HarnessSocket` path helper. `CaptureRegion` value type.
- `HarnessResponse.swift` -- `Codable` response struct (`status`, `message`, `data`). `ResponseData` enum. Result types: `CaptureResult`, `FrameCaptureResult`, `WindowInfoResult`, `ThemeColorsResult`, `RGBColor`.
- `HarnessError.swift` -- `LocalizedError` enum: `renderTimeout`, `connectionFailed`, `unexpectedResponse`, `unknownCommand`, `captureFailed`, `fileLoadFailed`.
- `CaptureService.swift` -- `@MainActor` enum: full window capture, region capture, frame sequence capture (SCStream), PNG writing.
- `FrameCaptureSession.swift` -- `SCStreamOutput`/`SCStreamDelegate` implementation: async frame delivery, serial I/O queue, `DispatchGroup`-based write synchronization.
- `RenderCompletionSignal.swift` -- `@MainActor` singleton: two-phase latch API, legacy continuation API, `signalRenderComplete()` called from view coordinator.

**`scripts/mkdn-ctl`** (client-side, 1 file):
- Python 3 CLI. Discovers the most recent socket via glob. Maps subcommands to JSON payloads. Supports `MKDN_SOCK` env override for targeting a specific instance. 90 lines.

**`mkdnTests/Unit/Support/`** (tests, 2 files):
- `HarnessCommandTests.swift` -- JSON round-trip tests for every command case; single-line wire format verification.
- `HarnessResponseTests.swift` -- JSON round-trip tests for all response/data variants; `HarnessSocket` path tests; `HarnessError` description tests; value type equality tests.

## Dependencies

| Dependency | Type | Usage |
|------------|------|-------|
| `AppSettings`, `DocumentState`, `DirectoryState` | Existing app state | Handler reads/writes app state to execute commands |
| `SelectableTextView.Coordinator` | Existing view layer | Calls `signalRenderComplete()` after render |
| `CGWindowListCreateImage` | CoreGraphics API | Static window/region screenshots |
| ScreenCaptureKit (`SCStream`, `SCContentFilter`) | System framework | Frame sequence capture for animation verification |
| CoreImage (`CIContext`, `CIImage`) | System framework | Pixel buffer to CGImage conversion in frame capture |
| Python 3 (`socket`, `json`, `glob`) | Standard library | mkdn-ctl client implementation |

No external packages. The harness uses only system frameworks and POSIX socket APIs.

## Testing

**Unit tests** (2 files, ~40 tests): Verify JSON serialization fidelity for every `HarnessCommand` case and `HarnessResponse` variant. Confirm wire format is single-line (no embedded newlines). Test `HarnessSocket.path(forPID:)` determinism. Test `CaptureRegion` and `RGBColor` value semantics and equality. Test `HarnessError` descriptions contain expected detail strings.

**Integration testing** is performed via the mkdn-ctl visual testing workflow: launch with `--test-harness`, exercise commands (load, theme, scroll, capture, info, resize, quit), and inspect captured PNGs. This validates the full socket-to-render-to-capture pipeline without requiring XCUITest infrastructure.
