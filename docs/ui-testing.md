# mkdn UI Testing Infrastructure

Automated UI testing for verifying spatial, visual, and animation compliance against the project's design-system PRDs.

## Architecture Overview

The test infrastructure uses a **process-based test harness with app-side cooperation**. Two processes communicate via a Unix domain socket with a line-delimited JSON protocol:

- **Test runner** (`swift test`): Swift Testing suites that drive the app, capture output, and assert compliance.
- **App under test** (`mkdn --test-harness`): The mkdn app in test harness mode, listening for commands on a Unix domain socket.

The app controls itself (no XCUITest, no accessibility permissions for basic control), captures its own window via `CGWindowListCreateImage`, and signals render completion deterministically via `RenderCompletionSignal`.

### Component Map

| Component | Location | Purpose |
|-----------|----------|---------|
| `TestHarnessServer` | `mkdn/Core/TestHarness/TestHarnessServer.swift` | Socket listener, command dispatcher |
| `TestHarnessHandler` | `mkdn/Core/TestHarness/TestHarnessHandler.swift` | @MainActor command execution |
| `CaptureService` | `mkdn/Core/TestHarness/CaptureService.swift` | Window/region/frame capture |
| `FrameCaptureSession` | `mkdn/Core/TestHarness/FrameCaptureSession.swift` | ScreenCaptureKit frame sequence capture |
| `RenderCompletionSignal` | `mkdn/Core/TestHarness/RenderCompletionSignal.swift` | Deterministic render-done signaling |
| `HarnessCommand` | `mkdn/Core/TestHarness/HarnessCommand.swift` | Command enum + socket path convention |
| `HarnessResponse` | `mkdn/Core/TestHarness/HarnessResponse.swift` | Response types + result structs |
| `TestHarnessClient` | `mkdnTests/Support/TestHarnessClient.swift` | Socket client for test runner |
| `AppLauncher` | `mkdnTests/Support/AppLauncher.swift` | Build + launch + connect lifecycle |
| `ImageAnalyzer` | `mkdnTests/Support/ImageAnalyzer.swift` | Pixel-level image analysis |
| `SpatialMeasurement` | `mkdnTests/Support/SpatialMeasurement.swift` | Edge detection + distance measurement |
| `ColorExtractor` | `mkdnTests/Support/ColorExtractor.swift` | Color comparison utilities |
| `FrameAnalyzer` | `mkdnTests/Support/FrameAnalyzer.swift` | Animation curve extraction |
| `JSONResultReporter` | `mkdnTests/Support/JSONResultReporter.swift` | Structured JSON test report |
| `PRDCoverageTracker` | `mkdnTests/Support/PRDCoverageTracker.swift` | PRD functional requirement coverage |

## Test Execution

### Running Tests

```bash
# Full UI compliance suite (spatial + visual + animation)
swift test --filter UITest

# Spatial compliance only
swift test --filter SpatialCompliance

# Visual compliance only
swift test --filter VisualCompliance

# Animation compliance only
swift test --filter AnimationCompliance

# All tests (unit + UI compliance)
swift test
```

Each compliance suite launches a fresh `mkdn --test-harness` instance, connects via Unix domain socket, loads test fixtures, captures rendered output, and asserts compliance against PRD specifications.

### Test Suites

| Suite | Files | Tests | PRD Coverage |
|-------|-------|-------|--------------|
| SpatialCompliance | `SpatialComplianceTests.swift`, `SpatialComplianceTests+Typography.swift`, `SpatialPRD.swift` | 16 | spatial-design-language FR-1 through FR-6 |
| VisualCompliance | `VisualComplianceTests.swift`, `VisualComplianceTests+Syntax.swift`, `VisualPRD.swift` | 12 | automated-ui-testing AC-004a through AC-004f |
| AnimationCompliance | `AnimationComplianceTests.swift`, `AnimationComplianceTests+FadeDurations.swift`, `AnimationComplianceTests+ReduceMotion.swift`, `AnimationPRD.swift` | 13 | animation-design-language FR-1 through FR-5 |

### Calibration Gates

Each suite begins with a calibration test that verifies measurement accuracy before running compliance assertions. If calibration fails, downstream tests are skipped (not failed), preventing false positives/negatives from broken infrastructure.

| Suite | Calibration | What It Verifies |
|-------|-------------|-----------------|
| Spatial | `test_spatialDesignLanguage_calibration` | Spatial measurement accuracy within 1pt at Retina |
| Visual | `test_visualCompliance_calibration` | Background color sampling matches ThemeColors.background exactly |
| Animation | `test_animationDesignLanguage_calibration` | Frame capture infrastructure + crossfade timing within 1 frame at 30fps |

