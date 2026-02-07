# Quick Build: Fix Mermaid Rendering

**Created**: 2026-02-07T10:00:00-06:00
**Request**: mermaid rendering is broken
**Scope**: Medium

## Plan

**Reasoning**: The mermaid rendering pipeline spans 5 files in a single system (Core/Mermaid + Features/Viewer). A previous fix (2026-02-06) addressed CSS variable resolution in SVGSanitizer, but the issue is reportedly recurring. The build compiles and all existing tests pass, but no tests exercise the actual JS-to-SVG-to-Image pipeline end-to-end. The most likely failure points are: (1) JXKit/JSContext promise resolution with `awaitPromise()`, (2) SVG patterns the sanitizer does not handle, (3) SwiftDraw rejecting sanitized SVG constructs, or (4) a regression from the AppState-to-AppSettings refactor affecting theme propagation. Risk is medium due to the diagnostic investigation required before a fix can be applied. Files: 4-5, Systems: 1, Risk: Medium.

**Files Affected**:
- `mkdn/Core/Mermaid/MermaidRenderer.swift` -- JS context creation and SVG rendering
- `mkdn/Core/Mermaid/SVGSanitizer.swift` -- CSS variable/color-mix resolution
- `mkdn/Features/Viewer/Views/MermaidBlockView.swift` -- view-layer rendering and error display
- `mkdnTests/Unit/Core/MermaidRendererTests.swift` -- add end-to-end rendering test
- `mkdn/Core/Mermaid/MermaidImageStore.swift` -- image caching layer

**Approach**: First, add an integration test that exercises the full JS rendering pipeline (MermaidRenderer.renderToSVG with a real flowchart) to capture the actual error. If the JS execution succeeds, test the SVG output through SVGSanitizer and then through SwiftDraw to identify which stage fails. Once the failure point is isolated, apply the targeted fix. The previous SVGSanitizer fix resolved var() and color-mix() issues, so this is likely a new SVG construct or a regression from the AppSettings migration.

**Estimated Effort**: 2-4 hours

## Tasks

- [ ] **T1**: Add an end-to-end integration test in MermaidRendererTests that calls `renderToSVG("graph TD\n    A --> B", theme: .solarizedDark)` to exercise the full JS pipeline, capturing the actual error message or verifying SVG output starts with `<svg` `[complexity:medium]`
- [ ] **T2**: Investigate the failure by examining the error output from T1 -- if JS context creation fails, fix Bundle.module resource loading; if SVG sanitization leaves unsupported CSS, extend SVGSanitizer patterns; if SwiftDraw rejects the SVG, identify and strip the problematic construct `[complexity:medium]`
- [ ] **T3**: Apply the targeted fix based on T2 findings and verify the rendering pipeline produces a valid NSImage from MermaidBlockView.svgStringToImage `[complexity:medium]`
- [ ] **T4**: Run full test suite and verify no regressions; confirm mermaid diagrams render in the running app with `swift run mkdn` using a test markdown file containing mermaid blocks `[complexity:simple]`

## Implementation Summary

{To be added by task-builder}

## Verification

{To be added by task-reviewer if --review flag used}
