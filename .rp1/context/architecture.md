# mkdn Architecture

## System Overview

```
CLI (mkdn file.md)          CLI (mkdn --test-harness)
  |                            |
  v                            v
MkdnApp (SwiftUI App)       MkdnApp + TestHarnessServer
  |                            |
  v                            v
AppState (@Observable, environment)
  |
  +---> ContentView
  |       |
  |       +---> WelcomeView (no file)
  |       +---> MarkdownPreviewView (preview-only)
  |       +---> SplitEditorView (side-by-side)
  |
  +---> FileWatcher (DispatchSource)
  |
  +---> Theme system (Solarized Dark/Light)
  |
  +---> Animation layer (AnimationConstants + MotionPreference)
  |
  +---> TestHarnessServer (Unix socket, test mode only)
          |
          +---> TestHarnessHandler (@MainActor command dispatch)
          +---> CaptureService (CGWindowListCreateImage + ScreenCaptureKit)
          +---> RenderCompletionSignal (CheckedContinuation-based)
```

## Rendering Pipeline

### Markdown
```
Raw text -> swift-markdown Document -> MarkdownVisitor -> [MarkdownBlock]
-> MarkdownBlockView (SwiftUI) -> native rendered output
```

### Mermaid Diagrams
```
Mermaid code block detected
-> MermaidRenderer (actor, singleton)
-> JXKit/JSContext + beautiful-mermaid.js
-> SVG string
-> SwiftDraw SVG rasterizer
-> NSImage
-> SwiftUI Image (with MagnifyGesture for pinch-to-zoom)
```

### Code Blocks
```
Code block with language tag
-> Splash SyntaxHighlighter
-> AttributedString with theme colors
-> SwiftUI Text
```

## Data Flow

1. File opened (CLI arg, drag-drop, or open dialog)
2. AppState.loadFile() reads content
3. FileWatcher starts monitoring for changes
4. Content flows to views via @Environment(AppState.self)
5. MarkdownRenderer parses on-demand in view body
6. Mermaid blocks trigger async rendering via MermaidRenderer actor

## Concurrency Model

- AppState: @MainActor (UI state)
- MermaidRenderer: actor (thread-safe JSC access + cache)
- FileWatcher: DispatchQueue + @MainActor for UI updates
- MotionPreference: value type, instantiated per-view from `@Environment(\.accessibilityReduceMotion)`. No shared state; resolves animation primitives locally.
- TestHarnessServer: DispatchQueue for socket I/O + semaphore-based AsyncBridge to dispatch commands to @MainActor. The socket loop runs on `socketQueue`; each command is bridged to MainActor via `Task { @MainActor in ... }` + `DispatchSemaphore.wait()`.
- TestHarnessHandler: @MainActor enum. All command handlers execute on MainActor. Render-wait commands suspend via `RenderCompletionSignal.awaitRenderComplete()`.
- CaptureService: @MainActor enum. Static captures via CGWindowListCreateImage (synchronous). Frame captures delegate to FrameCaptureSession.
- FrameCaptureSession: `@unchecked Sendable`. SCStream output arrives on serial `captureQueue`. PNG writes dispatched to serial `ioQueue` with DispatchGroup tracking. NSLock guards shared frame state.
- RenderCompletionSignal: @MainActor singleton. CheckedContinuation stored/resumed on MainActor -- no concurrent access possible.

## Test Harness Mode

When launched with `--test-harness`, the app enters test harness mode:

1. `TestHarnessMode.isEnabled` is set to `true`
2. `TestHarnessServer.shared.start()` binds a Unix domain socket at `/tmp/mkdn-test-harness-{pid}.sock`
3. The server accepts one client connection at a time on its socket queue
4. Commands arrive as line-delimited JSON, are decoded to `HarnessCommand`, and dispatched to `TestHarnessHandler` on MainActor
5. `RenderCompletionSignal` bridges the gap between command execution and render completion -- the `SelectableTextView.Coordinator` calls `signalRenderComplete()` after `makeNSView`/`updateNSView`, and render-wait commands (loadFile, switchMode, cycleTheme, setTheme, reloadFile) suspend until this signal fires or timeout expires
6. `CaptureService` provides two capture paths:
   - **Static**: `CGWindowListCreateImage` captures the window as a CGImage, cropped for region captures, written as PNG
   - **Animation**: `FrameCaptureSession` uses ScreenCaptureKit `SCStream` filtered to the app window, delivering frames at configurable FPS (30--60) for a specified duration

### Two-Process Test Architecture

```
swift test (test runner)          mkdn --test-harness (app under test)
  |                                 |
  AppLauncher                       TestHarnessServer
    - swift build --product mkdn      - bind /tmp/mkdn-test-harness-{pid}.sock
    - Process.run(--test-harness)     - accept() on socketQueue
    |                                 |
  TestHarnessClient                 TestHarnessHandler (@MainActor)
    - connect() with retry            - dispatch HarnessCommand
    - send JSON command               - execute on MainActor
    - read JSON response              - await RenderCompletionSignal
    |                                 |
  ImageAnalyzer / FrameAnalyzer     CaptureService / FrameCaptureSession
    - pixel-level analysis            - CGWindowListCreateImage
    - color matching                  - SCStream frame capture
    - animation curve fitting         - PNG output
```