### Workflow: AI Coding Agent

1. Make code changes to rendering, spacing, or animation code.
2. Run `swift test --filter UITest` (or a specific suite).
3. Parse the JSON report at `.build/test-results/mkdn-ui-test-report.json`.
4. Each failure includes the PRD reference, expected value, actual measured value, and captured image paths.
5. Use failure details to identify exactly which design requirement was violated and make targeted fixes.
6. Repeat until all tests pass.

### Workflow: Human Developer

1. Run `swift test --filter SpatialCompliance` (or any subset) during development.
2. Review Swift Testing console output for immediate pass/fail feedback.
3. On failure, inspect captured images at `/tmp/mkdn-captures/` for visual diagnosis.
4. Check the JSON report at `.build/test-results/mkdn-ui-test-report.json` for structured details.
5. The PRD coverage report shows which design requirements have test coverage and which do not.

## Test Fixtures

All test fixtures are static Markdown files checked into the repository at `mkdnTests/Fixtures/UITest/`.

| Fixture | Purpose |
|---------|---------|
| `canonical.md` | All Markdown element types (headings, paragraphs, code blocks, lists, blockquotes, tables, thematic breaks, Mermaid diagrams, inline formatting) |
| `long-document.md` | 31 top-level blocks for stagger animation testing |
| `mermaid-focus.md` | 4 Mermaid diagram types (flowchart, sequence, class, state) |
| `theme-tokens.md` | Code blocks isolating each SyntaxColors token type |
| `geometry-calibration.md` | Minimal known-spacing elements with documented expected values for spatial measurement calibration |

## Output Artifacts

### JSON Test Report

**Path**: `.build/test-results/mkdn-ui-test-report.json`

Written incrementally after each test assertion. Contains the full test run results and PRD coverage data.

**Schema**:

```json
{
  "timestamp": "2026-02-08T18:00:00Z",
  "totalTests": 41,
  "passed": 40,
  "failed": 1,
  "results": [
    {
      "name": "spatial-design-language FR-2: documentMargin",
      "status": "pass",
      "prdReference": "spatial-design-language FR-2",
      "expected": "32.0",
      "actual": "32.0",
      "imagePaths": [],
      "duration": 0,
      "message": null
    },
    {
      "name": "spatial-design-language FR-3: h1SpaceAbove",
      "status": "fail",
      "prdReference": "spatial-design-language FR-3",
      "expected": "48.0",
      "actual": "24.0",
      "imagePaths": [],
      "duration": 0,
      "message": "spatial-design-language FR-3: h1SpaceAbove expected 48.0pt, measured 24.0pt"
    }
  ],
  "coverage": {
    "prds": [
      {
        "prdName": "spatial-design-language",
        "totalFRs": 6,
        "coveredFRs": 5,
        "uncoveredFRs": ["FR-1"],
        "coveragePercent": 83.3
      },
      {
        "prdName": "animation-design-language",
        "totalFRs": 5,
        "coveredFRs": 5,
        "uncoveredFRs": [],
        "coveragePercent": 100.0
      }
    ]
  }
}
```

**Key fields in `results[]`**:

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Human-readable test identifier |
| `status` | `"pass"` or `"fail"` | Test outcome |
| `prdReference` | String | PRD name + FR identifier (e.g., `"spatial-design-language FR-3"`) |
| `expected` | String? | Expected value from PRD/constants |
| `actual` | String? | Measured value from capture analysis |
| `imagePaths` | [String] | Paths to captured images used in this assertion |
| `duration` | Number | Test duration in seconds (0 for assertion-level recording) |
| `message` | String? | Failure description with expected, actual, and PRD reference |

### Captured Images

**Path**: `/tmp/mkdn-captures/`

Single-frame window captures produced by `CaptureService`. Named sequentially: `mkdn-capture-0001.png`, `mkdn-capture-0002.png`, etc.

Each capture is at native Retina resolution (2x scale factor = 2px per point). Metadata is embedded in the `CaptureResult` response, not in the PNG file itself.

### Frame Sequences

**Path**: `/tmp/mkdn-frames/{timestamp}/`

Multi-frame animation captures produced by `FrameCaptureSession` via ScreenCaptureKit. Named sequentially: `frame_0001.png`, `frame_0002.png`, etc.

Used by animation compliance tests for curve-fitting analysis (pulse detection, transition timing, spring fitting, stagger measurement).

### PRD Coverage Report

Embedded in the JSON test report under the `coverage` key. Also available via `PRDCoverageTracker.generateReport(from:)`.

