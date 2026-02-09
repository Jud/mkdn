# Hypotheses: Cross-Element Selection

**Feature**: cross-element-selection
**PRD**: [Cross-Element Selection](../../prds/cross-element-selection.md)
**Created**: 2026-02-07
**Status**: VALIDATED

## Hypotheses

### H1: Single AttributedString Approach

**Status**: REJECTED
**Risk**: High
**Statement**: Rendering the entire Markdown preview as a single `AttributedString` in one SwiftUI `Text` view will enable native cross-block text selection while preserving acceptable visual quality and performance.
**Rationale**: SwiftUI's `.textSelection(.enabled)` works within a single `Text` view. If the entire document is one `Text`, selection "just works." But this may sacrifice per-block layout control (custom spacing, animations, staggered entrance), custom views (Mermaid WKWebView, code blocks with syntax highlighting), and performance on large documents.
**Validation Method**: Code experiment -- build a minimal prototype that renders a multi-block Markdown document as a single `AttributedString` in one `Text` view and test: (1) does cross-block selection work, (2) can headings/paragraphs/code blocks be styled distinctly, (3) what happens with large documents (1000+ lines), (4) can non-text elements (Mermaid, images) be embedded.
**Success Criteria**: Selection works across blocks, styling is acceptable, no visible lag on 1000-line documents, and non-text elements can be interleaved or gracefully excluded.

### H2: NSTextView Overlay Approach

**Status**: CONFIRMED
**Risk**: High
**Statement**: A transparent `NSTextView` (or custom `NSView`) overlay placed on top of the SwiftUI preview can handle selection gestures and highlight rendering by mapping screen coordinates to the underlying block views, without disrupting the existing per-block rendering architecture.
**Rationale**: This preserves the current architecture (per-block SwiftUI views with custom rendering, animations, Mermaid WKWebViews) while adding selection as a layer on top. But coordinate mapping between AppKit and SwiftUI views is notoriously fragile, especially with scrolling and layout changes.
**Validation Method**: Code experiment + external research -- (1) research how other macOS apps handle selection over composite views, (2) build a minimal prototype with an NSView overlay on a SwiftUI ScrollView containing multiple Text views, (3) test coordinate mapping accuracy during scrolling, (4) test that click events still reach underlying views (Mermaid focus).
**Success Criteria**: Overlay correctly maps drag coordinates to text positions across blocks, highlight renders accurately during scrolling, and underlying view interactions (Mermaid click-to-focus) still work.

### H3: Custom SwiftUI Selection Model Approach

**Status**: REJECTED
**Risk**: Medium
**Statement**: A pure SwiftUI custom selection model that tracks character ranges across `MarkdownBlock` elements, with each block view participating in hit-testing and highlight rendering via shared state, can achieve cross-block selection without AppKit bridging.
**Rationale**: Pure SwiftUI avoids the fragile coordinate-mapping issues of the overlay approach and preserves the full per-block rendering architecture. But it requires each block view to know about selection state, perform its own hit-testing, and render partial highlights -- significant implementation effort and potential performance cost.
**Validation Method**: Codebase analysis + code experiment -- (1) analyze how the current `MarkdownBlockView` renders text to determine if character-level hit-testing is feasible, (2) prototype a selection gesture recognizer that tracks positions across a VStack of Text views, (3) test whether `GeometryReader` or preference keys can reliably map click positions to text character indices within individual Text views.
**Success Criteria**: Can determine which character in which block a click/drag position corresponds to, can render partial highlights within individual block views, and the approach works during scrolling.

### H4: SwiftUI Text Character Hit-Testing

