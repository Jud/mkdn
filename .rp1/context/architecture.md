# mkdn Architecture

## System Overview

```
CLI (mkdn file1.md file2.md)     CLI (mkdn --test-harness)
  |                                 |
  v                                 v
MkdnCLI (ArgumentParser)          MkdnApp + TestHarnessServer
  -> FileValidator                  |
  -> execv with MKDN_LAUNCH_FILE   v
  -> LaunchContext.fileURLs       AppSettings (@Observable, app-wide)
  |                                 |
  v                                 v
MkdnApp (SwiftUI App)            DocumentWindow (per-window)
  |                                 |
  +---> AppSettings (zoom, theme, autoReload)
  |       |
  +---> DocumentWindow (per window)
          |
          +---> DocumentState (@Observable, per-window file lifecycle)
          |       |
          |       +---> ContentView
          |       |       |
          |       |       +---> WelcomeView (no file)
          |       |       +---> MarkdownPreviewView (preview-only)
          |       |       +---> SplitEditorView (side-by-side)
          |       |
          |       +---> FileWatcher (DispatchSource)
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

AppDelegate (NSApplicationDelegate)
  -> application(_:open:) for Finder/dock file opens
  -> FileOpenCoordinator.shared.pendingURLs (observed by DocumentWindow)
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

### Tables
```
Dual-layer rendering: invisible text + visual overlay + highlight overlay

1. Build Layer (MarkdownTextStorageBuilder+TableInline):
   .table(columns, rows) in MarkdownBlock
   -> appendTableInlineText: invisible text in NSTextStorage (clear foreground)
   -> Tab-separated cell content per row, newline-delimited rows
   -> TableAttributes.range (unique ID), .cellMap (TableCellMap), .colors (TableColorInfo)
   -> TableColumnSizer.computeWidths for column geometry
   -> Paragraph style: tab stops at cumulative column widths, fixed row height
   -> Output: TableOverlayInfo (blockIndex, tableRangeID, cellMap)

2. Visual Layer (OverlayCoordinator+TableOverlays -> TableBlockView):
   -> OverlayCoordinator.updateTableOverlays creates NSHostingView<TableBlockView>
   -> positionTextRangeEntry: bounding rect from layout fragments in text range
   -> TableBlockView provides pixel-identical visual rendering (unchanged)
   -> OverlayCoordinator observes scroll for sticky headers (TableHeaderView)

3. Highlight Layer (TableHighlightOverlay):
   -> NSView sibling on top of visual overlay, hitTest returns nil
   -> updateTableSelections: selection range -> cellMap.cellsInRange -> cell highlights
   -> updateTableFindHighlights: find match ranges -> cell highlights + current match
   -> System accent color (0.3 data, 0.4 header) for selection
   -> Theme findHighlight color (0.15 passive, 0.4 current) for find

4. Interaction:
   -> Selection: NSTextView native (invisible text participates in TextKit 2 selection)
   -> Find (Cmd+F): text storage search works natively on invisible text
   -> Copy (Cmd+C): CodeBlockBackgroundTextView.copy override detects TableAttributes,
      generates RTF table + tab-delimited plain text via TableCellMap
   -> Cmd+A: selects all including table text (cross-block continuity)
```

### Math (LaTeX)
```
Three detection paths:
1. ```math code fences -> MarkdownBlock.mathBlock(code:)
2. $$...$$ paragraphs  -> MarkdownBlock.mathBlock(code:)
3. Inline $...$        -> mathExpression attribute in inline text

Display math (block):
  MarkdownBlock.mathBlock(code:)
  -> MathRenderer renders LaTeX to NSImage (SwiftMath, CoreGraphics/CoreText)
  -> MathBlockView (overlay pattern, same as Mermaid)
  -> NSHostingView positioned by OverlayCoordinator over NSTextAttachment placeholder

Inline math:
  MarkdownVisitor detects $...$ via character state machine
  -> Marks span with MathAttributes.mathExpression (stores LaTeX string)
  -> MarkdownTextStorageBuilder renders LaTeX to NSImage via MathRenderer
  -> Embedded as NSTextAttachment in NSAttributedString
  -> Baseline alignment via descent offset for vertical centering with text
```

### Code Blocks
```
Code block with language tag
-> SyntaxHighlightEngine (tree-sitter, 16 languages)
-> NSMutableAttributedString with token-level foreground colors
-> NSTextView (via CodeBlockBackgroundTextView)
Unsupported/untagged -> plain monospace text (no coloring)
```

### Print
```
Cmd+P
-> CodeBlockBackgroundTextView.printView(_:)
-> PrintPalette.colors + PrintPalette.syntaxColors
-> MarkdownTextStorageBuilder.build(blocks:colors:syntaxColors:isPrint:true)
-> Table text gets visible foreground (not clear) via isPrint flag
-> Temporary CodeBlockBackgroundTextView (off-screen, white bg, 32pt inset)
-> drawBackground calls drawTableContainers(in:) for table visual structure
   (CodeBlockBackgroundTextView+TablePrint.swift):
   -> Enumerates TableAttributes.range regions in textStorage
   -> Computes bounding rects from layout fragments
   -> Draws rounded-rect border, header fill, alternating row fills, header-body divider
   -> Uses TableColorInfo from attributes (adapted to PrintPalette)
-> NSPrintOperation(view:printInfo:).run()
```

The on-screen view is never modified. The print override rebuilds the full
attributed string from the current `printBlocks` using the fixed print palette,
constructs a disposable TextKit 2 text view, and hands it to `NSPrintOperation`.
After the print dialog closes, the temporary view is discarded. No flicker,
no theme flash, no state mutation.

## Data Flow

1. File opened (CLI arg, drag-drop, or open dialog)
2. DocumentState.loadFile() reads content, starts FileWatcher
3. FileWatcher monitors for on-disk changes
4. Content flows to views via @Environment(DocumentState.self) and @Environment(AppSettings.self)
5. MarkdownRenderer parses on-demand in view body
6. Mermaid blocks trigger async rendering via MermaidRenderer actor

### Zoom Scale Factor Flow
```
AppSettings.scaleFactor (UserDefaults-persisted, 0.5--3.0)
  -> MkdnCommands: Zoom In/Out/Reset (Cmd+/Cmd-/Cmd0)
  -> MarkdownTextStorageBuilder.build(scaleFactor:) scales all fonts
  -> PlatformTypeConverter.headingFont/bodyFont/monospacedFont(scaleFactor:)
  -> TableColumnSizer.computeWidths(font:) uses scaled font metrics
  -> DocumentState.modeOverlayLabel shows "125%" feedback
```

### Multi-File CLI Launch Flow
```
main.swift: MkdnCLI.parse() -> cli.files (variadic)
  -> FileValidator.validate(path:) for each file
  -> Validated URLs joined as newline-separated MKDN_LAUNCH_FILE env var
  -> execv() re-launches binary with clean argv (no file args in argv)
  -> Re-launched process reads MKDN_LAUNCH_FILE
  -> LaunchContext.fileURLs = parsed URLs
  -> DocumentWindow.onAppear: first URL loads in current window
  -> Remaining URLs open via openWindow(value: url) -> new WindowGroup instances
```

## Concurrency Model

- AppSettings + DocumentState: @MainActor (UI state, per-app and per-window respectively)
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