Lists each tracked PRD with:
- `totalFRs`: Total functional requirements in the PRD
- `coveredFRs`: Number of FRs with at least one test
- `uncoveredFRs`: List of FR identifiers without test coverage
- `coveragePercent`: Percentage covered

## Permissions

### Screen Recording (Required)

Both `CGWindowListCreateImage` (single-frame capture) and `ScreenCaptureKit` (frame sequence capture) require Screen Recording permission.

**Local development**: System Preferences > Privacy & Security > Screen Recording. Grant access to **Terminal** (or your terminal emulator: iTerm2, Alacritty, etc.).

**CI environment**: Grant Screen Recording permission to the CI agent process. On macOS CI runners, this typically requires:

1. A logged-in GUI session (window server must be running).
2. The CI agent (or Terminal) added to the Screen Recording allow-list.
3. On macOS 14+, the system may prompt for ScreenCaptureKit permission separately from the legacy Screen Recording permission. Both must be granted.

**Symptom of missing permission**: `CGWindowListCreateImage` returns `nil`, causing `HarnessError.captureFailed("CGWindowListCreateImage returned nil")`. ScreenCaptureKit throws an authorization error on `SCStream.startCapture()`.

### Accessibility (Not Required)

The test harness does not use XCUITest or accessibility APIs. The app controls itself via the Unix domain socket protocol, so no accessibility permissions are needed.

## CI Configuration

### Requirements

| Requirement | Detail |
|-------------|--------|
| macOS version | macOS 14.0+ (Sonoma or later) |
| Xcode | Xcode 16.0+ with Swift 6 toolchain |
| Window server | A logged-in GUI session is required. Headless (SSH-only) runners will not work because `CGWindowListCreateImage` and `ScreenCaptureKit` require a window server. |
| Screen resolution | Retina display (2x scale factor). All spatial measurements assume 2x scaling. Non-Retina displays will produce different pixel dimensions and may cause spatial test failures. |
| Screen Recording | Permission granted to the CI agent/Terminal process |
| Disk space | Frame captures can produce significant temporary data. A 5-second capture at 60fps generates ~300 PNG frames. Ensure `/tmp` has adequate space. |

### CI Runner Setup

1. **Use a macOS runner with a GUI session**. GitHub Actions `macos-14` or `macos-15` runners provide this by default. Self-hosted runners must have a logged-in desktop session.

2. **Grant Screen Recording permission**. On GitHub Actions macOS runners, Screen Recording is typically pre-authorized for the runner agent. On self-hosted runners, manually add the CI agent to System Preferences > Privacy & Security > Screen Recording.

3. **Verify window server availability**:

```bash
# This should return a non-empty list if the window server is running
python3 -c "import Quartz; print(Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionAll, Quartz.kCGNullWindowID))"
```

4. **Build and test**:

```bash
swift build --product mkdn
swift test --filter UITest
```

5. **Collect artifacts**: The JSON report and captured images are written to deterministic paths. Collect them for post-run analysis:

```bash
# JSON report
cp .build/test-results/mkdn-ui-test-report.json $ARTIFACT_DIR/

# Captured images (if any failures need inspection)
cp -r /tmp/mkdn-captures/ $ARTIFACT_DIR/captures/ 2>/dev/null || true
cp -r /tmp/mkdn-frames/ $ARTIFACT_DIR/frames/ 2>/dev/null || true
```

### Tolerance Configuration

Test tolerances are defined as constants in the PRD files within `mkdnTests/UITest/`. To adjust tolerances for CI environments (where rendering may differ slightly from local development), modify these constants:

**Spatial tolerances** (`SpatialPRD.swift`):

| Constant | Default | Description |
|----------|---------|-------------|
| `spatialTolerance` | 1.0 pt | Maximum acceptable deviation for spatial measurements |
| `spatialColorTolerance` | 10 | RGB channel tolerance for background/content color detection |

**Visual tolerances** (`VisualPRD.swift`):

| Constant | Default | Description |
|----------|---------|-------------|
| `visualColorTolerance` | 10 | RGB channel tolerance for background color matching |
| `visualTextTolerance` | 15 | RGB channel tolerance for text color matching (wider due to anti-aliasing) |
| `visualSyntaxTolerance` | 25 | RGB channel tolerance for syntax token color detection (widest due to sub-pixel rendering variation) |

**Animation tolerances** (`AnimationPRD.swift`):

| Constant | Default | Description |
|----------|---------|-------------|
| `animTolerance30fps` | 33.3 ms | One frame at 30fps; timing accuracy threshold |
| `animTolerance60fps` | 16.7 ms | One frame at 60fps; timing accuracy threshold |
| `cpmRelativeTolerance` | 0.25 | 25% relative tolerance for breathing orb CPM measurement |
| `animOrbColorTolerance` | 30 | RGB channel tolerance for orb region detection |

