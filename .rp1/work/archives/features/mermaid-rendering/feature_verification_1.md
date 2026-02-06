# Feature Verification Report #1

**Generated**: 2026-02-06T19:42Z
**Feature ID**: mermaid-rendering
**Verification Scope**: all
**KB Context**: Loaded (index.md, patterns.md)
**Field Notes**: Not available

## Executive Summary
- Overall Status: PARTIAL
- Acceptance Criteria: 28/37 verified (76%)
- Implementation Quality: HIGH
- Ready for Merge: NO

The core rendering pipeline (detection, SVG conversion, rasterization, caching, error handling) is fully implemented and verified through code review and passing tests. The UI layer (MermaidBlockView) is implemented with correct architecture for scroll isolation, zoom, and activation gating. However, 5 acceptance criteria require manual/device testing to confirm (gesture feel, scroll behavior), and 4 criteria related to integration testing of the full JS rendering pipeline (5 diagram types producing SVG) cannot be verified without the beautiful-mermaid.js bundle loaded at test time. Documentation update tasks (TD1, TD2, TD3) remain incomplete.

## Field Notes Context
**Field Notes Available**: No

### Documented Deviations
None -- no field-notes.md exists.

### Undocumented Deviations
1. **MermaidBlockView activated state uses frame-based sizing instead of scaleEffect**: The design specifies `.scaleEffect(zoomScale)` for the activated state, but the implementation uses `frame(width: image.size.width * zoomScale, height: image.size.height * zoomScale)`. This is noted in the T3 implementation summary as an intentional choice for proper ScrollView content sizing, but it is not documented in a field-notes.md file.

2. **MermaidBlockView uses `svgStringToImage` local helper in addition to `MermaidRenderer.renderToImage`**: The view calls `renderToSVG` and then uses a local `svgStringToImage` function rather than calling `renderToImage` directly. This duplicates some conversion logic but gives the view control over `@MainActor` isolation for the rasterization step. Not documented as a deviation.

## Acceptance Criteria Verification

### FR-MER-001: Mermaid Block Detection
**AC1**: A fenced code block tagged with ` ```mermaid ` is identified as a Mermaid block.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownVisitor.swift`:25-31 - `convertBlock(_:)`
- Evidence: Lines 25-31 check `codeBlock.language?.lowercased()` against `"mermaid"` and return `.mermaidBlock(code: code)`. The `.lowercased()` call ensures case-insensitive matching.
- Field Notes: N/A
- Issues: None

**AC2**: The raw Mermaid source text is extracted and passed to the rendering pipeline.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownVisitor.swift`:26-29, `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownBlockView.swift`:36-37, `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:12,146
- Evidence: `MarkdownVisitor` extracts `codeBlock.code` and stores it in `.mermaidBlock(code:)`. `MarkdownBlockView` passes the code to `MermaidBlockView(code: code)`. `MermaidBlockView.renderDiagram()` calls `MermaidRenderer.shared.renderToSVG(code)`.
- Field Notes: N/A
- Issues: None

**AC3**: Non-mermaid code blocks are unaffected and continue to render as syntax-highlighted code.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownVisitor.swift`:28-31
- Evidence: The `if language == "mermaid"` check only matches mermaid; all other languages fall through to `return .codeBlock(language: language, code: code)` at line 31. `MarkdownBlockView` routes `.codeBlock` to `CodeBlockView` (line 34).
- Field Notes: N/A
- Issues: None

### FR-MER-002: Mermaid-to-SVG Conversion
**AC1**: Valid flowchart Mermaid syntax produces a well-formed SVG string.
- Status: PARTIAL (MANUAL_REQUIRED)
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift`:39-75 - `renderToSVG(_:)`
- Evidence: The rendering pipeline is correctly wired: validates input, checks cache, creates/reuses JXContext, loads beautiful-mermaid.js, escapes input, calls `renderMermaid()` JS function, and caches result. The code path for flowchart (`graph`/`flowchart` keywords) passes validation (lines 25-28 show these as supported types). However, actual SVG production requires the JS bundle and cannot be verified in unit tests.
- Field Notes: N/A
- Issues: Requires integration test with beautiful-mermaid.js bundle to confirm SVG output.

**AC2**: Valid sequence diagram syntax produces a well-formed SVG string.
- Status: PARTIAL (MANUAL_REQUIRED)
- Implementation: Same as AC1 - `sequenceDiagram` is in `supportedTypes` set (line 27)
- Evidence: Keyword passes validation; full pipeline identical to flowchart. Requires JS bundle for actual verification.
- Field Notes: N/A
- Issues: Same as AC1.

