# Field Notes: Automated UI Testing -- End-to-End Validation

**Feature ID**: automated-ui-testing
**Created**: 2026-02-08

## T1: Build Verification and Prerequisite Check

### Environment

- macOS 15.5 (Build 24F74), Apple Silicon (arm64)
- Swift 6, SPM
- Retina display (2x assumed)

### Findings

1. **Build**: `swift build --product mkdn` succeeds in ~0.33s (incremental). SPM warns about 5 unhandled fixture `.md` files in `mkdnTests/Fixtures/UITest/` -- these are test data, not code resources. No action needed.

2. **Fixtures**: All 5 required fixtures present:
   - `canonical.md`
   - `geometry-calibration.md`
   - `long-document.md`
   - `mermaid-focus.md`
   - `theme-tokens.md`

3. **Screen Recording Permission**: Confirmed via ScreenCaptureKit API (returned 20 on-screen windows). Note: `CGWindowListCreateImage` is marked `obsoleted` in macOS 15 SDK headers. The project compiles it successfully because `CaptureService.captureWindowImage(_:)` uses `@available(macOS, deprecated: 14.0)` annotation. Standalone Swift scripts cannot call it without similar annotation. This is not a blocking issue for the test infrastructure since it compiles within the SPM project context.

4. **Test Harness**: `mkdn --test-harness` launches the app and binds the Unix domain socket at `/tmp/mkdn-test-harness-{pid}.sock` within ~1 second. Socket is a Unix domain socket (type `srwxr-xr-x`). Process terminates cleanly on SIGTERM.

### Observations for Downstream Tasks

- The `CGWindowListCreateImage` deprecation on macOS 15 is worth noting. If Apple removes the symbol entirely in a future SDK, `CaptureService` will need migration to ScreenCaptureKit for static captures too (currently only frame sequences use SCK). Not blocking for this iteration.
- Socket binding latency of ~1s is well within the 20-attempt, 250ms retry window used by `TestHarnessClient.connect()`.

## T2: Harness Smoke Test

### Results

All 6 lifecycle steps validated successfully:

| Step | Duration | Result |
|------|----------|--------|
| AppLauncher.launch() | 0.26s | PASS (< 60s limit) |
| TestHarnessClient.ping() | 0.001s | PASS (pong received) |
| TestHarnessClient.loadFile() | 0.027s | PASS (render completion signaled) |
| TestHarnessClient.captureWindow() | 0.14s | PASS (Retina 2x PNG) |
| ImageAnalyzer content validity | 0.016s | PASS (real pixel data) |
| TestHarnessClient.quit() | 2.0s (incl. teardown sleep) | PASS (clean shutdown) |

Total suite time: ~2.5s

### Infrastructure Fix: SIGPIPE on Socket Write After App Termination

**Symptom**: Test process killed by SIGPIPE (signal 13) during the quit test. All preceding 5 tests passed, but the process died before the quit test could report success.

**Root Cause**: After sending the `quit` command (which the app acknowledges with "ok" then terminates asynchronously after 50ms), `AppLauncher.teardown()` attempted to send a second quit command via the same socket. Since the app had already terminated and closed its end of the socket, `Darwin.write()` to the broken pipe delivered SIGPIPE to the test runner process.

**Resolution**: Two fixes applied:
1. `TestHarnessClient.trySocketConnect()` now sets `SO_NOSIGPIPE` on the socket via `setsockopt()`. This converts SIGPIPE delivery into an EPIPE error return from `write()`, which the existing error handling code catches gracefully. This is the systemic fix -- all future socket writes to dead peers will fail with an error instead of killing the process.
2. The smoke test's quit step disconnects the client before calling `teardown()`, preventing the double-quit attempt.

**Files Modified**: `mkdnTests/Support/TestHarnessClient.swift` (1 line: `setsockopt` call)

### Observations for Downstream Tasks

- The `SO_NOSIGPIPE` fix is critical for all compliance suites. Without it, any test that shuts down the app (or whose app crashes) would kill the entire test runner process instead of producing a clean error. This was a latent bug in the test harness client that could never have been caught by code review alone.
- Launch time is fast (~0.26s without build). The 20-attempt retry in `connect()` is well calibrated -- connection succeeds on the first or second attempt.
- Render completion signaling works correctly. `loadFile` returns after the view renders (0.027s), not prematurely.
- `CGWindowListCreateImage` produces correct Retina captures despite macOS 15 deprecation warnings.
