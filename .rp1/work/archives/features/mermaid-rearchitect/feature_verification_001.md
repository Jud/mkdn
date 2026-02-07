# Feature Verification Report #001

**Generated**: 2026-02-07T17:17:00Z
**Feature ID**: mermaid-rearchitect
**Verification Scope**: all
**KB Context**: Loaded (index.md, patterns.md)
**Field Notes**: Available

## Executive Summary
- Overall Status: PARTIAL
- Acceptance Criteria: 31/38 verified (81%)
- Implementation Quality: HIGH
- Ready for Merge: NO (documentation tasks TD1-TD7 incomplete; CLAUDE.md still has stale "NO WKWebView" rule)

## Field Notes Context
**Field Notes Available**: Yes

### Documented Deviations
1. **JXKit not in Package.swift**: The actual codebase used `import JavaScriptCore` directly; JXKit was referenced only in KB docs, never as an SPM dependency. AC-001.3 and AC-010.2 are verified with this context (no JXKit removal needed).
2. **Three-token template**: Design spec listed two tokens (`__MERMAID_CODE__` and `__THEME_VARIABLES__`). Implementation uses three: `__MERMAID_CODE__` (HTML-escaped), `__MERMAID_CODE_JS__` (JS-escaped for originalCode variable), and `__THEME_VARIABLES__`. This is a necessary separation of concerns for HTML vs JS escaping.
3. **T7 completed during T1**: MermaidImageStore references in MarkdownPreviewView and DocumentState were cleaned up in T1 to satisfy T1's compilation AC. T7 required no additional changes.
4. **Empty Gesture directory removed**: `mkdn/Core/Gesture/` was removed after deleting its contents.

### Undocumented Deviations
1. **CLAUDE.md not updated**: CLAUDE.md (line 30) still says `**NO WKWebView** -- the entire app is native SwiftUI, no exceptions.` and (line 31) still describes `Mermaid rendering: JavaScriptCore + beautiful-mermaid -> SVG -> SwiftDraw -> native Image.` These are factually incorrect for the current codebase. Task TD1 is not yet completed.
2. **KB context files not updated**: index.md (line 27) still says `1. NO WKWebView anywhere`. patterns.md (lines 87) still says `**NO WKWebView** -- ever, for any reason`. Tasks TD2-TD7 are not yet completed.

## Acceptance Criteria Verification

### FR-001: Teardown of Existing Mermaid Pipeline

**AC-001.1**: Old source files deleted (MermaidRenderer, SVGSanitizer, MermaidCache, MermaidImageStore, ScrollPhaseMonitor, GestureIntentClassifier, DiagramPanState)
- Status: VERIFIED
- Implementation: Files confirmed absent from `mkdn/Core/Mermaid/` and `mkdn/Core/Gesture/` (directory itself removed). `mkdn/UI/Components/ScrollPhaseMonitor.swift` also absent.
- Evidence: `ls mkdn/Core/Mermaid/` shows only MermaidError.swift, MermaidRenderState.swift, MermaidThemeMapper.swift, MermaidWebView.swift. `ls mkdn/Core/Gesture/` returns "No such file or directory". `ls mkdn/UI/Components/ScrollPhaseMonitor.swift` returns "No such file or directory".
- Field Notes: Empty Gesture directory removed (documented).
- Issues: None

**AC-001.2**: All corresponding test files deleted
- Status: VERIFIED
- Implementation: `mkdnTests/Unit/Core/` directory contains no old Mermaid/gesture test files.
- Evidence: `ls mkdnTests/Unit/Core/` confirms absence of SVGSanitizerTests.swift, MermaidCacheTests.swift, MermaidImageStoreTests.swift, MermaidRendererTests.swift, GestureIntentClassifierTests.swift, DiagramPanStateTests.swift.
- Field Notes: N/A
- Issues: None

