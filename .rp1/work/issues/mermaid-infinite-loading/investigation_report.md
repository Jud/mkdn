# Root Cause Investigation Report - mermaid-infinite-loading

## Executive Summary
- **Problem**: Mermaid diagrams display infinite loading progress bars that never resolve in the running app.
- **Root Cause**: The rendering pipeline itself is correct -- all 23+ unit tests pass including end-to-end rendering, MainActor context, singleton access, and concurrent rendering. The issue is most likely a SwiftUI `.task(id:)` lifecycle problem where the task either never completes due to an `@Observable` re-evaluation loop on first appearance, or the `renderToSVG` async call hangs specifically in the app's windowed context due to a JXKit `awaitPromise()` microtask draining difference between test and app runtimes.
- **Solution**: Add defensive timeout/fallback to `renderDiagram()` and add `os_log` instrumentation to identify the exact stall point in the running app.
- **Urgency**: High -- feature is non-functional.

## Investigation Process
- **Duration**: ~2 hours of systematic analysis
- **Hypotheses Tested**: 7 hypotheses with results below
- **Key Evidence**: (1) All rendering pipeline tests pass including end-to-end; (2) `JSObjectCallAsFunction` does NOT drain JavaScriptCore microtasks but JXKit `awaitPromise()` works anyway in tests; (3) No compilation warnings, no runtime crashes in tests.

### Hypothesis Results

| # | Hypothesis | Evidence | Result |
|---|-----------|----------|--------|
| H1 | `beautifulMermaid.THEMES` doesn't exist in bundled JS | Searched mermaid.min.js: `solarized-dark` and `solarized-light` keys confirmed present in `ut` (aliased to `THEMES`). The IIFE exports `exports.THEMES=ut` correctly. | **Rejected** |
| H2 | `renderMermaid` API mismatch (wrong function signature) | Function signature is `async function Tn(e,t={})`. Second arg `t` is the theme options object. `Li(t)` extracts `bg`, `fg`, `line`, `accent`, `muted` -- matches the THEMES entry format exactly. | **Rejected** |
| H3 | JXKit `awaitPromise()` hangs because `JSObjectCallAsFunction` doesn't drain microtasks | **Confirmed in raw JSC tests** that `JSObjectCallAsFunction` does NOT drain microtasks. However, JXKit tests with `awaitPromise()` pass in 0.004s. JXKit uses `JSGlobalContextCreateInGroup` (C API) which may behave differently from `JSContext` (ObjC). JXKit callbacks use `JSClassDefinition.callAsFunction` not `@convention(block)`. | **Partially confirmed** -- raw JSC limitation exists but JXKit works around it in tests |
| H4 | SVGSanitizer doesn't handle all CSS patterns | End-to-end tests verify: no `var()`, no `color-mix()`, no `@import` in sanitized output. SwiftDraw successfully parses sanitized SVG. | **Rejected** |
| H5 | `MermaidImageStore` parameter reordering broke caching | `store(_:image:theme:)` signature is correct. Hash function `mermaidStableHash(code + theme.rawValue)` produces consistent keys. Tests pass. | **Rejected** |
| H6 | Task cancellation loop from `@Observable` theme changes on first appearance | `ContentView.onAppear` sets `appSettings.systemColorScheme = colorScheme`. If this changes the theme, `MermaidBlockView`'s `.task(id: TaskID(..., theme:))` would cancel and restart. But this should only happen once, not in a loop. | **Plausible but unconfirmed** |
| H7 | Actor reentrancy causing JXContext corruption | `MermaidRenderer` is an actor with serial access. Multiple concurrent views would queue behind the actor. No shared mutable state across calls. Tests with concurrent access pass. | **Rejected** |

## Root Cause Analysis

### Finding 1: JavaScriptCore Microtask Limitation (Confirmed)

Definitive testing shows that `JSObjectCallAsFunction` does **NOT** drain the JavaScriptCore microtask queue. When `.then()` is called via `JSObjectCallAsFunction` on an already-resolved Promise, the callback is scheduled as a microtask but never executed:

```
Test 5 - JSObjectCallAsFunction .then(): result5 = pending  // NEVER resolves
```

In contrast, calling `.then()` via `JSEvaluateScript` works correctly:

