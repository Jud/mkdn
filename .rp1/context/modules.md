# mkdn Module Inventory

## App Layer (`mkdn/App/`)

| File | Purpose |
|------|---------|
| mkdnApp.swift | @main entry, WindowGroup, commands |
| AppState.swift | Central @Observable state |
| ViewMode.swift | Preview-only vs side-by-side enum |
| ContentView.swift | Root view, mode switching, toolbar |
| MkdnCommands.swift | Menu bar commands |

## Core Layer (`mkdn/Core/`)

### Markdown (`Core/Markdown/`)
| File | Purpose |
|------|---------|
| MarkdownRenderer.swift | Parse + render coordinator |
| MarkdownBlock.swift | Block element enum |
| MarkdownVisitor.swift | swift-markdown walker -> MarkdownBlock |

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
| CLIHandler.swift | Argument parsing for `mkdn file.md` |

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
| Views/MermaidBlockView.swift | Mermaid diagram with zoom |
| Views/TableBlockView.swift | Native table rendering |
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
| MotionPreference.swift | Reduce Motion resolver. `MotionPreference(reduceMotion:)` struct with `Primitive` enum. `resolved(_:)` returns `Animation?` (nil for continuous when RM on). `allowsContinuousAnimation` bool, `staggerDelay` accessor. |

## Dependencies

| Package | Purpose | Used In |
|---------|---------|---------|
| apple/swift-markdown | Markdown AST parsing | Core/Markdown |
| swhitty/SwiftDraw | SVG -> NSImage | Core/Mermaid |
| jectivex/JXKit | Swift JSC wrapper | Core/Mermaid |
| apple/swift-argument-parser | CLI args | Core/CLI |
| JohnSundell/Splash | Syntax highlighting | Features/Viewer |
| ScreenCaptureKit (system) | SCStream frame capture for animation verification | Core/TestHarness |

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

### UI Compliance Suites (`mkdnTests/UITest/`)
| File | Purpose |
|------|---------|
| SpatialComplianceTests.swift + SpatialComplianceTests+Typography.swift | 16 spatial tests: margins, spacing, indentation. Calibration gate validates measurement accuracy within 1pt |
| SpatialPRD.swift | PRD constants for spatial-design-language FR-1 through FR-6. Tolerance: 1.0pt spatial, 10 color |
| VisualComplianceTests.swift + VisualComplianceTests+Syntax.swift | 12 visual tests: theme colors, syntax highlighting tokens. Calibration gate validates background color sampling |
| VisualPRD.swift | PRD constants for automated-ui-testing AC-004. Tolerances: 10 color, 15 text, 25 syntax |
| AnimationComplianceTests.swift + AnimationComplianceTests+FadeDurations.swift + AnimationComplianceTests+ReduceMotion.swift | 13 animation tests: orb pulse, fade durations, spring curves, stagger delays, reduce motion. Calibration gate validates frame capture + crossfade timing |
| AnimationPRD.swift | PRD constants for animation-design-language FR-1 through FR-5. Tolerances: 33.3ms at 30fps, 16.7ms at 60fps, 25% CPM relative |

### Vision Compliance (`mkdnTests/UITest/VisionCompliance/`)
| File | Purpose |
|------|---------|
| VisionCaptureTests.swift | Capture orchestrator: produces deterministic screenshots of all fixtures (canonical, theme-tokens, mermaid-focus, geometry-calibration) across both Solarized themes in preview-only mode (4 fixtures x 2 themes = 8 captures). Writes manifest.json with metadata and SHA-256 image hashes for the LLM visual verification workflow |
| VisionCapturePRD.swift | VisionCaptureHarness singleton, VisionCaptureConfig (fixtures, themes, viewMode), fixture path resolution, output directory resolution, capture ID generation, SHA-256 hash computation (CryptoKit), CaptureManifestEntry/CaptureManifest types, manifest writing |
| VisionCompliancePRD.swift | Shared harness for vision compliance tests. VisionComplianceHarness singleton (same pattern as SpatialHarness/VisualHarness/AnimationHarness), visionFixturePath resolution, visionExtractCapture response validation, visionLoadAnalyzer CGImage loading + ImageAnalyzer initialization |

### Fixtures (`mkdnTests/Fixtures/UITest/`)
| File | Purpose |
|------|---------|
| canonical.md | All Markdown element types for comprehensive rendering verification |
| long-document.md | 31 top-level blocks for stagger animation testing |
| mermaid-focus.md | 4 Mermaid diagram types (flowchart, sequence, class, state) |
| theme-tokens.md | Code blocks isolating each SyntaxColors token type |
| geometry-calibration.md | Known-spacing elements for spatial measurement calibration |