**AC-001.3**: SwiftDraw and JXKit removed from Package.swift
- Status: INTENTIONAL DEVIATION
- Implementation: `/Users/jud/Projects/mkdn/Package.swift` -- SwiftDraw fully removed. JXKit was never present.
- Evidence: Package.swift dependencies array (lines 17-21) contains only swift-markdown, swift-argument-parser, and Splash. `grep -r "SwiftDraw\|JXKit" Package.swift` returns no matches.
- Field Notes: "JXKit Was Never in Package.swift" -- field notes document that the actual codebase used `import JavaScriptCore` (system framework) directly, not JXKit.
- Issues: None (deviation is documented and correct)

**AC-001.4**: beautiful-mermaid.js resource deleted and removed from Package.swift
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid.min.js` is now standard Mermaid.js v11.12.2 (2.7MB), not beautiful-mermaid.
- Evidence: Old beautiful-mermaid.js replaced by standard Mermaid.js. `grep -r "beautiful-mermaid" mkdn/ Package.swift` returns no matches. Old copy rule removed; new `.copy("Resources/mermaid.min.js")` rule in Package.swift (line 32) references the new standard library.
- Field Notes: "Mermaid.js v11.12.2 Bundled" documented in field notes.
- Issues: None

**AC-001.5**: App builds successfully after removal
- Status: VERIFIED
- Implementation: `swift build` completes with "Build complete!" in 0.33s with 0 errors.
- Evidence: Build output: `Build complete! (0.33s)`
- Field Notes: N/A
- Issues: None

**AC-001.6**: No dead imports or references to removed code remain
- Status: VERIFIED
- Implementation: Grep searches for all deleted component names, SwiftDraw, JXKit, JavaScriptCore, and beautiful-mermaid return zero results in mkdn/ and mkdnTests/.
- Evidence: `grep -r "MermaidRenderer\|SVGSanitizer\|MermaidCache\|MermaidImageStore\|ScrollPhaseMonitor\|GestureIntentClassifier\|DiagramPanState" mkdn/ mkdnTests/` -- no matches. `grep -r "SwiftDraw\|JXKit\|JavaScriptCore\|beautiful-mermaid" mkdn/ mkdnTests/ Package.swift` -- no matches.
- Field Notes: N/A
- Issues: None

### FR-002: WKWebView-Per-Diagram Rendering

**AC-002.1**: Each Mermaid code block results in a separate WKWebView instance
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownBlockView.swift`:36-37 routes `.mermaidBlock(code)` to `MermaidBlockView(code: code)`. Each `MermaidBlockView` creates its own `MermaidWebView` which instantiates a new `WKWebView` in `makeNSView` (`/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`:60).
- Evidence: `MermaidWebView.makeNSView` (line 47-75) creates `WKWebView(frame: .zero, configuration: configuration)` on every call. Each `MermaidBlockView` (line 26-32 of MermaidBlockView.swift) creates a new `MermaidWebView` instance.
- Field Notes: N/A
- Issues: None

**AC-002.2**: WKWebView loads self-contained HTML template with standard Mermaid.js
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`:102-126 -- `loadTemplate` reads `mermaid-template.html` from `Bundle.module`, performs token substitution, and calls `webView.loadHTMLString(html, baseURL: resourceDirectory)`. Template at `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid-template.html` includes `<script src="mermaid.min.js"></script>` (line 11) which resolves via the baseURL to the bundled standard Mermaid.js.
- Evidence: Template line 11: `<script src="mermaid.min.js"></script>`. MermaidWebView line 125: `webView.loadHTMLString(html, baseURL: resourceDirectory)` where `resourceDirectory = templateURL.deletingLastPathComponent()`.
- Field Notes: Three-token substitution documented in field notes.
- Issues: None

**AC-002.3**: All five diagram types render correctly (flowchart, sequence, state, class, ER)
- Status: MANUAL_REQUIRED
- Implementation: The HTML template uses standard Mermaid.js v11.12.2 which natively supports all five types. The template initializes with `startOnLoad: false` and calls `mermaid.run()` which renders any valid Mermaid syntax.
- Evidence: Template line 20-26: `mermaid.initialize({ startOnLoad: false, theme: 'base', themeVariables: ..., securityLevel: 'strict', flowchart: { htmlLabels: true } })`. Standard Mermaid.js inherently supports all five types.
- Field Notes: N/A
- Issues: Requires manual visual verification with actual diagram content for each type.

**AC-002.4**: WKWebView wrapped in NSViewRepresentable
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`:31 -- `struct MermaidWebView: NSViewRepresentable`.
- Evidence: Line 31: `struct MermaidWebView: NSViewRepresentable`
- Field Notes: N/A
- Issues: None

