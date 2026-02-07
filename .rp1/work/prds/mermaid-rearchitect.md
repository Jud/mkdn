# PRD: Mermaid Re-Architect

**Charter**: [Project Charter](../../context/charter.md)
**Supersedes**: [mermaid-rendering.md](mermaid-rendering.md) (to be archived)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-07

## Surface Overview

Ground-up redesign of Mermaid diagram rendering in mkdn. The existing pipeline (JavaScriptCore + beautiful-mermaid.js + SwiftDraw SVG rasterization + custom gesture handling) is replaced entirely with a WKWebView-per-diagram approach.

Each Mermaid code block in a rendered Markdown document gets its own WKWebView instance that loads standard Mermaid.js. The WKWebView renders the diagram directly in a web context where Mermaid.js works natively, eliminating the fragile JSC + SVG + SwiftDraw chain.

The rest of the app remains fully native SwiftUI. WKWebView is used exclusively for Mermaid diagram rendering -- nowhere else.

**Key design decisions**:
- Simplicity and working > architectural purity
- The original charter's "No WKWebView" constraint is explicitly relaxed for Mermaid diagrams only
- All existing Mermaid/gesture code is deleted -- clean slate
- Standard Mermaid.js replaces beautiful-mermaid.js
- Diagrams respect the app's Solarized Dark/Light theme via the HTML template

## Scope

### In Scope
- WKWebView-per-diagram rendering: each Mermaid code block gets its own WKWebView that loads standard Mermaid.js
- Supported diagram types: flowchart, sequence, state, class, ER
- Theme-aware rendering: WKWebView HTML template applies Solarized Dark/Light colors matching the current app theme
- Simple interaction model: scroll events pass through diagrams to the document by default; clicking a diagram focuses it for interaction (pinch-to-zoom, two-finger pan); Escape or click-outside unfocuses; subtle visual indicator for focus state
- Deletion of all existing Mermaid and gesture files (clean slate):
  - `mkdn/Core/Mermaid/MermaidRenderer.swift`
  - `mkdn/Core/Mermaid/SVGSanitizer.swift`
  - `mkdn/Core/Mermaid/MermaidCache.swift`
  - `mkdn/Core/Mermaid/MermaidImageStore.swift`
  - `mkdn/UI/Components/ScrollPhaseMonitor.swift`
  - `mkdn/Core/Gesture/GestureIntentClassifier.swift`
  - `mkdn/Core/Gesture/DiagramPanState.swift`
- Deletion of corresponding test files
- Removal of SwiftDraw dependency and beautiful-mermaid.js bundle resource
- New `MermaidBlockView` using WKWebView
- Updates to `Package.swift` to remove SwiftDraw and mermaid.min.js resource

### Out of Scope
- Interactive/editable diagrams (click-to-edit nodes, drag-to-rearrange)
- Diagram types beyond the five listed (gantt, pie, journey, gitgraph, mindmap, etc.)
- Exporting rendered diagrams as standalone image files
- Server-side or cloud rendering
- Using WKWebView for anything other than Mermaid diagrams
- Complex gesture systems or scroll-trapping prevention heuristics

## Requirements

### Functional Requirements

1. **WKWebView per diagram**: Each Mermaid code block is rendered in its own `WKWebView` instance wrapped in an `NSViewRepresentable`. The WKWebView loads an HTML template containing standard Mermaid.js and the diagram source.

2. **HTML template**: A self-contained HTML template that:
   - Loads Mermaid.js (bundled locally or from CDN with local fallback)
   - Receives the Mermaid code block text and renders it
   - Accepts theme colors (background, foreground, line/edge colors) as CSS variables or Mermaid configuration to match Solarized Dark/Light
   - Reports the rendered diagram's natural size back to Swift via `WKScriptMessageHandler` so the hosting view can size the WKWebView correctly
   - Has a transparent or theme-matching background