No XCUITest dependency -- the app controls itself. No `.xcodeproj` required -- pure SPM project. The test harness client connects via POSIX sockets with retry logic (20 attempts, 250ms delay) to handle the race between process launch and socket readiness.

### Vision Verification (LLM-Based Design Compliance)

In addition to the deterministic pixel-level compliance suites (Spatial, Visual, Animation), the test harness infrastructure is also consumed by the **LLM visual verification workflow**. This workflow uses the same capture mechanism to produce deterministic screenshots, which are then evaluated by Claude Code's vision capabilities against design PRDs and the charter's design philosophy.

The capture orchestrator (`VisionCaptureTests.swift`) follows the same harness singleton pattern as the other compliance suites. It captures all fixtures across both Solarized themes in preview-only mode (8 screenshots total), writing them to `.rp1/work/verification/captures/` with a `manifest.json` recording metadata (dimensions, scale factor, SHA-256 content hash) for each capture.

Shell scripts in `scripts/visual-verification/` orchestrate the full workflow: capture screenshots, evaluate them via LLM vision, generate failing Swift tests for detected issues, invoke `/build --afk` to fix the code, and re-verify. Generated tests live in `mkdnTests/UITest/VisionCompliance/` and share a `VisionComplianceHarness` singleton that follows the same pattern as SpatialHarness/VisualHarness/AnimationHarness.

```
scripts/visual-verification/
  capture.sh          -> swift test --filter VisionCapture -> screenshots + manifest
  evaluate.sh         -> LLM vision evaluation -> evaluation report
  generate-tests.sh   -> failing Swift tests in VisionCompliance/
  heal-loop.sh        -> full loop: capture -> evaluate -> generate -> fix -> verify
  verify.sh           -> re-capture + re-evaluate after fix
```

#### Multi-Test Build Prompt (SA-2)

When the heal-loop invokes `/build --afk` to fix vision-detected failures, it constructs a structured multi-test prompt containing per-test details and explicit iteration instructions. For each generated test file, the prompt includes the file path, PRD reference, specification excerpt, and observation from the evaluation report. The prompt instructs the build agent to run `swift test --filter VisionDetected`, fix failures, re-run, and repeat until all listed tests pass. This allows the build agent to address multiple failures in a single invocation rather than requiring the outer heal-loop to re-iterate for each individual fix.

#### Registry-Based Regression Detection (SA-3)

The `verify.sh` script performs two levels of regression detection when comparing a new evaluation against prior state:

1. **Phase 3 (previous-evaluation comparison)**: Compares the new evaluation against the immediately-previous evaluation to classify issues as resolved, regression, or remaining.
2. **Phase 3b (registry history scan)**: For each issue in the new evaluation not already classified by Phase 3, the script reads the capture's entry in `registry.json` and scans all historical evaluations. If the same PRD reference was previously marked as `"status": "resolved"` in any prior evaluation, the issue is classified as a **reintroduced regression** with the original resolution timestamp attached. This catches issues that were resolved several iterations ago but reappear after an unrelated fix.

The re-verification report includes a `reintroducedRegressions` section alongside the existing `resolvedIssues`, `newRegressions`, and `remainingIssues` sections. Registry entries for reintroduced regressions are recorded with status `"reintroduced"`.

#### Enhanced Audit Trail (SA-4)

The `buildInvocation` audit entry in `audit.jsonl` records the full context of each `/build --afk` invocation:

- `testPaths`: array of project-relative paths to the generated test files passed to the build agent
- `filesModified`: array of project-relative file paths changed by the build step (captured via `git diff --name-only` between pre-build and post-build HEAD)
- `testsFixed`: array of test suite names that now pass after the build
- `testsRemaining`: array of test suite names that still fail after the build

These fields supplement the existing `type`, `timestamp`, `loopId`, `iteration`, `result`, and `prdRefs` fields. If `git diff` fails, `filesModified` gracefully defaults to an empty array.

#### Attended Mode Continuation (SA-5)

When `heal-loop.sh` is invoked with `--attended` and reaches an escalation point, the interactive menu offers three options: continue with manual guidance (`c`), skip remaining issues (`s`), or quit and write an escalation report (`q`).

Selecting `c` prompts the developer to enter multi-line guidance text (terminated by an empty line or Ctrl-D). The guidance is validated as non-empty (with up to 3 retries before falling back to an escalation report), confirmed via a preview of the first 5 lines, and then:

1. Stored in the `MANUAL_GUIDANCE` variable for the next iteration's build prompt
2. Incorporated verbatim under a "Developer Guidance" section in the `/build --afk` prompt
3. Recorded as a `manualGuidance` audit entry (with the guidance text sanitized via `jq --arg`)
4. Cleared after the next iteration completes (guidance applies to one iteration only)
