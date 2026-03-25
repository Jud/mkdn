# Mermaid Diagram Rendering

## What This Is

This is the diagram engine. When a fenced code block has language `mermaid`, the parser produces a `.mermaidBlock(code:)`, and this system renders it as an interactive SVG diagram using Mermaid.js running inside a WKWebView. Each mermaid block gets its own web view, its own render lifecycle, and a click-to-focus interaction model that lets users zoom and pan the diagram without interfering with document scrolling.

The Mermaid rendering layer is the only place in mkdn that uses WKWebView -- this is an explicit architectural constraint. Mermaid.js is a JavaScript library that renders diagrams as SVGs, and there's no pure-Swift equivalent that handles the full Mermaid syntax (flowcharts, sequence diagrams, class diagrams, state diagrams, Gantt charts, etc.). So we accept the web view for this one use case and build carefully around it.

## How It Works

Five files collaborate here, and the data flow crosses the Swift/JavaScript boundary:

```
.mermaidBlock(code:)
    |
    v
TextStorageBuilder inserts NSTextAttachment placeholder
    |
    v
OverlayCoordinator positions MermaidBlockView over placeholder
    |
    v
MermaidBlockView creates MermaidWebView (NSViewRepresentable)
    |
    v
MermaidTemplateLoader.writeTemplateFile(code:, theme:)
    |--- loadTemplate(): reads mermaid-template.html from bundle
    |--- htmlEscape(code): sanitizes diagram source for HTML embedding
    |--- jsEscape(code): sanitizes for JavaScript template literal
    |--- MermaidThemeMapper.themeVariablesJSON(for:): Solarized -> Mermaid vars
    |--- writes substituted HTML to temp file alongside mermaid.min.js copy
    |
    v
WKWebView.loadFileURL(tempFile, allowingReadAccessTo: tempDir)
    |
    v
Mermaid.js renders diagram -> SVG
    |
    v
JavaScript sends WKScriptMessages:
    "sizeReport"     -> { width, height, intrinsicWidth }
    "renderComplete" -> {}
    "renderError"    -> { message }
    |
    v
Coordinator updates @Binding: renderedHeight, renderedAspectRatio,
                               intrinsicWidth, renderState
```

### The web view structure (macOS)

**MermaidWebView** (`mkdn/Core/Mermaid/MermaidWebView.swift`) is an `NSViewRepresentable` that wraps a `WKWebView` inside a `MermaidContainerView`. The container view is a custom `NSView` that gates `hitTest()` based on focus state -- when unfocused, it returns `nil` for all hit tests, letting events pass through to the document scroll view. When focused, it lets the web view receive events for pinch-to-zoom and pan.

The web view is actually a `NoFocusRingWKWebView` subclass that suppresses macOS focus rings on itself and all internal subviews. WebKit creates internal subview hierarchies lazily (during first paint or interaction), so a simple extension override can't catch them all. The subclass intercepts `didAddSubview` and `viewDidMoveToWindow` to recursively suppress focus rings.

All mermaid web views share a single `WKProcessPool` (static property), so they run in a single web content process rather than spawning one per diagram. This is critical for memory -- a document with 5 mermaid blocks would otherwise create 5 separate web processes.

### Template loading

**MermaidTemplateLoader** (`mkdn/Core/Mermaid/MermaidTemplateLoader.swift`) handles getting the HTML content into the web view. The flow is:

1. Load `mermaid-template.html` from the bundle resources
2. Perform token substitution: `__MERMAID_CODE__` (HTML-escaped diagram source), `__MERMAID_CODE_JS__` (JS-escaped for the template literal), `__THEME_VARIABLES__` (JSON object from `MermaidThemeMapper`)
3. Write the substituted HTML to a temporary file in a shared temp directory that also contains a copy of `mermaid.min.js`
4. Load the temp file into the web view with `loadFileURL(_:allowingReadAccessTo:)` pointing to the temp directory

The temp directory approach exists because WebKit's file URL security model requires both the HTML file and the `mermaid.min.js` script to be within the `allowingReadAccessTo:` directory. We can't point to the bundle directory directly because the HTML is dynamically generated. The `mermaid.min.js` is copied (not symlinked) into the temp directory because WebKit resolves symlinks before checking access permissions (commit `6e5d101`).

The template loader also has a careful `resourceBundle` accessor that handles Homebrew symlink launches (commit `2280b3a`). `Bundle.module` calls `fatalError` when the app is launched via a symlink because `Bundle.main` doesn't detect the `.app` structure. The accessor resolves symlinks and navigates the `.app/Contents/Resources/` hierarchy to find the resource bundle.

### Theme mapping

