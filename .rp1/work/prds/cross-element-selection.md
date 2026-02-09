# PRD: Cross-Element Selection

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.3.0
**Status**: Complete
**Created**: 2026-02-07

## Surface Overview

Cross-element selection enables users to click-drag across multiple distinct rendered Markdown blocks in the preview pane and copy the selected content as plain text. Currently, mkdn renders each Markdown block (paragraph, heading, code block, list, blockquote, table) as an independent SwiftUI `Text` view with `.textSelection(.enabled)`, meaning selection stops at block boundaries. This surface replaces the SwiftUI `Text`-based preview rendering with an `NSTextView`-based architecture that provides native cross-block text selection while preserving the ability to embed non-text elements (Mermaid diagrams, images) via overlays.

### Why NSTextView

Hypothesis validation ([hypotheses.md](../features/cross-element-selection/hypotheses.md)) eliminated the other approaches:

- **Single AttributedString** (REJECTED): SwiftUI `Text` cannot embed WKWebView (Mermaid), images, or custom views. Loses per-block layout control, animations, and custom styling. `.textSelection(.enabled)` disables TextRenderers.
- **Pure SwiftUI custom selection** (REJECTED): SwiftUI `Text` has no public API for character-level hit-testing — no way to map a screen coordinate to a character index. `GeometryReader` and preference keys only see view frames, not text layout internals.
- **NSTextView overlay** (CONFIRMED): Proven architecture (RichText library). `NSTextView` provides `characterIndexForInsertion(at:)`, native selection highlight, Cmd+C, and `NSTextAttachment` for non-text content placeholders. TextKit 2 (`NSTextLayoutManager`) available on macOS 14+.

## Scope

### In Scope