3. **Theme integration**: The HTML template applies colors matching the current `AppTheme` (Solarized Dark or Solarized Light). At minimum: background color, text/label color, line/edge color, node fill color. The Mermaid.js `initialize()` call should use a `theme` and `themeVariables` configuration derived from `ThemeColors`.

4. **Scroll pass-through (default state)**: By default, scroll wheel events on a diagram pass through to the parent document scroll. The WKWebView should not capture scroll events in its unfocused state. The simplest approach that avoids scroll trapping.

5. **Click-to-focus interaction**: Clicking a diagram focuses it, enabling pinch-to-zoom and two-finger pan within the WKWebView. A subtle visual indicator (e.g., a thin accent-colored border or slight glow) shows focus state. Pressing Escape or clicking outside the diagram unfocuses it and returns scroll control to the document.

6. **Async rendering with UI states**: Show a loading state while the WKWebView initializes and Mermaid.js renders the diagram. Show an error state if rendering fails. Match the existing loading/error UI style (ProgressView spinner, warning icon + message).

7. **Auto-sizing**: The WKWebView should size itself to fit the rendered diagram's natural dimensions (reported via JS message handler), up to a maximum height. No fixed 400px box -- let diagrams be as tall as they need to be, with a sensible max.

8. **Supported diagrams**: flowchart, sequence, state, class, ER.

9. **Error handling**: Graceful degradation on render failure. Mermaid.js parse errors should be caught and displayed in the error state view. Never crash the app.

10. **Diagram re-rendering on theme change**: When the user switches themes, diagrams should re-render with the new theme colors. This can be done by re-evaluating JS in the existing WKWebView or by reloading the HTML template.

### Non-Functional Requirements

1. **Simplicity**: The implementation should be as simple as possible. Avoid over-engineering. WKWebView handles rendering, scrolling, and zooming natively -- lean on that rather than building custom gesture systems.

2. **Performance**: WKWebView creation has overhead. For documents with many diagrams, consider lazy initialization (only create WKWebView when the diagram scrolls into view). Standard Mermaid.js rendering should be fast for typical diagrams.

3. **Memory**: Each WKWebView has a non-trivial memory footprint. For documents with many diagrams, consider releasing WKWebViews for off-screen diagrams and re-creating them on scroll-back. This is a stretch goal -- get it working first.

4. **Reliability**: WKWebView is a battle-tested web rendering engine. Standard Mermaid.js is the canonical implementation. This should be more reliable than the JSC + beautiful-mermaid + SwiftDraw chain.

5. **macOS 14.0+ / Swift 6**: Use `@preconcurrency import WebKit` if needed for Sendable conformance. WKWebView must be created and used on the main actor.

## Dependencies & Constraints

### Dependencies to Add
- **WebKit framework** (system framework) -- `WKWebView`, `WKScriptMessageHandler`, `WKUserContentController`
- **Mermaid.js** -- standard Mermaid.js library, bundled as a local resource with CDN fallback option

### Dependencies to Remove
- **SwiftDraw** (SPM) -- only used for Mermaid SVG rasterization; remove from `Package.swift`
- **beautiful-mermaid.js** (`mkdn/Resources/mermaid.min.js`) -- delete the file and remove `.copy("Resources/mermaid.min.js")` from `Package.swift`

### Dependencies to Keep
- **apple/swift-markdown** -- still used for Markdown parsing and identifying mermaid code blocks
- **AppState / AppSettings** -- theme colors used to configure the WKWebView HTML template

### Constraints
- WKWebView is used for Mermaid diagrams only -- the rest of the app remains fully native SwiftUI
- macOS 14.0+ / Swift 6 strict concurrency
- WKWebView must be created and interacted with on `@MainActor`

## Milestones

### Phase 1: Teardown
- Delete all existing Mermaid and gesture files (7 source files + test files)
- Remove SwiftDraw from `Package.swift`
- Remove `mermaid.min.js` resource from `Package.swift` and delete the file
- Remove dead imports or references in remaining files
- Verify the app builds with Mermaid blocks showing a placeholder/fallback

