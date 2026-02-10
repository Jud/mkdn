# Root Cause Investigation Report - render-timeout-001

## Executive Summary
- **Problem**: `VisionCaptureTests` fails with "Render timeout after loading file" on the first `loadFile(geometry-calibration.md)` call, despite a prior 3-second warm-up sleep and the removal of the warm-up loadFile from commit `f542e0c`.
- **Root Cause**: A race condition in the `RenderCompletionSignal` -- the `setTheme("solarizedDark")` call that precedes `loadFile` consumes the render completion signal that was produced by the initial `.task(id:)` firing, leaving a stale `awaitRenderComplete` continuation in place. When `loadFile` then sets `markdownContent` to the file contents, SwiftUI's `.task(id: markdownContent)` fires asynchronously with a 150ms debounce, but `RenderCompletionSignal.awaitRenderComplete()` is already waiting inside `handleLoadFile`. The `updateNSView` call that would fire `signalRenderComplete()` depends on `textStorageResult` being updated by the async `.task(id:)`, which runs concurrently on MainActor but is not guaranteed to complete before the 10-second timeout -- specifically because the `setTheme` call's own `awaitRenderComplete` may have already consumed the one signal that the initial view creation produced, and the subsequent `loadFile` may or may not trigger a new `updateNSView` in time.
- **Solution**: Redesign the render completion signaling to be content-aware (e.g., correlate signal with the specific file path or content hash that was loaded) or use an idempotent polling approach instead of one-shot continuation.
- **Urgency**: High -- this blocks the entire LLM visual verification capture pipeline.

## Investigation Process
- **Hypotheses Tested**: 5 (see details below)
- **Key Evidence**: 3 critical findings from code analysis and commit history

### Hypothesis 1: @Observable suppresses notification on identical value (PARTIALLY CONFIRMED)
The commit message for `f542e0c` states: "@Observable skips notification on identical values, so RenderCompletionSignal never fired." This was the diagnosis for why the warm-up step (loading `geometry-calibration.md`) followed by the main loop loading the same file caused a timeout. The fix was to remove the warm-up entirely. However, this hypothesis only explains the warm-up scenario, not the current failure.

### Hypothesis 2: setTheme consumes a stale render signal (CONFIRMED - PRIMARY ROOT CAUSE)
**Evidence chain:**

1. The test sequence for the first fixture is:
   - `VisionCaptureHarness.ensureRunning()` -- launches the app
   - `Task.sleep(for: .seconds(3))` -- warm-up delay
   - First iteration: `setTheme("solarizedDark")` then `loadFile("geometry-calibration.md")`

2. When the app launches with `--test-harness`, it starts with:
   - `ContentView` showing `WelcomeView` (no file loaded, so `currentFileURL == nil`)
   - `MarkdownPreviewView` is NOT in the view hierarchy yet (it only appears when `documentState.currentFileURL != nil`)

3. `handleSetTheme("solarizedDark")` at `TestHarnessHandler.swift:114-134`:
   - Sets `settings.themeMode = .solarizedDark`
   - Calls `try? await RenderCompletionSignal.shared.awaitRenderComplete(timeout: .seconds(5))`
   - This installs a `CheckedContinuation` and waits up to 5 seconds
   - Since no `MarkdownPreviewView` is in the hierarchy (WelcomeView is showing), no `SelectableTextView` exists to call `signalRenderComplete()`
   - The continuation times out after 5 seconds, but the error is **swallowed** by `try?`
   - `setTheme` returns `"ok"` regardless

4. After `setTheme` completes (5+ seconds later), `loadFile("geometry-calibration.md")` is called:
   - `handleLoadFile` at `TestHarnessHandler.swift:48-62`:
     - Calls `docState.loadFile(at: url)` which sets `currentFileURL` and `markdownContent`
     - Immediately calls `try await RenderCompletionSignal.shared.awaitRenderComplete()`
     - This installs a **new** continuation

5. Setting `currentFileURL` causes `ContentView` to switch from `WelcomeView` to `MarkdownPreviewView`. This triggers:
   - `MarkdownPreviewView` appears in the hierarchy
   - `.task(id: documentState.markdownContent)` fires (initial render path, no debounce)
   - `SelectableTextView.makeNSView` is called, which calls `signalRenderComplete()` at line 59

6. **The critical race**: The `handleLoadFile` method does this:
   ```swift
   try docState.loadFile(at: url)     // sets markdownContent synchronously
   try await RenderCompletionSignal.shared.awaitRenderComplete()  // installs continuation
   ```
   Between these two lines, SwiftUI may have already started processing the state change. The `.task(id:)` fires asynchronously. `makeNSView`/`updateNSView` runs when SwiftUI decides to render. If `signalRenderComplete()` fires **before** `awaitRenderComplete()` installs its continuation, the signal is **dropped** (the `guard let cont = continuation else { return }` at line 56 of `RenderCompletionSignal.swift` silently discards it). Then `awaitRenderComplete` waits for a signal that already fired, and times out after 10 seconds.