- **NSTextView-based preview rendering**: Replace `ScrollView` + `VStack` + per-block SwiftUI `Text` views with a single `NSTextView` (via `NSViewRepresentable`) configured as read-only and selectable
- **Multi-block text selection**: Click-drag selection spanning paragraphs, headings, lists, blockquotes, code blocks, and table text
- **Non-text element overlay**: Mermaid diagrams and images rendered as SwiftUI views overlaid at coordinates determined by `NSTextAttachment` placeholders in the text flow
- **Visual highlight**: Native macOS selection highlight (system blue), with theme-aware customization via `NSTextView.selectedTextAttributes`
- **Plain-text copy** (Cmd+C) of selected content
- **Shift-click to extend** selection
- **Cmd+A to select all** text content
- **Click-to-deselect** (clicking without drag clears selection)
- **Staggered entrance animation**: The current per-block fade + drift entrance animation must be preserved in the NSTextView architecture — elegant, beautiful, and performant. Per the [charter's design philosophy](../../context/charter.md): *"Every visual and interactive element must be crafted with obsessive attention to sensory detail… No element is too small to get right — if it moves, glows, fades, or responds to input, it deserves the same care as the core rendering engine."* The entrance animation is a defining part of the reading experience. Losing it is not acceptable. Degrading it is not acceptable.

### Out of Scope

- Selection within or across Mermaid diagram blocks (they are non-text overlays, not part of the `NSTextView` text flow)
- Selection in the editor pane (TextEditor has native selection)
- Drag-and-drop of selected text
- Rich text (HTML/RTF) copy -- plain text only
- Selection in the WelcomeView empty state
- ~~Re-implementing staggered entrance animations in the NSTextView layer~~ (moved to In Scope — animation preservation is required)

## Requirements

### Functional Requirements

#### FR-1: NSTextView Preview Renderer

Replace the current `MarkdownPreviewView` rendering pipeline:

| Current | Target |
|---------|--------|
| `ScrollView` > `VStack(spacing: 12)` > `ForEach(renderedBlocks)` > `MarkdownBlockView` | `NSViewRepresentable` wrapping an `NSTextView` with `NSTextStorage` populated from `[MarkdownBlock]` |
| Per-block SwiftUI `Text(attributedString)` | Single `NSAttributedString` with block-level styling (paragraph spacing, fonts, colors) via `NSParagraphStyle` |
| `MermaidBlockView` (WKWebView) as inline SwiftUI view | `NSTextAttachment` placeholder in text flow + SwiftUI overlay positioned at attachment coordinates |
| `CodeBlockView` with syntax highlighting | Code block text rendered inline in `NSTextView` with monospaced font + background color via `NSAttributedString` attributes, or as `NSTextAttachment` + overlay for complex styling |
| `.textSelection(.enabled)` per-block | `NSTextView.isSelectable = true`, `isEditable = false` — selection spans the entire document |

The `MarkdownBlock` enum and `MarkdownVisitor` parsing pipeline remain unchanged. Only the view layer changes.

#### FR-2: Text Selection

Native `NSTextView` selection behavior:

1. **Click-drag**: Sets selection range from mouseDown to current mouse position. `NSTextView` handles this natively.
2. **Shift-click**: Extends selection to the new click position. `NSTextView` handles this natively.
3. **Cmd+A**: Selects all. `NSTextView` handles this natively.
4. **Click-to-deselect**: Single click moves the insertion point, clearing selection. `NSTextView` handles this natively.
5. **Cmd+C**: Copies selected text as plain text. `NSTextView` handles this natively (may need to override to ensure plain text only via `NSPasteboard`).

#### FR-3: Non-Text Element Overlay

For elements that cannot be rendered as `NSAttributedString` text (Mermaid diagrams, images):

1. Insert an `NSTextAttachment` placeholder of the correct size into the `NSTextStorage` at the block's position in the document flow.
2. Position a SwiftUI view (via overlay or `NSHostingView`) at the coordinates determined by the attachment's layout in the `NSTextView`.
3. The placeholder participates in the text flow (pushes subsequent text down) but is not itself selectable text.
4. Click events on overlaid views must reach the underlying SwiftUI/AppKit view (Mermaid click-to-focus must still work).

#### FR-4: Theme Integration

- Text styling (fonts, colors) derived from `ThemeColors` and converted to `NSFont`/`NSColor`.
- Selection highlight color customized via `NSTextView.selectedTextAttributes` to use the theme's accent color.
- Background color matches `ThemeColors.background`.
- Theme changes trigger a full re-render of the `NSAttributedString` (same as current behavior where theme changes trigger `MarkdownRenderer.render()`).

#### FR-5: State Lifecycle

- Selection state clears when a new file is loaded or the current file is reloaded.
- Selection state clears when switching between preview-only and side-by-side modes.
- The `NSTextView` content updates when `documentState.markdownContent` changes (same debounce pattern as current implementation).

### Non-Functional Requirements

- **NFR-1: Performance** -- Rendering a 1000-line Markdown document into `NSAttributedString` must complete in under 100ms. Selection and scrolling must maintain 120fps.
- **NFR-2: Visual parity** -- The NSTextView-rendered preview must be visually indistinguishable from the current SwiftUI Text rendering for paragraphs, headings, lists, blockquotes, and code blocks. Any visual regressions are blockers.
- **NFR-3: Font fidelity** -- SwiftUI `Font` values must be correctly converted to `NSFont` equivalents. Body, heading, and monospaced fonts must match their SwiftUI counterparts.
- **NFR-4: Accessibility** -- VoiceOver must announce selected text. The `NSTextView` must expose its text content via the accessibility API.
- **NFR-5: Animation quality** -- The staggered entrance animation must be elegant, beautiful, and performant. Specifically: (1) each block must fade in with an upward drift, staggered by block index, matching the current SwiftUI animation's feel and timing; (2) the animation must run at 120fps with no dropped frames, even on 1000-line documents; (3) the animation must feel physical and natural, timed to human rhythms per the [charter's design philosophy](../../context/charter.md); (4) Reduce Motion must be respected. A side-by-side comparison with the current SwiftUI animation is a required acceptance test — the NSTextView version must be at least as polished. Any regression in animation quality is a blocker.

## Dependencies & Constraints

### Technical Dependencies

