# Design Decisions: Core Markdown Rendering

**Feature ID**: core-markdown-rendering
**Created**: 2026-02-06

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | Image loading approach | NSImage direct loading via URLSession (remote) and NSImage(contentsOf:) (local) | AsyncImage is unreliable for local file URLs on macOS; NSImage provides consistent behavior for both sources and avoids SwiftUI framework limitations | AsyncImage (network-only, no local file support); WKWebView-based loading (violates hard constraint) |
| D2 | Nested list depth tracking | Pass `depth: Int` parameter through the view hierarchy | Keeps the MarkdownBlock model flat and simple; depth is a rendering concern, not a semantic one. Avoids adding complexity to the visitor. | Add `depth` property to ListItem model; add `depth` to each MarkdownBlock case; use a separate NestedListBlock case |
| D3 | Table model enrichment | Replace `[String]` headers/cells with `[TableColumn]` (header + alignment) and `[[AttributedString]]` rows | Enables column alignment (FR-005) and inline formatting in table cells (FR-007). AttributedString is already used for all other inline content. | Keep plain String cells (loses inline formatting); add alignment as a separate parallel array |
| D4 | Multi-language syntax highlighting | Swift-only via Splash; all other languages render as plain themed monospace | Splash only ships SwiftGrammar. Adding custom grammars for other languages is out of scope. Graceful degradation per BR-001. | Integrate tree-sitter for multi-language support (heavyweight, new dependency); use regex-based highlighting (fragile, maintenance burden) |
| D5 | Link interaction mechanism | AttributedString .link attribute consumed by SwiftUI's built-in openURL | Minimal code; follows platform conventions. SwiftUI Text automatically makes .link attributes tappable when the environment provides openURL. | Custom Button/Link wrapping per link run (more code, breaks text flow); NSWorkspace.shared.open() via manual gesture (bypasses SwiftUI environment) |
| D6 | HTML block handling | Render as raw monospace text (similar to unfenced code block) | Conservative MVP approach per BR-005. Rendering HTML natively would require a parser and violate the no-WKWebView constraint. Displaying raw text is honest about the limitation. | Silently omit HTML blocks (current behavior -- loses content); parse subset of HTML (scope creep, security risk) |
| D7 | Caching strategy for parsed blocks | No caching; stateless re-render on every change | Pipeline is fast enough (< 100ms for < 500 lines per NFR-001). LazyVStack provides view-level virtualization. Adding a cache introduces stale-state bugs and complexity. | LRU cache keyed on content hash + theme (premature optimization); memoize via Equatable MarkdownBlock comparison |
| D8 | MarkdownBlock ID stability | Deterministic content-based hashing (DJB2 or similar) replacing .hashValue and UUID() | .hashValue is not stable across process runs (Swift randomizes it). UUID() for thematicBreak causes unnecessary SwiftUI view identity churn on every render. Deterministic IDs enable proper view diffing. | Use array index as ID (fragile under insertions); use UUID for all cases (no view reuse) |
| D9 | PreviewViewModel usage | Preserve current pattern: MarkdownPreviewView calls MarkdownRenderer directly, PreviewViewModel used by SplitEditorView | MarkdownPreviewView's direct call is simpler and stateless. PreviewViewModel adds value for the editor use case (didSet-triggered re-render) but not for read-only preview. | Route all rendering through PreviewViewModel (unnecessary indirection for preview-only mode) |
| D10 | Visitor Strikethrough support | Handle via Strikethrough AST node from swift-markdown, apply .strikethroughStyle on AttributedString | swift-markdown supports GFM strikethrough natively. AttributedString has first-class strikethrough support. No additional dependencies. | Regex-based strikethrough detection post-parsing (fragile); custom inline parser (unnecessary) |

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| Markdown parser | apple/swift-markdown (existing) | KB patterns.md, Package.swift | Already a project dependency; Apple-maintained; supports CommonMark + GFM tables/strikethrough |
| Syntax highlighter | Splash (existing) | KB patterns.md, Package.swift | Already a project dependency; Swift-only is an accepted trade-off per requirements A2 |
| Image loading | NSImage + URLSession | Codebase pattern (MermaidBlockView uses NSImage) | Follows existing pattern for native image handling; avoids AsyncImage local-file limitations |
| State management | @Observable + @Environment | KB patterns.md | Established project pattern; required by project constraints |
| Testing framework | Swift Testing (@Suite, @Test, #expect) | KB patterns.md, existing tests | Required by NFR-010; all existing tests use this framework |
| View architecture | Feature-Based MVVM | KB patterns.md, existing structure | Established project pattern; ImageBlockView placed in Features/Viewer/Views/ |
| Inline formatting approach | AttributedString with inlinePresentationIntent | Codebase (MarkdownVisitor.swift) | Already implemented for bold/italic/code; extend for strikethrough |
| Error handling | Typed errors with LocalizedError | KB patterns.md | Established pattern per MermaidError; apply to image loading errors |
| Concurrency model | @MainActor for views, async/await for image loading | KB architecture.md | Follows existing concurrency model; image loading is the only async operation in this feature |