**AC3**: Valid state diagram syntax produces a well-formed SVG string.
- Status: PARTIAL (MANUAL_REQUIRED)
- Implementation: Same as AC1 - `stateDiagram` and `stateDiagram-v2` are in `supportedTypes` set (line 28)
- Evidence: Keywords pass validation; full pipeline identical to flowchart. Requires JS bundle for actual verification.
- Field Notes: N/A
- Issues: Same as AC1.

**AC4**: Valid class diagram syntax produces a well-formed SVG string.
- Status: PARTIAL (MANUAL_REQUIRED)
- Implementation: Same as AC1 - `classDiagram` is in `supportedTypes` set (line 29)
- Evidence: Keyword passes validation; full pipeline identical to flowchart. Requires JS bundle for actual verification.
- Field Notes: N/A
- Issues: Same as AC1.

**AC5**: Valid ER diagram syntax produces a well-formed SVG string.
- Status: PARTIAL (MANUAL_REQUIRED)
- Implementation: Same as AC1 - `erDiagram` is in `supportedTypes` set (line 29)
- Evidence: Keyword passes validation; full pipeline identical to flowchart. Requires JS bundle for actual verification.
- Field Notes: N/A
- Issues: Same as AC1.

**AC6**: The JavaScript execution occurs entirely in-process with no network calls or external processes.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift`:98-126 - `getOrCreateContext()`
- Evidence: Uses `JXContext()` (JavaScriptCore in-process context) with no network configuration. The JS source is loaded from `Bundle.module` local resource (`mermaid.min.js`). JXKit wraps JavaScriptCore which is sandboxed with no network/filesystem access by default. No `URLSession`, `Process`, or other external communication APIs are used anywhere in the Mermaid pipeline.
- Field Notes: N/A
- Issues: None

### FR-MER-003: SVG-to-Native-Image Rasterization
**AC1**: A valid SVG string is rasterized into a displayable native image.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift`:78-87 - `renderToImage(_:)`, `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:162-166 - `svgStringToImage(_:)`
- Evidence: Both paths convert SVG string to `Data`, create `SwiftDraw.SVG(data:)`, and call `.rasterize()` to produce `NSImage`. The view uses this via `svgStringToImage` at line 147.
- Field Notes: N/A
- Issues: None

**AC2**: The resulting image preserves visual fidelity of the original SVG (lines, text, shapes, colors).
- Status: PARTIAL (MANUAL_REQUIRED)
- Implementation: SwiftDraw library handles SVG fidelity
- Evidence: SwiftDraw is the industry-standard Swift SVG rasterizer. Visual fidelity depends on SwiftDraw's SVG feature coverage and beautiful-mermaid's SVG output compatibility. Cannot be verified without visual inspection.
- Field Notes: N/A
- Issues: Requires manual visual inspection of rendered diagrams.

**AC3**: The image is displayed inline within the Markdown document at the position of the original Mermaid code block.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`:13-18, `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownBlockView.swift`:36-37
- Evidence: `MarkdownPreviewView` renders blocks in a `LazyVStack` via `ForEach(blocks)`. Each `.mermaidBlock` is routed to `MermaidBlockView` by `MarkdownBlockView` at its natural position in the block sequence. The `LazyVStack` preserves document order.
- Field Notes: N/A
- Issues: None

### FR-MER-004: Rendering State UI
**AC1**: A loading spinner is displayed while rendering is in progress.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:25-26, 112-123 - `loadingView`
- Evidence: `isLoading` starts as `true` (line 17). The body checks `if isLoading { loadingView }` (line 25). `loadingView` renders a `ProgressView()` with `.controlSize(.small)` and "Rendering diagram..." text. The loading state is cleared after render completes at line 158.
- Field Notes: N/A
- Issues: None

**AC2**: On successful render, the spinner is replaced by the rendered diagram image.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:27-28, 143-158 - `renderDiagram()`
- Evidence: After successful render, `renderedImage` is set (line 148) and `isLoading` is set to `false` (line 158). The body conditionally shows `diagramView(image:)` when `renderedImage` is non-nil and `isLoading` is false (lines 25-28).
- Field Notes: N/A
- Issues: None

