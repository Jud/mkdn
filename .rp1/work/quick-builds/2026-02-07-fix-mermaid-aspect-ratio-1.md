# Quick Build: Fix Mermaid Aspect Ratio

**Created**: 2026-02-07T12:00:00Z
**Request**: Mermaid charts are rendering super long (tall). They should use the available width first, and then calculate the height based on the SVG's aspect ratio at that width. Currently the SVG renders at its intrinsic/natural size which can be very tall and narrow. The fix needs to happen in both the HTML template (CSS/JS that measures the SVG after render) and the SwiftUI frame sizing in MermaidBlockView. The JS sizeReport should report the SVG dimensions after the SVG has been constrained to fill the container width, and the SwiftUI side should use those dimensions.
**Scope**: Small

## Plan

**Reasoning**: 3 files affected, 1 system (Mermaid rendering pipeline), low-medium risk (CSS/JS sizing + SwiftUI frame changes contained to mermaid rendering). No architectural changes needed.

**Files Affected**:
- `mkdn/Resources/mermaid-template.html`
- `mkdn/Features/Viewer/Views/MermaidBlockView.swift`
- `mkdn/Core/Mermaid/MermaidWebView.swift`

**Approach**: The root cause is two-fold. First, the HTML template renders the SVG at its intrinsic/natural size because the `#diagram` container uses `display: inline-block` and the SVG only has `max-width: 100%` (which does nothing when the container shrinks to content). The fix is to make the diagram container `display: block; width: 100%` and force the SVG to `width: 100%` so the browser reflows it to fill the available width while maintaining aspect ratio. Then the JS `sizeReport` will report the width-constrained dimensions. Second, the SwiftUI side in `MermaidBlockView` currently only tracks `renderedHeight` and ignores the width. It needs to also track the aspect ratio from the sizeReport so that it can use `GeometryReader` to compute the correct height for whatever width SwiftUI assigns. The coordinator in `MermaidWebView` needs to extract both width and height, compute the aspect ratio, and pass it up.

**Estimated Effort**: 1.5 hours

## Tasks

- [x] **T1**: Update `mermaid-template.html` CSS to force `#diagram` to `display: block; width: 100%` and `#diagram svg` to `width: 100%; height: auto` so the SVG fills the container width and the browser computes the proportional height. Verify the sizeReport JS already reports post-layout dimensions via `getBoundingClientRect()`. `[complexity:simple]`
- [x] **T2**: Update `MermaidWebView.swift` coordinator to extract both `width` and `height` from the sizeReport message and compute/store an aspect ratio (height/width). Add a new `@Binding var renderedAspectRatio: CGFloat` to `MermaidWebView` and update the coordinator's `handleMessage` to set it. `[complexity:simple]`
- [x] **T3**: Update `MermaidBlockView.swift` to use `GeometryReader` to obtain the available width, add `@State private var renderedAspectRatio: CGFloat` state, pass it as a binding to `MermaidWebView`, and compute `height = availableWidth * aspectRatio` for the frame sizing instead of using the raw `renderedHeight`. `[complexity:medium]`
- [x] **T4**: Verify the `reRenderWithTheme` path in the HTML template also correctly constrains width (it calls `render()` which re-measures, so it should work, but confirm the new `<pre>` element respects the CSS). Also verify the `renderedHeight` fallback/loading state still looks correct with the new sizing approach. `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Resources/mermaid-template.html` | Changed `#diagram` from `display: inline-block` to `display: block; width: 100%` and `#diagram svg` from `max-width: 100%` to `width: 100%; height: auto` so the SVG fills container width and browser computes proportional height. `getBoundingClientRect()` already reports post-layout dimensions. | Done |
| T2 | `mkdn/Core/Mermaid/MermaidWebView.swift` | Added `@Binding var renderedAspectRatio: CGFloat` property. Updated `handleMessage` to extract both `width` and `height` from sizeReport, guard `width > 0`, and compute `renderedAspectRatio = height / width`. | Done |
| T3 | `mkdn/Features/Viewer/Views/MermaidBlockView.swift` | Added `@State private var renderedAspectRatio: CGFloat = 0.5` state. Replaced fixed `renderedHeight` frame with SwiftUI `.aspectRatio(1/renderedAspectRatio, contentMode: .fit)` when rendered, keeping 100px fixed height for loading/error states. Extracted `diagramContent` computed property with `@ViewBuilder` for clean conditional layout. | Done |
| T4 | (verification only) | Confirmed `reRenderWithTheme` works: new `<pre>` is replaced by SVG which inherits `width: 100%; height: auto` CSS. Loading/error states use 100px fixed height unaffected by aspect ratio changes. | Done |

## Verification

{To be added by task-reviewer if --review flag used}
