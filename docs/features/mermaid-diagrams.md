# Feature: Mermaid Diagrams

> Renders Mermaid code blocks as themed, interactive diagrams using one WKWebView per diagram with standard Mermaid.js.

## Overview

Mermaid diagram rendering is the sole exception to mkdn's native-SwiftUI-only rule. Each Mermaid code block detected by the Markdown parser (`MarkdownBlock.mermaidBlock`) gets its own `WKWebView` instance that loads a bundled HTML template containing standard Mermaid.js. The diagrams are theme-aware (Solarized Dark/Light), auto-sized to their rendered content, and use a click-to-focus interaction model that prevents scroll trapping while allowing pinch-to-zoom and pan when explicitly activated. All WKWebView instances share a single `WKProcessPool` to keep memory overhead low.

## User Experience

- Mermaid code blocks render inline as SVG diagrams matching the current Solarized theme.
- A loading spinner displays while Mermaid.js renders; parse errors show a warning icon with message.
- **Unfocused (default)**: scroll events pass through to the document. A pointing-hand cursor hints at interactivity.
- **Click to focus**: clicking a diagram activates it with a subtle border glow. Pinch-to-zoom and two-finger pan work natively via WKWebView.
- **Escape or click outside**: unfocuses the diagram and returns scroll control to the document.
- Theme switches re-render all visible diagrams in-place via JavaScript without recreating the WKWebView.
- Supports flowchart, sequence, state, class, and ER diagram types.

## Architecture

**Data Flow:**
`MarkdownVisitor` detects fenced code blocks with language `mermaid` and emits `MarkdownBlock.mermaidBlock(code:)`. The block view layer routes this to `MermaidBlockView`, which embeds a `MermaidWebView` (NSViewRepresentable). On creation, the HTML template undergoes token substitution (`__MERMAID_CODE__`, `__MERMAID_CODE_JS__`, `__THEME_VARIABLES__`) and is loaded into the WKWebView with `baseURL` pointing to the bundled resources directory so `mermaid.min.js` resolves locally. After Mermaid.js renders, JavaScript posts size and completion messages back to Swift via `WKScriptMessageHandler`. On theme change, `updateNSView` calls `evaluateJavaScript("reRenderWithTheme(...)")` to re-render in-place.

**Key Types:**
- `MermaidBlockView` -- SwiftUI view managing focus state, loading/error overlays, and frame sizing.
- `MermaidWebView` -- NSViewRepresentable wrapping `MermaidContainerView` + `NoFocusRingWKWebView` + Coordinator.
- `MermaidContainerView` -- NSView subclass that gates `hitTest(_:)` to enable scroll pass-through when unfocused.
- `NoFocusRingWKWebView` -- WKWebView subclass suppressing focus rings on all internal subviews.
- `MermaidThemeMapper` -- Maps `AppTheme` to Mermaid `themeVariables` JSON using hardcoded Solarized hex values.
- `MermaidRenderState` -- Enum: `.loading`, `.rendered`, `.error(String)`.
- `MermaidError` -- Error enum: `.templateNotFound`, `.renderFailed(String)`.

**Integration Points:**
- `AppSettings.theme` drives theme variable injection and re-rendering.
- `MarkdownBlockView` routes `.mermaidBlock` cases to `MermaidBlockView`.
- `Bundle.module` provides the HTML template and `mermaid.min.js` resource.

## Implementation Decisions

1. **One WKWebView per diagram, shared WKProcessPool**: Each diagram is isolated for independent lifecycle and error handling, but all share a single web content process (`static let sharedProcessPool`) to limit process overhead.
2. **hitTest gating for scroll pass-through**: `MermaidContainerView.hitTest(_:)` returns `nil` when unfocused, letting all events fall through to the parent ScrollView. No custom gesture classifiers or scroll-phase monitors needed.
3. **Hardcoded hex lookup in MermaidThemeMapper**: Avoids runtime `SwiftUI.Color`-to-hex conversion. Each Solarized palette maps directly to Mermaid's 26 `themeVariables` keys.
4. **In-place JS re-render on theme change**: `evaluateJavaScript` calls `reRenderWithTheme()` rather than destroying and recreating the WKWebView, avoiding the cost of full re-initialization.
5. **Template string substitution**: HTML template uses `__MERMAID_CODE__` (HTML-escaped) and `__MERMAID_CODE_JS__` (JS-escaped) tokens replaced in Swift before `loadHTMLString`. The `baseURL` points to the resource directory so the `<script src="mermaid.min.js">` tag resolves without network access.
6. **Click-to-focus with NSEvent monitors**: Coordinator installs local event monitors for click-outside (`.leftMouseDown`) and Escape key (`.keyDown`, keyCode 53) only while the diagram is focused, removing them on unfocus or teardown.

## Files

| File | Role |
|------|------|
| `mkdn/Core/Mermaid/MermaidWebView.swift` | NSViewRepresentable + MermaidContainerView + NoFocusRingWKWebView + Coordinator (message handling, navigation delegate, event monitors) |
| `mkdn/Core/Mermaid/MermaidThemeMapper.swift` | Maps AppTheme to Mermaid themeVariables JSON (hardcoded Solarized hex) |
| `mkdn/Core/Mermaid/MermaidRenderState.swift` | Render lifecycle enum (loading/rendered/error) |
| `mkdn/Core/Mermaid/MermaidError.swift` | Error cases for template-not-found and render failure |
| `mkdn/Features/Viewer/Views/MermaidBlockView.swift` | SwiftUI view: focus state, ZStack overlay (loading/error), aspect-ratio sizing, cursor management |
| `mkdn/Resources/mermaid-template.html` | HTML template with Mermaid.js init, render loop, ResizeObserver, reRenderWithTheme function |
| `mkdn/Resources/mermaid.min.js` | Bundled standard Mermaid.js library (offline, no CDN) |

## Dependencies

- **External**: WebKit framework (WKWebView, WKScriptMessageHandler, WKProcessPool), Mermaid.js (bundled resource)
- **Internal**: `AppSettings` / `AppTheme` / `ThemeColors` (theme integration), `MarkdownBlock.mermaidBlock` (parser output), `AnimationConstants` (focus border width/glow), `MotionPreference` (reduced-motion support), `PulsingSpinner` (loading indicator)

## Testing

| Test File | Coverage |
|-----------|----------|
| `mkdnTests/Unit/Core/MermaidThemeMapperTests.swift` | Hex value correctness for both themes, valid JSON output, all 26 required keys present, dark vs. light differentiation |
| `mkdnTests/Unit/Core/MermaidHTMLTemplateTests.swift` | Token substitution removes all placeholders, HTML escaping of special characters, JS escaping of backticks/backslashes/dollar signs, MermaidRenderState equatable conformance |