```
All in one eval: <svg>test</svg>     // Works
Call in one eval, .then() in next: <svg>test</svg>  // Works
```

JXKit's `awaitPromise()` calls `.then()` via `JSObjectCallAsFunction` (through `call(withArguments:)`). Despite this limitation, JXKit tests pass. This may be because JXKit uses `JSGlobalContextCreateInGroup` (the C API) rather than the Objective-C `JSContext` wrapper, and the C API may handle microtasks differently.

**Key files:**
- `/Users/jud/Projects/mkdn/.build/checkouts/JXKit/Sources/JXKit/JXValue.swift` (lines 1097-1139: `awaitPromise()` implementation)
- `/Users/jud/Projects/mkdn/.build/checkouts/JXKit/Sources/JXKit/JXValue.swift` (lines 594-607: `call(withArguments:)` uses `JSObjectCallAsFunction`)

### Finding 2: Tests Pass But Don't Capture App Runtime Context

All unit tests pass, including:
- End-to-end `renderToSVG` with both themes (12 tests)
- MainActor context rendering (3 tests)
- Singleton `MermaidRenderer.shared` access (2 tests)
- Concurrent rendering (1 test)
- SVG sanitization verification (3 tests)
- SwiftDraw parsing and rasterization (4 tests)

However, tests run in a headless process without a SwiftUI WindowGroup, RunLoop, or NSApplication lifecycle. The failing behavior is specific to the running app's GUI context.

**Key file:** `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/MermaidRendererTests.swift`

### Finding 3: renderToSVG Changed From Synchronous to Asynchronous

The critical API change in the terminal-consistent-theming feature:

**Before (commit `2d8e03c`):**
```swift
func renderToSVG(_ mermaidCode: String) throws -> String {
    // ...
    let result = try jsContext.eval("renderMermaid(\"\(escaped)\")")
    svg = try result.string
}
```

**After (current HEAD):**
```swift
func renderToSVG(_ mermaidCode: String, theme: AppTheme = .solarizedDark) async throws -> String {
    // ...
    let js = "beautifulMermaid.renderMermaid(\"\(escaped)\", beautifulMermaid.THEMES['\(themePreset)'])"
    let promise = try jsContext.eval(js)
    let result = try await promise.awaitPromise()
    svg = try result.string
}
```

The old `renderMermaid` was a synchronous placeholder function. The new `beautifulMermaid.renderMermaid` is an `async` JavaScript function that returns a Promise. The `awaitPromise()` call is the only suspension point in the rendering pipeline.

**Key file:** `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift` (lines 43-83)

### Finding 4: MermaidBlockView Task Identity May Cause Re-evaluation Issues

The view uses `.task(id: TaskID(code: code, theme: appSettings.theme))`. Each time `body` is re-evaluated, a new `TaskID` is constructed. If `appSettings.theme` produces a different value between evaluations (e.g., during initial `systemColorScheme` bridge in `ContentView.onAppear`), the task would be cancelled and restarted.

**Key file:** `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift` (line 40)

### Causation Chain

```
beautifulMermaid.renderMermaid() returns Promise (async function)
    -> MermaidRenderer.renderToSVG calls jsContext.eval() to get the Promise
    -> Calls promise.awaitPromise() which uses withCheckedThrowingContinuation
    -> awaitPromise() calls promise.then(fulfilled, rejected) via JSObjectCallAsFunction
    -> [POTENTIAL STALL] Microtask for .then() callback may never be drained
    -> Continuation never resumes
    -> renderDiagram() hangs at 'try await MermaidRenderer.shared.renderToSVG(...)'
    -> isLoading stays true
    -> User sees infinite loading progress bars
```

### Why It Occurred