| Dependency | Type | Description |
|------------|------|-------------|
| `MarkdownBlock` enum | Input | The parsed block model. Unchanged — the NSTextView renderer consumes the same `[MarkdownBlock]` array. |
| `MarkdownVisitor` | Input | The swift-markdown visitor that produces `[MarkdownBlock]`. Unchanged. |
| `MarkdownPreviewView` | Replaced | The current SwiftUI preview view. Replaced by an `NSViewRepresentable` wrapping `NSTextView`. |
| `MarkdownBlockView` | Replaced | Per-block SwiftUI rendering. Replaced by `NSAttributedString` construction per block type. |
| `ThemeColors` | Consumer | Selection highlight and text styling colors. Needs `NSColor` conversion helpers. |
| `MermaidBlockView` | Adapted | Currently a standalone SwiftUI view with WKWebView. Becomes an overlay positioned at `NSTextAttachment` coordinates. |
| `CodeBlockView` | Adapted | May be rendered inline via `NSAttributedString` (simple case) or as an overlay (complex syntax highlighting). |
| `DocumentState` | Integration | Content changes, file reload, and mode switching trigger NSTextView updates. |
| TextKit 2 | Platform | `NSTextLayoutManager`, `NSTextContentStorage` — available on macOS 14.0+ (project minimum). |

### Constraints

| Constraint | Impact |
|------------|--------|
| **AppKit bridging required** | The preview pane moves from pure SwiftUI to `NSViewRepresentable` + `NSTextView`. This is consistent with the existing Mermaid WKWebView pattern (AppKit bridging for specific capabilities). |
| **Font conversion** | SwiftUI `Font` → `NSFont` conversion is required. macOS 13+ provides safer conversion APIs. Must verify all font styles render identically. |
| **Scroll container change** | The current SwiftUI `ScrollView` is replaced by `NSTextView`'s built-in scroll view (`NSScrollView`). This may affect integration with the spatial design language's window chrome spacing (see spatial-design-language PRD). |
| **Mermaid overlay synchronization** | WKWebView overlays must track their `NSTextAttachment` positions during scrolling and layout changes. The RichText library's approach validates this is feasible but complex. |
| **Entrance animation preservation** | The current staggered block entrance animation (per-block fade + drift) must be preserved in the `NSTextView` architecture. Possible approaches: staged `NSTextStorage` insertion with `NSAnimationContext`, `CAAnimation` on text layout fragments via `NSTextLayoutManager` delegate, or a transitional overlay that fades out to reveal the final `NSTextView` content. |

## Milestones & Timeline

Priority-driven development, no fixed deadline. Ship when ready.

| Phase | Description | Exit Criteria |
|-------|-------------|---------------|
| Core | Build `NSTextView`-based preview renderer: `NSViewRepresentable` wrapper, `NSAttributedString` construction from `[MarkdownBlock]`, text selection (click-drag, Cmd+C), theme integration, staggered entrance animation via TextKit 2 per-layout-fragment `CALayer` animation. Text-only blocks (paragraphs, headings, lists, blockquotes, code blocks). | Can render a Markdown document in `NSTextView`, select across 2+ blocks, and copy plain text. Visual parity with current rendering for text blocks. Staggered entrance animation passes side-by-side comparison with current SwiftUI implementation — elegant, smooth, no dropped frames. |
| Overlay | Add non-text element overlay: `NSTextAttachment` placeholders for Mermaid and images, SwiftUI overlay positioning, click-through for Mermaid focus. | Mermaid diagrams render at correct positions in the document flow. Click-to-focus still works. |
| Polish | Shift-click extend, Cmd+A, theme-aware selection highlight, edge cases (empty blocks, thematic breaks, tables), accessibility (VoiceOver). | All functional requirements met, no frame drops during selection, VoiceOver works. |

## Open Questions

