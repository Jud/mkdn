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
- FrameCaptureSession: `@unchecked Sendable`. SCStream output arrives on serial `captureQueue`. CIContext pixel buffer conversion. Serial ioQueue + DispatchGroup for non-blocking PNG writes.
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

Shell scripts in `scripts/visual-verification/` orchestrate the workflow:

```
scripts/visual-verification/
  verify-visual.sh  -> top-level: capture + evaluate + human-readable summary
  capture.sh        -> swift test --filter VisionCapture -> screenshots + manifest
  evaluate.sh       -> LLM vision evaluation -> evaluation report
```

The workflow is on-demand and developer-initiated. `verify-visual.sh` chains capture and evaluation, then formats the results as a terminal-friendly summary showing issue counts by severity and per-issue details with PRD references. The developer reviews findings and decides what to fix. To re-verify after changes, run `verify-visual.sh` again.

Evaluation results are cached based on SHA-256 hashes of image content, prompt templates, and PRD files. Unchanged inputs skip API calls entirely. Reports are written to `.rp1/work/verification/reports/` as structured JSON.
