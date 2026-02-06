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

## Anti-Patterns

- **NO WKWebView** -- ever, for any reason
- **NO ObservableObject** -- use @Observable
- **NO force unwrapping** in production code (tests are OK)
- **NO implicit returns** from complex expressions
- **NO magic numbers** in business logic (UI layout constants are acceptable)