**MermaidThemeMapper** (`mkdn/Core/Mermaid/MermaidThemeMapper.swift`) maps `AppTheme` to Mermaid.js `themeVariables` -- a JSON object with 26 keys controlling every color in Mermaid diagrams (node fill, border, text, line, actor, signal, note, etc.). We use Mermaid's `base` theme with custom variables rather than the built-in dark/light themes, because the built-in themes don't match our Solarized palette.

The hex values are hardcoded, not computed from `Color` at runtime. This avoids the unreliable `Color`-to-hex conversion that would require rendering a SwiftUI `Color` to read its components. The values are derived directly from the Solarized palette definitions in `SolarizedDark.swift` and `SolarizedLight.swift`.

### Theme switching

When the theme changes, we don't recreate the web view. Instead, `updateNSView` detects the theme change and calls `reRenderWithTheme()`, which evaluates a JavaScript snippet via `MermaidTemplateLoader.reRenderScript(theme:)`. This script calls `window.reRenderWithTheme()` in the template, which does an in-place color swap on the existing SVG using a two-pass placeholder replacement. This is dramatically faster than re-running `mermaid.run()`, which would tear down and rebuild the entire SVG DOM.

The color swap logic in the template JavaScript is carefully built to handle ambiguity: when multiple theme variable keys map to the same hex value in the old theme but different values in the new theme, those ambiguous colors are skipped to avoid corrupting non-changing instances.

### The JavaScript bridge

The HTML template (`mkdn/Resources/mermaid-template.html`) contains the JavaScript that bridges Mermaid.js to Swift:

- **`sizeReport`**: After rendering, measures the SVG bounding box and sends width, height, and intrinsic width (from the SVG `viewBox` attribute) to Swift. A `ResizeObserver` sends updated sizes when the web view resizes.
- **`renderComplete`**: Signals that `mermaid.run()` completed successfully and an SVG was produced.
- **`renderError`**: Sends error messages from Mermaid.js parse/render failures.

The `ResizeObserver` uses `requestAnimationFrame` debouncing to avoid flooding Swift with size reports during animated resizes.

### The Coordinator

The `Coordinator` is an `@MainActor` `NSObject` subclass that serves as both `WKScriptMessageHandler` and `WKNavigationDelegate`. It handles:

- **Message routing**: Dispatches JS messages to update the parent view's `@Binding` properties
- **Navigation policy**: Allows the initial page load and `other` navigation types (for JS-initiated content), but cancels user-initiated navigation (clicks on links inside diagrams)
- **Process termination recovery**: If the WebKit content process crashes, it sets the render state to error and reloads
- **Click-outside monitoring**: Installs an `NSEvent.addLocalMonitorForEvents` that detects clicks outside the container view and sets `isFocused = false`
- **Escape key monitoring**: Installs a key event monitor for keyCode 53 (Escape) to unfocus the diagram
- **Cleanup**: Removes message handlers and deletes the temp file on view dismantle

## Why It's Like This

**Why one WKWebView per diagram?** Because Mermaid.js renders into the DOM of the page it's loaded in. You can't render multiple independent diagrams in one web view without them interfering with each other's layout. Each diagram needs its own isolated rendering context.

**Why the shared process pool?** Without it, each WKWebView gets its own WebKit content process. A document with 5 mermaid blocks would spawn 5 processes, each loading `mermaid.min.js` (~2MB parsed JavaScript). The shared pool runs all diagrams in one process, sharing the parsed JS and reducing memory by roughly 4x for multi-diagram documents.

**Why the MermaidContainerView hit-test gating?** This is the click-to-focus interaction model. Mermaid diagrams support zoom and pan, but those gestures conflict with document scrolling. By default, the container passes all events through to the document (unfocused state). When the user clicks on the diagram, `MermaidBlockView` sets `isFocused = true`, the container starts accepting hit tests, and the web view receives events. Clicking outside or pressing Escape returns to unfocused state.

**Why write to temp files instead of loading HTML strings?** `WKWebView.loadHTMLString` doesn't support relative resource URLs -- the `<script src="mermaid.min.js">` would fail because there's no base URL context. `loadFileURL` with `allowingReadAccessTo:` gives the web view a filesystem context where it can resolve the relative script path.

**Why hard-copy the mermaid.min.js instead of symlinking?** This is a battle-tested fix (commit `6e5d101`). WebKit resolves symlinks before checking the `allowingReadAccessTo:` directory. A symlink to the bundle's `mermaid.min.js` would resolve to a path outside the temp directory, and WebKit would deny access. Additionally, `FileManager.fileExists` returns `true` for stale symlinks, which caused the copy-based fix to be skipped when a symlink from a previous approach still existed. The current code uses remove-then-copy to handle both cases.

## Where the Complexity Lives

