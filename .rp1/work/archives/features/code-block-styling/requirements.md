# Requirements Specification: Code Block Styling

**Feature ID**: code-block-styling
**Parent PRD**: [Syntax Highlighting](../../prds/syntax-highlighting.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-09

## 1. Feature Overview

Code blocks rendered in the Markdown preview should appear as visually distinct, contained elements -- with a proper background box (rounded corners, padding, border) and syntax highlighting -- rather than resembling oversized inline code. The current TextKit 2 rendering pipeline applies `.backgroundColor` to individual character runs but provides no visual container (no padding, no rounded rectangle, no border), making fenced code blocks indistinguishable from large spans of inline code. This feature ensures code blocks read as first-class block-level elements with clear visual boundaries, adequate internal whitespace, and syntax highlighting that is easy to scan.

## 2. Business Context

### 2.1 Problem Statement

Users viewing Markdown documents with fenced code blocks (triple-backtick) see code rendered as monospaced text with a flat background color applied run-by-run. There is no visual box, no rounded corners, no internal padding creating breathing room, and no border delineating the code block from surrounding content. The result looks like "big inline code chunks" rather than the contained, styled code blocks users expect from polished Markdown renderers. This undermines the charter's goal of a "beautiful" viewing experience and its explicit requirement that syntax highlighting for code blocks is "paramount."

### 2.2 Business Value

- Aligns the rendered output with user expectations set by GitHub, VS Code, Obsidian, and other Markdown tools that render code blocks as distinct visual containers
- Fulfills the charter's design philosophy of "obsessive attention to sensory detail" for one of the most common Markdown elements in developer-generated documents
- Delivers on the charter's explicit "Will Do" item: "Syntax highlighting for code blocks (paramount)"
- Directly impacts the success criterion of "personal daily-driver use" -- poorly rendered code blocks are a friction point in documents produced by LLMs and coding agents, which frequently contain code

### 2.3 Success Metrics

- Code blocks are immediately recognizable as contained, boxed elements distinct from surrounding paragraph text
- A user can visually identify where a code block begins and ends without reading the text content
- Syntax-highlighted tokens (Swift) are legible and well-spaced within the container
- The code block styling passes visual verification via the LLM vision-based compliance workflow (`scripts/visual-verification/verify-visual.sh`)

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Relevance |
|-----------|-----------|
| Developer viewing Markdown | Primary user. Views documents containing code blocks daily. Expects code to appear in a visually distinct container with syntax highlighting. |
| Developer editing Markdown | Secondary. Sees code block rendering in the side-by-side preview pane while editing. |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project creator | Daily-driver quality: code blocks must look polished enough to prefer mkdn over alternatives for viewing LLM-generated Markdown |
| Design system | Code block styling must be consistent with the established spatial design language (8pt grid, SpacingConstants) and theming system (ThemeColors) |

## 4. Scope Definition

### 4.1 In Scope

- Visual container for fenced code blocks: rounded-corner background box with internal padding, border, and clear visual separation from surrounding content
- Consistent styling across both Solarized Dark and Solarized Light themes
- Language label display above the code body when a language tag is present in the fenced code block
- Syntax highlighting for Swift code blocks (existing Splash integration)
- Plain monospaced rendering for non-Swift code blocks in the theme's `codeForeground` color
- Horizontal scrollability for code lines that exceed the container width
- Visual verification using the on-demand LLM vision-based workflow to confirm the styling meets design standards
- Both the TextKit 2 rendering path (primary preview) and the SwiftUI `CodeBlockView` (if still used in any context) should produce visually consistent results

### 4.2 Out of Scope

- Additional language grammars beyond Swift (existing Splash limitation, accepted)
- Line numbers in code blocks
- Copy-to-clipboard button on code blocks
- Editor-side syntax highlighting (preview-side only)
- Code block folding or collapse
- Custom user themes
- Changes to inline code rendering (backtick spans within paragraphs)

### 4.3 Assumptions

| ID | Assumption |
|----|------------|
| A-1 | The TextKit 2 pipeline (`MarkdownTextStorageBuilder` + `SelectableTextView`) is the primary and active rendering path for the preview; code block styling must work within this pipeline |
| A-2 | The existing theme color system (`ThemeColors.codeBackground`, `ThemeColors.codeForeground`, `ThemeColors.border`) provides sufficient color definitions for the code block container |
| A-3 | The spatial design language (`SpacingConstants`) provides the appropriate padding and margin values for the code block container |
| A-4 | NSTextView / TextKit 2 supports paragraph-level background drawing with rounded corners and padding (may require custom `NSTextLayoutFragment` subclassing or a background drawing delegate) |
| A-5 | Visual verification via `scripts/visual-verification/verify-visual.sh` can capture and evaluate code block rendering for compliance |

## 5. Functional Requirements

| REQ-ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|--------|----------|-----------|-------------|-----------|---------------------|
| FR-1 | Must Have | Developer viewing Markdown | Code blocks render with a visible background box that extends the full width of the content area, with rounded corners | Code blocks must be visually identifiable as contained elements, not just colored text runs | A code block displays with a continuous rounded-rectangle background that extends from left edge to right edge of the content area, with uniform corner radius on all four corners |
| FR-2 | Must Have | Developer viewing Markdown | Code blocks have internal padding between the background box edge and the code text content | Without padding, text pressed against the box edge looks cramped and unprofessional | Code text is inset from the background box edges by a consistent padding value on all four sides; text never touches the box boundary |
| FR-3 | Must Have | Developer viewing Markdown | Code blocks display a subtle border along the background box perimeter | A border delineates the code block boundary, especially important when the code background color is close to the document background | A 1pt border is visible around the code block background box in both Solarized Dark and Solarized Light themes |
| FR-4 | Must Have | Developer viewing Markdown | Code blocks have vertical spacing (margin) above and below that separates them from adjacent content | Clear separation between code blocks and surrounding paragraphs, headings, or other blocks | Vertical space before and after a code block is at least as large as the standard block spacing, and the code block does not visually merge with adjacent elements |
| FR-5 | Should Have | Developer viewing Markdown | A language label appears above the code body when the fenced code block specifies a language tag | The language label helps users identify the code's language at a glance | When a language tag is present (e.g., ```swift), the language name appears above the code content in a smaller, secondary-colored font within the code block container |
| FR-6 | Must Have | Developer viewing Markdown | Swift code blocks display syntax highlighting with token-level coloring | Syntax highlighting is "paramount" per the charter; Swift is the only supported language via Splash | Swift code blocks render with distinct colors for keywords, strings, comments, types, numbers, functions, properties, and preprocessor directives, matching the active theme's SyntaxColors |
| FR-7 | Must Have | Developer viewing Markdown | Non-Swift code blocks render as plain monospaced text in the theme's codeForeground color | Non-Swift code must still render legibly within the styled container, not as broken or missing content | Code blocks with non-Swift language tags or no language tag render all text in monospaced font with the theme's codeForeground color, within the same styled container |
| FR-8 | Should Have | Developer viewing Markdown | Code blocks are horizontally scrollable when content exceeds the container width | Long code lines should not be truncated or wrapped in a way that distorts the code's structure | When a code line exceeds the visible width of the code block container, the user can scroll horizontally to view the full line |
| FR-9 | Must Have | Developer viewing Markdown | Code block styling is consistent across both Solarized Dark and Solarized Light themes | Theme consistency is a core design principle; code blocks must look polished in both themes | Switching between themes updates the code block background, border, foreground, and syntax colors immediately; the container shape and spacing remain identical |
| FR-10 | Must Have | Developer viewing Markdown | Text within code blocks is selectable | Cross-block text selection is a key capability of the TextKit 2 rendering pipeline | Users can click and drag to select text within and across code blocks, consistent with selection behavior in other block types |
| FR-11 | Should Have | Developer viewing Markdown | Code block styling is validated through the visual verification workflow | Automated visual compliance ensures styling meets design standards and catches regressions | Running `scripts/visual-verification/verify-visual.sh` includes code block evaluation in its assessment, and code blocks pass the visual compliance check |

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

- Code block rendering (including syntax highlighting and container drawing) must complete within the existing rendering budget: < 100ms for a typical document (< 500 lines) on Apple Silicon
- Adding the visual container (background box, border, rounded corners) must not introduce measurable frame drops during scrolling

### 6.2 Security Requirements

- No additional security requirements beyond existing constraints (no WKWebView, no network requests for rendering)

### 6.3 Usability Requirements

- Code block containers must provide sufficient contrast between the code background and the document background to be immediately distinguishable
- Internal padding must be large enough that code text does not feel cramped, but not so large that it wastes space
- The border must be subtle enough to not compete with the code content for visual attention

### 6.4 Compliance Requirements

- Code block styling must respect the existing spatial design language (8pt grid, SpacingConstants primitives)
- All styling values must come from named theme constants (ThemeColors, SpacingConstants), not hardcoded literals
- Implementation must pass SwiftLint strict mode and SwiftFormat

## 7. User Stories

### STORY-1: Recognizable Code Block Container

**As a** developer viewing a Markdown document,
**I want** fenced code blocks to render inside a clearly bounded, rounded-corner box with a distinct background color,
**So that** I can immediately distinguish code from surrounding prose without reading the content.

**Acceptance:**
- GIVEN a Markdown document containing a fenced code block (triple backtick)
- WHEN the document renders in the preview
- THEN the code block appears inside a rounded-rectangle container with a background color distinct from the document background, a visible border, and internal padding separating the text from the container edges

### STORY-2: Syntax-Highlighted Swift Code

**As a** developer viewing a Markdown document with Swift code blocks,
**I want** Swift code to display with token-level syntax highlighting using my selected theme's colors,
**So that** I can quickly scan and understand the code structure.

**Acceptance:**
- GIVEN a Markdown document containing a fenced code block tagged as `swift`
- WHEN the document renders in the preview
- THEN keywords, strings, comments, types, numbers, functions, properties, and preprocessor directives each display in their designated theme color within the styled container

### STORY-3: Language Label

**As a** developer viewing a Markdown document with multiple code blocks in different languages,
**I want** the language name to appear as a label above the code content when specified,
**So that** I can identify the language without reading the code.

**Acceptance:**
- GIVEN a fenced code block with a language tag (e.g., ```python)
- WHEN the document renders in the preview
- THEN the language name ("python") appears above the code content in a smaller, secondary-colored font within the code block container

### STORY-4: Visual Verification Compliance

**As a** developer maintaining mkdn,
**I want** code block styling to be verifiable through the automated visual verification workflow,
**So that** styling regressions are caught during development.

**Acceptance:**
- GIVEN the visual verification workflow (`scripts/visual-verification/verify-visual.sh`)
- WHEN the workflow captures and evaluates the canonical fixture containing code blocks
- THEN code block styling is included in the evaluation, and the blocks are assessed for container visibility, proper background, border, padding, and syntax highlighting

## 8. Business Rules

| Rule ID | Rule | Rationale |
|---------|------|-----------|
| BR-1 | Code block container styling uses only values from ThemeColors and SpacingConstants -- no hardcoded color or spacing literals | Consistency with the design system; enables theme switching without per-component updates |
| BR-2 | The code block container must be a continuous background rectangle, not per-line or per-run background coloring | Per-run backgrounds create visual fragmentation that looks like inline code; a continuous container communicates "this is a block-level element" |
| BR-3 | The language label is part of the code block container (same background) and appears only when a language tag is present | The label is inside the box to maintain visual cohesion; it is optional because not all code blocks specify a language |
| BR-4 | Syntax highlighting applies only to Swift code blocks; all other languages render as plain monospaced text | This is the established Splash limitation; non-Swift code must still render correctly, just without token coloring |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Type | Description |
|------------|------|-------------|
| TextKit 2 rendering pipeline | Internal | Code block styling must be implemented within `MarkdownTextStorageBuilder` + `SelectableTextView`, the active rendering path |
| ThemeColors | Internal | Background, foreground, and border colors come from the theme's color palette |
| SpacingConstants | Internal | Padding and margin values should reference the spatial design language primitives |
| Splash | External | Syntax highlighting for Swift code blocks |
| Visual verification workflow | Internal | `scripts/visual-verification/` scripts validate the visual output |

### Constraints

| Constraint | Impact |
|------------|--------|
| TextKit 2 / NSTextView rendering | Rounded-corner background boxes with padding are not natively supported by `NSAttributedString.Key.backgroundColor` (which draws flat, per-run backgrounds). Custom drawing will likely be required at the `NSTextLayoutManager` or `NSTextLayoutFragment` level. |
| Cross-block text selection | The code block container must not break the existing cross-block text selection capability of the TextKit 2 pipeline |
| Swift 6 strict concurrency | All new types must be Sendable-safe |
| SwiftLint strict mode | All code must pass with all opt-in rules enabled |
| No WKWebView | Code block rendering must remain fully native -- no web-based syntax highlighters |

## 10. Clarifications Log

| Date | Question | Resolution |
|------|----------|------------|
| 2026-02-09 | What does "background box" mean specifically? | A continuous rounded-rectangle background that spans the full code block, as opposed to per-character-run `.backgroundColor` which creates a fragmented "inline code" appearance. The box includes rounded corners, internal padding, and a subtle border. |
| 2026-02-09 | Does this affect inline code (single backtick)? | No. This feature is exclusively about fenced code blocks (triple backtick). Inline code rendering is unchanged. |
| 2026-02-09 | Should both the TextKit 2 path and the SwiftUI CodeBlockView be updated? | The TextKit 2 path (`MarkdownTextStorageBuilder` + `SelectableTextView`) is the active rendering pipeline and is the primary target. The SwiftUI `CodeBlockView` already has container styling (rounded rectangle, border, padding) but may not be in the active rendering path. Both should produce visually consistent results if both are used. |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | syntax-highlighting.md | Best filename/title match for "code-block-styling" feature. The syntax-highlighting PRD covers code block rendering, syntax highlighting, and code block visual styling (NFR-5 explicitly mentions "rounded corners, border, background"). |
| Visual verification scope | Include code block evaluation in the existing canonical fixture captures | The requirements mention using verify-visual; the canonical.md fixture already contains code blocks. No new fixtures needed for basic compliance. |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| "actual background box" -- unclear if this means a SwiftUI-level container or TextKit 2-level custom drawing | Interpreted as a continuous rounded-rectangle background at the TextKit 2 rendering level, since MarkdownTextStorageBuilder is the active rendering path. The current per-run `.backgroundColor` attribute does not create a "box." | Codebase analysis: MarkdownPreviewView uses SelectableTextView with MarkdownTextStorageBuilder, not CodeBlockView. |
| "syntax highlighting" -- unclear if new language support is needed | Interpreted as ensuring existing Swift syntax highlighting renders correctly within the new container. No new language grammars. | syntax-highlighting PRD (status: Complete) explicitly limits to Swift-only via Splash. Charter says "paramount" but does not require multi-language. |
| Specific padding, corner radius, and border values not specified | Deferred to implementation; values should come from SpacingConstants (componentPadding = 12pt for internal padding) and existing CodeBlockView values (cornerRadius 6, border opacity 0.3) as established conventions. | spatial-design-language PRD FR-4 (componentPadding = 12pt/cozy); existing CodeBlockView.swift uses cornerRadius 6, border opacity 0.3. |
| "meets our design standards" -- undefined criteria for visual verification | Interpreted as: code blocks should display a visible container (background box with rounded corners and border), proper padding, readable syntax highlighting, and consistent theme application. These are the criteria the LLM vision evaluator will assess. | Charter design philosophy: "obsessive attention to sensory detail." Visual verification workflow evaluates against PRD specs. |
| Whether code block text should remain selectable | Yes, text selection must be preserved. Cross-block selection is a key capability of the TextKit 2 pipeline. | cross-element-selection PRD exists in the PRD directory; SelectableTextView is built for text selection. |