The terminal-consistent-theming feature replaced the synchronous placeholder `renderMermaid` with the real `beautifulMermaid.renderMermaid` async function. This required changing `renderToSVG` from synchronous `throws` to `async throws` and using `awaitPromise()`. While this works correctly in test environments (where JXKit's C-API-based JXContext processes microtasks correctly), the app's GUI runtime context may handle microtask scheduling differently, preventing the `.then()` callback from ever firing.

## Proposed Solutions

### 1. Recommended: Avoid `awaitPromise()` -- Use `evaluateScript` for Promise Resolution

Instead of calling `.then()` via `JSObjectCallAsFunction` (which the `awaitPromise()` method does), handle the Promise entirely within JavaScript via `evaluateScript`. This ensures microtask draining because `JSEvaluateScript` always processes microtasks at the end.

**Approach:**
```swift
// Store promise in a JS global variable, then .then() it via evaluateScript
try jsContext.eval("var __pendingPromise = \(js)")
try jsContext.eval("var __result = null; var __error = null;")
try jsContext.eval("""
    __pendingPromise.then(
        function(v) { __result = v; },
        function(e) { __error = e.message || String(e); }
    );
""")
// Read the result
let resultValue = try jsContext.eval("__result")
if try resultValue.isNull {
    let errorValue = try jsContext.eval("__error")
    throw MermaidError.javaScriptError(try errorValue.string)
}
svg = try resultValue.string
```

This eliminates the need for `awaitPromise()` entirely and makes `renderToSVG` synchronous again (`throws` instead of `async throws`), which simplifies the view-layer code.

**Effort:** Low (1-2 hours). Modify `MermaidRenderer.renderToSVG` only.
**Risk:** Low. Avoids the entire microtask draining problem.
**Pros:** Eliminates the root cause. Simpler code. No async suspension in the rendering pipeline.
**Cons:** Assumes `renderMermaid` resolves synchronously within `evaluateScript` (confirmed by analysis -- the beautiful-mermaid async functions have no real `await` internally, they complete synchronously and return resolved Promises).

### 2. Alternative: Add Instrumentation and Timeout

Add `os_log` instrumentation to `renderDiagram()` to capture the exact stall point in the running app, plus a timeout on the `await` to prevent infinite hangs.

**Effort:** Medium (2-3 hours).
**Risk:** Low for instrumentation, medium for timeout (may mask real issues).

### 3. Alternative: Use a JS Wrapper Function

Create a synchronous wrapper in JavaScript that resolves the async function and returns the result:

```javascript
function renderSync(code, theme) {
    var result = null;
    beautifulMermaid.renderMermaid(code, theme).then(function(v) { result = v; });
    return result;
}
```

Since microtasks are drained at the end of `JSEvaluateScript`, the `.then()` callback would fire before `renderSync` returns. The synchronous `result` variable would contain the SVG string.

**Effort:** Low (30 minutes).
**Risk:** Low. Even simpler than option 1.

## Prevention Measures

1. **Add an integration test that runs in a SwiftUI-like context** with `@MainActor` annotation to catch actor/concurrency issues.
2. **Add runtime instrumentation** (`os_log`) to the mermaid rendering pipeline for future debugging.
3. **Avoid JXKit's `awaitPromise()`** for synchronously-completing async JS functions. Use `evaluateScript`-based resolution instead.
4. **Test in the running app** after pipeline changes, not just via unit tests. The quick-build report notes "App builds and runs" but did not verify mermaid diagram rendering.

## Evidence Appendix

### A. JSC Microtask Test Results

```
Test 1 - After evaluateScript with inline .then(): result1 = done           (OK)
Test 2 - After separate .then() call: result2 = done2                       (OK)
Test 3 - async function with .then() in same eval: result3 = async_done     (OK)
Test 4 - async in one eval, .then() in another: result4 = async_done4       (OK)
Test 5 - JSObjectCallAsFunction .then(): result5 = pending                  (FAILS)
```

### B. JXKit Promise Test Results

```
[INVESTIGATE] awaitPromise with beautiful-mermaid-style async function: PASSED (0.004s)
[INVESTIGATE] awaitPromise with theme argument: PASSED (0.004s)
```

### C. Full Test Suite Results

```
23/23 MermaidRenderer tests passed (0.092s)
3/3 MainActor rendering tests passed (0.085s)
2/2 Singleton concurrent access tests passed (0.083s)
1/1 TaskID equality test passed (0.001s)
```

### D. Key File Locations

- Renderer: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift`
- View: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`
- Image Store: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidImageStore.swift`
- SVG Sanitizer: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/SVGSanitizer.swift`
- JS Bundle: `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid.min.js`
- JXKit awaitPromise: `/Users/jud/Projects/mkdn/.build/checkouts/JXKit/Sources/JXKit/JXValue.swift` (line 1097)
- AppSettings: `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`
- AppTheme: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/AppTheme.swift`
