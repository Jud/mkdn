# Quick Build: Fix Mermaid Block Rendering

**Created**: 2026-02-07T18:30:00-06:00
**Request**: Fix Mermaid block rendering: (1) Mermaid renderers are not auto-resizing to fit their content, (2) pinch-to-zoom is not working, (3) they seem totally broken/not rendering, (4) they should pre-render content eagerly instead of waiting until scrolled into view.
**Scope**: Medium

## Plan

**Reasoning**: 4 files affected, 1 system (Mermaid rendering pipeline), medium risk. The codebase was recently re-architected from JavaScriptCore + beautiful-mermaid + SwiftDraw to WKWebView-per-diagram. The new pipeline has 4 distinct issues that can each be addressed with targeted fixes in the view layer. No architectural changes needed -- these are integration/wiring bugs in the new WKWebView approach.

**Files Affected**:
- `mkdn/Features/Viewer/Views/MermaidBlockView.swift` -- auto-sizing frame logic, maxDiagramHeight cap
- `mkdn/Core/Mermaid/MermaidWebView.swift` -- enable WKWebView magnification for pinch-to-zoom, fix WKWebView frame to fill container
- `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift` -- change LazyVStack to VStack for eager rendering
- `mkdn/Resources/mermaid-template.html` -- fix body overflow style to allow content measurement, add error handling for mermaid.js load failure

**Approach**: Fix each of the 4 issues independently. (1) Auto-sizing: remove the `maxDiagramHeight` cap or raise it significantly, and ensure the WKWebView's intrinsic size is driven by the JS sizeReport callback. (2) Pinch-to-zoom: set `webView.allowsMagnification = true` in MermaidWebView.makeNSView so WKWebView supports native pinch gestures when focused. (3) Broken rendering: verify the mermaid.min.js resource is standard Mermaid.js (not the old beautiful-mermaid), ensure Bundle.module resource loading works, and check that the HTML template's `<script src="mermaid.min.js">` resolves correctly against the baseURL. (4) Eager pre-rendering: change `LazyVStack` to `VStack` in MarkdownPreviewView so all blocks (including Mermaid WKWebViews) are instantiated immediately rather than deferred until scroll.

**Estimated Effort**: 3-4 hours

## Tasks

- [x] **T1**: Diagnose and fix broken rendering -- verify mermaid.min.js is valid standard Mermaid.js, ensure the HTML template loads correctly via Bundle.module baseURL, and add console/error logging to the JS render function so failures are surfaced to the Swift renderError handler `[complexity:medium]`
- [x] **T2**: Fix auto-resizing -- remove or significantly raise the 600px maxDiagramHeight cap in MermaidBlockView, ensure the WKWebView frame fills its container by setting proper autoresizing constraints, and verify the JS sizeReport message correctly drives the SwiftUI frame height `[complexity:medium]`
- [x] **T3**: Enable pinch-to-zoom -- set `webView.allowsMagnification = true` in MermaidWebView.makeNSView and verify that the MermaidContainerView hitTest gating correctly enables/disables interaction on focus/unfocus `[complexity:simple]`
- [x] **T4**: Enable eager pre-rendering -- change LazyVStack to VStack in MarkdownPreviewView.swift so all Mermaid blocks create their WKWebViews immediately on document load, and verify rendering works for documents with multiple diagrams `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Resources/mermaid-template.html` | Changed `overflow: hidden` to `overflow: visible` on body so content can be measured; added guard for `typeof mermaid === 'undefined'` that posts renderError if mermaid.min.js fails to load; added error case when mermaid.run() produces no SVG; made `reRenderWithTheme` a window-scoped function | Done |
| T2 | `mkdn/Features/Viewer/Views/MermaidBlockView.swift`, `mkdn/Core/Mermaid/MermaidWebView.swift` | Removed the 600px `maxDiagramHeight` cap so frame is driven entirely by JS `sizeReport` height; replaced `autoresizingMask` with proper Auto Layout constraints (leading/trailing/top/bottom) so WKWebView fills container; initialized WKWebView frame from `container.bounds` instead of `.zero` | Done |
| T3 | `mkdn/Core/Mermaid/MermaidWebView.swift` | Set `webView.allowsMagnification = true` in `makeNSView`; MermaidContainerView hitTest gating already correctly gates interaction on focus state | Done |
| T4 | `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift` | Changed `LazyVStack` to `VStack` so all blocks (including Mermaid WKWebViews) are instantiated immediately on document load | Done |

## Verification

{To be added by task-reviewer if --review flag used}