**AC3**: On render failure, a warning icon and a human-readable error message are displayed.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:29-30, 125-139 - `errorView(message:)`
- Evidence: On error, `errorMessage` is set (line 151 or 155) and `renderedImage` is nil. The body shows `errorView(message:)` which displays `Image(systemName: "exclamationmark.triangle")` (warning icon, line 127) and the error message text (line 133).
- Field Notes: N/A
- Issues: None

**AC4**: The error message includes enough context to help the user identify the problem in their Mermaid source.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift`:148-172 - `MermaidError.errorDescription`
- Evidence: Each error case provides contextual descriptions: `.emptyInput` says "Add a diagram type and definition", `.unsupportedDiagramType` names the type and lists supported types, `.javaScriptError` includes the JS error message, `.contextCreationFailed` includes the underlying reason. Tests verify these messages contain relevant details (MermaidRendererTests lines 106-135).
- Field Notes: N/A
- Issues: None

### FR-MER-005: SVG Cache
**AC1**: Rendering the same Mermaid source text a second time returns the cached SVG without re-executing JavaScript.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift`:47-51
- Evidence: Before JS execution, the renderer checks `cache.get(cacheKey)` (line 49). If a cached value exists, it returns immediately (line 50) without calling `getOrCreateContext()` or evaluating JS. The cache key is computed via `mermaidStableHash(mermaidCode)` (line 48). Unit tests confirm get/set behavior (`MermaidCacheTests.basicGetSet`).
- Field Notes: N/A
- Issues: None

**AC2**: Changing the Mermaid source text (even by one character) results in a cache miss and a fresh render.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidCache.swift`:74-80 - `mermaidStableHash(_:)`
- Evidence: DJB2 hash operates on individual UTF-8 bytes, so any character change produces a different hash. Unit test `stableHashDistinctness` confirms that "A --> B" and "A --> C" produce different hashes. A different hash means `cache.get(cacheKey)` returns nil, triggering a fresh render.
- Field Notes: N/A
- Issues: None

**AC3**: The cache has a bounded size with an eviction policy to prevent unbounded memory growth.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidCache.swift`:7-51
- Evidence: `MermaidCache` has a `capacity` property (default 50, line 12). The `set` method checks `accessOrder.count >= capacity` (line 35) and calls `evictLeastRecentlyUsed()` before inserting. Unit tests `lruEviction` and `defaultCapacity` confirm the behavior: cache never exceeds capacity, LRU entries are evicted.
- Field Notes: N/A
- Issues: None