**The resource bundle lookup** in `MermaidTemplateLoader.resourceBundle` is a 5-step fallback chain that handles direct launch, SPM build output, and Homebrew symlink scenarios. Each step is necessary for a different deployment context, and removing any one would break a real use case. The comments document which scenario each step covers.

**The theme swap JavaScript** in the HTML template is the most intricate code in the system. It builds a deduplicated color swap map, identifies ambiguous colors (where the same hex maps to different targets via different theme variable keys), excludes them, then does a two-pass placeholder replacement to avoid chain swaps (where a new color matches another old color). This is necessary because Mermaid doesn't expose a "re-render with new theme" API -- we have to mutate the SVG DOM directly.

**The `nonisolated(unsafe) static var sharedTempDirectory`** in `MermaidTemplateLoader` is a known concurrency compromise. It's mutable static state accessed without synchronization, which violates Swift 6 strict concurrency. The `nonisolated(unsafe)` annotation explicitly acknowledges this. In practice, it's safe because the template loader is only called from `@MainActor` contexts, but the compiler can't verify that.

**Process termination recovery** in the Coordinator's `webViewWebContentProcessDidTerminate` is a safety net. WebKit can kill content processes for memory pressure or crashes. The coordinator sets the render state to error and calls `reload()` on the web view to attempt recovery. This is fire-and-forget -- if the reload also fails, the diagram shows an error state permanently.

## The Grain of the Wood

**Adding a new theme**: Add a case to `MermaidThemeMapper.themeVariables(for:)` with the 26 required keys. All hex values are documented by their Solarized reference names in the comments. The tests verify that all required keys are present and that the JSON is valid.

**Changing the diagram interaction model**: The click-to-focus behavior is split between `MermaidBlockView` (which manages the `isFocused` state and cursor changes) and `MermaidWebView` (which installs/removes event monitors). The container view's `hitTest` gating is the mechanism; the policy lives in the coordinator's monitor installation.

**Updating Mermaid.js**: Replace `mermaid.min.js` in the resources. The template HTML and the loader code don't reference any Mermaid API beyond `mermaid.initialize()` and `mermaid.run()`, which have been stable across Mermaid major versions.

## Watch Out For

**The known pulsing bug.** Documents with many or complex mermaid diagrams can cause a render pulse loop -- the diagram renders, reports its size, the overlay resizes, which triggers a re-layout in TextKit, which repositions the overlay, which triggers a resize in the web view, which reports a new size. This is noted in the project's memory as a known issue. The `ResizeObserver` in the template uses `requestAnimationFrame` debouncing to mitigate this, but it doesn't fully prevent it.

**Temp file cleanup is best-effort.** The coordinator cleans up its temp file on dismantle, and `MermaidTemplateLoader.cleanUpTemplateFile` uses `try?` to silently ignore failures. The shared temp directory (`/tmp/mkdn-mermaid/`) persists across app launches and accumulates stale HTML files if cleanup fails. This is harmless but untidy.

**Navigation policy blocks link clicks inside diagrams.** The coordinator's `decidePolicyFor` method cancels all non-initial, non-programmatic navigation. This means clickable nodes in Mermaid diagrams (like `click A href "https://..."` syntax) won't navigate. This is intentional -- we don't want diagrams opening URLs in the embedded web view -- but it means Mermaid's click interaction features don't work.

**The `NoFocusRingWKWebView` subclass exists because WebKit creates internal subviews lazily.** A simple `focusRingType = .none` on the web view doesn't work because WebKit adds new subviews during first paint and interaction, and those subviews have their own focus rings. The subclass intercepts `didAddSubview` and `viewDidMoveToWindow` to catch these. If you see blue focus rings on mermaid diagrams, this mechanism has been defeated.

## Key Files

| File | What It Is |
|------|------------|
| `mkdn/Core/Mermaid/MermaidWebView.swift` | NSViewRepresentable: WKWebView + MermaidContainerView + Coordinator with event monitors |
| `mkdn/Core/Mermaid/MermaidTemplateLoader.swift` | Template loading, escaping, temp file management, resource bundle resolution |
| `mkdn/Core/Mermaid/MermaidThemeMapper.swift` | AppTheme to Mermaid.js themeVariables JSON, hardcoded Solarized hex values |
| `mkdn/Core/Mermaid/MermaidRenderState.swift` | Lifecycle enum: loading, rendered, error(String) |
| `mkdn/Core/Mermaid/MermaidError.swift` | LocalizedError types: templateNotFound, renderFailed |
| `mkdn/Resources/mermaid-template.html` | HTML template: Mermaid.js init, render, size reporting, theme swap JS |
| `mkdn/Features/Viewer/Views/MermaidBlockView.swift` | SwiftUI overlay: click-to-focus, cursor management, loading/error states |