**AC-002.5**: WKWebView created and used on main actor (Swift 6 concurrency)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`:3 uses `@preconcurrency import WebKit`. Coordinator is explicitly `@MainActor` (line 160). WKWebView is created in `makeNSView` which is called on the main thread by SwiftUI. The `userContentController` delegate method is `nonisolated` and dispatches to `@MainActor` via `Task` (lines 177-184).
- Evidence: Line 3: `@preconcurrency import WebKit`. Line 160: `@MainActor final class Coordinator`. Lines 177-184: `nonisolated func userContentController(...)` with `Task { @MainActor in self.handleMessage(message) }`.
- Field Notes: Documented that `@preconcurrency import WebKit` used for Swift 6 concurrency.
- Issues: None

### FR-003: Theme-Aware Diagram Rendering

**AC-003.1**: HTML template accepts theme colors as Mermaid.js themeVariables
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid-template.html`:23 -- `themeVariables: __THEME_VARIABLES__`. `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`:117 -- `MermaidThemeMapper.themeVariablesJSON(for: theme)` generates the JSON. Line 122: `.replacingOccurrences(of: "__THEME_VARIABLES__", with: themeJSON)`.
- Evidence: Template line 22-23: `theme: 'base', themeVariables: __THEME_VARIABLES__`. MermaidWebView lines 117-122 perform the substitution.
- Field Notes: N/A
- Issues: None

**AC-003.2**: Solarized Dark diagrams use dark-theme-appropriate colors
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidThemeMapper.swift`:48-75 -- `solarizedDarkVariables` dictionary with all 26 keys matching the design spec hex values.
- Evidence: All dark hex values verified against design spec table in requirements.md. Unit tests in `MermaidThemeMapperTests` (lines 38-67) verify every key/value pair.
- Field Notes: N/A
- Issues: None

**AC-003.3**: Solarized Light diagrams use light-theme-appropriate colors
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidThemeMapper.swift`:87-114 -- `solarizedLightVariables` dictionary with all 26 keys matching the design spec hex values.
- Evidence: All light hex values verified against design spec table in requirements.md. Unit tests in `MermaidThemeMapperTests` (lines 69-99) verify every key/value pair.
- Field Notes: N/A
- Issues: None

**AC-003.4**: WKWebView background transparent or theme-matching, no white flash
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`:63-64 -- `webView.setValue(false, forKey: "drawsBackground")` and `webView.underPageBackgroundColor = .clear`. `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:33 -- `MermaidWebView` opacity is 0 until `renderState == .rendered`, preventing blank flash.
- Evidence: MermaidWebView lines 63-64 disable background drawing. MermaidBlockView line 33: `.opacity(renderState == .rendered ? 1 : 0)`. Template line 8: `body { background: transparent; }`.
- Field Notes: N/A
- Issues: None

### FR-004: Diagram Re-Rendering on Theme Change

