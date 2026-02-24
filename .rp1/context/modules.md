# mkdn Module Inventory

## App Layer (`mkdn/App/`)

| File | Purpose |
|------|---------|
| AppSettings.swift | @Observable app-wide settings: zoom scaleFactor (0.5--3.0), themeMode (auto/dark/light), autoReloadEnabled, hasShownDefaultHandlerHint. Persisted to UserDefaults. Methods: zoomIn/zoomOut/zoomReset, cycleTheme |
| DocumentState.swift | @Observable per-window document lifecycle: file I/O (loadFile, saveFile, saveAs, reloadFile), viewMode, unsaved-changes detection, FileWatcher ownership, mode overlay label |
| DocumentWindow.swift | SwiftUI View wrapper creating per-window DocumentState. Loads file on appear, consumes LaunchContext URLs for multi-file CLI launch, observes FileOpenCoordinator for runtime file opens, wires test harness in test mode |
| AppDelegate.swift | NSApplicationDelegate for system file-open events (Finder, dock drag-drop). Routes URLs through FileOpenCoordinator. Applies squircle icon mask with drop shadow on launch |
| FileOpenCoordinator.swift | @Observable singleton bridging AppKit file-open events to SwiftUI window creation. pendingURLs queue, consumeAll() drain, isMarkdownURL() validation |
| FocusedDocumentStateKey.swift | FocusedValueKey for accessing active window's DocumentState from menu commands |
| OpenRecentCommands.swift | File > Open Recent submenu. Reads NSDocumentController.recentDocumentURLs, routes selection through FileOpenCoordinator |
| ViewMode.swift | Preview-only vs side-by-side enum |
| ContentView.swift | Root view, mode switching, toolbar |
| MkdnCommands.swift | Menu bar commands: About, Set Default Handler, Close Window, Save/Save As, Find (panel + next/prev/selection), Print/Page Setup, Open/Reload, Zoom In/Out/Reset, Preview/Edit mode, Cycle Theme |

## Core Layer (`mkdn/Core/`)

### Markdown (`Core/Markdown/`)
| File | Purpose |
|------|---------|
| MarkdownRenderer.swift | Parse + render coordinator |
| MarkdownBlock.swift | Block element enum (11 cases incl. htmlBlock, image). CheckboxState enum (checked/unchecked). ListItem with optional checkbox. IndexedBlock for positional identity. DJB2 stableHash for deterministic IDs |
| MarkdownVisitor.swift | swift-markdown Document walker -> [MarkdownBlock]. Inline text conversion with emphasis/strong/strikethrough/code/link support. Checkbox extraction from ListItem.checkbox. Standalone image promotion to block-level. Table column alignment mapping |
| MarkdownTextStorageBuilder.swift | Converts [IndexedBlock] -> NSAttributedString + [AttachmentInfo]. Inline content conversion (bold/italic/code/link/strikethrough). Delegates to SyntaxHighlightEngine for multi-language syntax highlighting. Paragraph style helpers. Plain text extraction |
| MarkdownTextStorageBuilder+Blocks.swift | Block-type rendering: heading, paragraph, code block (with language label, CodeBlockAttributes marking, rawCode storage), attachment placeholder, HTML block. Code block padding/indent constants |
| MarkdownTextStorageBuilder+Complex.swift | Blockquote (recursive depth), ordered/unordered lists (nested, with checkbox rendering via SF Symbols) |
| MarkdownTextStorageBuilder+TableInline.swift | Table invisible-text generation: `appendTableInlineText` builds tab-separated cell content per row with clear foreground, TableAttributes marking, TableCellMap construction, and row height estimation. TableRowContext carries per-row build state. Replaces attachment-based table rendering |
| PlatformTypeConverter.swift | SwiftUI-to-AppKit type bridge: Color->NSColor, scaled font factory (heading/body/monospaced/captionMonospaced), paragraph style builder |
| CodeBlockAttributes.swift | Custom NSAttributedString.Key constants: range (block ID), colors (CodeBlockColorInfo), rawCode (clipboard source). CodeBlockColorInfo class (NSObject subclass for attribute storage) |
| TableAttributes.swift | Custom NSAttributedString.Key constants for table cross-cell selection: range (table ID), cellMap (TableCellMap), colors (TableColorInfo), isHeader (bool). TableColorInfo class (NSObject subclass) stores resolved NSColor values for table container drawing |
| TableCellMap.swift | NSObject subclass mapping character offsets to cell positions. CellPosition (row/column, header row = -1), CellEntry (position + NSRange + content). O(log n) binary search cell lookup, range intersection for selection mapping, tab-delimited and RTF content extraction for clipboard |
| TableColumnSizer.swift | Pure column width computation from cell content |