### Hypothesis 3: The 3-second warm-up sleep is insufficient (DISPROVED)
The 3-second sleep at line 31 of `VisionCaptureTests.swift` is meant to let SwiftUI complete initial layout. However, this is not the issue because:
- The app starts showing `WelcomeView`, not `MarkdownPreviewView`
- No `SelectableTextView` exists until a file is loaded
- The sleep duration is irrelevant to the signal race

### Hypothesis 4: The `.task(id:)` debounce delay (150ms) causes the signal to fire too late (PARTIALLY RELEVANT)
The `.task(id: documentState.markdownContent)` in `MarkdownPreviewView.swift:44` has a 150ms debounce for non-initial renders:
```swift
if isInitialRender {
    isInitialRender = false
} else {
    try? await Task.sleep(for: .milliseconds(150))
}
```
For the first render (`isInitialRender == true`), there is no debounce. But since `MarkdownPreviewView` is being created fresh (switching from WelcomeView), `isInitialRender` starts as `true`, so no debounce. This is not the primary cause.

### Hypothesis 5: The `setTheme` 5-second timeout delays the overall flow (CONFIRMED - CONTRIBUTING FACTOR)
The `handleSetTheme` call at `TestHarnessHandler.swift:130` uses `try? await RenderCompletionSignal.shared.awaitRenderComplete(timeout: .seconds(5))`. When no `SelectableTextView` is in the hierarchy (WelcomeView is showing), this blocks for the full 5 seconds. Combined with the 3-second initial warm-up, the `loadFile` call doesn't happen until ~8 seconds after the app launches. This is a contributing factor to timing sensitivity but not the root cause of the timeout.

## Root Cause Analysis

### Technical Details

**File**: `/Users/jud/Projects/mkdn/mkdn/Core/TestHarness/RenderCompletionSignal.swift`
**Lines**: 33-48 (awaitRenderComplete) and 55-59 (signalRenderComplete)

The fundamental design flaw is a **fire-and-forget signal race**:

1. `signalRenderComplete()` silently drops signals when no continuation is waiting (line 56: `guard let cont = continuation else { return }`)
2. `awaitRenderComplete()` assumes the signal will arrive **after** the continuation is installed
3. `handleLoadFile()` calls `docState.loadFile()` (which mutates `@Observable` state) and then immediately calls `awaitRenderComplete()` -- but SwiftUI's render cycle may have already executed `makeNSView` and called `signalRenderComplete()` in between

**File**: `/Users/jud/Projects/mkdn/mkdn/Core/TestHarness/TestHarnessHandler.swift`
**Lines**: 48-62 (handleLoadFile)

The `handleLoadFile` has no mechanism to detect if the render already completed before `awaitRenderComplete` was called.

### Causation Chain

```
1. App launches -> WelcomeView (no SelectableTextView in hierarchy)
2. setTheme("solarizedDark") -> awaitRenderComplete(timeout: 5s)
3. No SelectableTextView exists -> timeout after 5s (error swallowed by try?)
4. loadFile("geometry-calibration.md") called
5. docState.loadFile() sets currentFileURL + markdownContent (synchronous)
6. SwiftUI schedules view update: WelcomeView -> MarkdownPreviewView
7. handleLoadFile calls awaitRenderComplete() -- installs continuation
   ** RACE WINDOW: steps 6 and 7 compete for MainActor **
   If SwiftUI already ran makeNSView before step 7:
     -> signalRenderComplete() fires with no continuation -> signal lost
     -> awaitRenderComplete waits 10s -> HarnessError.renderTimeout
     -> handleLoadFile returns .error("Render timeout after loading file")
```

### Why It Occurs

The `RenderCompletionSignal` uses a single-shot `CheckedContinuation` pattern that is fundamentally racy when the state mutation and the signal registration happen on the same actor (MainActor). Since `docState.loadFile()` and `awaitRenderComplete()` are both `@MainActor`, SwiftUI can interleave render cycles between them. The `withCheckedThrowingContinuation` call at line 34 of `RenderCompletionSignal.swift` is itself an async suspension point -- the continuation closure runs synchronously, but the `await` suspends, giving SwiftUI an opportunity to process the pending view update and call `signalRenderComplete()` before the continuation is stored.

## Proposed Solutions

### 1. Recommended: Pre-install continuation before state mutation

Move the `awaitRenderComplete` setup **before** the state mutation so the continuation is already installed when `signalRenderComplete()` fires:

```swift
// In handleLoadFile:
let signal = RenderCompletionSignal.shared
signal.prepareForRender()  // install continuation first
try docState.loadFile(at: url)
try await signal.awaitPreparedRender(timeout: .seconds(10))
```

This requires splitting `awaitRenderComplete` into a two-phase API: `prepareForRender()` (synchronous, installs the continuation immediately) and `awaitPreparedRender()` (async, waits for the signal).

**Effort**: Small (modify `RenderCompletionSignal` + all render-wait command handlers)
**Risk**: Low -- the MainActor isolation ensures no concurrent access
**Pros**: Eliminates the race entirely; minimal code change
**Cons**: Requires caller discipline (must always call prepare then await)

### 2. Alternative A: Polling-based render verification