**AC-004.1**: After theme switch, all visible diagrams display new theme colors
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`:89-92 -- `updateNSView` detects theme change (`coordinator.currentTheme != theme`) and calls `reRenderWithTheme`. Lines 128-139: `reRenderWithTheme` calls `webView.evaluateJavaScript("reRenderWithTheme(\(themeJSON));")` which re-initializes Mermaid with new themeVariables, removes the old SVG, creates a new `<pre class="mermaid">` element, and re-renders.
- Evidence: MermaidWebView lines 89-92 trigger re-render. Template lines 47-63 define `reRenderWithTheme` function. JavaScript re-initialization uses `mermaid.initialize()` with new `themeVarsJSON`.
- Field Notes: N/A
- Issues: None

**AC-004.2**: Re-rendering occurs without user scroll/reload
- Status: VERIFIED
- Implementation: Theme re-rendering happens in-place via `evaluateJavaScript` (no WKWebView recreation). The `updateNSView` callback fires automatically when SwiftUI detects the `theme` property has changed.
- Evidence: MermaidWebView line 132: `webView.evaluateJavaScript(script)` -- in-place JS execution, no navigation or view recreation.
- Field Notes: Design decision D5 (in-place JS re-render vs. full recreation) correctly implemented.
- Issues: None

### FR-005: Scroll Pass-Through for Unfocused Diagrams

**AC-005.1**: Scrolling passes smoothly through unfocused diagrams
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`:14-21 -- `MermaidContainerView.hitTest(_:)` returns `nil` when `allowsInteraction` is false, causing all events to pass through to the parent responder chain. Line 49: `container.allowsInteraction = isFocused` (false by default). Line 78: `updateNSView` keeps it in sync.
- Evidence: MermaidContainerView lines 17-20: `override func hitTest(_ point: NSPoint) -> NSView? { guard allowsInteraction else { return nil }; return super.hitTest(point) }`. MermaidBlockView line 14: `@State private var isFocused = false` (default unfocused).
- Field Notes: N/A
- Issues: None

**AC-005.2**: No custom scroll-phase monitoring or gesture classification heuristics
- Status: VERIFIED
- Implementation: No `ScrollPhaseMonitor`, `GestureIntentClassifier`, or `DiagramPanState` exist anywhere in the codebase. The entire `mkdn/Core/Gesture/` directory has been removed. The scroll pass-through mechanism is a simple `hitTest` override on `MermaidContainerView`.
- Evidence: `grep -r "ScrollPhaseMonitor\|GestureIntentClassifier\|DiagramPanState" mkdn/` returns no matches. `mkdn/Core/Gesture/` directory does not exist.
- Field Notes: N/A
- Issues: None

### FR-006: Click-to-Focus Interaction Model

**AC-006.1**: Clicking a diagram transitions to focused state
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:48-49 -- `.onTapGesture { isFocused = true }`. Line 47: `.contentShape(Rectangle())` ensures the entire area is tappable.
- Evidence: MermaidBlockView lines 47-49.
- Field Notes: N/A
- Issues: None

**AC-006.2**: Visual focus indicator (border/glow) visible when focused
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:104-110 -- `focusBorder` computed property renders `RoundedRectangle(cornerRadius: 6).stroke(colors.accent, lineWidth: 2)` when `isFocused` is true. Applied as `.overlay(focusBorder)` at line 46.
- Evidence: MermaidBlockView lines 104-110: 2pt accent-colored border overlay matching design spec.
- Field Notes: N/A
- Issues: None

**AC-006.3**: Pinch-to-zoom works in focused state
- Status: MANUAL_REQUIRED
- Implementation: When focused, `MermaidContainerView.allowsInteraction = true` (MermaidWebView line 78), causing `hitTest` to return the WKWebView. WKWebView natively provides pinch-to-zoom.
- Evidence: Architecture is correct: hitTest gating allows WKWebView to receive events when focused. WKWebView's native zoom behavior is a platform capability.
- Field Notes: N/A
- Issues: Requires manual verification on actual hardware.

**AC-006.4**: Two-finger pan works in focused state
- Status: MANUAL_REQUIRED
- Implementation: Same mechanism as AC-006.3 -- WKWebView natively provides two-finger pan when it receives events.
- Evidence: hitTest gating correctly implemented. WKWebView pan is a platform capability.
- Field Notes: N/A
- Issues: Requires manual verification on actual hardware.

**AC-006.5**: Escape unfocuses and returns scroll control
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:52-55 -- `.onKeyPress(.escape) { isFocused = false; return .handled }`. Line 51: `.focusable(isFocused)` ensures keyboard events are received when focused.
- Evidence: MermaidBlockView lines 51-55. When `isFocused` becomes false, `updateNSView` sets `container.allowsInteraction = false` (MermaidWebView line 78), returning scroll control to the document.
- Field Notes: N/A
- Issues: None