### Highlighting (`Core/Highlighting/`)
| File | Purpose |
|------|---------|
| SyntaxHighlightEngine.swift | Stateless enum. `highlight(code:language:syntaxColors:)` creates tree-sitter Parser per call, parses code, executes highlight query, maps captures to TokenType, applies NSColor foreground attributes. Returns nil for unsupported languages. Falls back to plain text if query compilation fails |
| TreeSitterLanguageMap.swift | LanguageConfig struct + TreeSitterLanguageMap enum. Case-insensitive alias resolution (js, ts, py, rb, sh, yml, cpp) for 16 languages. `configuration(for:)` returns parser Language + highlight query. `supportedLanguages` lists canonical names |
| TokenType.swift | 13-case enum (keyword, string, comment, type, number, function, property, preprocessor, operator, variable, constant, attribute, punctuation). `from(captureName:)` maps tree-sitter capture names (with subcategory prefix splitting). `color(from:)` resolves to SyntaxColors property |
| HighlightQueries.swift | Embedded tree-sitter highlight query strings (.scm) for all 16 languages. Sourced verbatim from grammar repositories. TypeScript/C++ queries concatenate base + override queries |

### Math (`Core/Math/`)
| File | Purpose |
|------|---------|
| MathRenderer.swift | Stateless LaTeX-to-NSImage renderer via SwiftMath. Renders LaTeX strings to NSImage using CoreGraphics/CoreText for both inline and display math |
| MathAttributes.swift | Custom NSAttributedString.Key for inline math (mathExpression). Stores original LaTeX string as attribute value for rendering in TextStorageBuilder |

### Mermaid (`Core/Mermaid/`)
| File | Purpose |
|------|---------|
| MermaidRenderer.swift | Actor: JSC + beautiful-mermaid -> SVG -> NSImage |

### FileWatcher (`Core/FileWatcher/`)
| File | Purpose |
|------|---------|
| FileWatcher.swift | DispatchSource file monitoring |

### CLI (`Core/CLI/`)
| File | Purpose |
|------|---------|
| MkdnCLI.swift | ParsableCommand struct for `mkdn [files...]`. Variadic `[String]` argument accepting multiple .md/.markdown paths |
| LaunchContext.swift | Static `fileURLs` storage for validated CLI URLs. `consumeURLs()` drains once. `nonisolated(unsafe)` for sequential access pattern (set in main.swift, consumed in DocumentWindow.onAppear) |
| CLIError.swift | Typed errors: unsupportedExtension, fileNotFound, fileNotReadable. LocalizedError conformance with per-case exit codes |
| FileValidator.swift | Path validation pipeline: tilde expansion, relative path resolution, symlink resolution, extension check (.md/.markdown), existence check, UTF-8 readability check |

### TestHarness (`Core/TestHarness/`)
| File | Purpose |
|------|---------|
| HarnessCommand.swift | Command enum (14 cases: loadFile, captureWindow, captureRegion, switchMode, cycleTheme, setTheme, reloadFile, getWindowInfo, getThemeColors, setReduceMotion, ping, quit, startFrameCapture, stopFrameCapture), CaptureRegion struct, HarnessSocket path convention |
| HarnessResponse.swift | Response struct with ResponseData enum (capture, frameCapture, windowInfo, themeColors, pong). Result types: CaptureResult, FrameCaptureResult, WindowInfoResult, ThemeColorsResult, RGBColor |
| HarnessError.swift | Error enum: renderTimeout, connectionFailed, unexpectedResponse, unknownCommand, captureFailed, fileLoadFailed |
| RenderCompletionSignal.swift | @MainActor singleton. CheckedContinuation-based render-done signaling. `awaitRenderComplete(timeout:)` suspends until `signalRenderComplete()` fires from SelectableTextView.Coordinator |
| TestHarnessServer.swift | Unix domain socket listener on DispatchQueue. POSIX socket APIs (bind/listen/accept). Semaphore-based AsyncBridge for @MainActor dispatch. Line-delimited JSON protocol with iso8601 dates. Socket at `/tmp/mkdn-test-harness-{pid}.sock` |
| TestHarnessHandler.swift | @MainActor command dispatch for all 14 cases. Weak refs to AppSettings + DocumentState. Delegates captures to CaptureService, uses RenderCompletionSignal for render-wait commands |
| CaptureService.swift | @MainActor enum. CGWindowListCreateImage for static window/region captures. FrameCaptureSession lifecycle for animation frame sequences. PNG writing via NSBitmapImageRep |
| FrameCaptureSession.swift | SCStream-based frame capture via ScreenCaptureKit. SCStreamOutput delegate for frame delivery on serial captureQueue. CIContext pixel buffer conversion. Serial ioQueue + DispatchGroup for non-blocking PNG writes |