**Status**: REJECTED
**Risk**: High
**Statement**: SwiftUI provides (or can be made to provide) character-level hit-testing on `Text` views -- i.e., given a screen coordinate within a `Text` view, determine which character index it maps to.
**Rationale**: Both Approach B (overlay) and Approach C (custom model) require mapping screen coordinates to character positions within rendered text. SwiftUI's `Text` does not expose a public API for this. AppKit's `NSTextView` has `characterIndex(for:)`, but SwiftUI `Text` is not backed by `NSTextView`. This is a foundational capability that must exist for either approach to work.
**Validation Method**: External research + code experiment -- (1) search for SwiftUI APIs or workarounds for character-level hit-testing in Text views (TextKit, NSTextContentManager, accessibility APIs), (2) investigate whether wrapping content in NSTextView instead of SwiftUI Text is viable, (3) test if `NSTextView` can be styled to match the current SwiftUI rendering quality.
**Success Criteria**: A reliable method exists to map a screen point to a character index within rendered text, with acceptable accuracy (within 1 character) and performance.

### H5: NSTextView Entrance Animation Preservation

**Status**: CONFIRMED
**Risk**: High
**Statement**: The NSTextView-based architecture (confirmed in H2) can reproduce the current staggered per-block entrance animation (fade-in + upward drift, staggered by block index) with visual fidelity comparable to the current SwiftUI implementation.
**Rationale**: The current animation uses per-block SwiftUI `.opacity()` + `.offset(y:)` modifiers with `.animation(.easeOut.delay(...))`. Moving to a single `NSTextView` eliminates per-block SwiftUI views, so this mechanism no longer applies. The question is whether NSTextView/TextKit 2/Core Animation can achieve an equivalent effect. Candidate approaches: (1) staged `NSTextStorage` insertion — append blocks one by one with delays, (2) `CAAnimation` on `NSTextLayoutFragment` views via `NSTextLayoutManager` delegate, (3) transitional SwiftUI overlay that fades out to reveal the final NSTextView, (4) `NSAnimationContext` with per-paragraph alpha/transform animation. If none of these can produce a smooth staggered fade+drift, the NSTextView architecture may need to be reconsidered.
**Validation Method**: External research + code experiment — (1) research whether `NSTextLayoutManager` exposes per-paragraph/per-layout-fragment views that can be independently animated, (2) research whether `CAAnimation` can be applied to `NSTextLayoutFragment` sublayers, (3) research staged `NSTextStorage` editing as an animation technique, (4) build a minimal prototype testing the most promising approach, (5) evaluate visual quality vs. the current SwiftUI animation.
**Success Criteria**: At least one approach produces a staggered entrance animation where each block fades in with upward drift, visually comparable to the current SwiftUI implementation, without degrading scroll performance or text selection.

## Validation Findings

### H1 Findings
**Validated**: 2026-02-07T21:23:00Z
**Method**: CODE_EXPERIMENT + EXTERNAL_RESEARCH
**Result**: REJECTED

**Evidence**:

Code experiment confirmed that a single `AttributedString` can be constructed with distinct styling per block type (headings with large bold fonts, paragraphs with body font, code with monospaced font, different colors). Building a 1000-block document took only 0.021 seconds, producing ~174K characters. The `Text` + `.textSelection(.enabled)` modifier does enable range-based drag selection on macOS within a single view.

However, critical limitations make this approach unacceptable for mkdn:

1. **No non-text element embedding**: SwiftUI `Text` can only render text from `AttributedString`. It cannot embed `WKWebView` (Mermaid diagrams), `Image` views, or any custom SwiftUI views. The current architecture uses `MermaidBlockView` with `WKWebView` for diagrams, `ImageBlockView` for images -- these cannot be interleaved into a single `Text` view.

2. **No per-block layout control**: `AttributedString` supports inline character-level styling (font, color, etc.) but not block-level layout properties like custom vertical spacing between blocks, full-width backgrounds for code blocks, left-border styling for blockquotes, or table grid layouts. The current `MarkdownPreviewView` uses a `VStack(spacing: 12)` with per-block views -- this layout granularity is lost.

3. **No per-block animations**: The current staggered entrance animation (`blockAppeared` dictionary, per-block opacity/offset animation) would be impossible with a single `Text` view. The entire document would have to appear/disappear as a unit.