Replace the signal mechanism with a polling approach that checks whether `SelectableTextView.updateNSView` has been called since the command was dispatched, using a monotonic render counter:

**Effort**: Medium
**Risk**: Low
**Pros**: No race conditions possible; naturally handles missed signals
**Cons**: Introduces polling overhead; less elegant than event-driven

### 3. Alternative B: AsyncStream-based signal buffering

Replace `CheckedContinuation` with an `AsyncStream` that buffers signals. `awaitRenderComplete` would consume the next element from the stream, and `signalRenderComplete` would yield to the stream. Buffered elements would handle the case where the signal fires before the consumer is waiting.

**Effort**: Medium
**Risk**: Low-Medium (need to handle buffer overflow / stale signals)
**Pros**: Naturally handles the ordering race
**Cons**: May consume stale signals from unrelated renders

### 4. Alternative C: Fix the setTheme timeout for WelcomeView scenario

Short-term: detect when no `SelectableTextView` is in the hierarchy and skip `awaitRenderComplete` in `handleSetTheme`. This does not fix the fundamental `handleLoadFile` race but avoids the 5-second delay and may change the timing enough to work in practice.

**Effort**: Small
**Risk**: High -- relies on timing luck, not correctness
**Pros**: Quick fix
**Cons**: Does not fix the root cause; will regress under different timing

## Prevention Measures

1. **Signal mechanisms should buffer**: Any async completion signal that can fire before the consumer is listening should buffer at least one signal to prevent lost wakeups. This is a classic producer-consumer race.

2. **State mutation + signal registration should be atomic**: When a state change is expected to trigger a signal, the signal listener must be installed before the state change occurs, not after.

3. **Avoid `try?` on render-wait calls**: The `handleSetTheme` swallowing the timeout error (`try?`) masked the fact that no render signal was arriving. If this had been a hard error, the issue would have been caught earlier.

## Evidence Appendix

### A. RenderCompletionSignal race window

From `/Users/jud/Projects/mkdn/mkdn/Core/TestHarness/RenderCompletionSignal.swift`:
```swift
// Line 34-48: awaitRenderComplete installs continuation INSIDE withCheckedThrowingContinuation
public func awaitRenderComplete(timeout: Duration = .seconds(10)) async throws {
    try await withCheckedThrowingContinuation { cont in
        self.continuation = cont  // installed here
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: timeout)
            // timeout handler...
        }
    }
}

// Line 55-59: signalRenderComplete drops signal if no continuation
public func signalRenderComplete() {
    guard let cont = continuation else { return }  // DROPS if continuation not yet installed
    continuation = nil
    cont.resume()
}
```

### B. handleLoadFile state mutation before signal registration

From `/Users/jud/Projects/mkdn/mkdn/Core/TestHarness/TestHarnessHandler.swift`:
```swift
// Line 48-62: loadFile mutates state, then awaits render
private static func handleLoadFile(_ path: String) async -> HarnessResponse {
    guard let docState = documentState else { return .error("No document state available") }
    let url = URL(fileURLWithPath: path)
    do {
        try docState.loadFile(at: url)                                    // STATE CHANGE
        try await RenderCompletionSignal.shared.awaitRenderComplete()     // SIGNAL WAIT (too late?)
        return .ok(message: "Loaded: \(path)")
    } catch is HarnessError {
        return .error("Render timeout after loading file")
    }
}
```

### C. SelectableTextView.makeNSView fires signalRenderComplete

From `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`:
```swift
// Line 30-62: makeNSView calls signalRenderComplete at end
func makeNSView(context: Context) -> NSScrollView {
    // ... setup ...
    textView.textStorage?.setAttributedString(attributedText)
    // ... overlays ...
    RenderCompletionSignal.shared.signalRenderComplete()  // Line 59
    return scrollView
}
```

### D. ContentView conditional rendering

From `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:
```swift
// Line 20-31: MarkdownPreviewView only appears when file is loaded
if documentState.currentFileURL == nil {
    WelcomeView()
} else {
    switch documentState.viewMode {
    case .previewOnly:
        MarkdownPreviewView()  // only in hierarchy when file is loaded
    }
}
```

### E. Commit history showing three failed fix attempts

```
f542e0c TX-fix-warmup-removal - remove warm-up causing render timeout
f6ed800 TX-fix-fixture-order  - reorder fixtures for warm-up
9c84635 TX-fix-loadfile-error - improve error reporting and add warm-up
```

Each fix addressed a symptom without resolving the fundamental signal race.

### F. MarkdownPreviewView .task(id:) flow

From `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`:
```swift
// Line 44: task fires when markdownContent changes
.task(id: documentState.markdownContent) {
    if isInitialRender {
        isInitialRender = false  // no debounce for first render
    } else {
        try? await Task.sleep(for: .milliseconds(150))  // 150ms debounce
    }
    // ... render blocks, update textStorageResult ...
}
```

The `.task(id:)` is asynchronous -- SwiftUI schedules it, and it may complete and trigger `SelectableTextView.updateNSView` (which calls `signalRenderComplete`) before or after `handleLoadFile` installs its continuation.
