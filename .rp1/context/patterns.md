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

Use Swift Testing, organize in @Suite structs:
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