**AC4**: A cache-clearing capability exists that forces all diagrams to re-render on next display.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift`:90-92 - `clearCache()`
- Evidence: `clearCache()` calls `cache.removeAll()` which clears both `storage` and `accessOrder`. Unit test `clearCacheSucceeds` confirms it completes without error. After clearing, all subsequent renders will be cache misses.
- Field Notes: N/A
- Issues: None

### FR-MER-006: Pinch-to-Zoom
**AC1**: A pinch gesture on a rendered diagram increases or decreases the magnification level.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:99-108 - `zoomGesture`
- Evidence: `MagnifyGesture` is attached to the diagram image in both inactive (line 57) and activated (line 83) states. `.onChanged` computes `baseZoomScale * value.magnification` and assigns to `zoomScale`. The `scaleEffect(zoomScale)` (inactive, line 53) or frame-based sizing (activated, lines 72-73) applies the magnification.
- Field Notes: N/A
- Issues: None

**AC2**: Magnification is clamped to the range 0.5x (minimum) to 4.0x (maximum).
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:103
- Evidence: `zoomScale = max(0.5, min(newScale, 4.0))` clamps the value to [0.5, 4.0].
- Field Notes: N/A
- Issues: None

**AC3**: Zoom level persists while the diagram is displayed (does not reset on re-layout).
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:18-19, 105-107
- Evidence: `zoomScale` and `baseZoomScale` are `@State` properties, which persist across SwiftUI re-renders. The base+delta pattern (`baseZoomScale = zoomScale` on gesture end at line 106) ensures the zoom accumulates rather than resetting.
- Field Notes: N/A
- Issues: None

**AC4**: The zoom gesture feels smooth and responsive with no visible lag.
- Status: PARTIAL (MANUAL_REQUIRED)
- Implementation: SwiftUI `MagnifyGesture` with `@State` binding
- Evidence: The implementation uses standard SwiftUI gesture APIs with direct state mutation, which is the recommended pattern for responsive gestures. However, actual smoothness requires device testing.
- Field Notes: N/A
- Issues: Requires manual testing on actual hardware.

### FR-MER-007: Two-Finger Scroll/Pan
**AC1**: Two-finger scrolling within an activated/focused diagram pans the view horizontally and vertically.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:67-75 - `activatedDiagramView`
- Evidence: The activated state wraps the image in `ScrollView([.horizontal, .vertical])` (line 67). The image is sized explicitly via `frame(width:height:)` based on `image.size * zoomScale` (lines 71-74), enabling scrolling in both directions when the image exceeds the container.
- Field Notes: N/A
- Issues: None

**AC2**: The diagram must be explicitly activated (e.g., clicked) before internal scrolling is enabled.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:42-47, 58-61
- Evidence: `diagramView(image:)` checks `isActivated` (line 42). When false, `inactiveDiagramView` has no `ScrollView` (line 49-64). The `.onTapGesture` at line 58 sets `isActivated = true`. Only after activation does `activatedDiagramView` render with `ScrollView`.
- Field Notes: N/A
- Issues: None

**AC3**: Panning is bounded to the content area of the diagram (cannot scroll past edges into empty space).
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:67-75
- Evidence: SwiftUI `ScrollView` natively bounds scrolling to its content size. The content is sized to `image.size.width * zoomScale` by `image.size.height * zoomScale` (lines 72-73), and the container is `maxWidth: .infinity, maxHeight: 400` (line 76). ScrollView will not allow panning beyond the content bounds.
- Field Notes: N/A
- Issues: None

### FR-MER-008: Scroll Isolation
**AC1**: Scrolling the Markdown document with a two-finger gesture moves the document, not the contents of a Mermaid diagram.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:42-47
- Evidence: When `isActivated` is false (default), `inactiveDiagramView` is rendered which contains no `ScrollView`. Without a ScrollView in the hierarchy, scroll gestures pass through to the parent `ScrollView` in `MarkdownPreviewView` (line 13 of that file). This is the conditional ScrollView rendering pattern from design decision D5.
- Field Notes: N/A
- Issues: None

**AC2**: A Mermaid diagram that is partially visible does not trap or redirect scroll momentum.
- Status: VERIFIED
- Implementation: Same as AC1 -- no ScrollView when not activated
- Evidence: Without a nested `ScrollView`, there is no mechanism to trap scroll events. The `MagnifyGesture` attached to the image does not interfere with scroll gestures. The `contentShape(Rectangle())` at line 56 is for tap detection only.
- Field Notes: N/A
- Issues: None

**AC3**: Only after the user explicitly interacts with a diagram (e.g., clicking it) does the diagram capture scroll input for internal panning.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:58-61
- Evidence: `.onTapGesture { isActivated = true; isFocused = true }` is the only activation trigger. ScrollView only appears when `isActivated == true` (line 42-43).
- Field Notes: N/A
- Issues: None

**AC4**: Clicking outside the diagram or pressing Escape deactivates diagram-internal scrolling and returns scroll control to the document.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:86-94
- Evidence: `.onKeyPress(.escape)` sets `isActivated = false` (line 87). `.onChange(of: isFocused)` detects when focus is lost (clicking elsewhere) and sets `isActivated = false` (lines 90-93). When deactivated, the ScrollView is removed from the hierarchy, returning scroll control to the document.
- Field Notes: N/A
- Issues: None

### FR-MER-009: Theme-Aware Diagram Containers
**AC1**: The diagram container background uses the active theme's secondary background color.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:62, 77, 121, 137
- Evidence: All view states (inactive diagram line 62, activated diagram line 77, loading line 121, error line 137) use `.background(appState.theme.colors.backgroundSecondary)`.
- Field Notes: N/A
- Issues: None

**AC2**: Text labels and borders within the container use the active theme's secondary foreground color.
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:118, 134, 81
- Evidence: Loading text uses `foregroundColor(appState.theme.colors.foregroundSecondary)` (line 118). Error description text uses `foregroundColor(appState.theme.colors.foregroundSecondary)` (line 134). However, the activated border uses `appState.theme.colors.accent` (line 81) rather than `foregroundSecondary`. The inactive state border/corner radius does not use foregroundSecondary either. The requirement says "text labels and borders" should use foregroundSecondary, but the accent-colored border on activation is a design decision for visual feedback.
- Field Notes: N/A
- Issues: The activated border uses accent color instead of foregroundSecondary. This appears to be an intentional design choice for visual distinction but differs from the literal AC text. The design document explicitly calls for "accent-colored border" so this is consistent with design but the requirement says foregroundSecondary.

**AC3**: Switching themes updates diagram container colors without requiring a re-render of the diagram image itself.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:14, 62, 77
- Evidence: `@Environment(AppState.self) private var appState` is reactive. Container backgrounds reference `appState.theme.colors.backgroundSecondary` directly. When the theme changes, SwiftUI re-evaluates these color references without triggering `renderDiagram()` again (the `.task` modifier only runs once on appear). The rendered `NSImage` is stored in `@State` and is not affected by theme changes.
- Field Notes: N/A
- Issues: None

### FR-MER-010: Graceful Error Handling
**AC1**: Malformed Mermaid syntax (e.g., missing diagram type, broken arrows) produces an error state view, not a crash.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:153-156, `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift`:62-71
- Evidence: All errors from `renderToSVG` are caught in the `do/catch` block (lines 145-157 of MermaidBlockView). Errors set `errorMessage` and clear `renderedImage`, triggering the `errorView`. JS errors are caught and wrapped as `MermaidError.javaScriptError` (lines 65-71 of MermaidRenderer). The actor isolation and structured error handling prevent crashes.
- Field Notes: N/A
- Issues: None

**AC2**: JavaScript execution errors (e.g., runtime exceptions in beautiful-mermaid.js) produce an error state view with the JS error message.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift`:65-71
- Evidence: `catch let error as JXError` extracts `error.message` and wraps it as `MermaidError.javaScriptError(error.message)` (line 67). The generic catch also wraps `error.localizedDescription` (line 70). The error description includes "JavaScript error: {message}" (line 163). The view displays this via `error.localizedDescription` at line 155.
- Field Notes: N/A
- Issues: None

