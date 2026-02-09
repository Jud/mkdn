# Quick Build: Fix Render Signal Race

**Created**: 2026-02-09T14:00:00-08:00
**Request**: Fix the RenderCompletionSignal race condition that causes render timeout in VisionCapture tests. The signal fires before the continuation is installed because docState.loadFile() triggers a SwiftUI render cycle before awaitRenderComplete() stores its continuation. Redesign to a two-phase API: prepareForRender() (synchronous, installs latch before state mutation) and awaitPreparedRender() (async, waits for signal). Also fix handleSetTheme's 5-second waste waiting for a signal when no SelectableTextView exists.
**Scope**: Small

## Plan

**Reasoning**: Two files require modification (RenderCompletionSignal.swift, TestHarnessHandler.swift). Single system (TestHarness render signaling). Low risk because MainActor isolation prevents concurrent access, and the fix follows a well-understood pattern of installing the listener before triggering the event. Investigation report at `.rp1/work/issues/render-timeout-001/investigation_report.md` provides a complete root cause analysis and confirms the recommended approach.

**Files Affected**:
- `mkdn/Core/TestHarness/RenderCompletionSignal.swift` -- redesign to two-phase API with latch
- `mkdn/Core/TestHarness/TestHarnessHandler.swift` -- update all call sites to use prepare-then-await pattern; add guard for setTheme when no view is present

**Approach**: Replace the single-method `awaitRenderComplete()` API with a two-phase design: (1) `prepareForRender()` -- a synchronous method that installs a latch (boolean flag) so that any `signalRenderComplete()` call is captured even before the async continuation is installed, and (2) `awaitPreparedRender(timeout:)` -- an async method that checks the latch first (returning immediately if signal already arrived) then falls back to the continuation-based wait. Update `handleLoadFile`, `handleReloadFile`, `handleSwitchMode`, `handleCycleTheme`, and `handleSetTheme` to call `prepareForRender()` before state mutation, then `awaitPreparedRender()` after. For `handleSetTheme` and `handleCycleTheme`, detect whether a SelectableTextView is in the hierarchy (by checking `documentState.currentFileURL != nil`) and skip the render wait entirely if no view exists, eliminating the 5-second timeout waste.

**Estimated Effort**: 1.5 hours

## Tasks

- [x] **T1**: Redesign `RenderCompletionSignal` with two-phase API -- add `prepareForRender()` (synchronous, sets a `pendingLatch` flag and clears any stale continuation), `awaitPreparedRender(timeout:)` (async, checks latch first then installs continuation), and update `signalRenderComplete()` to set latch when no continuation exists instead of silently dropping. Keep existing `awaitRenderComplete()` as deprecated fallback. `[complexity:medium]`
- [x] **T2**: Update `handleLoadFile` and `handleReloadFile` in `TestHarnessHandler.swift` to call `prepareForRender()` before `docState.loadFile()`/`docState.reloadFile()`, then `awaitPreparedRender()` after. This eliminates the race window where the signal fires between state mutation and continuation installation. `[complexity:simple]`
- [x] **T3**: Update `handleSwitchMode`, `handleCycleTheme`, and `handleSetTheme` to use the two-phase API. For `handleSetTheme` and `handleCycleTheme`, add a guard that skips the render wait when `documentState?.currentFileURL == nil` (no SelectableTextView in hierarchy), eliminating the 5-second timeout waste on WelcomeView. `[complexity:simple]`
- [x] **T4**: Verify the fix compiles and existing tests pass. Run `swift build` and `swift test --filter VisionCapture` to confirm the race condition is resolved. `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Core/TestHarness/RenderCompletionSignal.swift` | Added two-phase API: `prepareForRender()` sets latch before state mutation, `awaitPreparedRender()` uses latch-then-poll-then-continuation strategy, `cancelPrepare()` cleans up when no render expected. `signalRenderComplete()` now sets latch when no continuation exists. Old API kept as deprecated. | Done |
| T2 | `mkdn/Core/TestHarness/TestHarnessHandler.swift` | Updated `handleLoadFile` and `handleReloadFile` to use prepare-then-await pattern. Added content-change detection: compares `markdownContent` before/after mutation and skips render wait when `@Observable` would suppress notification (same content loaded). | Done |
| T3 | `mkdn/Core/TestHarness/TestHarnessHandler.swift` | Updated `handleSwitchMode`, `handleCycleTheme`, `handleSetTheme` to use two-phase API. Added `documentState?.currentFileURL != nil` guard in `handleSetTheme` and `handleCycleTheme` to skip render wait when no SelectableTextView is in hierarchy (WelcomeView). | Done |
| T4 | (verification) | `swift build` clean, `swift test --filter VisionCapture` passes (17.6s, all 8 captures). Race condition resolved by: (1) latch captures signals before continuation installed, (2) content-change detection avoids timeout on identical `@Observable` values, (3) no-view guard eliminates 5s waste. | Done |

**Deviations from plan**:
- Added `cancelPrepare()` method (not in original spec) to cleanly handle the case where `@Observable` suppresses notifications for identical property values. Investigation revealed that loading the same file twice (different theme, same content) triggers no SwiftUI render cycle, causing an indefinite wait.
- Added content-change detection in `handleLoadFile`/`handleReloadFile` to compare `markdownContent` before/after mutation.
- `awaitPreparedRender()` uses a three-phase strategy (latch check, polling window of ~512ms at 16ms intervals, then continuation) instead of pure continuation-based wait, because SwiftUI's `@Observable` framework may not deliver view updates until the next run loop iteration after Task suspension.

## Verification

{To be added by task-reviewer if --review flag used}