**WKWebView rendering variation**: Mermaid diagrams render in WKWebView, which can produce slight visual differences across macOS versions and GPU configurations. Mermaid-related visual tests should use wider tolerances. The current test suite does not perform pixel-exact Mermaid comparison; it verifies Mermaid diagram presence and focus border behavior via frame analysis.

**Adjusting tolerances for CI**: If CI produces consistent failures at default tolerances, increase the relevant constant. For example, if text color matching fails due to different font rendering on the CI runner, increase `visualTextTolerance` from 15 to 20. Document any CI-specific tolerance overrides in this file.

## Known Limitations

### Capture Timing

- **IPC latency**: There is inherent latency between sending a command (e.g., `setTheme`) and the start of frame capture. Animation tests account for this with 3-frame tolerance for fade durations, but very short animations (under 100ms) may be difficult to capture precisely.
- **ScreenCaptureKit frame delivery**: Frame delivery is asynchronous and hardware-accelerated, but the actual frame rate may be slightly below the requested rate depending on system load. The calibration test verifies this before running timing-sensitive tests.

### Render Completion Detection

- The render completion signal is tied to `SelectableTextView.Coordinator.updateNSView`. This covers the main content rendering path but does not capture WKWebView Mermaid diagram rendering completion. Mermaid diagrams may still be loading when the render-complete signal fires.
- For Mermaid-dependent tests, an additional fixed delay after render completion may be necessary. This is a known gap; the harness does not yet provide a Mermaid-specific render completion signal.

### Platform Dependencies

- **Retina assumption**: All spatial measurements assume a 2x Retina display. Running tests on a non-Retina display will produce incorrect pixel-to-point conversions.
- **macOS version**: Font rendering, anti-aliasing, and color management can vary across macOS versions. Tests developed on one version may need tolerance adjustments when running on a different version.
- **Dark Mode / Appearance**: The test harness sets the theme explicitly via `setTheme` commands. The macOS system appearance (dark/light mode) should not affect results because mkdn uses its own theme system, but edge cases in system chrome rendering may exist.

### SpacingConstants Migration

Spatial compliance tests currently use hardcoded PRD values (e.g., `documentMargin = 32`) because `SpacingConstants.swift` does not yet exist. When `SpacingConstants` is implemented, the constants in `SpatialPRD.swift` should be replaced with references to the source-of-truth enum. Each constant has a migration comment documenting its future `SpacingConstants` name.

### Test Isolation

Each compliance suite shares a single app instance across all tests in the suite (via `SpatialHarness`, `VisualHarness`, or `AnimationHarness`). Tests within a suite run with the `.serialized` trait. Suites are independent and can run in parallel with separate app instances.

If a test leaves the app in an unexpected state (wrong theme, wrong file loaded), subsequent tests in the same suite may fail. The harness ensures known state by explicitly setting theme and loading files at the start of each test.

### Temporary File Cleanup

Captured images and frame sequences are written to `/tmp/` directories. These are not automatically cleaned up after test runs. In CI, add a cleanup step or configure the runner to periodically purge `/tmp/mkdn-captures/` and `/tmp/mkdn-frames/`.

## Harness Command Reference

All commands are sent as single-line JSON over the Unix domain socket at `/tmp/mkdn-test-harness-{pid}.sock`.

| Command | Parameters | Response Data | Triggers Render Wait |
|---------|------------|---------------|---------------------|
| `loadFile` | `path: String` | none | Yes |
| `switchMode` | `mode: "previewOnly" \| "sideBySide"` | none | Yes |
| `cycleTheme` | none | none | Yes |
| `setTheme` | `theme: "solarizedDark" \| "solarizedLight"` | none | Yes |
| `reloadFile` | none | none | Yes |
| `captureWindow` | `outputPath: String?` | `CaptureResult` | No |
| `captureRegion` | `region: CaptureRegion, outputPath: String?` | `CaptureResult` | No |
| `startFrameCapture` | `fps: Int, duration: Double, outputDir: String?` | `FrameCaptureResult` | No |
| `stopFrameCapture` | none | none | No |
| `getWindowInfo` | none | `WindowInfoResult` | No |
| `getThemeColors` | none | `ThemeColorsResult` | No |
| `setReduceMotion` | `enabled: Bool` | none | No |
| `ping` | none | `pong` | No |
| `quit` | none | none | No |

Commands that trigger render wait block until `RenderCompletionSignal` fires (or timeout). This ensures captures taken immediately after a command reflect the fully rendered state.