**AC3**: SVG rasterization failures (e.g., invalid SVG data from JS) produce an error state view.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift`:80-86, `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:147-152
- Evidence: `renderToImage` throws `MermaidError.invalidSVGData` if `data(using: .utf8)` fails (line 82) and `MermaidError.svgRenderingFailed` if `SVG(data:)` returns nil (line 85). In the view, `svgStringToImage` returns nil on failure (line 162-166), and the view sets an error message at line 151.
- Field Notes: N/A
- Issues: None

**AC4**: Empty Mermaid code blocks produce an appropriate error or empty state, not a crash.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift`:40-43
- Evidence: `renderToSVG` trims whitespace and checks `trimmed.isEmpty` (line 41-43). Empty input throws `MermaidError.emptyInput` with message "Mermaid diagram source is empty. Add a diagram type and definition." Unit tests `emptyInputError` and `whitespaceOnlyInputError` verify both empty string and whitespace-only input.
- Field Notes: N/A
- Issues: None

## Implementation Gap Analysis

### Missing Implementations
- **TD1**: modules.md documentation update not completed
- **TD2**: architecture.md documentation update not completed
- **TD3**: patterns.md documentation update not completed

### Partial Implementations
- **FR-MER-002 AC1-AC5** (5 criteria): The rendering pipeline code is complete and correct, but actual SVG output from the 5 supported diagram types has not been verified through automated tests. The unit tests validate error handling and caching but do not exercise the full JS rendering path due to beautiful-mermaid.js bundle not being available in the test target. These require integration testing or manual verification.

- **FR-MER-003 AC2**: Visual fidelity of rendered SVG-to-image conversion requires manual visual inspection. The code correctly uses SwiftDraw but actual output quality depends on SVG compatibility between beautiful-mermaid.js output and SwiftDraw's parser.

- **FR-MER-009 AC2**: The activated state border uses accent color rather than foregroundSecondary as specified in the requirements. The design document explicitly prescribes accent color for the activation indicator, creating a discrepancy between requirements and design.

### Implementation Issues
- None -- no incorrectly implemented criteria found. All implemented code matches its design specification.

## Code Quality Assessment

**Overall Quality: HIGH**

1. **Architecture**: Clean separation between rendering logic (actor), caching (struct), error types (enum), and UI (view). The actor pattern correctly isolates mutable state for concurrency safety.

2. **Error Handling**: Comprehensive typed error enum with LocalizedError conformance. All error paths produce user-facing messages. JS errors are properly caught and wrapped. Empty/unsupported input is validated before reaching JS execution.

3. **Concurrency Safety**: `MermaidRenderer` is an actor with private mutable state. `MermaidCache` is a value type (struct) inside the actor, requiring no additional Sendable conformance. The `@preconcurrency import SwiftDraw` in MermaidBlockView correctly handles SwiftDraw's non-Sendable types.

4. **SwiftUI Patterns**: Correct use of `@State`, `@FocusState`, `@Environment`. The conditional ScrollView rendering for scroll isolation is an elegant solution. The base+delta zoom pattern is the standard approach for MagnifyGesture.

5. **Testing**: 21 focused unit tests covering cache behavior and error handling. Tests use Swift Testing framework as required. Parameterized test for unsupported types is a good practice. Tests create fresh instances to avoid shared state issues.

6. **Code Style**: Consistent with project patterns. Proper documentation comments. No force unwrapping. Clean module structure.

7. **Minor Observations**:
   - The `svgStringToImage` function in `MermaidBlockView` duplicates logic from `MermaidRenderer.renderToImage`. This is acceptable for `@MainActor` isolation control but could be refactored.
   - The `@preconcurrency import SwiftDraw` at line 169 is placed at the end of the file rather than with other imports at the top. This is functional but unconventional.

## Recommendations
1. **Complete documentation tasks TD1, TD2, TD3**: Update modules.md, architecture.md, and patterns.md with the new MermaidCache module, LRU caching strategy, scroll isolation pattern, and base+delta zoom pattern.

2. **Create field-notes.md**: Document the two undocumented deviations identified: (a) frame-based sizing instead of scaleEffect in activated state, (b) local svgStringToImage helper instead of using MermaidRenderer.renderToImage.

3. **Add integration tests for diagram rendering**: Create integration tests that load the beautiful-mermaid.js bundle and verify SVG output for all 5 supported diagram types. This would close the gap on FR-MER-002 AC1-AC5. Consider adding the JS resource to the test target in Package.swift.

4. **Resolve FR-MER-009 AC2 discrepancy**: The requirements specify foregroundSecondary for borders, but the design specifies accent color for the activation border. Clarify which is authoritative and update one or the other for consistency.

5. **Move `@preconcurrency import SwiftDraw`**: Relocate from line 169 to the top of MermaidBlockView.swift with other imports for conventional file organization.

6. **Run manual verification**: Test the 6 MANUAL_REQUIRED items (gesture smoothness, 5 diagram type rendering, visual fidelity) on actual hardware.

## Verification Evidence

### Key Code References

**Mermaid Block Detection** (`MarkdownVisitor.swift:25-31`):
```swift
case let codeBlock as CodeBlock:
    let language = codeBlock.language?.lowercased()
    let code = codeBlock.code
    if language == "mermaid" {
        return .mermaidBlock(code: code)
    }
    return .codeBlock(language: language, code: code)