## Features Layer (`mkdn/Features/`)

### Viewer (`Features/Viewer/`)
| File | Purpose |
|------|---------|
| Views/MarkdownPreviewView.swift | Full-width preview |
| Views/MarkdownBlockView.swift | Block element renderer |
| Views/CodeBlockView.swift | Syntax-highlighted code |
| Views/CodeBlockCopyButton.swift | Hover-revealed copy button for code blocks. doc.on.doc icon with checkmark confirmation via symbolEffect(.replace). Uses quickShift animation, ultraThinMaterial background |
| Views/CodeBlockBackgroundTextView.swift | NSTextView subclass drawing rounded-rect containers behind code blocks via CodeBlockAttributes. TextKit 2 layout fragment enumeration. Mouse tracking for hover-revealed copy button overlay (NSHostingView of CodeBlockCopyButton). Copies raw code via rawCode attribute. Table-aware `copy(_:)` override detects TableAttributes in selection, generates RTF table + tab-delimited plain text via TableCellMap |
| Views/CodeBlockBackgroundTextView+TablePrint.swift | Print-time table container rendering. Draws rounded-rect border, header background, alternating row fills, and header-body divider behind visible table text during Cmd+P. Guarded by `NSPrintOperation.current`. Enumerates `TableAttributes.range` regions, computes bounding rects from layout fragments, draws via NSBezierPath using TableColorInfo |
| Views/SelectableTextView.swift | NSViewRepresentable wrapping read-only NSTextView (TextKit 2). Cross-block text selection, find bar (Cmd+F). Hosts CodeBlockBackgroundTextView. Coordinator owns EntranceAnimator and OverlayCoordinator. `textViewDidChangeSelection` delegates to `overlayCoordinator.updateTableSelections` for cell-level highlight updates. Find handler calls `overlayCoordinator.updateTableFindHighlights` for table find feedback |
| Views/OverlayCoordinator.swift | Manages NSHostingView overlays for Mermaid, images, thematic breaks at NSTextAttachment locations. Variable-width positioning (preferredWidth). Layout and scroll observation via NotificationCenter. Table overlays delegated to OverlayCoordinator+TableOverlays extension |
| Views/OverlayCoordinator+TableOverlays.swift | Table overlay management extension for OverlayCoordinator. Text-range-based positioning (via TableAttributes.range, not attachments). Creates TableBlockView visual overlays + TableHighlightOverlay siblings. `positionTextRangeEntry` computes bounding rect from layout fragments. `updateTableSelections` maps selection to cells. `updateTableFindHighlights` maps find matches to cell highlights. Scroll-driven sticky headers |
| Views/TableHighlightOverlay.swift | Lightweight NSView subclass drawing cell-level selection and find highlights on top of TableBlockView. hitTest returns nil (mouse events pass through). Cell rectangles computed from TableCellMap columnWidths/rowHeights. Selection: system accent color (0.3 data, 0.4 header). Find: theme findHighlight color (0.15 passive, 0.4 current) |
| Views/EntranceAnimator.swift | Per-layout-fragment staggered fade-in using CALayer covers. Code block and table fragments grouped by block ID (via `blockGroupID` checking both CodeBlockAttributes.range and TableAttributes.range) for unified entrance. 8pt upward drift via CATransform3D. Respects Reduce Motion (immediate appearance). Cleanup via scheduled Task |
| Views/ImageBlockView.swift | Async image loading with local path resolution (relative to document), remote URL support, loading/error placeholders. Security: validates local paths stay within document directory |
| Views/MermaidBlockView.swift | Mermaid diagram with zoom |
| Views/TableBlockView.swift | Native table rendering |
| Views/TableHeaderView.swift | Sticky header overlay for long tables |
| ViewModels/PreviewViewModel.swift | Preview state management |

### Editor (`Features/Editor/`)
| File | Purpose |
|------|---------|
| Views/SplitEditorView.swift | HSplitView editor + preview |
| Views/MarkdownEditorView.swift | TextEditor wrapper |
| ViewModels/EditorViewModel.swift | Editor state management |

### Theming (`Features/Theming/`)
| File | Purpose |
|------|---------|
| ThemePickerView.swift | Theme selection UI |

## UI Layer (`mkdn/UI/`)

