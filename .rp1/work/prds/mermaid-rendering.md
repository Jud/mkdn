# PRD: mermaid-rendering

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-06

## Surface Overview

The mermaid-rendering surface is the native Mermaid diagram rendering pipeline within mkdn. It converts Mermaid diagram code blocks found in Markdown documents into native SwiftUI images entirely in-process, with no WKWebView.

**Pipeline**: Mermaid text -> JavaScriptCore (JXKit) + beautiful-mermaid.js (pure JS, no WASM) -> SVG string -> SwiftDraw -> NSImage -> SwiftUI Image.

**Key design decisions**:
- Actor singleton (`MermaidRenderer`) with SVG string cache keyed by source hash
- Async rendering with loading spinner, error states, and graceful degradation
- `MermaidBlockView` provides `MagnifyGesture` pinch-to-zoom (0.5x-4.0x) and two-finger scroll on rendered diagrams
- Supported diagram types: flowchart, sequence, state, class, ER
- WASM was investigated and ruled out -- string-heavy workload is JSC's strength, not WASM's
- JXContext is created per-render call (stateless); the beautiful-mermaid.js bundle is loaded from app resources

## Scope

### In Scope
- Full native rendering pipeline: Mermaid text -> JavaScriptCore (JXKit) + beautiful-mermaid.js -> SVG string -> SwiftDraw -> NSImage -> SwiftUI Image
- Actor singleton (`MermaidRenderer`) with SVG string cache keyed by source hash
- Supported diagram types: flowchart, sequence, state, class, ER
- Async rendering with loading spinner and error state UI (`MermaidBlockView`)
- Graceful degradation on render failure (error view with message)
- `MagnifyGesture` pinch-to-zoom (0.5x to 4.0x range) on rendered diagrams
- Two-finger scroll (horizontal + vertical `ScrollView`) on rendered diagrams
- Theme-aware background colors on diagram containers