```

**LRU Cache with Bounded Capacity** (`MermaidCache.swift:28-41`):
```swift
mutating func set(_ key: UInt64, value: String) {
    if storage[key] != nil {
        storage[key] = value
        promoteToMostRecent(key)
        return
    }
    if accessOrder.count >= capacity {
        evictLeastRecentlyUsed()
    }
    storage[key] = value
    accessOrder.append(key)
}
```

**JXContext Reuse with Error Recovery** (`MermaidRenderer.swift:62-71`):
```swift
} catch let error as JXError {
    context = nil  // Discard potentially corrupted context
    throw MermaidError.javaScriptError(error.message)
} catch {
    context = nil
    throw MermaidError.javaScriptError(error.localizedDescription)
}
```

**Scroll Isolation via Conditional ScrollView** (`MermaidBlockView.swift:42-47`):
```swift
@ViewBuilder
private func diagramView(image: NSImage) -> some View {
    if isActivated {
        activatedDiagramView(image: image)  // Has ScrollView
    } else {
        inactiveDiagramView(image: image)   // No ScrollView
    }
}
```

**Base+Delta Zoom Pattern** (`MermaidBlockView.swift:100-107`):
```swift
MagnifyGesture()
    .onChanged { value in
        let newScale = baseZoomScale * value.magnification
        zoomScale = max(0.5, min(newScale, 4.0))
    }
    .onEnded { _ in
        baseZoomScale = zoomScale
    }
```

**Test Results**: 96/96 tests passing (including 10 MermaidCache tests + 11 MermaidRenderer tests).

**Build Status**: `swift build` succeeds with no errors.
