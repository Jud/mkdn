# Requirements Specification: Cross-Element Selection

**Feature ID**: cross-element-selection
**Parent PRD**: [Cross-Element Selection](../../prds/cross-element-selection.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-08

## 1. Feature Overview

Cross-element selection enables users to click-drag across multiple rendered Markdown blocks in the preview pane and copy the selected content as plain text. Today, each Markdown block (paragraph, heading, code block, list, blockquote, table) is an independent SwiftUI `Text` view with `.textSelection(.enabled)`, which confines selection to a single block. This feature replaces the preview rendering layer with an NSTextView-based architecture that provides native, continuous cross-block text selection while preserving the ability to embed non-text elements (Mermaid diagrams, images) as overlays and maintaining the signature staggered entrance animation.

## 2. Business Context

### 2.1 Problem Statement

Users reading Markdown documents in mkdn cannot select text across block boundaries. Selecting a heading and the paragraph below it, or copying a section spanning multiple paragraphs and code blocks, requires tedious per-block copy-paste. This is a fundamental usability gap for a daily-driver Markdown viewer. Every other Mac text-viewing application (Preview, TextEdit, Safari, Xcode) supports continuous text selection across rendered elements.

### 2.2 Business Value

- Removes a friction point that undermines the "open, render beautifully, edit, close" workflow described in the project charter.
- Enables users to extract and reuse content from rendered Markdown documents without switching to the editor pane or the source file.
- Brings mkdn's text interaction model to parity with native macOS applications, reinforcing the "Mac-native" positioning.
- Strengthens the case for daily-driver adoption (charter success criteria) by eliminating a common annoyance.

### 2.3 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Cross-block selection works | Users can select text spanning 2+ distinct block types and copy it | Manual verification |
| Visual parity | Preview rendering is indistinguishable from current SwiftUI rendering for all text block types | Side-by-side visual comparison |
| Animation parity | Staggered entrance animation is at least as polished as current SwiftUI implementation | Side-by-side visual comparison |
| Performance | Rendering a 1000-line document completes in under 100ms; selection and scrolling maintain 120fps | Profiling |
| No regressions | Mermaid diagram rendering, click-to-focus, theme switching, file reload, mode switching all continue to work | Regression testing |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Reader | Developer viewing Markdown artifacts (docs, specs, reports) produced by LLMs/coding agents. Reads, scrolls, selects, copies excerpts. | Primary beneficiary. Currently cannot select across blocks. |
| Editor | Developer using side-by-side mode to edit Markdown. Has native TextEditor selection in the editor pane. | Indirect beneficiary. Preview pane selection improves the editing workflow when referencing rendered output. |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project creator (daily-driver user) | Smooth, native-feeling text selection in preview mode. No visual or animation regressions. |
| Future users | Standard macOS text interaction expectations met (click-drag, Shift-click, Cmd+A, Cmd+C). |

## 4. Scope Definition

### 4.1 In Scope

- Multi-block text selection via click-drag spanning paragraphs, headings, lists, blockquotes, code blocks, and table text in the preview pane.
- Plain-text copy (Cmd+C) of selected content.
- Shift-click to extend selection.
- Cmd+A to select all text content.
- Click-to-deselect (clicking without drag clears selection).
- Native macOS selection highlight (system blue), customizable to match the active theme's accent color.
- Non-text element overlay: Mermaid diagrams and images rendered as overlaid views at positions determined by placeholders in the text flow.
- Staggered entrance animation preservation: per-block fade-in with upward drift, staggered by block index, matching the feel and timing of the current SwiftUI implementation.
- Theme integration: text styling, selection highlight color, and background color derived from the active theme.
- State lifecycle: selection clears on file load/reload and on view mode switch.
- Accessibility: VoiceOver announces selected text; text content exposed via accessibility API.
- Reduce Motion support: entrance animation respects the system Reduce Motion preference.

### 4.2 Out of Scope

- Selection within or across Mermaid diagram blocks (they are non-text overlays).
- Selection in the editor pane (TextEditor already provides native selection).
- Drag-and-drop of selected text.
- Rich text (HTML/RTF) copy -- plain text only.
- Selection in the WelcomeView empty state.
- Find-in-document (Cmd+F) functionality.
- Right-click context menu on selected text.

### 4.3 Assumptions

| ID | Assumption | Risk if Wrong |
|----|------------|---------------|
| A-1 | The NSTextView-based renderer can achieve visual parity with the current SwiftUI Text rendering for all text block types. | Visual regressions may require significant styling effort. Mitigated by side-by-side comparison during implementation. |
| A-2 | Plain text copy is sufficient; users do not need rich text or formatted copy. | Users may expect pasted text to retain formatting in rich-text editors. Acceptable for an MVP Markdown viewer. |
| A-3 | Mermaid diagrams can be excluded from selection without confusing users. | Users may expect to "select through" a diagram. Mitigated by selection visually skipping the diagram placeholder while including text above and below. |
| A-4 | Selection state does not need to persist across file reloads. | Users may lose their place; minor inconvenience. |
| A-5 | Placeholder attachments in the text flow correctly reserve space for overlaid Mermaid/image views, and coordinates remain synchronized during scrolling. | Overlay misalignment. Mitigated by proven architecture (RichText library pattern). |
| A-6 | Staggered entrance animations can be reproduced using per-layout-fragment layer animation (confirmed by hypothesis H5). | If animation quality is insufficient, the approach may need revision. Mitigated by prototype validation. |

## 5. Functional Requirements

### FR-001: Multi-Block Text Selection

- **Priority**: Must Have
- **User Type**: Reader, Editor
- **Requirement**: A user must be able to click and drag across multiple distinct rendered Markdown blocks (paragraphs, headings, lists, blockquotes, code blocks, tables) in the preview pane to create a continuous text selection that spans block boundaries.
- **Rationale**: This is the core capability that eliminates the per-block selection limitation. Without it, the feature has no value.
- **Acceptance Criteria**:
  1. GIVEN a rendered Markdown document with at least two consecutive text blocks, WHEN the user clicks at a position in the first block and drags to a position in the second block, THEN the selection highlight is visible across both blocks and all intervening text.
  2. GIVEN a rendered document with heading, paragraph, and code block in sequence, WHEN the user selects across all three, THEN all three block types are included in the selection.
  3. GIVEN a selection spanning multiple blocks, WHEN the user presses Cmd+C, THEN the selected text is copied to the clipboard as plain text.

### FR-002: Standard macOS Selection Behaviors

- **Priority**: Must Have
- **User Type**: Reader, Editor
- **Requirement**: The preview pane must support standard macOS text selection interactions: click-drag to select, Shift-click to extend selection, Cmd+A to select all, and single click to deselect.
- **Rationale**: Users expect standard macOS text interaction behaviors. Deviating from platform conventions creates cognitive friction.
- **Acceptance Criteria**:
  1. GIVEN an existing selection, WHEN the user Shift-clicks at a different position, THEN the selection extends (or contracts) to include the new position.
  2. GIVEN no existing selection, WHEN the user presses Cmd+A, THEN all text content in the preview is selected.
  3. GIVEN an existing selection, WHEN the user single-clicks without dragging, THEN the selection is cleared.

### FR-003: Plain Text Copy

- **Priority**: Must Have
- **User Type**: Reader, Editor
- **Requirement**: When text is selected and the user presses Cmd+C, the selected content must be placed on the system clipboard as plain text only (no HTML, RTF, or other rich formats).
- **Rationale**: Users copy from the viewer to paste into terminals, code editors, chat apps, and other tools. Plain text is the universally compatible format. Consistent with the project's scope guardrails (no export formats).
- **Acceptance Criteria**:
  1. GIVEN selected text spanning a heading and a paragraph, WHEN the user presses Cmd+C and pastes into a plain-text editor, THEN the pasted content is the plain text of the heading followed by the paragraph with appropriate line breaks.
  2. GIVEN selected text that spans across a non-text element placeholder (e.g., a Mermaid diagram), WHEN the user copies, THEN the text above and below the diagram is included but the diagram itself contributes no text to the clipboard.

### FR-004: Non-Text Element Overlay

- **Priority**: Must Have
- **User Type**: Reader
- **Requirement**: Non-text elements (Mermaid diagrams, images) must be rendered as overlaid views positioned at the correct location in the document flow, with placeholder space reserved in the text layout so that subsequent text is pushed down appropriately.
- **Rationale**: Mermaid diagram rendering is a core differentiator of mkdn (charter). The rendering must continue to work after the preview layer migration. The placeholder approach ensures diagrams participate in the document flow without being selectable text.
- **Acceptance Criteria**:
  1. GIVEN a Markdown document containing a Mermaid code block between two paragraphs, WHEN the document is rendered, THEN the Mermaid diagram appears at the correct vertical position between the two paragraphs, with the second paragraph pushed below the diagram.
  2. GIVEN a rendered Mermaid diagram, WHEN the user clicks on it, THEN the Mermaid click-to-focus interaction works (click events reach the underlying view).
  3. GIVEN a rendered document with Mermaid diagrams, WHEN the user scrolls, THEN the diagram overlays remain correctly aligned with their placeholder positions.

### FR-005: Visual Parity with Current Rendering

- **Priority**: Must Have
- **User Type**: Reader, Editor
- **Requirement**: The preview rendering after migration must be visually indistinguishable from the current SwiftUI Text-based rendering for paragraphs, headings (H1-H6), lists (ordered and unordered), blockquotes, code blocks, thematic breaks, and tables.
- **Rationale**: The charter's design philosophy demands "obsessive attention to sensory detail." Any visible regression in text rendering quality undermines daily-driver adoption. Users must not notice the architectural change.
- **Acceptance Criteria**:
  1. GIVEN the same Markdown document rendered by both the current SwiftUI implementation and the new implementation, WHEN compared side-by-side, THEN fonts, font sizes, font weights, line spacing, paragraph spacing, text colors, background colors, and blockquote/code block styling are visually equivalent.
  2. GIVEN a Markdown document with all supported block types, WHEN rendered in both implementations, THEN no block type exhibits visible layout differences (spacing, alignment, indentation).

### FR-006: Selection Highlight Theming

- **Priority**: Should Have
- **User Type**: Reader
- **Requirement**: The selection highlight color should be customizable to match the active theme's accent color, rather than always using the default system blue.
- **Rationale**: Terminal-consistent theming is a core differentiator (charter). The selection highlight should feel like part of the themed experience, not a jarring system default.
- **Acceptance Criteria**:
  1. GIVEN the Solarized Dark theme is active, WHEN the user selects text, THEN the selection highlight uses a color consistent with the Solarized palette.
  2. GIVEN the user switches themes, WHEN text is selected, THEN the selection highlight color updates to match the new theme.

### FR-007: Staggered Entrance Animation

- **Priority**: Must Have
- **User Type**: Reader
- **Requirement**: When a new document is loaded or the current document is reloaded, each rendered block must fade in with an upward drift, staggered by block index, matching the timing and feel of the current SwiftUI staggered entrance animation. The animation must feel physical and natural, timed to human rhythms per the charter's design philosophy.
- **Rationale**: The entrance animation is a defining part of mkdn's reading experience. The charter states: "Every visual and interactive element must be crafted with obsessive attention to sensory detail... No element is too small to get right." Losing or degrading the entrance animation is not acceptable.
- **Acceptance Criteria**:
  1. GIVEN a new Markdown document is loaded, WHEN the preview renders, THEN each block appears with a fade-in (opacity 0 to 1) and upward drift (vertical offset to final position), with each subsequent block starting its animation after a staggered delay.
  2. GIVEN the current SwiftUI entrance animation and the new implementation shown side-by-side, WHEN a document loads, THEN the new animation is at least as polished and smooth as the current one.
  3. GIVEN the system Reduce Motion preference is enabled, WHEN a document loads, THEN the entrance animation is either suppressed or replaced with a simple fade (no motion).
  4. GIVEN a 1000-line document, WHEN the entrance animation plays, THEN there are no dropped frames (maintains 120fps).

### FR-008: State Lifecycle Management

- **Priority**: Must Have
- **User Type**: Reader, Editor
- **Requirement**: Selection state must clear when a new file is loaded, when the current file is reloaded (via the outdated indicator), and when switching between preview-only and side-by-side view modes.
- **Rationale**: Stale selection state from a previous document or view mode creates confusion. Clearing selection on state transitions is the expected macOS behavior.
- **Acceptance Criteria**:
  1. GIVEN text is selected in the preview, WHEN a new file is opened, THEN the selection is cleared and the new document renders without any selection.
  2. GIVEN text is selected in the preview, WHEN the user reloads the file via the outdated indicator, THEN the selection is cleared.
  3. GIVEN text is selected in preview-only mode, WHEN the user switches to side-by-side mode, THEN the selection is cleared.

### FR-009: Theme Change Re-rendering

- **Priority**: Must Have
- **User Type**: Reader
- **Requirement**: When the user switches themes, the preview must fully re-render with the new theme's fonts, colors, and background, updating all text styling and the selection highlight color.
- **Rationale**: Theme switching is a core feature. The rendered preview must reflect the active theme at all times.
- **Acceptance Criteria**:
  1. GIVEN a rendered document in Solarized Dark, WHEN the user switches to Solarized Light, THEN all text colors, background colors, code block styling, blockquote styling, and selection highlight color update to the Light theme values.

### FR-010: Content Update on Document Change

- **Priority**: Must Have
- **User Type**: Editor
- **Requirement**: In side-by-side mode, when the user edits Markdown content in the editor pane, the preview must update to reflect the changes using the same debounce pattern as the current implementation.
- **Rationale**: Live preview is the core value of side-by-side mode. The architectural migration must not break this interaction.
- **Acceptance Criteria**:
  1. GIVEN side-by-side mode is active, WHEN the user types in the editor pane, THEN the preview updates after the debounce interval to reflect the new content.

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| Requirement | Target |
|-------------|--------|
| NFR-001: Document rendering | Rendering a 1000-line Markdown document into the styled text representation must complete in under 100ms. |
| NFR-002: Selection fluidity | Selection highlighting (click-drag) and scrolling must maintain 120fps with no visible stutter or dropped frames. |
| NFR-003: Entrance animation performance | The staggered entrance animation must maintain 120fps even on 1000-line documents, with no dropped frames. |

### 6.2 Security Requirements

No specific security requirements. The preview pane renders local file content only. No network access, no user input beyond selection gestures and keyboard shortcuts.

### 6.3 Usability Requirements

| Requirement | Description |
|-------------|-------------|
| NFR-004: Platform consistency | All selection interactions (click-drag, Shift-click, Cmd+A, Cmd+C, click-to-deselect) must behave identically to native macOS text views (TextEdit, Preview, Safari). |
| NFR-005: Discoverability | No new UI elements or instructions needed. Text selection is a universally understood interaction pattern on macOS. |

### 6.4 Compliance Requirements

| Requirement | Description |
|-------------|-------------|
| NFR-006: Accessibility | VoiceOver must announce selected text. The rendered text content must be exposed via the macOS accessibility API. |
| NFR-007: Reduce Motion | The entrance animation must respect the system Reduce Motion preference. When enabled, entrance animation must either be suppressed or replaced with a non-motion alternative (simple fade). |

## 7. User Stories

### STORY-001: Select and Copy Across Blocks

**As a** reader viewing a Markdown document in preview mode,
**I want** to click-drag across multiple blocks (e.g., a heading and its following paragraphs) to select them,
**So that** I can copy the selected content to paste into another application without switching to the editor or source file.

**Acceptance**:
- GIVEN a rendered document with a heading followed by two paragraphs, WHEN I click at the start of the heading and drag to the end of the second paragraph, THEN the heading and both paragraphs are highlighted.
- WHEN I press Cmd+C, THEN the heading text and paragraph text are on the clipboard as plain text with appropriate line breaks.

### STORY-002: Select All and Copy

**As a** reader who wants the full text content of a rendered document,
**I want** to press Cmd+A to select all text,
**So that** I can quickly copy the entire document's rendered text content.

**Acceptance**:
- GIVEN a rendered document, WHEN I press Cmd+A, THEN all text content is selected (Mermaid diagrams and images are skipped).
- WHEN I press Cmd+C, THEN the full document text is on the clipboard.

### STORY-003: Extend Selection with Shift-Click

**As a** reader refining a text selection,
**I want** to Shift-click to extend my current selection to a new endpoint,
**So that** I can adjust my selection without re-dragging from the start.

**Acceptance**:
- GIVEN I have selected the first paragraph, WHEN I Shift-click at the end of the third paragraph, THEN the selection extends to include paragraphs one through three.

### STORY-004: View Mermaid Diagrams in Document Flow

**As a** reader viewing a document with Mermaid diagrams,
**I want** diagrams to appear at the correct position in the document flow and remain interactive (click-to-focus),
**So that** the reading experience is seamless and diagrams are not displaced by the selection architecture.

**Acceptance**:
- GIVEN a document with text, a Mermaid diagram, and more text, WHEN rendered, THEN the diagram appears at the correct vertical position.
- WHEN I click on the diagram, THEN the Mermaid click-to-focus interaction works.
- WHEN I select text above and below the diagram, THEN the selection visually skips the diagram area.

### STORY-005: Enjoy Entrance Animation

**As a** reader opening a new Markdown document,
**I want** to see the content appear with the signature staggered fade-in animation,
**So that** the reading experience feels crafted, polished, and delightful.

**Acceptance**:
- GIVEN I open a Markdown file, WHEN the preview renders, THEN each block fades in with an upward drift, staggered by position.
- GIVEN I have Reduce Motion enabled, WHEN the preview renders, THEN blocks appear without motion (fade only or instant).

### STORY-006: Deselect by Clicking

**As a** reader who has finished copying selected text,
**I want** to single-click anywhere in the preview to clear the selection,
**So that** the highlight is removed and I can continue reading without visual clutter.

**Acceptance**:
- GIVEN text is selected, WHEN I single-click without dragging, THEN the selection is cleared.

## 8. Business Rules

| ID | Rule |
|----|------|
| BR-001 | Selection is confined to the preview pane. It does not cross the boundary into the editor pane in side-by-side mode. |
| BR-002 | Non-text elements (Mermaid diagrams, images) are excluded from text selection. Selection visually skips over them but includes text above and below. |
| BR-003 | Copy always produces plain text, regardless of the source block types (code blocks, headings, styled text all copy as plain text). |
| BR-004 | The entrance animation stagger delay is capped so that the total animation duration remains bounded regardless of document length. Off-screen blocks do not animate. |
| BR-005 | Entrance animation plays on document load and reload. It does not play on incremental edits in side-by-side mode. |
| BR-006 | Theme changes trigger a full re-render of the preview content. |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Type | Description |
|------------|------|-------------|
| MarkdownBlock enum | Input | The parsed block model consumed by the new renderer. Unchanged. |
| MarkdownVisitor | Input | The swift-markdown visitor producing `[MarkdownBlock]`. Unchanged. |
| ThemeColors | Consumer | Provides fonts, colors for text styling and selection highlight. Needs conversion helpers to platform-native types. |
| MermaidBlockView | Adapted | Currently a standalone SwiftUI view with WKWebView. Becomes an overlay positioned at placeholder coordinates. |
| CodeBlockView | Adapted | May be rendered inline with monospaced font and background styling, or as an overlay for complex syntax highlighting. |
| DocumentState | Integration | Content changes, file reload, and mode switching trigger preview updates. |
| AnimationConstants | Consumer | Stagger delay values, fade/drift parameters, Reduce Motion alternatives. |
| MotionPreference | Consumer | Reduce Motion resolution for entrance animation. |
| macOS 14.0+ TextKit 2 | Platform | Required for per-layout-fragment layer animation and modern text layout APIs. |

### Constraints

| Constraint | Impact |
|------------|--------|
| The preview pane moves from pure SwiftUI to an AppKit-bridged view. This is consistent with the existing Mermaid WKWebView pattern. | All SwiftUI-specific rendering in the preview (Text views, modifiers, animations) must be reimplemented or bridged. |
| SwiftUI Font to platform font conversion is required. | All font styles (body, heading H1-H6, monospaced, emphasis) must render identically after conversion. |
| The current SwiftUI ScrollView is replaced by the text view's built-in scroll container. | May affect integration with spatial design language window chrome constants. |
| Mermaid WKWebView overlays must track their placeholder positions during scrolling and layout changes. | Complex coordinate synchronization required. Proven feasible by RichText library pattern. |
| Entrance animation uses per-layout-fragment layer animation via the viewport layout controller delegate. | Requires careful first-frame management to avoid flicker. Must distinguish full reload from incremental edit. |

## 10. Clarifications Log

| ID | Question | Resolution | Source |
|----|----------|------------|--------|
| CL-001 | How should selection behave when it spans a code block -- select raw code text or syntax-highlighted display text? | Inferred: select the display text (what the user sees), copy as plain text without syntax highlighting markup. This is standard behavior for selectable code blocks in documentation viewers. | PRD OQ-2 (open); conservative default |
| CL-002 | Should table cell content be selectable individually, or should table selection follow row/column boundaries? | Inferred: table text is selectable as continuous text within the document flow, without cell/row/column boundary awareness. Tables are rendered as styled text, and selection flows through them naturally. | PRD OQ-3 (open); conservative default |
| CL-003 | What is the correct behavior when the user scrolls during an active drag-selection? | Inferred: native auto-scroll behavior during drag -- the view auto-scrolls as the user drags toward the edges. This is standard macOS text view behavior and is handled natively. | PRD OQ-4 (open); platform default |
| CL-004 | Should code blocks be rendered inline or as overlays? | Inferred: prefer inline rendering (styled text with monospaced font and background attributes) for maximum selectability. Only use overlay if syntax highlighting fidelity requires it. | PRD OQ-5 (open); conservative default favoring selectability |
| CL-005 | How does the new scroll container interact with the spatial design language window chrome constants? | Inferred: the text view's scroll container must respect the same insets (top, side) as the current SwiftUI ScrollView. Exact integration is a design-phase concern. | PRD OQ-6 (open); conservative default |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | cross-element-selection.md | Feature ID exactly matches PRD filename. Only one matching PRD. |
| Charter association | charter.md | Standard project charter providing vision, design philosophy, and scope guardrails. |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| Code block selection behavior (OQ-2) | Select display text, copy as plain text without markup | Conservative default; standard behavior in documentation viewers |
| Table selection model (OQ-3) | Continuous text flow selection, no cell/row/column awareness | Conservative default; simplest model, maximizes selectability |
| Scroll-during-drag behavior (OQ-4) | Native auto-scroll during drag selection | Platform default; handled natively by the text view |
| Code block rendering approach (OQ-5) | Prefer inline rendering for selectability; overlay only if syntax highlighting requires it | Conservative default; prioritizes the core feature (selection) |
| Scroll container inset integration (OQ-6) | New scroll container must respect same insets as current ScrollView | Conservative default; defers specifics to design phase |
| Entrance animation timing parameters | Reuse existing AnimationConstants values (stagger delay, duration, easing) | KB: AnimationConstants.swift defines named animation primitives |
| Reduce Motion behavior | Use MotionPreference resolver for animation suppression | KB: MotionPreference.swift handles Reduce Motion resolution |