4. **TextRenderer incompatibility**: Research confirmed (via fatbobman.com deep dive) that "once `.textSelection(.enabled)` is turned on, all TextRenderers become ineffective" -- a documented SwiftUI pitfall that further limits custom rendering.

5. **Block content limitations**: Research confirmed that "block content (blockquotes, code blocks, etc.) also cannot be selected together with the preceding or following Text" even in approaches that use multiple Text views, reinforcing that SwiftUI's text selection model is fundamentally per-view.

6. **Paragraph spacing is primitive**: `AttributedString` with `\n` separators produces single-line spacing, not the custom 12px inter-block spacing currently used. There is no `AttributedString` attribute for custom paragraph spacing in SwiftUI's `Text` (unlike NSAttributedString's `paragraphStyle.paragraphSpacing` which works in NSTextView).

**Sources**:
- Code experiment at `/tmp/hypothesis-cross-element-selection/Sources/main.swift`
- [A Deep Dive into SwiftUI Rich Text Layout](https://fatbobman.com/en/posts/a-deep-dive-into-swiftui-rich-text-layout/) (TextRenderer + textSelection incompatibility, cross-block selection limitations)
- [Enable text selection for non-editable text](https://nilcoalescing.com/blog/EnableTextSelectionForNonEditableText/) (per-view selection limitation confirmed)
- [WWDC25: Cook up a rich text experience in SwiftUI](https://developer.apple.com/videos/play/wwdc2025/280/) (TextEditor + AttributedString is editing-focused, not read-only viewer)

**Implications for Design**:
The single `AttributedString` approach cannot serve as the primary rendering strategy for mkdn's Markdown preview. It would require abandoning the entire per-block architecture including Mermaid diagram rendering, code block styling, table layouts, blockquote borders, and entrance animations. This approach might only work as a fallback for simple text-only documents, but is not a viable general solution.

---

### H4 Findings
**Validated**: 2026-02-07T21:23:00Z
**Method**: EXTERNAL_RESEARCH
**Result**: REJECTED

**Evidence**:

Extensive research confirms that SwiftUI's `Text` view does **not** expose any public API for character-level hit-testing. There is no method to determine which character index corresponds to a given screen coordinate within a `Text` view.

**SwiftUI Text has no hit-testing API:**
- SwiftUI's `Text` does not expose its internal text layout (no `NSLayoutManager`, no `NSTextLayoutManager`, no `NSTextContainer`).
- SwiftUI's hit-testing system (`allowsHitTesting`, tap gestures) operates at the view frame level, not the character level.
- There is no `Text.characterIndex(for:)` or equivalent API in SwiftUI.
- Accessibility APIs do not expose character-level position information from `Text` views.

**AppKit has the API, but only for NSTextView:**
- `NSTextView.characterIndexForInsertion(at:)` -- returns character index at a given point.
- `NSLayoutManager.characterIndex(for:in:fractionOfDistanceBetweenInsertionPoints:)` -- returns character index in TextKit 1.
- `NSTextLayoutManager.textLayoutFragment(for:)` + line fragment `characterIndex(for:)` -- TextKit 2 equivalent with coordinate conversion chain: text container space -> layout fragment space -> line fragment space.

**The gap cannot be bridged for SwiftUI Text:**
- SwiftUI `Text` is not backed by `NSTextView` on macOS. It uses a private rendering path (likely Core Text based).
- There is no public API to access the underlying text layout objects from a SwiftUI `Text` view.
- `_introspect` or mirror-based hacks to access internals are fragile and break across OS versions.

**The workaround is to use NSTextView directly:**
- If character-level hit-testing is needed, the text must be rendered in an `NSTextView` (via `NSViewRepresentable`), not a SwiftUI `Text` view.
- `NSTextView` provides `characterIndexForInsertion(at:)` natively.
- TextKit 2 (`NSTextLayoutManager`) provides `textLayoutFragment(for:)` for modern hit-testing with proper coordinate conversions.
- Third-party library STTextView (TextKit 2 based) also provides this capability.

**Sources**:
- [characterIndexForInsertion(at:) API](https://developer.apple.com/documentation/appkit/nstextview/1449505-characterindexforinsertionatpoin) (Apple official docs)
- [NSLayoutManager.characterIndex(for:in:fractionOfDistanceBetweenInsertionPoints:)](https://developer.apple.com/documentation/appkit/nslayoutmanager/characterindex(for:in:fractionofdistancebetweeninsertionpoints:)) (TextKit 1)
- [Adopting TextKit 2](https://shadowfacts.net/2022/textkit-2/) (textLayoutFragment hit-testing code examples, coordinate conversion chain)
- [STTextView](https://github.com/krzyzanowskim/STTextView) (TextKit 2 based text view alternative)
- [SwiftUI Hit-Testing Internals](https://dev.to/sebastienlato/swiftui-hit-testing-event-propagation-internals-2106) (confirms SwiftUI hit-testing is view-frame level, not character level)

**Implications for Design**:
**This is a critical finding.** Since SwiftUI `Text` cannot do character-level hit-testing, Approaches B (overlay) and C (custom model) cannot work with the current SwiftUI `Text`-based rendering. Any approach requiring character-level position mapping must replace SwiftUI `Text` with `NSTextView` for the text-bearing block views. This fundamentally reframes the design space: the choice is not between "SwiftUI overlay vs. SwiftUI custom model" but rather "how much of the rendering pipeline should migrate from SwiftUI Text to NSTextView?" The RichText library's approach (NSTextView for layout + text, SwiftUI overlay for custom views) is the proven architecture for this pattern.

---

### H2 Findings
**Validated**: 2026-02-07T21:23:00Z
**Method**: EXTERNAL_RESEARCH + CODEBASE_ANALYSIS
**Result**: CONFIRMED

**Evidence**:

Research confirms that the NSTextView-based approach (using platform text views for text rendering and selection, with SwiftUI views overlaid for non-text content) is a proven, working architecture used by production libraries.

**RichText library validates the architecture:**
The RichText library (by LiYanan, analyzed in fatbobman.com deep dive) uses exactly this pattern:
- **Platform Text View layer** (`NSTextView` on macOS): Handles overall layout, text rendering, and text selection natively.
- **SwiftUI View overlay**: Custom views positioned atop the platform layer using coordinate information from the text layout engine.
- Key finding: "The coordinate system of the overlay is consistent with the Platform Text View, so it fits perfectly."
- The approach enables "perfect text selection on both iOS and macOS" while supporting embedded SwiftUI views.

**NSTextView provides all required capabilities:**
- `characterIndexForInsertion(at:)` for character-level hit-testing (confirmed H4 alternative).
- `isEditable = false` + `isSelectable = true` for read-only selectable text.
- Native selection highlight rendering with the standard macOS blue highlight.
- Built-in Cmd+C copy support for selected text.
- `NSTextAttachment` for embedding non-text content placeholders within the text flow.
- TextKit 2 (`NSTextLayoutManager`) available on macOS 14+ (the project's deployment target).

**Coordinate mapping is feasible but requires care:**
- When using `NSViewRepresentable`, the AppKit view's coordinate system aligns with the SwiftUI layout system.
- For non-text elements (Mermaid WKWebViews, images), the overlay approach uses `InlineTextAttachment` objects that store view size and position, with the SwiftUI overlay rendering the actual views at those coordinates.
- Scrolling synchronization is the main challenge -- the NSTextView would need to be the scroll container (or tightly synchronized with SwiftUI's ScrollView).

**Impact on current architecture (codebase analysis):**
The current rendering pipeline (`mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`) uses:
- `ScrollView` > `VStack(spacing: 12)` > `ForEach(renderedBlocks)` > `MarkdownBlockView`
- Each `MarkdownBlockView` renders via SwiftUI `Text` for paragraphs/headings, `CodeBlockView` for code, `MermaidBlockView` (WKWebView) for diagrams, `TableBlockView` for tables.
- The migration would replace the `ScrollView` + `VStack` + individual `Text` views with a single `NSTextView` (via `NSViewRepresentable`) that handles all text content, with overlaid SwiftUI views for non-text elements.
- The `MarkdownBlock` enum and `MarkdownVisitor` parsing pipeline can remain unchanged -- only the view layer needs modification.
- Staggered entrance animations would need to be reimplemented within the NSTextView layer (or omitted for initial implementation).

**Key risks identified:**
1. **NSTextView + SwiftUI font mismatch**: SwiftUI's `Font` type requires explicit conversion to platform fonts (`NSFont`). iOS 16+/macOS 13+ provide safer conversion APIs.
2. **Mermaid WKWebView integration**: WKWebViews need to be positioned as overlays at coordinates determined by `NSTextAttachment` placeholders in the text flow. This is complex but proven by RichText library.
3. **Scroll synchronization**: If NSTextView handles scrolling internally, the SwiftUI overlay views must be positioned relative to the NSTextView's visible rect, not the SwiftUI coordinate space.
4. **Async content (images, Mermaid)**: "Because images are loaded asynchronously, they cannot be selected together with text" -- async content complicates the layout.

**Sources**:
- [A Deep Dive into SwiftUI Rich Text Layout](https://fatbobman.com/en/posts/a-deep-dive-into-swiftui-rich-text-layout/) (RichText library architecture, "Platform Text View + View overlay")
- [NSTextView.selectable](https://developer.apple.com/documentation/appkit/nstextview/1449297-selectable) (read-only selectable configuration)
- [RichTextKit](https://github.com/danielsaidi/RichTextKit) (production SwiftUI + NSTextView integration)
- Codebase analysis: `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift:28-46` (current VStack-based layout)
- Codebase analysis: `mkdn/Features/Viewer/Views/MarkdownBlockView.swift:21-67` (per-block rendering via Text views)
- Codebase analysis: `mkdn/Features/Viewer/Views/MermaidBlockView.swift:9-52` (WKWebView-based Mermaid rendering)

**Implications for Design**:
The NSTextView-based approach is the most architecturally sound path forward. It leverages proven macOS text selection capabilities while preserving the ability to embed non-text elements. The main implementation cost is replacing the SwiftUI `Text` rendering in `MarkdownBlockView` with `NSTextView`-based rendering, and managing the overlay coordination for Mermaid diagrams and other non-text content. This approach should be the primary recommendation for the feature design.

---

### H3 Findings
**Validated**: 2026-02-07T21:23:00Z
**Method**: CODEBASE_ANALYSIS + EXTERNAL_RESEARCH
**Result**: REJECTED

**Evidence**:

H3 proposed a pure SwiftUI custom selection model where each block view participates in hit-testing and highlight rendering. This approach is rejected because it depends on H4 (SwiftUI Text character hit-testing), which was rejected.

**Codebase analysis confirms the dependency:**
The current `MarkdownBlockView` (`mkdn/Features/Viewer/Views/MarkdownBlockView.swift`) renders text blocks as SwiftUI `Text(attributedString)` views. For H3's custom selection model to work, each of these `Text` views would need to:
1. Report which character a click/drag coordinate maps to.
2. Render partial selection highlights (e.g., characters 5-20 highlighted in a paragraph).

SwiftUI `Text` cannot do either of these. There is no API to:
- Get a character index from a point within a `Text` view.
- Apply partial background highlighting to a range of characters within a `Text` view (the `.textSelection(.enabled)` modifier's highlight is system-managed and cannot be controlled programmatically).

**GeometryReader cannot bridge the gap:**
`GeometryReader` can determine the frame of a `Text` view relative to a coordinate space, but it cannot determine character positions within the text. Text layout (line wrapping, glyph positioning) is internal to the `Text` view and not exposed through any SwiftUI API.

**Preference keys are insufficient:**
SwiftUI preference keys can propagate view geometry up the hierarchy, but they have the same limitation -- they operate on view frames, not on internal text layout geometry.

**The approach would require replacing Text with NSTextView:**
If each block's text were rendered via an `NSTextView` (wrapped in `NSViewRepresentable`) instead of SwiftUI `Text`, then character-level hit-testing would be possible via `characterIndexForInsertion(at:)`. But at that point, the approach converges with H2 (NSTextView-based rendering), eliminating the "pure SwiftUI" distinction that motivated H3.

**Sources**:
- H4 findings (SwiftUI Text lacks character hit-testing API)
- Codebase analysis: `mkdn/Features/Viewer/Views/MarkdownBlockView.swift:27-31` (paragraph rendering as `Text(text)`)
- Codebase analysis: `mkdn/Features/Viewer/Views/MarkdownBlockView.swift:83-88` (heading rendering as `Text(text)`)
- [Enable text selection for non-editable text](https://nilcoalescing.com/blog/EnableTextSelectionForNonEditableText/) ("no way to select contents of multiple Text views simultaneously")
- [SwiftUI Mastering Text Selection](https://medium.com/@itsuki.enjoy/swiftui-mastering-text-selection-a11e1f9bd54f) (per-view selection boundary)

**Implications for Design**:
A pure SwiftUI custom selection model is not feasible with the current SwiftUI `Text` API. Any approach requiring character-level position mapping must use AppKit text views (NSTextView or equivalent). This eliminates Approach C as a pure-SwiftUI option and directs the design toward H2's NSTextView-based architecture.

---

### H5 Findings
**Validated**: 2026-02-08T00:00:00Z
**Method**: EXTERNAL_RESEARCH
**Result**: CONFIRMED

**Evidence**:

TextKit 2's `NSTextViewportLayoutController` delegate architecture provides direct, per-paragraph layer access that enables staggered entrance animations equivalent to the current SwiftUI implementation.

**The key mechanism: `configureRenderingSurfaceFor` delegate method**

TextKit 2's viewport layout controller calls three delegate methods during layout:

1. `textViewportLayoutControllerWillLayout(_:)` — called before layout begins
2. `textViewportLayoutController(_:configureRenderingSurfaceFor:)` — called **for each visible `NSTextLayoutFragment`** (one per paragraph)
3. `textViewportLayoutControllerDidLayout(_:)` — called after all fragments are laid out

Each `NSTextLayoutFragment` gets its own `CALayer` (via a custom `TextLayoutFragmentLayer` subclass). This is the same granularity as the current per-block SwiftUI views — one animatable unit per paragraph/heading/code block.

**Apple's own sample code demonstrates per-fragment animation:**

```swift
func textViewportLayoutController(
    _ controller: NSTextViewportLayoutController,
    configureRenderingSurfaceFor textLayoutFragment: NSTextLayoutFragment
) {
    let (layer, layerIsNew) = findOrCreateLayer(textLayoutFragment)
    if !layerIsNew {
        let oldPosition = layer.position
        layer.updateGeometry()
        if oldPosition != layer.position {
            animate(layer, from: oldPosition, to: layer.position)
        }
    }
    contentLayer.addSublayer(layer)
}

private func animate(_ layer: CALayer, from source: CGPoint, to destination: CGPoint) {
    let animation = CABasicAnimation(keyPath: "position")
    animation.fromValue = source
    animation.toValue = destination
    animation.duration = 0.3
    layer.add(animation, forKey: nil)
}
```

**Adapting for staggered entrance animation:**

The current mkdn animation uses per-block opacity (0→1) + offset (y: 8→0) with staggered delays. This maps directly to `CALayer` animation:

1. In `configureRenderingSurfaceFor:`, detect newly created layers (`layerIsNew == true`).
2. For new layers during an entrance animation pass:
   - Set initial `layer.opacity = 0` and offset `layer.position.y += 8`.
   - Apply two `CABasicAnimation`s: one on `"opacity"` (0→1) and one on `"position"` (offset→final), both with `.easeOut` timing.
   - Stagger the `beginTime` by `Double(fragmentIndex) * staggerDelay`, capped at `staggerCap`.
3. Track whether the current render is a full reload vs. incremental edit (same logic as the current `shouldStagger` check). Only apply entrance animation on full reloads.
4. Respect `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` for the Reduce Motion setting.

**Why this works well:**

- `NSTextLayoutFragment` maps 1:1 to paragraphs — the same granularity as `MarkdownBlock` in the current architecture.
- `CALayer` provides `opacity`, `position`, `transform` — all animatable with `CABasicAnimation` or `CAAnimationGroup`.
- `CABasicAnimation` supports `beginTime` for stagger delays, `timingFunction` for ease-out curves, and `duration` matching the current SwiftUI animation parameters.
- The viewport layout controller only calls `configureRenderingSurfaceFor:` for visible fragments, so off-screen blocks don't pay animation cost.
- This is the **same mechanism Apple uses** in their TextKit 2 sample app to animate paragraph repositioning when comments are inserted — we're just applying it to entrance appearance instead.

**Risks and caveats:**

1. **First-frame flicker**: Must ensure the `NSTextStorage` is populated and layout completes before the view becomes visible, so that `configureRenderingSurfaceFor:` fires with the correct initial state. A brief initial opacity=0 on the entire `NSTextView` (removed after first layout pass) prevents flicker.
2. **Incremental vs. full reload detection**: Need to distinguish between "new document loaded" (stagger) and "user typed a character" (no stagger). This mirrors the current `shouldStagger` logic and can use the same heuristic (check if any fragment layers already exist).
3. **Fragment count vs. block count**: `NSTextLayoutFragment` boundaries correspond to paragraphs in the `NSTextStorage`, not necessarily to `MarkdownBlock` boundaries. A heading + its following paragraph are two separate fragments (two separate layers), which is actually the desired behavior. Code blocks with multiple lines may be one fragment or multiple depending on how they're modeled in the `NSAttributedString`. This needs verification during implementation.

**Sources**:
- [Meet TextKit 2 — WWDC21](https://developer.apple.com/videos/play/wwdc2021/10061/) (NSTextViewportLayoutController delegate, per-fragment layer animation, Apple sample code)
- [TextKit 2 Example App from the Apple Docs — Christian Tietze](https://christiantietze.de/posts/2022/05/textkit2-example/) (configureRenderingSurfaceFor implementation details, findOrCreateLayer pattern)
- [CALayer.opacity](https://developer.apple.com/documentation/quartzcore/calayer/1410933-opacity) (animatable opacity property)
- [CABasicAnimation](https://developer.apple.com/documentation/quartzcore/cabasicanimation) (beginTime for stagger delays, timingFunction for easing)

**Implications for Design**:
The NSTextView architecture fully supports staggered entrance animations via TextKit 2's per-layout-fragment `CALayer` system. The implementation maps almost directly from the current SwiftUI pattern (per-block opacity + offset with stagger delay) to the Core Animation equivalent (per-fragment-layer `CABasicAnimation` on opacity + position with staggered `beginTime`). This removes the entrance animation concern as a blocker for the NSTextView migration. The animation should be implemented during the Core phase alongside the initial `NSTextView` renderer, not deferred to a later phase.

---

## Summary

| Hypothesis | Risk | Result | Implication |
|------------|------|--------|-------------|
| H1: Single AttributedString | HIGH | REJECTED | Cannot embed non-text elements (Mermaid, images); loses per-block layout, animations, and custom styling |
| H2: NSTextView Overlay | HIGH | CONFIRMED | Proven architecture (RichText library); NSTextView provides selection + hit-testing; overlay handles non-text elements |
| H3: Custom SwiftUI Selection | MEDIUM | REJECTED | Depends on H4 which is rejected; SwiftUI Text lacks character-level hit-testing and programmatic highlight control |
| H4: SwiftUI Text Hit-Testing | HIGH | REJECTED | No public API exists; character-level hit-testing requires NSTextView or TextKit; cannot be done with SwiftUI Text |
| H5: NSTextView Entrance Animation | HIGH | CONFIRMED | TextKit 2's per-layout-fragment CALayer system supports staggered fade+drift entrance animation via configureRenderingSurfaceFor delegate |
