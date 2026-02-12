# mkdn Code Patterns

## Observation Pattern

Use Swift's Observation framework (`@Observable`), NOT Combine's `ObservableObject`.

```swift
// CORRECT
@Observable
final class AppState {
    var viewMode: ViewMode = .previewOnly
}

// WRONG - do not use
class AppState: ObservableObject {
    @Published var viewMode: ViewMode = .previewOnly
}
```

Access in views:
```swift
@Environment(AppState.self) private var appState
```

For bindings:
```swift
@Bindable var state = appState
Picker("Mode", selection: $state.viewMode) { ... }
```

## Actor Pattern (Mermaid)

Use actors for thread-safe state with async interfaces:
```swift
actor MermaidRenderer {
    static let shared = MermaidRenderer()
    private var cache: [Int: String] = [:]

    func renderToSVG(_ code: String) async throws -> String { ... }
}
```

## Feature-Based MVVM

Each feature has its own directory with Views/ and ViewModels/:
```
Features/
  Viewer/
    Views/MarkdownPreviewView.swift
    ViewModels/PreviewViewModel.swift
```

## Variable-Width Overlay Pattern

Overlay views (hosted in `NSHostingView` over `NSTextAttachment` placeholders) can specify a `preferredWidth` to render narrower than the container width. Table overlays use this to left-align narrow tables without stretching to fill the container. Mermaid/image overlays leave `preferredWidth` as nil to use full container width (existing behavior).

```swift
// In OverlayEntry:
var preferredWidth: CGFloat?  // nil = containerWidth (default)

// In positionEntry:
let overlayWidth = entry.preferredWidth ?? context.containerWidth
```

## Theme Access

Always access theme via AppState in the environment:
```swift
@Environment(AppState.self) private var appState
let colors = appState.theme.colors
```

## Error Handling

Use typed errors with LocalizedError conformance:
```swift
enum MermaidError: LocalizedError {
    case invalidSVGData
    var errorDescription: String? { ... }
}
```

## Testing Pattern

Use Swift Testing, organize in @Suite structs. Unit tests live in `mkdnTests/Unit/`, UI compliance tests in `mkdnTests/UITest/`.

```swift
@Suite("MarkdownRenderer")
struct MarkdownRendererTests {
    @Test("Parses a heading")
    func parsesHeading() {
        let blocks = MarkdownRenderer.render(text: "# Hello", theme: .solarizedDark)
        #expect(!blocks.isEmpty)
    }
}
```

For UI compliance testing, see the **UI Test Pattern** section below.

## UI Test Pattern

UI compliance tests use a two-process harness: the test runner drives the app via Unix domain socket IPC. No XCUITest, no accessibility permissions for basic control.

### Suite Structure

Each compliance suite uses `@Suite(.serialized)` to ensure test ordering, shares one app instance via a harness singleton, and begins with a calibration gate:

```swift
@Suite("Spatial Compliance", .serialized)
struct SpatialComplianceTests {
    @Test("Calibration gate")
    func test_spatialDesignLanguage_calibration() async throws {
        let client = try await SpatialHarness.shared.client()
        _ = try await client.loadFile(path: fixturePath("geometry-calibration.md"))
        let response = try await client.captureWindow()
        // Validate measurement infrastructure accuracy
        // If this fails, downstream tests are skipped
    }

    @Test("Document margin")
    func test_documentMargin() async throws {
        // Uses ImageAnalyzer for pixel-level spatial measurement
    }
}
```

### Calibration-Gate Pattern

The first test in each suite validates capture infrastructure before running compliance assertions:
- **Spatial**: measurement accuracy within 1pt at Retina
- **Visual**: background color sampling matches ThemeColors exactly
- **Animation**: frame capture infrastructure + crossfade timing within 1 frame at 30fps

If calibration fails, remaining tests skip (not fail) to prevent false positives from broken infrastructure.

### Capture and Analysis

```swift
// Static capture -> pixel analysis
let response = try await client.captureWindow()
let image = loadCGImage(from: response)
let analyzer = ImageAnalyzer(image: image, scaleFactor: 2.0)
let color = analyzer.sampleColor(at: CGPoint(x: 10, y: 10))

// Frame capture -> animation analysis
let frameResponse = try await client.startFrameCapture(fps: 30, duration: 3.0)
let frames = loadFrames(from: frameResponse)
let frameAnalyzer = FrameAnalyzer(frames: frames, fps: 30, scaleFactor: 2.0)
let pulse = frameAnalyzer.measureOrbPulse(orbRegion: orbRect)
```

### PRD-Driven Assertions

Each test maps to a specific PRD functional requirement. Failures include the PRD reference, expected value, and actual measured value:

```swift
reporter.record(
    name: "spatial-design-language FR-2: documentMargin",
    status: measured == expected ? .pass : .fail,
    prdReference: "spatial-design-language FR-2",
    expected: "\(expected)",
    actual: "\(measured)"
)
```

## Animation Pattern

All animations use named primitives from `AnimationConstants`. Never use inline
`.animation(.easeInOut(duration: 0.3))` -- reference the named constant instead.

### Named Primitives

| Primitive | Type | Use |
|-----------|------|-----|
| `breathe` | Continuous | Orb core pulse, loading spinner |
| `haloBloom` | Continuous | Orb outer halo (phase-offset from breathe) |
| `springSettle` | Spring | Prominent entrances (overlays, focus borders) |
| `gentleSpring` | Spring | Layout transitions (mode switch, split pane) |
| `quickSettle` | Spring | Hover feedback, micro-interactions |
| `fadeIn` / `fadeOut` | Fade | Element appear/disappear |
| `crossfade` | Fade | State transitions (theme change, loading->rendered) |
| `quickFade` | Fade | Fast exits (popover dismiss, hover exit) |
| `quickShift` | Fade | Symmetric fast transitions (focus borders, state toggles) |

### MotionPreference (Reduce Motion)

Instantiate from the SwiftUI environment, then resolve primitives:
```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

private var motion: MotionPreference {
    MotionPreference(reduceMotion: reduceMotion)
}

// Resolve to standard or reduced alternative:
withAnimation(motion.resolved(.springSettle)) { ... }
```

Resolution rules:
- Continuous primitives (breathe, haloBloom) -> `nil` (disabled)
- Spring/fade primitives -> `reducedInstant` (0.01s)
- Crossfade -> `reducedCrossfade` (0.15s, preserves continuity)

Use `motion.allowsContinuousAnimation` to guard `onAppear` animation triggers.
Use `motion.staggerDelay` (returns 0 when RM on) for cascading entrances.

### Hover Modifiers

Two reusable hover feedback modifiers:
```swift
// Scale feedback for interactive elements (orbs, buttons):
.hoverScale()                                    // default 1.06
.hoverScale(AnimationConstants.toolbarHoverScale) // toolbar: 1.05

// Brightness feedback for content areas (Mermaid diagrams):
.hoverBrightness()  // 0.03 white overlay
```

Both use `quickSettle` animation and disable animation (not feedback) for RM.

## Anti-Patterns

- **NO WKWebView** -- ever, for any reason
- **NO ObservableObject** -- use @Observable
- **NO force unwrapping** in production code (tests are OK)
- **NO implicit returns** from complex expressions
- **NO magic numbers** in business logic (UI layout constants are acceptable)
