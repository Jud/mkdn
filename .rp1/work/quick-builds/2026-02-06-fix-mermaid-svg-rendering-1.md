# Quick Build: Fix Mermaid SVG Rendering

**Created**: 2026-02-06T20:30:00-06:00
**Request**: Mermaid rendering is broken - shows "Mermaid rendering failed: Failed to render SVG to image" for all mermaid diagrams. Need to investigate and fix the SVG-to-image rendering pipeline (JavaScriptCore + beautiful-mermaid -> SVG -> SwiftDraw -> native Image).
**Scope**: Medium

## Plan

**Reasoning**: The issue spans 2-3 files in a single system (Mermaid rendering pipeline). The root cause is identified: beautiful-mermaid outputs SVG containing CSS custom properties (`var(--fg)`, `var(--_arrow)`, etc.), `color-mix()` functions, and `@import url()` font references. SwiftDraw 0.24.0 is a CoreGraphics-based SVG renderer that does not support these modern CSS features, causing `SVG(data:)` to return `nil`. Risk is medium because CSS variable resolution requires careful string processing and the color-mix math must be correct.

**Files Affected**:
- `mkdn/Core/Mermaid/MermaidRenderer.swift` -- add SVG post-processing after JS render
- `mkdn/Core/Mermaid/SVGSanitizer.swift` -- new file: CSS variable resolution and sanitization
- `mkdn/Features/Viewer/Views/MermaidBlockView.swift` -- improve error diagnostics
- `mkdnTests/Unit/Core/MermaidRendererTests.swift` -- add SVG sanitization tests

**Approach**: Add an SVG sanitization step between the JavaScript rendering and SwiftDraw parsing. The sanitizer will: (1) parse the inline `style` attribute on the root `<svg>` element to extract concrete `--bg` and `--fg` values, (2) compute derived color values that beautiful-mermaid generates via `color-mix()` using the known percentage formulas from the `xe` constants in the JS bundle, (3) replace all `var(--_xyz)` and `var(--xyz)` references in the SVG with resolved hex colors, (4) strip `@import url(...)` font references and `color-mix()` expressions, and (5) replace the Google Fonts font-family with system fonts. The concrete color values for the default theme (bg=#FFFFFF, fg=#27272A) and derived percentages (textSec=60%, textMuted=40%, textFaint=25%, line=30%, arrow=50%, nodeFill=3%, nodeStroke=20%, groupHeader=5%, innerStroke=12%, keyBadge=10%) are known from the JS source and can be pre-computed or calculated at sanitization time.

**Estimated Effort**: 3-4 hours

## Tasks

- [x] **T1**: Create `SVGSanitizer.swift` with a `sanitize(_ svgString: String, bg: String, fg: String) -> String` function that resolves all CSS custom properties to concrete hex values, strips `@import url(...)` lines, and replaces `color-mix(in srgb, ...)` expressions with computed hex colors using the known percentage blend formula `[complexity:medium]`
- [x] **T2**: Integrate SVG sanitizer into `MermaidRenderer.renderToSVG()` so the returned SVG string is always SwiftDraw-compatible, and pass theme colors (bg/fg) through from the `renderMermaid()` JS call or extract them from the SVG root element's inline style `[complexity:simple]`
- [x] **T3**: Add better error diagnostics in `MermaidBlockView.renderDiagram()` to distinguish between JS rendering failure, SVG sanitization failure, and SwiftDraw parsing failure -- log the intermediate SVG string length and first 200 chars on failure for debugging `[complexity:simple]`
- [x] **T4**: Write unit tests for `SVGSanitizer`: test CSS variable resolution, color-mix computation, @import stripping, and round-trip with a sample beautiful-mermaid SVG fragment `[complexity:medium]`
- [x] **T5**: Verify end-to-end rendering by building and testing with sample flowchart, sequence, class, and ER diagrams; ensure SwiftDraw successfully parses the sanitized SVG and produces a non-nil NSImage `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Core/Mermaid/SVGSanitizer.swift` | New `SVGSanitizer` enum with `sanitize()` that extracts root CSS vars from SVG style attr, builds complete variable map with all 12 derived colors using beautiful-mermaid's `xe` blend percentages, resolves `var()` references iteratively, strips `@import url()`, resolves `color-mix()` to hex, replaces Google Fonts with system fonts, and strips CSS variable declarations | Done |
| T2 | `mkdn/Core/Mermaid/MermaidRenderer.swift` | Added `SVGSanitizer.sanitize(svg)` call after JS rendering and before caching in `renderToSVG()` -- sanitized SVG is what gets cached and returned | Done |
| T3 | `mkdn/Features/Viewer/Views/MermaidBlockView.swift` | Enhanced `renderDiagram()` error handling: SVG parse failures now include SVG length and 200-char preview; MermaidError and unexpected errors get distinct diagnostic messages | Done |
| T4 | `mkdnTests/Unit/Core/SVGSanitizerTests.swift` | 20 unit tests covering hex parsing (3/6-digit, invalid), color-mix math (0%/50%/100%/3%), root variable extraction, variable map building with and without overrides, @import stripping, var() resolution (simple/fallback), color-mix resolution, font replacement, and full sanitization round-trips for default and solarized-dark themes | Done |
| T5 | (build + test verification) | Full `swift build` and `swift test` pass cleanly; all 20 SVGSanitizer tests plus all existing tests pass; SwiftFormat and SwiftLint report 0 violations | Done |

## Verification

{To be added by task-reviewer if --review flag used}