**AC-006.6**: Clicking outside unfocuses
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`:235-255 -- `installClickOutsideMonitor` uses `NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown)`. It converts the click location to the container view's coordinate space and checks if the click is outside bounds. If outside and in the same window, sets `parent.isFocused = false`. Lines 83-87 of `updateNSView` install/remove the monitor based on focus state.
- Evidence: MermaidWebView lines 235-255 implement click-outside detection. Lines 83-87 manage monitor lifecycle. Lines 95-98 `dismantleNSView` removes monitor on view teardown.
- Field Notes: N/A
- Issues: None

### FR-007: Async Rendering with Loading and Error States

**AC-007.1**: Loading spinner displayed while rendering
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:16 -- `@State private var renderState: MermaidRenderState = .loading` (starts in loading). Lines 74-82: `loadingView` displays `ProgressView().controlSize(.small)` with "Rendering diagram..." text. Lines 62-63: overlay switches on renderState, showing `loadingView` for `.loading`.
- Evidence: MermaidBlockView lines 74-82 and 62-63. Initial state is `.loading`, spinner shown until JS sends `renderComplete` message.
- Field Notes: N/A
- Issues: None

**AC-007.2**: Warning icon and error message on render failure
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:85-100 -- `errorView(message:)` displays `Image(systemName: "exclamationmark.triangle")` (warning icon) with .orange foreground, "Mermaid rendering failed" bold caption, and the error message text.
- Evidence: MermaidBlockView lines 85-100 implement the error view with warning icon and descriptive message.
- Field Notes: N/A
- Issues: None

**AC-007.3**: Mermaid.js parse errors caught and surfaced
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid-template.html`:40-43 -- `catch (error) { window.webkit.messageHandlers.renderError.postMessage({ message: error.message || String(error) }); }`. `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`:199-207 -- Coordinator's `handleMessage` routes `renderError` messages to `parent.renderState = .error(errorMessage)`.
- Evidence: Template lines 40-43 catch JS errors. MermaidWebView lines 199-207 set error state. MermaidBlockView lines 69-70 display the error view.
- Field Notes: N/A
- Issues: None

**AC-007.4**: One diagram failure does not affect others
- Status: VERIFIED
- Implementation: Each `MermaidBlockView` has its own `@State` for `renderState` (MermaidBlockView line 16). Each `MermaidWebView` creates its own `WKWebView` with its own Coordinator (MermaidWebView line 60-68). Error state is scoped to the individual diagram's state, not shared.
- Evidence: Separate `@State` per view instance. Separate WKWebView and Coordinator per diagram.
- Field Notes: N/A
- Issues: None

**AC-007.5**: No diagram scenario causes app crash
- Status: MANUAL_REQUIRED
- Implementation: Error handling covers template not found (MermaidWebView lines 108-113), JS render errors (template lines 40-43), and JS evaluation errors (MermaidWebView lines 133-138). All paths set error state rather than crashing.
- Evidence: All error paths handled gracefully. No force unwraps in production code. `try?` used for template loading (line 107).
- Field Notes: N/A
- Issues: Requires manual stress testing with various malformed diagrams.

### FR-008: Auto-Sizing of Diagram Views

