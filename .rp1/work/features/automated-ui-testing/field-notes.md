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