### Phase 2: Basic WKWebView Rendering
- Create `MermaidWebView` (`NSViewRepresentable` wrapping `WKWebView`)
- Create HTML template with bundled Mermaid.js
- Wire into `MermaidBlockView` (or replace it)
- Basic rendering of all 5 diagram types
- Loading spinner and error state UI
- JS-to-Swift message handler for reporting rendered size
- Auto-sizing the WKWebView to fit diagram content

### Phase 3: Theme Integration
- Pass Solarized Dark/Light colors into the HTML template
- Configure Mermaid.js `initialize()` with `themeVariables` matching `ThemeColors`
- Re-render diagrams on theme change
- Verify visual quality across both themes and all 5 diagram types

### Phase 4: Scroll & Interaction Polish
- Implement scroll pass-through in unfocused state
- Click-to-focus with subtle visual indicator
- Escape / click-outside to unfocus
- Verify pinch-to-zoom and two-finger pan work in focused state
- Test that document scrolling is never captured by unfocused diagrams

### Phase 5: Cleanup & Testing
- Write tests for the new implementation (HTML template generation, theme color mapping, error handling)
- Archive the old `mermaid-rendering.md` PRD
- Update charter/CLAUDE.md to note the WKWebView exception for Mermaid
- Final QA pass across diagram types and themes

## Open Questions

- **Mermaid.js delivery**: Bundle locally vs. CDN with local fallback. Bundling is simpler and works offline. Recommend: bundle locally.
- **WKWebView pool/reuse**: For documents with many diagrams, should we pool WKWebViews? Start simple (one per diagram), optimize later if needed.
- **Diagram max height**: Sensible maximum height before internal scrolling? Let implementation decide based on testing.

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A1 | Standard Mermaid.js renders correctly in WKWebView on macOS 14+ | Extremely low risk -- this is Mermaid's native environment | Will Do: Mermaid rendering |
| A2 | WKWebView scroll events can be passed through to parent SwiftUI scroll in unfocused state | May need NSEvent override or hitTest customization; fallback is disabling WKWebView scroll entirely when unfocused | Will Do: Native gestures |
| A3 | Memory overhead of multiple WKWebViews is acceptable for typical documents (1-5 diagrams) | For diagram-heavy docs, may need lazy init / off-screen teardown | Performance NFR |
| A4 | SwiftDraw is only used for Mermaid rendering and can be fully removed | If used elsewhere, keep in Package.swift | Dependency cleanup |
| A5 | Five diagram types cover majority of developer use cases | Standard Mermaid.js supports all types, so adding more is trivial | Will Do: 5 diagram types |

## Discoveries

- **Codebase Discovery**: JXKit was referenced in KB documentation (modules.md, architecture.md) but was never added to Package.swift; the codebase used `import JavaScriptCore` (system framework) directly. -- *Ref: [field-notes.md](../archives/features/mermaid-rearchitect/field-notes.md)*
- **Codebase Discovery**: `MermaidError` enum was co-located inside `MermaidRenderer.swift` rather than in its own file; deleting the renderer also deleted the error type. -- *Ref: [field-notes.md](../archives/features/mermaid-rearchitect/field-notes.md)*
- **Design Deviation**: HTML template uses three substitution tokens (`__MERMAID_CODE__`, `__MERMAID_CODE_JS__`, `__THEME_VARIABLES__`) instead of the two specified in design, to distinguish HTML escaping from JS escaping. -- *Ref: [field-notes.md](../archives/features/mermaid-rearchitect/field-notes.md)*
- **Codebase Discovery**: Pre-existing SwiftLint violations exist in `DocumentWindow.swift`, `MarkdownPreviewView.swift`, and `MarkdownBlockView.swift` that are unrelated to Mermaid work. -- *Ref: [field-notes.md](../archives/features/mermaid-rearchitect/field-notes.md)*