### Components (`UI/Components/`)
| File | Purpose |
|------|---------|
| OutdatedIndicator.swift | File-changed badge |
| ViewModePicker.swift | Mode toggle toolbar item |
| WelcomeView.swift | Empty state screen |
| OrbVisual.swift | Reusable 3-layer orb (outerHalo, midGlow, innerCore) with RadialGradient. Params: color, isPulsing, isHaloExpanded. Visual-only -- no animation state. |
| PulsingSpinner.swift | Orb-rhythm loading spinner using `AnimationConstants.breathe`. Static full-opacity when Reduce Motion is on. |
| HoverFeedbackModifier.swift | `HoverFeedbackModifier` (scale) and `BrightnessHoverModifier` (brightness overlay). View extensions `.hoverScale(_:)` and `.hoverBrightness()`. Uses quickSettle animation, nil for RM. |
| FileChangeOrbView.swift | File-changed pulsing orb. Delegates to `OrbVisual`, owns animation state, hover feedback via `.hoverScale()`, tap-to-reload popover. |
| ModeTransitionOverlay.swift | Ephemeral mode-name overlay. Spring-settle entrance, quick-fade exit, auto-dismiss after 1.5s. RM uses reducedCrossfade for both. |

### Theme (`UI/Theme/`)
| File | Purpose |
|------|---------|
| AppTheme.swift | Theme enum |
| ThemeColors.swift | Color palette struct |
| SolarizedDark.swift | Dark theme values |
| SolarizedLight.swift | Light theme values |
| AnimationConstants.swift | Named animation primitives (breathe, haloBloom, springSettle, gentleSpring, quickSettle, fadeIn, fadeOut, crossfade, quickFade, quickShift), stagger/hover/focus constants, orb colors, overlay timing, reduce-motion alternatives. MARK-delimited groups. |
| PrintPalette.swift | Print-friendly color palette enum. Static `colors: ThemeColors` (white bg, black text) and `syntaxColors: SyntaxColors` (ink-efficient, WCAG AA). Applied automatically during Cmd+P -- not user-selectable, not tied to AppTheme. |
| MotionPreference.swift | Reduce Motion resolver. `MotionPreference(reduceMotion:)` struct with `Primitive` enum. `resolved(_:)` returns `Animation?` (nil for continuous when RM on). `allowsContinuousAnimation` bool, `staggerDelay` accessor. |

## Dependencies

| Package | Purpose | Used In |
|---------|---------|---------|
| apple/swift-markdown | Markdown AST parsing | Core/Markdown |
| swhitty/SwiftDraw | SVG -> NSImage | Core/Mermaid |
| jectivex/JXKit | Swift JSC wrapper | Core/Mermaid |
| apple/swift-argument-parser | CLI args | Core/CLI |
| mgriebling/SwiftMath (>=1.7.0) | Native LaTeX math rendering via CoreGraphics/CoreText | Core/Math |
| ChimeHQ/SwiftTreeSitter | Tree-sitter parsing | Core/Highlighting |
| tree-sitter-{lang} (16 grammars) | Language grammars (swift, python, javascript, typescript, rust, go, bash, json, yaml, html, css, c, cpp, ruby, java, kotlin) | Core/Highlighting |

## Test Layer (`mkdnTests/`)

### Support (`mkdnTests/Support/`)
| File | Purpose |
|------|---------|
| TestHarnessClient.swift | POSIX socket client with typed async methods for every HarnessCommand. Retry-based connect (20 attempts, 250ms delay). Blocking I/O on serial ioQueue, poll()-based read with timeout |
| AppLauncher.swift | `swift build --product mkdn` + Process launch with `--test-harness` flag. Connects TestHarnessClient, manages teardown (quit command + process termination + socket cleanup) |
| ImageAnalyzer.swift | Pixel-level CGImage analysis. Handles 4 macOS byte orders (RGBA, ARGB, BGRA, ABGR). Point-to-pixel coordinate conversion via scaleFactor. Methods: sampleColor, averageColor, contentBounds, findColorBoundary, dominantColor, findRegion |
| ColorExtractor.swift | PixelColor struct (UInt8 RGBA). Chebyshev distance matching (max per-channel delta) |
| SpatialMeasurement.swift | Edge detection, distance measurement, gap measurement between rendered elements |
| FrameAnalyzer.swift | Animation curve extraction from frame sequences. measureOrbPulse (peak counting, CPM), measureTransitionDuration (progress 10%--90%, curve inference), measureSpringCurve (overshoot peak, damping estimation, settle time), measureStaggerDelays (per-region appearance frame detection) |
| JSONResultReporter.swift | Structured test result collection. Writes JSON report to `.build/test-results/mkdn-ui-test-report.json` |
| PRDCoverageTracker.swift | Maps test results to PRD functional requirements. Reports covered/uncovered FRs per PRD |
