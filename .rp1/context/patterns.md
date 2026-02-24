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

### Screen Theme (via AppState)

Always access the screen theme via AppState in the environment:
```swift
@Environment(AppState.self) private var appState
let colors = appState.theme.colors
```

### Print Palette (direct static)

The print palette is accessed directly via static properties -- it is not an `AppTheme` case and is never selected by the user:
```swift
let colors = PrintPalette.colors
let syntaxColors = PrintPalette.syntaxColors
```

`PrintPalette` is a fixed, theme-independent palette (white background, black text, ink-efficient syntax colors) applied automatically when the user prints via Cmd+P. It bypasses `AppState` entirely -- the on-screen theme is never consulted or modified during print.

## Error Handling

Use typed errors with LocalizedError conformance:
```swift
enum MermaidError: LocalizedError {
    case invalidSVGData
    var errorDescription: String? { ... }
}
```

## Testing Pattern

Use Swift Testing, organize in @Suite structs. Unit tests live in `mkdnTests/Unit/`.

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

## Dual-Layer Table Rendering Pattern

Tables use a dual-layer approach: invisible text in `NSTextStorage` provides selection, find, and clipboard semantics, while a SwiftUI `TableBlockView` overlay provides the visual rendering. A third `TableHighlightOverlay` draws cell-level selection and find feedback on top.

### Invisible Text Layer (NSTextStorage)

Table cell content is written as tab-separated, newline-delimited text with `.foregroundColor: NSColor.clear` so it participates in TextKit 2 selection, find, and clipboard operations without being visible. Custom attributes mark the text:

```swift
// TableAttributes -- mirrors CodeBlockAttributes pattern
TableAttributes.range    // unique String ID per table (UUID)
TableAttributes.cellMap  // TableCellMap instance (cell geometry + lookup)
TableAttributes.colors   // TableColorInfo (resolved NSColor values)
TableAttributes.isHeader // NSNumber(booleanLiteral: true) on header row
```

### TableCellMap (Cell Geometry + Lookup)

`TableCellMap` is an `NSObject` subclass stored as an attributed string attribute on every character in the table's invisible text. It provides:

- **O(log n) cell lookup**: binary search on sorted cell start positions (`cellAt(offset:)`)
- **Range intersection**: selected character range to set of cell positions (`cellsInRange(_:)`)
- **Content extraction**: tab-delimited plain text and RTF table data for clipboard (`tabDelimitedText(for:)`, `rtfData(for:colors:)`)
- **Geometry**: `columnWidths`, `rowHeights` (index 0 = header), `columnCount`, `rowCount`

### Visual Overlay Layer (TableBlockView)

The existing SwiftUI `TableBlockView` is hosted in `NSHostingView` and positioned by `OverlayCoordinator` using text-range-based positioning (bounding rect of layout fragments matching the table's `TableAttributes.range`). This replaces attachment-based positioning.

### Highlight Overlay Layer (TableHighlightOverlay)

A lightweight `NSView` sibling positioned identically to the visual overlay, on top of it. Draws cell rectangles computed from `TableCellMap.columnWidths` and `rowHeights`. All mouse events pass through (`hitTest` returns `nil`).

### Copy Override

`CodeBlockBackgroundTextView.copy(_:)` detects `TableAttributes.cellMap` in the selection, extracts selected cells via `TableCellMap`, and writes both RTF table data and tab-delimited plain text to `NSPasteboard`. Non-table portions of the selection are passed through as-is.

### Print Path

During `Cmd+P`, the builder's `isPrint: true` flag makes table text visible (non-clear foreground). `CodeBlockBackgroundTextView+TablePrint.swift` draws table containers (border, header fill, alternating rows) via `NSBezierPath` in `drawBackground`, matching the `CodeBlockBackgroundTextView` code block container pattern.

## Inline Math Rendering Pattern

Inline math (`$...$`) uses a three-stage pipeline: detection, attribution, and rendering.

### Detection (MarkdownVisitor)

A character state machine in `MarkdownVisitor` detects `$...$` delimiters during inline text conversion. The state machine handles edge cases: escaped dollars (`\$`), double-dollar (`$$`) for display math, and rejection of empty or whitespace-only expressions. When a valid inline math span is found, it is marked with the `mathExpression` attribute rather than emitted as plain text.

### Attribution (MathAttributes)

`MathAttributes.swift` defines a custom `NSAttributedString.Key` (`mathExpression`) that stores the original LaTeX string. This follows the same pattern as `CodeBlockAttributes` and `TableAttributes` -- a custom key carrying domain-specific data through the attributed string pipeline.

```swift
// MathAttributes -- custom key for inline math
extension NSAttributedString.Key {
    static let mathExpression: NSAttributedString.Key  // stores LaTeX string
}
```

### Rendering (TextStorageBuilder)

`MarkdownTextStorageBuilder` detects `mathExpression` attributes in inline content and renders them:

1. Calls `MathRenderer` to convert the LaTeX string to an `NSImage` (via SwiftMath's CoreGraphics/CoreText backend)
2. Creates an `NSTextAttachment` with the rendered image
3. Applies baseline alignment via a descent offset so the math expression aligns vertically with surrounding text
4. Inserts the attachment character into the attributed string in place of the LaTeX source

This mirrors the image attachment pattern but with baseline-aware vertical positioning to ensure math expressions sit correctly on the text baseline.

## Anti-Patterns

- **NO WKWebView** -- ever, for any reason
- **NO ObservableObject** -- use @Observable
- **NO force unwrapping** in production code (tests are OK)
- **NO implicit returns** from complex expressions
- **NO magic numbers** in business logic (UI layout constants are acceptable)
- **NO reading displayed text for code block copy** -- use the `CodeBlockAttributes.rawCode` attribute which stores the original unformatted code string. Reading `textStorage.string` from the visible range would include the language label line and trailing newlines, producing wrong clipboard content. The `rawCode` attribute is set once during `appendCodeBlock` and read by `CodeBlockBackgroundTextView.copyCodeBlock(at:)` via `textStorage.attribute(CodeBlockAttributes.rawCode, at:, effectiveRange:)`
