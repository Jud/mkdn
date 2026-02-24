# Design Decisions: Native LaTeX Math Rendering

**Feature ID**: native-latex-math
**Created**: 2026-02-24

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | Math rendering library | SwiftMath (mgriebling/SwiftMath >= 3.3.0) | Requirements specify it; native CoreGraphics rendering, no WebView, MIT license, actively maintained | LaTeXSwiftUI (uses WKWebView, violates constraints), MathJax via JSC (complex, JS dependency) |
| D2 | Block math rendering approach | Overlay pattern (NSTextAttachment placeholder + NSHostingView) | Identical to existing Mermaid/image overlay pattern; consistent architecture, theme-reactive | Inline rendering in NSTextStorage (works but loses overlay positioning and dynamic sizing benefits) |
| D3 | Inline math rendering approach | NSImage via NSTextAttachment in NSAttributedString | Natural fit for TextKit 2 text flow; baseline alignment via attachment bounds; prints naturally through NSPrintOperation | SwiftUI overlay per inline expression (positioning nightmare for mid-paragraph content), attributed string font manipulation (SwiftMath uses its own CG rendering engine) |
| D4 | Inline math detection location | Post-processing in MarkdownVisitor.inlineText(from:) | swift-markdown does not parse $ delimiters; post-processing the constructed AttributedString is the cleanest integration point | Pre-processing raw Markdown text before swift-markdown parsing (fragile, would need to re-inject results), custom swift-markdown plugin (undocumented extension API) |
| D5 | Block math print strategy | Render directly into NSAttributedString when isPrint=true in TextStorageBuilder | Simplest approach; reuses existing print pipeline completely; no new drawBackground extension needed | drawBackground extension like table print (more complex; tables needed it because of invisible-text pattern; math doesn't need invisible text) |
| D6 | Inline math attribute type | Custom AttributedString.Key (MathExpressionAttribute) carrying LaTeX source as String value | Clean separation between detection (MarkdownVisitor) and rendering (TextStorageBuilder); follows existing custom attribute pattern (CodeBlockAttributes, TableAttributes) | Sentinel characters in text (fragile, would need escaping), separate data structure passed alongside AttributedString (adds complexity to all inline processing APIs) |
| D7 | Theme change for block math | Re-render via MathBlockView.onChange(of: appSettings.theme) | SwiftMath bakes color into the rendered image; must re-render to change color. Single expression renders in < 1ms, so re-rendering is imperceptible | CALayer tint manipulation (not applicable to bitmap content), separate color overlay view (alpha compositing would degrade quality) |
| D8 | Theme change for inline math | Full TextStorageResult rebuild (existing pattern) | MarkdownPreviewView already rebuilds the entire TextStorageResult on theme change; inline math re-renders naturally as part of this existing flow | Selective NSTextAttachment replacement (complex traversal logic, unnecessary given full rebuild is already the established pattern) |
| D9 | MathRenderer concurrency model | @MainActor stateless enum | MTMathUILabel is an NSView requiring main thread; stateless enum avoids actor overhead; synchronous rendering is fast enough (< 1ms per expression on Apple Silicon) | Actor (like MermaidRenderer) -- unnecessary since there is no shared mutable state to protect; MermaidRenderer is an actor because JSC context access needs serialization |
| D10 | Inline math baseline alignment | NSTextAttachment.bounds with negative y origin using MTMathUILabel.descent | Standard NSTextAttachment technique for baseline alignment; MTMathUILabel accurately reports its mathematical descent, enabling precise baseline positioning | Manual font metric calculation (less accurate, does not account for expression-specific depth), fixed offset (does not adapt to expression shape -- subscripts need more offset than simple variables) |

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| New module location | `mkdn/Core/Math/` | KB patterns.md (Feature-Based MVVM, Core layer) | Math rendering is a core capability like Markdown and Mermaid, not a feature-specific view concern |
| MathBlockView location | `mkdn/Features/Viewer/Views/` | KB patterns.md (Feature-Based MVVM) | View components live in Features/Viewer/Views/ alongside MermaidBlockView, ImageBlockView |
| Builder extension file | `MarkdownTextStorageBuilder+MathInline.swift` | Codebase pattern (existing +Blocks, +Complex, +TableInline extensions) | Follows established file splitting pattern for the builder |
| Test file organization | `mkdnTests/Unit/Core/` | Codebase pattern (existing Core/ test files) | Follows established test directory structure |
| Test framework | Swift Testing (@Suite, @Test, #expect) | KB patterns.md, CLAUDE.md | Project standard; no XCTest |
| Fixture file | `fixtures/math-test.md` | Codebase convention (fixtures/table-test.md exists) | Follows existing fixture naming pattern |
| Error handling | Return nil from MathRenderer (caller handles fallback) | KB patterns.md (typed errors, graceful degradation) | Consistent with requirements (BR-4: parse failure is expected, not error) |
| Animation for block math overlay | None (instant appearance) | Existing overlay pattern analysis | Mermaid has loading animation because of async JS rendering; math rendering is synchronous and fast, so no loading state needed |
| Inline math scale-awareness | Render at screen backingScaleFactor * zoom scaleFactor | Codebase pattern (PlatformTypeConverter.bodyFont(scaleFactor:)) | Ensures crisp rendering at all zoom levels within the 0.5x-3.0x range |
| $ detection algorithm | Character-by-character state machine | Conservative default | Regex would work but state machine gives precise control over business rules (BR-2 whitespace, escaped $, adjacent $$) |