| ID | Question | Impact | Status |
|----|----------|--------|--------|
| OQ-1 | ~~Which implementation approach (A, B, or C)?~~ | ~~Determines architecture~~ | **Resolved: NSTextView (Approach B)** -- validated by hypothesis testing |
| OQ-2 | How should selection behave when it spans a code block -- select raw code text or syntax-highlighted display text? | Affects copy output for code blocks | Open |
| OQ-3 | Should table cell content be selectable individually, or should table selection follow row/column boundaries? | Affects NSAttributedString construction for tables | Open |
| OQ-4 | What is the correct behavior when the user scrolls during an active drag-selection? | NSTextView handles this natively (auto-scrolls during drag), but behavior should be verified | Open |
| OQ-5 | Should code blocks be rendered inline in the NSTextView (via NSAttributedString with monospaced font + background attributes) or as NSTextAttachment + overlay (preserving the current CodeBlockView with syntax highlighting)? | Affects code block visual quality and selectability | Open |
| OQ-6 | How does the NSTextView scroll container interact with the spatial-design-language PRD's window chrome constants (`windowTopInset`, `windowSideInset`)? The NSTextView's `NSScrollView` replaces the current SwiftUI `ScrollView`. | Affects integration with the spatial design system | Open |

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A-1 | `NSTextView` with `NSAttributedString` can achieve visual parity with the current SwiftUI `Text` rendering for all text block types | Visual regressions may require significant styling effort or acceptance of minor differences. Mitigation: side-by-side comparison during Core phase. | Design Philosophy: "obsessive attention to sensory detail" |
| A-2 | Plain text copy is sufficient; users do not need rich text or formatted copy | Users may expect pasted text to retain formatting in rich-text editors | Scope: no export formats |
| A-3 | Mermaid diagrams can be excluded from selection without confusing users | Users may expect to "select through" a diagram to reach text below it. Mitigation: selection should visually skip the diagram placeholder but include text above and below. | Scope: Mermaid as image |
| A-4 | Selection state does not need to persist across file reloads | Users may lose their place after reload; minor inconvenience | File watching: manual reload |
| A-5 | `NSTextAttachment` placeholders in the text flow correctly reserve space for overlaid Mermaid/image views, and the coordinates remain synchronized during scrolling | If coordinates drift, overlays will misalign. The RichText library validates this works but mkdn's specific layout (Mermaid WKWebViews with dynamic height) may add complexity. | Architecture: proven by RichText library |
| A-6 | Staggered entrance animations can be reproduced in the `NSTextView` architecture using staged text insertion, `CAAnimation` on layout fragments, or a transitional overlay | If animation reproduction proves infeasible in `NSTextView`, the architecture choice may need revisiting. Mitigation: prototype animation approach during Core phase before committing fully. | Design Philosophy: "obsessive attention to sensory detail" — animation polish is non-negotiable |
| R-1 | `NSTextView` rendering may not match SwiftUI `Text` rendering pixel-for-pixel | Font metrics, line spacing, and paragraph spacing may differ subtly between AppKit and SwiftUI. Extensive visual tuning may be required. | Success Criteria: daily-driver use requires the reading experience to be at least as good as current |
| R-2 | Replacing the SwiftUI ScrollView with NSTextView's NSScrollView may break integration with other SwiftUI features (animations, transitions, environment propagation) | May need to bridge SwiftUI environment values into the AppKit layer manually. | Architecture: SwiftUI + AppKit boundary |

## Discoveries

- **NSTextViewportLayoutControllerDelegate is nonisolated in SDK**: The `NSTextViewportLayoutControllerDelegate` protocol methods are not marked `@MainActor` despite always being called on the main thread; use `@preconcurrency` conformance (matching the existing pattern in `MermaidWebView.swift`). -- *Ref: [field-notes.md](archives/features/cross-element-selection/field-notes.md)*
- **TextKit 2 is default on macOS 14+**: `NSTextView.scrollableTextView()` produces a TextKit 2-backed view on macOS 14+ (confirmed via non-nil `textLayoutManager`), so no opt-in is required for TextKit 2 features on the project's minimum target. -- *Ref: [field-notes.md](archives/features/cross-element-selection/field-notes.md)*
- **NSTextLayoutFragment does not expose a CALayer**: Per-fragment layer animation requires a cover-layer workaround -- add opaque `CALayer` sublayers at fragment frames that fade out to reveal text beneath, combined with a single `CATransform3D` translation for upward drift. -- *Ref: [field-notes.md](archives/features/cross-element-selection/field-notes.md)*