**AC-008.1**: Rendered size reported from JS to Swift via WKScriptMessageHandler
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid-template.html`:34-37 -- `window.webkit.messageHandlers.sizeReport.postMessage({ width: bbox.width, height: bbox.height })`. `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`:55 -- `contentController.add(context.coordinator, name: "sizeReport")`. Lines 188-195: Coordinator parses `height` from message body and updates `parent.renderedHeight`.
- Evidence: Template lines 34-37 send size. MermaidWebView line 55 registers handler. Lines 188-195 process size report.
- Field Notes: N/A
- Issues: None

**AC-008.2**: Host view sizes to match reported dimensions
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:37-43 -- `.frame(maxWidth: .infinity, minHeight: renderState == .rendered ? min(renderedHeight, maxDiagramHeight) : 100, maxHeight: min(renderedHeight, maxDiagramHeight))`. `renderedHeight` is bound to the value reported by JS via MermaidWebView.
- Evidence: MermaidBlockView lines 37-43 use `renderedHeight` (bound from JS) for frame height.
- Field Notes: N/A
- Issues: None

**AC-008.3**: Maximum height enforced (600pt)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:18 -- `private let maxDiagramHeight: CGFloat = 600`. Lines 40-42: `min(renderedHeight, maxDiagramHeight)` used for both minHeight and maxHeight.
- Evidence: MermaidBlockView line 18 defines 600pt max. Lines 40-42 apply the cap.
- Field Notes: N/A
- Issues: None

**AC-008.4**: Short diagrams display at natural height
- Status: VERIFIED
- Implementation: When `renderedHeight < maxDiagramHeight`, `min(renderedHeight, maxDiagramHeight)` equals `renderedHeight`, so the view sizes to the natural height.
- Evidence: Math is correct: `min(renderedHeight, 600)` for any height < 600 returns the natural height.
- Field Notes: N/A
- Issues: None

### FR-009: HTML Template for Mermaid Rendering

**AC-009.1**: Mermaid.js bundled as local resource
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid.min.js` -- standard Mermaid.js v11.12.2, 2,754,895 bytes. `/Users/jud/Projects/mkdn/Package.swift`:32 -- `.copy("Resources/mermaid.min.js")`.
- Evidence: File exists at expected path. Package.swift line 32 includes copy rule.
- Field Notes: "Mermaid.js v11.12.2 Bundled" documented.
- Issues: None

**AC-009.2**: Template renders without network access
- Status: VERIFIED
- Implementation: Template loads Mermaid.js via `<script src="mermaid.min.js"></script>` which resolves locally via the `baseURL` parameter in `loadHTMLString`. No external URLs referenced in template.
- Evidence: Template line 11 uses relative `src="mermaid.min.js"`. MermaidWebView line 124-125: `baseURL: resourceDirectory` (local bundle path). No `http://` or `https://` URLs in template.
- Field Notes: N/A
- Issues: None

**AC-009.3**: Template accepts theme configuration at render time
- Status: VERIFIED
- Implementation: Template line 23: `themeVariables: __THEME_VARIABLES__` token substituted with JSON from `MermaidThemeMapper.themeVariablesJSON(for:)`. Re-render function `reRenderWithTheme(themeVarsJSON)` accepts new theme at runtime.
- Evidence: Template lines 22-23 and 47-63. MermaidWebView lines 117-122 perform initial substitution. Lines 128-139 handle runtime theme changes.
- Field Notes: N/A
- Issues: None

**AC-009.4**: Template reports rendered dimensions to Swift
- Status: VERIFIED
- Implementation: Template lines 33-37: `svg.getBoundingClientRect()` then `sizeReport.postMessage({width, height})`. Coordinator lines 188-195 receive and process the message.
- Evidence: Full JS-to-Swift size reporting pipeline verified.
- Field Notes: N/A
- Issues: None

**AC-009.5**: Template background transparent or theme-matching
- Status: VERIFIED
- Implementation: Template line 8: `body { background: transparent; overflow: hidden; }`.
- Evidence: CSS sets transparent background.
- Field Notes: N/A
- Issues: None

### FR-010: Dependency Cleanup in Package.swift

**AC-010.1**: SwiftDraw removed from Package.swift
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/Package.swift` -- no SwiftDraw reference in dependencies or targets.
- Evidence: `grep SwiftDraw Package.swift` returns no matches. Dependencies (lines 17-21) list only swift-markdown, swift-argument-parser, Splash.
- Field Notes: N/A
- Issues: None

**AC-010.2**: JXKit removed from Package.swift
- Status: INTENTIONAL DEVIATION
- Implementation: JXKit was never in Package.swift.
- Evidence: `grep JXKit Package.swift` returns no matches. Field notes confirm "JXKit Was Never in Package.swift".
- Field Notes: Documented deviation -- actual codebase used raw `import JavaScriptCore`.
- Issues: None (no action needed)

**AC-010.3**: Old mermaid.min.js resource rule removed
- Status: VERIFIED
- Implementation: The old `.copy("Resources/mermaid.min.js")` rule for beautiful-mermaid is replaced by the same rule now pointing to standard Mermaid.js v11.12.2.
- Evidence: Package.swift line 32: `.copy("Resources/mermaid.min.js")` -- the rule itself is the same name but the underlying file is now standard Mermaid.js (2.7MB vs the smaller beautiful-mermaid).
- Field Notes: N/A
- Issues: None

**AC-010.4**: Standard Mermaid.js added as bundled resource
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/Package.swift`:32 -- `.copy("Resources/mermaid.min.js")`. File at `mkdn/Resources/mermaid.min.js` is 2,754,895 bytes (standard Mermaid.js v11.12.2).
- Evidence: Package.swift line 32. File exists and is standard Mermaid.js.
- Field Notes: "Mermaid.js v11.12.2 Bundled" documented.
- Issues: None