### Out of Scope
- WASM-based rendering (investigated and ruled out -- string-heavy workload is JSC's strength)
- WKWebView-based rendering (project-wide constraint)
- Interactive/editable diagrams (click-to-edit nodes, drag-to-rearrange)
- Diagram types beyond the five listed (gantt, pie, journey, gitgraph, etc.)
- Exporting rendered diagrams as standalone image files
- Server-side or cloud rendering

## Requirements

### Functional Requirements

1. **Rendering pipeline**: `MermaidRenderer` actor converts Mermaid text to SVG via JXKit/JavaScriptCore + beautiful-mermaid.js, then SwiftDraw rasterizes SVG to NSImage for display as a SwiftUI Image.
2. **Caching**: SVG string cache keyed by source hash within the actor, with a `clearCache()` method.
3. **JXContext lifecycle**: Fresh JXContext per render call (stateless); the beautiful-mermaid.js bundle is loaded from Bundle.main resources each time.
4. **Async rendering with UI states**: `.task` modifier for async rendering. Three states: loading (ProgressView spinner), success (rendered image), error (warning icon + error message).
5. **Gestures**: `MagnifyGesture` for pinch-to-zoom clamped to 0.5x-4.0x range. `ScrollView([.horizontal, .vertical])` for two-finger panning within the diagram.
6. **Scroll isolation (critical)**: Mermaid diagrams must NEVER capture/hijack the parent document scroll. When a user is scrolling the Markdown document top-to-bottom, their scroll must pass through diagram views without getting trapped. Diagram-internal scrolling/panning should require explicit activation (e.g., clicking the diagram first, or entering a focused interaction mode). This is a first-class UX requirement.
7. **Theme integration**: Diagram container backgrounds use `appState.theme.colors.backgroundSecondary`. Text colors use `foregroundSecondary`.
8. **Error model**: `MermaidError` enum with cases `invalidSVGData`, `svgRenderingFailed`, `javaScriptError(String)`, all conforming to `LocalizedError`.
9. **Supported diagrams**: flowchart, sequence, state, class, ER.

### Non-Functional Requirements

1. **Performance**: Rendering should feel near-instant for typical diagrams. Optimize for speed at every stage of the pipeline. SVG caching avoids redundant re-renders. Consider reusing the JXContext across renders to avoid repeated JS bundle loading.
2. **Memory footprint**: Minimize memory usage. SVG cache should have a bounded size with eviction policy (LRU or count-limited) to prevent unbounded growth. Release NSImage/SVG data when diagrams scroll off-screen.
3. **Reliability**: Graceful degradation on JS errors -- never crash the app, always show an error state with a meaningful message.
4. **Thread safety**: Actor isolation ensures no data races on the cache or JSContext.

## Dependencies & Constraints

### External Dependencies (SPM)
- **JXKit** -- Swift-friendly wrapper around JavaScriptCore for evaluating JS in-process
- **SwiftDraw** -- SVG parsing and rasterization to NSImage

### Bundled Resources
- **beautiful-mermaid.js** (`mermaid.min.js`) -- zero-DOM Mermaid rendering library, loaded from Bundle.main at render time

### Internal Dependencies
- **apple/swift-markdown** -- upstream Markdown parser that identifies mermaid code blocks to feed into this pipeline
- **AppState.theme** -- theme colors used for diagram container backgrounds

### Constraints
- No WKWebView (project-wide architectural constraint)
- No WASM (investigated and ruled out -- string-heavy workload favors JSC)
- macOS 14.0+ / Swift 6 strict concurrency (actor isolation on MermaidRenderer)
- JXContext created fresh per render call (stateless JS execution)
- SVG cache currently unbounded (eviction policy is an NFR gap to address)

## Milestones

### Phase 1: Basic Pipeline Wiring
- JXKit integration with beautiful-mermaid.js
- `MermaidRenderer` actor with `renderToSVG()` -- Mermaid text in, SVG string out
- Unit tests for SVG output correctness across all 5 diagram types

### Phase 2: SwiftDraw Rasterization + SwiftUI Display
- SwiftDraw SVG -> NSImage conversion via `renderToImage()`
- `MermaidBlockView` with basic async rendering (`.task` modifier)
- Loading spinner and error state UI

### Phase 3: Caching + Error Handling
- SVG string cache keyed by source hash
- Bounded cache with eviction policy (LRU or count-limited)
- `MermaidError` typed errors with `LocalizedError` conformance
- Graceful degradation -- never crash, always show error state

### Phase 4: Gesture Support + Scroll Isolation
- `MagnifyGesture` pinch-to-zoom (0.5x-4.0x)
- Two-finger scroll/pan within diagram (activated only on explicit click/focus)
- **Scroll isolation**: document scroll must never be captured by diagram views
- Theme-aware background colors on diagram containers

### Phase 5: Performance Optimization
- JXContext reuse across renders (avoid repeated JS bundle loading)
- JIT warmup -- keep context alive for JSC's DFG/FTL compilers
- Memory footprint audit -- release NSImage/SVG data for off-screen diagrams
- Cache eviction tuning

## Open Questions

- Optimal cache eviction strategy (LRU vs. count-limited) and size bounds
- Exact scroll isolation UX: click-to-focus vs. hover-to-activate vs. modifier-key approach
- Whether JXContext reuse (Phase 5) introduces memory pressure that offsets JIT benefits

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A1 | beautiful-mermaid.js works in JavaScriptCore without DOM | Must find or create a DOM-free Mermaid renderer | Will Do: Mermaid rendering |
| A2 | SwiftDraw handles all SVG output from beautiful-mermaid | Some SVG features may not render; need fallback or SVG cleanup | Will Do: Native rendering |
| A3 | JSC string-heavy performance beats WASM for this workload | May need to revisit WASM approach if perf is poor | Won't Do: WASM |
| A4 | Five diagram types cover the majority of developer use cases | Users may request gantt, pie, journey charts | Will Do: 5 diagram types |
| A5 | Scroll isolation is achievable with SwiftUI gesture system | May need AppKit interop or custom NSScrollView subclass | Will Do: Native gestures |
