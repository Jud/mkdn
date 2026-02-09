# Design Decisions: Cross-Element Selection

**Feature ID**: cross-element-selection
**Created**: 2026-02-08

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | Text rendering technology for preview pane | NSTextView + TextKit 2 (NSTextLayoutManager) | Only native macOS technology that provides continuous cross-block text selection with standard platform behaviors (Shift-click, Cmd+A, Cmd+C). TextKit 2 on macOS 14+ provides per-layout-fragment control needed for entrance animation. | (a) SwiftUI overlay selection tracking -- would require reimplementing all selection behaviors; (b) WebView-based rendering -- contradicts native UI constraint; (c) Multiple Text views with custom gesture coordinator -- cannot match native selection feel |
| D2 | Non-text element (Mermaid, images) positioning strategy | NSTextAttachment placeholders in text flow + overlay NSHostingView positioned at attachment coordinates | Allows non-text elements to participate in document flow (pushing text below them) while remaining interactive and separately rendered. Proven pattern used by rich-text editing libraries. | (a) Render everything as text -- impossible for Mermaid WKWebView diagrams; (b) Interleave NSTextView segments with SwiftUI views -- breaks continuous selection across segments |
| D3 | Entrance animation technology | Per-layout-fragment CALayer animation via NSTextViewportLayoutControllerDelegate | Provides per-block stagger control matching current SwiftUI fadeIn + offset animation. Operates within TextKit 2's layout architecture rather than fighting it. | (a) Animate entire NSTextView as one unit -- loses per-block stagger; (b) SwiftUI animation wrapper -- cannot control individual fragment appearance timing; (c) Manual CALayer sublayer creation -- fragile, conflicts with TextKit rendering |
| D4 | Code block rendering approach | Inline text with monospaced font + background paragraph attribute | Maximizes selectability -- code text is part of continuous selection. Syntax highlighting preserved via attributed string color runs from Splash. Matches CL-004 (prefer inline for selectability). | Overlay approach (like Mermaid blocks) -- would exclude code blocks from text selection, contradicting core feature purpose |
| D5 | Table rendering approach | Inline text with paragraph indent/tab stop alignment | Keeps table content selectable as continuous text (CL-002). Selection flows through table cells naturally. | NSTextAttachment overlay -- would exclude table content from selection; NSTextTable -- deprecated in TextKit 2 |
| D6 | Relationship to existing rendering pipeline | Preserve MarkdownRenderer, MarkdownVisitor, MarkdownBlock unchanged; add new conversion layer | Minimizes blast radius. Existing parsing logic and tests remain valid. New MarkdownTextStorageBuilder is purely additive. | Rewrite MarkdownVisitor to produce NSAttributedString directly -- higher risk, breaks all existing rendering tests, tightly couples parsing to AppKit |
| D7 | Color conversion approach | `NSColor(swiftUIColor)` initializer (macOS 14+) | Direct platform conversion with correct color space handling. No custom code needed. | Manual RGB component extraction -- error-prone, may lose color space information |
| D8 | Splash syntax highlighting integration | Convert Splash's Foundation.AttributedString output to NSAttributedString | Splash already produces correctly styled AttributedString. Foundation provides `NSAttributedString(attributedString)` conversion. No re-implementation needed. | Re-implement syntax highlighting with NSAttributedString output format -- unnecessary code duplication |
| D9 | Selection state lifecycle | Programmatic clear via `NSTextView.setSelectedRange()` in updateNSView | NSTextView selection is inherently imperative. Clearing on content change, theme change, and mode switch matches FR-008 requirements. | SwiftUI Binding-based selection -- NSTextView doesn't support declarative selection state |

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| Text rendering layer | NSTextView + TextKit 2 | Requirements (specifies NSTextView-based architecture) | Requirements explicitly call for NSTextView-based architecture to enable cross-block selection |
| SwiftUI-AppKit bridging | NSViewRepresentable | KB patterns.md + codebase | Existing pattern used by MermaidWebView and WindowAccessor in the codebase |
| Animation framework | Core Animation (CABasicAnimation) | Requirements A-6 + codebase AnimationConstants | Requirements specify per-layout-fragment layer animation; CA is the native layer animation API |
| Overlay hosting | NSHostingView | Codebase pattern | Standard approach for embedding SwiftUI views in AppKit; follows existing Mermaid architecture |
| Font specification | NSFont system APIs | Codebase MarkdownBlockView.swift | Direct equivalents exist for every SwiftUI font specification used in MarkdownBlockView |
| Code block strategy | Inline (not overlay) | Requirements CL-004 | Conservative default favoring selectability per requirements specification |
| Table strategy | Inline text flow | Requirements CL-002 | Conservative default; continuous text selection without cell boundary awareness |
| Test framework | Swift Testing (@Suite, @Test, #expect) | KB patterns.md | Existing codebase standard; all tests use Swift Testing |
| New file locations | Core/Markdown/ for converters, Features/Viewer/Views/ for views | KB modules.md | Follows existing module organization |
| Paragraph separation | Single \n with paragraph spacing attributes | Platform convention | NSAttributedString convention; clean plain-text extraction for copy |