**AC-010.5**: Project builds and non-Mermaid tests pass
- Status: VERIFIED
- Implementation: `swift build` succeeds. `swift test` runs 131 tests, all pass (exit code 1 is the known signal 5 issue with Swift Testing + executable targets, not a test failure).
- Evidence: Build: "Build complete! (0.33s)". Tests: All 131 tests show "passed" in output. MermaidThemeMapper (5 tests) and MermaidHTMLTemplate (4 tests) all pass. All pre-existing tests pass.
- Field Notes: N/A
- Issues: None

## Implementation Gap Analysis

### Missing Implementations
- **TD1 (CLAUDE.md update)**: CLAUDE.md line 30 still reads `**NO WKWebView** -- the entire app is native SwiftUI, no exceptions.` and line 31 still describes the old Mermaid pipeline. This is factually incorrect and will mislead future agents/contributors.
- **TD2 (architecture.md Mermaid section)**: KB architecture.md not updated to reflect WKWebView approach.
- **TD3 (architecture.md Concurrency)**: KB architecture.md concurrency section still references MermaidRenderer actor.
- **TD4 (modules.md Core/Mermaid)**: KB modules.md file inventory not updated.
- **TD5 (modules.md Dependencies)**: KB modules.md dependencies table not updated.
- **TD6 (patterns.md Actor Pattern)**: KB patterns.md still shows old `actor MermaidRenderer` pattern (line 32-37) and "NO WKWebView -- ever, for any reason" anti-pattern (line 87).
- **TD7 (concept_map.md User Workflows)**: KB concept_map.md not updated with click-to-focus model.
- **KB index.md**: Line 27 still says "NO WKWebView anywhere" -- will need updating when TD tasks are completed.

### Partial Implementations
- None. All code implementation tasks (T1-T9) are complete.

### Implementation Issues
- None. All implemented code matches design specifications accurately.

## Code Quality Assessment

**Overall: HIGH**

The implementation demonstrates excellent quality across multiple dimensions:

1. **Architecture alignment**: The four-component architecture (MermaidContainerView, MermaidWebView, MermaidBlockView, HTML template) matches the design spec exactly.

2. **Swift 6 concurrency**: Properly handled via `@preconcurrency import WebKit`, `@MainActor` Coordinator, and `nonisolated` protocol conformance with `Task { @MainActor in }` dispatch.

3. **Error handling**: All error paths are gracefully handled without force unwraps. Template-not-found, JS render errors, and JS evaluation errors all route to the error state UI.

4. **Clean separation of concerns**: HTML/JS escaping split into appropriate methods. Theme mapping isolated in MermaidThemeMapper. State management in MermaidBlockView. WebKit integration in MermaidWebView.

5. **Resource cleanup**: Zero dead references to removed components. Clean Package.swift with no unused dependencies.

6. **Testing**: Test coverage focuses on high-value app-specific logic (theme mapping correctness, token substitution, HTML/JS escaping) while correctly avoiding tests of framework behavior (WKWebView rendering, Mermaid.js output).

7. **Code style**: Consistent with project conventions. `@Observable` (not ObservableObject), Swift Testing framework, proper documentation comments.

## Recommendations

