# Requirements Specification: Block Rendering Fix

**Feature ID**: block-rendering-fix
**Parent PRD**: [Block Rendering Fix](../../prds/block-rendering-fix.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-07

## 1. Feature Overview

Two rendering bugs in the Markdown preview pipeline cause content blocks to render as invisible empty areas and code blocks to display with inconsistent foreground colors. The first bug stems from duplicate block IDs (the `thematicBreak` case always returns the static string `"hr"`), which corrupts SwiftUI's view diffing and animation state tracking. The second bug stems from whitespace runs in syntax-highlighted code blocks lacking a foreground color attribute, which breaks color continuity in rendered output. Both bugs degrade the core value proposition of the app -- beautifully rendered Markdown.

## 2. Business Context

### 2.1 Problem Statement

Users opening Markdown documents containing multiple thematic breaks (`---`) see invisible or missing blocks in the preview. The document appears broken -- content that exists in the source is not displayed. Additionally, syntax-highlighted code blocks can show inconsistent coloring where whitespace boundaries cause adjacent token colors to render incorrectly. Both issues undermine trust in the rendering pipeline and make the app unsuitable as a daily-driver Markdown viewer.

### 2.2 Business Value

Fixing these bugs restores the reliability of the core Markdown rendering pipeline. The app's success criterion (from the charter) is daily-driver use by the creator. Invisible content blocks and broken code highlighting are blocking defects for that goal. These are not edge cases -- thematic breaks are common in Markdown documents, and every code block with whitespace is affected by the color continuity issue.

### 2.3 Success Metrics

- SM-1: Documents with multiple thematic breaks render all blocks visibly and correctly, with no invisible or missing content areas.
- SM-2: Syntax-highlighted code blocks display consistent foreground colors across all runs, including whitespace-adjacent tokens.
- SM-3: Stagger animations play correctly for all blocks in documents containing duplicate content blocks (e.g., multiple thematic breaks, identical paragraphs).
- SM-4: Zero regressions in existing rendering behavior for documents without duplicate blocks.

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Markdown Viewer | Developer using mkdn to read Markdown artifacts from coding agents/LLMs | Primary -- directly impacted by invisible blocks and broken code highlighting |
| Markdown Editor | Developer using side-by-side edit+preview mode | Impacted when editing documents with thematic breaks; preview pane shows broken rendering |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project Creator | Daily-driver reliability -- rendering bugs are blocking defects for adoption |
| End Users | Trust that the preview accurately reflects the Markdown source content |

## 4. Scope Definition

### 4.1 In Scope

- Ensuring every `MarkdownBlock` produces a unique, deterministic ID within a rendered document, including `thematicBreak` and any other content-identical blocks (e.g., two identical paragraphs).
- Ensuring whitespace runs in syntax-highlighted code blocks carry a foreground color attribute matching the plain text color.
- Unit tests verifying block ID uniqueness across multiple thematic breaks, duplicate paragraphs, and other colliding block types.
- Unit tests verifying foreground color is set on all `AttributedString` runs, including whitespace runs.

### 4.2 Out of Scope

- Mermaid rendering pipeline changes.
- FileWatcher behavior.
- Editor views or editor-side changes.
- CLI / Argument Parser changes.
- UI component hierarchy changes (MarkdownBlockView, CodeBlockView view structure).
- MarkdownVisitor parsing logic (only the ID contract of produced blocks is affected).
- Theme color palette changes.
- No new external dependencies.

### 4.3 Assumptions

- A-1: The `MarkdownBlock` enum's `id` property is the sole source of identity used by `ForEach` in `MarkdownPreviewView`.
- A-2: The `blockAppeared` dictionary in `MarkdownPreviewView` is keyed on `block.id` and used for stagger animation state.
- A-3: Splash's `OutputBuilder` protocol signature for `addWhitespace` is unchanged and the fix is internal to the builder implementation.
- A-4: Block IDs that incorporate positional information remain deterministic across re-renders of the same content, preserving SwiftUI's diffing behavior.
- A-5: The `plainTextColor` used in `addPlainText()` and `addToken()` is the correct color for whitespace runs.

## 5. Functional Requirements

### REQ-001: Unique Block IDs for Thematic Breaks

| Attribute | Value |
|-----------|-------|
| **Priority** | Must Have |
| **User Type** | Markdown Viewer, Markdown Editor |
| **Requirement** | Every `thematicBreak` block must produce a unique ID within a single rendered document. The static string `"hr"` must be replaced with an ID that incorporates positional or ordinal information. |
| **Rationale** | SwiftUI's `ForEach` relies on unique IDs for correct view diffing. Duplicate IDs cause blocks to render as invisible empty areas, breaking the core viewing experience. |
| **Acceptance Criteria** | AC-001a: A document containing three thematic breaks produces three `MarkdownBlock` values with three distinct `id` values. AC-001b: All three thematic breaks are visible in the rendered preview with no invisible or zero-height areas. |

### REQ-002: Unique Block IDs for Content-Identical Blocks

| Attribute | Value |
|-----------|-------|
| **Priority** | Must Have |
| **User Type** | Markdown Viewer, Markdown Editor |
| **Requirement** | Any two `MarkdownBlock` values with identical content at different positions in a document must produce distinct IDs. This applies to duplicate paragraphs, duplicate headings, duplicate blockquotes, and any other block types where content alone cannot distinguish them. |
| **Rationale** | The duplicate ID problem is not limited to thematic breaks. Any content-identical blocks will collide, causing the same invisible-block rendering corruption. |
| **Acceptance Criteria** | AC-002a: A document containing two identical paragraphs produces two `MarkdownBlock` values with distinct `id` values. AC-002b: A document containing duplicate headings at different levels or same level produces distinct IDs. |

### REQ-003: Deterministic Block IDs Across Re-renders

| Attribute | Value |
|-----------|-------|
| **Priority** | Must Have |
| **User Type** | Markdown Viewer, Markdown Editor |
| **Requirement** | Block IDs must be deterministic -- the same content at the same position must produce the same ID across re-renders. |
| **Rationale** | SwiftUI's diffing algorithm requires stable identifiers. Non-deterministic IDs would cause unnecessary view recreation, breaking animations and performance. |
| **Acceptance Criteria** | AC-003a: Rendering the same Markdown content twice produces identical arrays of block IDs. AC-003b: Stagger animations do not restart or flicker on content re-render when content has not changed. |

### REQ-004: Whitespace Foreground Color in Syntax Highlighting

| Attribute | Value |
|-----------|-------|
| **Priority** | Must Have |
| **User Type** | Markdown Viewer, Markdown Editor |
| **Requirement** | Whitespace runs produced by the syntax highlighting output builder must carry a foreground color attribute matching the plain text color, ensuring color continuity across all runs in the `AttributedString`. |
| **Rationale** | Missing foreground color on whitespace runs causes SwiftUI's `Text` view to render adjacent tokens with inconsistent colors, producing visual artifacts in code blocks. |
| **Acceptance Criteria** | AC-004a: Every run in the `AttributedString` produced by the theme output builder has a non-nil `foregroundColor` attribute, including whitespace runs. AC-004b: Whitespace runs use the same `plainTextColor` as plain text runs. |

### REQ-005: Stagger Animation Integrity with Duplicate Blocks

| Attribute | Value |
|-----------|-------|
| **Priority** | Should Have |
| **User Type** | Markdown Viewer |
| **Requirement** | The stagger animation system (keyed on block IDs via the `blockAppeared` dictionary) must function correctly for documents containing previously-colliding block types. Each block must animate independently. |
| **Rationale** | Duplicate IDs corrupt the `blockAppeared` dictionary, causing blocks to skip their entrance animation or animate at the wrong time. |
| **Acceptance Criteria** | AC-005a: In a document with three thematic breaks, each thematic break block plays its stagger animation at the correct delay relative to its position. |

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

- NFR-001: The ID generation change must not introduce measurable rendering latency. Appending positional suffixes or incorporating indices is a trivial string operation.
- NFR-002: Re-rendering a document after a file change must remain instantaneous (no perceptible delay introduced by ID computation).

### 6.2 Security Requirements

- No security implications. This is a rendering-only change with no network, filesystem, or data exposure surface.

### 6.3 Usability Requirements

- NFR-003: The fix must be invisible to users. There is no user-facing change other than previously-invisible blocks becoming visible and code blocks displaying correct colors.

### 6.4 Compliance Requirements

- No compliance implications.

## 7. User Stories

### STORY-001: Viewing Documents with Multiple Horizontal Rules

**As a** Markdown viewer
**I want** all sections separated by horizontal rules to be visible in the preview
**So that** I can read the complete document without missing content

**Acceptance Scenarios**:

- GIVEN a Markdown document with three sections separated by `---` thematic breaks
  WHEN I open the document in mkdn
  THEN all three thematic breaks render as visible horizontal lines AND all content sections between them are visible

- GIVEN a Markdown document with five consecutive thematic breaks
  WHEN I open the document in mkdn
  THEN all five horizontal lines are rendered, each at the correct position

### STORY-002: Reading Syntax-Highlighted Code Blocks

**As a** Markdown viewer
**I want** code blocks to display consistent syntax highlighting colors
**So that** I can read code with proper visual distinction between tokens

**Acceptance Scenarios**:

- GIVEN a Markdown document with a Swift code block containing keywords, strings, and whitespace
  WHEN I view the rendered preview
  THEN all tokens display their correct theme colors AND whitespace between tokens does not cause adjacent tokens to lose their intended colors

### STORY-003: Viewing Documents with Repeated Content

**As a** Markdown viewer
**I want** duplicate paragraphs or headings to all appear in the preview
**So that** I see an accurate representation of the source document

**Acceptance Scenarios**:

- GIVEN a Markdown document containing two identical paragraphs at different positions
  WHEN I open the document in mkdn
  THEN both paragraphs are visible in the preview at their correct positions

## 8. Business Rules

- BR-001: The rendered preview must be a faithful visual representation of the Markdown source. No source content may be invisible or missing from the preview.
- BR-002: Syntax highlighting must produce visually consistent output. Every character run in a highlighted code block must carry explicit color information.
- BR-003: Animation state (stagger entrance animations) must track individual blocks. No two blocks may share animation state due to identifier collision.

## 9. Dependencies & Constraints

### Internal Dependencies

| Dependency | Description |
|------------|-------------|
| `MarkdownBlock.swift` | Core of the duplicate ID bug; `id` computed property must be modified |
| `ThemeOutputFormat.swift` | Core of the whitespace color bug; `addWhitespace` must set foreground color |
| `MarkdownPreviewView.swift` | Consumer of block IDs via `ForEach` and `blockAppeared` dictionary; no changes needed if IDs are unique |
| `MarkdownRenderer.swift` | Coordinator between visitor and consumers; may host post-processing for ID deduplication |

### External Dependencies

| Dependency | Constraint |
|------------|------------|
| Splash (JohnSundell/Splash) | `OutputBuilder` protocol signature unchanged; fix is internal to the builder |
| swift-markdown (apple/swift-markdown) | Upstream AST types unchanged; fix is in ID generation from parsed blocks |

### Constraints

- C-1: No new external dependencies.
- C-2: No protocol-level changes to Splash's `OutputBuilder`.
- C-3: Block IDs must remain deterministic for SwiftUI diffing correctness.
- C-4: Changes must pass SwiftLint strict mode and SwiftFormat.

## 10. Clarifications Log

| Item | Question | Resolution | Source |
|------|----------|------------|--------|
| CL-001 | Which block types beyond thematicBreak can produce duplicate IDs? | Any content-identical blocks at different positions (duplicate paragraphs, duplicate headings). The fix must be positional/ordinal, not content-based. | PRD FR-1, concept_map.md block element list |
| CL-002 | Should the ID scheme use array index or content hash + index? | The PRD specifies "positional or ordinal information" -- either approach satisfies the requirement as long as IDs are unique and deterministic. | PRD FR-1 |
| CL-003 | Does the whitespace color fix affect non-Swift code blocks? | Yes. Splash is used for all syntax-highlighted code blocks. The fix applies to all languages processed by the theme output builder. | architecture.md code block pipeline, PRD FR-2 |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | `block-rendering-fix.md` | Exact filename match with feature ID `block-rendering-fix` |
| Priority assignment | All functional requirements set to Must Have (except REQ-005 as Should Have) | Both bugs are blocking defects for daily-driver use per charter success criteria; animation integrity is important but secondary |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| Scope of "content-identical blocks" | Extended beyond thematicBreak to include any block type where two instances could share identical content (paragraphs, headings, blockquotes) | PRD FR-1 mentions "any other content-identical blocks"; concept_map.md lists all block element types |
| Which users are affected | Both Markdown Viewer (preview-only) and Markdown Editor (side-by-side preview pane) users | architecture.md shows both MarkdownPreviewView (preview-only) and SplitEditorView (side-by-side) consuming the same rendering pipeline |
| Whether MarkdownPreviewView needs changes | No direct changes needed -- if block IDs are unique, ForEach and blockAppeared work correctly | PRD scope explicitly excludes UI component changes; the fix is in ID generation |
| Whitespace color value | Use `plainTextColor` (matching `addPlainText()` behavior) | PRD FR-2 explicitly specifies matching `plainTextColor` |
| Test update for existing whitespace assertion | Existing test asserting `foregroundColor == nil` for whitespace must be updated to assert `foregroundColor == plainTextColor` | PRD FR-4 explicitly calls this out |