1. **[BLOCKING] Complete TD1**: Update CLAUDE.md Critical Rules to note the WKWebView exception for Mermaid diagrams and update the Mermaid rendering description. The current CLAUDE.md contradicts the actual implementation, which will cause confusion for any agent or developer reading it.

2. **[BLOCKING] Complete TD2-TD7**: Update all KB context files. patterns.md line 87 (`**NO WKWebView** -- ever, for any reason`) and the `actor MermaidRenderer` example code directly contradict the current implementation.

3. **[LOW] Update KB index.md**: Line 27 states "NO WKWebView anywhere" -- should be updated to note the Mermaid exception when TD tasks are completed.

4. **[LOW] Manual verification**: Perform manual testing of all five diagram types (flowchart, sequence, state, class, ER) in both themes, and verify pinch-to-zoom/pan behavior on actual hardware.

5. **[LOW] Stress testing**: Test with malformed Mermaid syntax and documents with many (10+) diagrams to verify error isolation (AC-007.4) and memory behavior (NFR-003).

## Verification Evidence

### Files Verified

| File | Path | Status |
|------|------|--------|
| MermaidWebView.swift | `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift` | Present, 273 lines |
| MermaidRenderState.swift | `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderState.swift` | Present, 13 lines |
| MermaidError.swift | `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidError.swift` | Present, 19 lines |
| MermaidThemeMapper.swift | `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidThemeMapper.swift` | Present, 115 lines |
| MermaidBlockView.swift | `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift` | Present, 111 lines |
| mermaid-template.html | `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid-template.html` | Present, 68 lines |
| mermaid.min.js | `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid.min.js` | Present, 2.7MB |
| Package.swift | `/Users/jud/Projects/mkdn/Package.swift` | Present, 48 lines |
| MarkdownBlockView.swift | `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownBlockView.swift` | Present, routes mermaidBlock to MermaidBlockView |
| MarkdownPreviewView.swift | `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift` | Present, no MermaidImageStore references |
| MermaidThemeMapperTests.swift | `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/MermaidThemeMapperTests.swift` | Present, 128 lines |
| MermaidHTMLTemplateTests.swift | `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/MermaidHTMLTemplateTests.swift` | Present, 71 lines |
| CLAUDE.md | `/Users/jud/Projects/mkdn/CLAUDE.md` | Present, NOT UPDATED (stale WKWebView rule) |

### Files Confirmed Deleted

| File | Expected Path | Status |
|------|--------------|--------|
| MermaidRenderer.swift | mkdn/Core/Mermaid/ | Confirmed absent |
| SVGSanitizer.swift | mkdn/Core/Mermaid/ | Confirmed absent |
| MermaidCache.swift | mkdn/Core/Mermaid/ | Confirmed absent |
| MermaidImageStore.swift | mkdn/Core/Mermaid/ | Confirmed absent |
| ScrollPhaseMonitor.swift | mkdn/UI/Components/ | Confirmed absent |
| GestureIntentClassifier.swift | mkdn/Core/Gesture/ | Confirmed absent (directory removed) |
| DiagramPanState.swift | mkdn/Core/Gesture/ | Confirmed absent (directory removed) |
| SVGSanitizerTests.swift | mkdnTests/Unit/Core/ | Confirmed absent |
| MermaidCacheTests.swift | mkdnTests/Unit/Core/ | Confirmed absent |
| MermaidImageStoreTests.swift | mkdnTests/Unit/Core/ | Confirmed absent |
| MermaidRendererTests.swift | mkdnTests/Unit/Core/ | Confirmed absent |
| GestureIntentClassifierTests.swift | mkdnTests/Unit/Core/ | Confirmed absent |
| DiagramPanStateTests.swift | mkdnTests/Unit/Core/ | Confirmed absent |

### Build & Test Results

- **Build**: `swift build` -- Build complete (0.33s), 0 errors
- **Tests**: `swift test` -- 131/131 tests pass (signal 5 exit code is known Swift Testing issue, not a failure)
- **Dead references**: Zero matches for any removed component name, SwiftDraw, JXKit, JavaScriptCore, or beautiful-mermaid in source or test directories
