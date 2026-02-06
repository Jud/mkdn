# Development Tasks: Core Markdown Rendering

**Feature ID**: core-markdown-rendering
**Status**: Not Started
**Progress**: 75% (9 of 12 tasks)
**Estimated Effort**: 5 days
**Started**: 2026-02-06

## Overview

Extend the existing Markdown rendering pipeline to achieve complete CommonMark block and inline type coverage, with GFM table alignment and strikethrough support, async image display, link interaction, depth-aware list rendering, and full theming integration. The approach extends the existing skeleton (MarkdownBlock, MarkdownVisitor, MarkdownBlockView, CodeBlockView, TableBlockView) rather than replacing any component.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. **[T1, T2, T5, T7, T8]** -- T1 is model changes, T2 is theme review, T5 is CodeBlockView clarification (no model change), T7 is view-level depth parameter (no model change), T8 is link verification/investigation
2. **[T3, T4, T6]** -- T3 depends on T1 (visitor produces new model types), T4 depends on T1 (new ImageBlockView for new .image case), T6 depends on T1 (TableBlockView consumes new table model)
3. **[T10]** -- Tests depend on T1 and T3 at minimum; best written after all functional changes

**Dependencies**:

- T3 -> T1 (Interface: visitor must produce the new MarkdownBlock cases defined in T1)
- T4 -> T1 (Interface: ImageBlockView renders the .image case defined in T1)
- T6 -> T1 (Interface: TableBlockView consumes TableColumn/AttributedString defined in T1)
- T10 -> [T1, T3] (Data: tests exercise the model and visitor together)

**Critical Path**: T1 -> T3 -> T10

## Task Breakdown

### Foundation (Parallel Group 1)

- [x] **T1**: Extend MarkdownBlock model with image, htmlBlock, enriched table cases, and stable IDs `[complexity:medium]`

    **Reference**: [design.md#31-model-changes-markdownblock](design.md#31-model-changes-markdownblock), [design.md#32-model-changes-markdownblockid](design.md#32-model-changes-markdownblockid)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] `.image(source: String, alt: String)` case added to MarkdownBlock enum
    - [x] `.htmlBlock(content: String)` case added to MarkdownBlock enum
    - [x] `.table(headers:rows:)` replaced with `.table(columns: [TableColumn], rows: [[AttributedString]])`
    - [x] `TableColumn` struct created with `header: AttributedString` and `alignment: TableColumnAlignment`
    - [x] `TableColumnAlignment` enum created with `.left`, `.center`, `.right` cases
    - [x] Both new types conform to `Sendable`
    - [x] `id` property uses deterministic content-based hashing (DJB2 or similar) instead of `.hashValue`
    - [x] All new cases have corresponding `id` computation returning stable, deterministic strings
    - [x] `swift build` succeeds with no errors after changes (downstream breakages in views/visitor expected and addressed in later tasks)

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/MarkdownBlock.swift`, `mkdn/Core/Markdown/MarkdownVisitor.swift`, `mkdn/Features/Viewer/Views/MarkdownBlockView.swift`, `mkdn/Features/Viewer/Views/TableBlockView.swift`, `mkdnTests/Unit/Core/MarkdownRendererTests.swift`
    - **Approach**: Added `.image`, `.htmlBlock` cases and enriched `.table` case with `TableColumn`/`TableColumnAlignment` types. Replaced `.hashValue`/`UUID()` IDs with DJB2-based `stableHash()`. Minimal downstream fixups to visitor (convertTable), views (new switch cases, alignment support), and tests (pattern matching) to maintain `swift build` success.
    - **Deviations**: None
    - **Tests**: 29/29 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

- [x] **T2**: Review and verify ThemeColors completeness for all block types `[complexity:simple]`

    **Reference**: [design.md#5-implementation-plan](design.md#5-implementation-plan)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] ThemeColors reviewed against all MarkdownBlock cases including new `.image` and `.htmlBlock`
    - [x] `linkColor` property exists and is defined in both SolarizedDark and SolarizedLight themes
    - [x] Any missing color properties added (if needed -- design notes current ThemeColors appears complete)
    - [x] No hardcoded color values exist in any rendering view (BR-003 compliance)

    **Implementation Summary**:

    - **Files**: No code changes required
    - **Approach**: Comprehensive audit of ThemeColors (12 properties) and SyntaxColors (8 properties) against all 11 MarkdownBlock cases. Verified all Markdown rendering views (MarkdownBlockView, CodeBlockView, TableBlockView, MarkdownPreviewView) source colors exclusively from theme. Confirmed `linkColor` defined as Solarized `blue` in both SolarizedDark and SolarizedLight. Confirmed upcoming ImageBlockView (T4) needs are covered by existing `foregroundSecondary`/`backgroundSecondary` properties. No missing properties identified.
    - **Deviations**: None
    - **Tests**: 29/29 passing (no changes)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ⏭️ N/A |

- [x] **T5**: Clarify and enhance CodeBlockView multi-language fallback `[complexity:simple]`

    **Reference**: [design.md#37-view-changes-codeblockview](design.md#37-view-changes-codeblockview)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] Swift-only Splash highlighting logic is explicit: `language == "swift"` uses SwiftGrammar, all others render as plain monospace
    - [x] Language label always displays when language string is present (regardless of highlighting support)
    - [x] Non-Swift languages render with `codeForeground` theme color in monospace font (not blank, not error)
    - [x] Missing or empty language string results in plain monospace with no language label
    - [x] Code blocks with unsupported languages satisfy BR-001 (graceful degradation)

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/CodeBlockView.swift`
    - **Approach**: Replaced compound guard (`guard let language, !language.isEmpty, language == "swift"`) with a single explicit guard (`guard language == "swift"`). Added docstring documenting the intentional Swift-only Splash design decision and BR-001 compliance. No behavioral change -- the refactor makes the design intent self-documenting rather than an opaque side effect of a compound condition.
    - **Deviations**: None
    - **Tests**: 29/29 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

- [x] **T7**: Enhance list rendering with depth-aware bullets and indentation `[complexity:medium]`

    **Reference**: [design.md#34-view-changes-markdownblockview](design.md#34-view-changes-markdownblockview)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] `MarkdownBlockView` accepts a `depth: Int = 0` parameter
    - [x] Unordered list bullets cycle through 4 styles by depth: bullet, white bullet, small black square, small white square
    - [x] Each nesting level has progressively deeper left padding/indentation
    - [x] Recursive child `MarkdownBlockView` instances receive `depth + 1`
    - [x] Ordered lists display correct numbering at each depth level
    - [x] 4-level nested lists render with visually distinct indentation at each level (FR-006)

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/MarkdownBlockView.swift`
    - **Approach**: Added `depth: Int = 0` parameter and static `bulletStyles` array with 4 Unicode bullet characters cycling by depth level. Unordered list view selects bullet via `min(depth, bulletStyles.count - 1)`. Both ordered and unordered list item children pass `depth + 1` to recursive MarkdownBlockView instances. Blockquote children pass through the current `depth` unchanged. Indentation is naturally progressive via cumulative `.padding(.leading, 4)` from nested list views. Ordered list numbering restarts correctly at each level via `items.enumerated()`.
    - **Deviations**: None
    - **Tests**: 29/29 passing

- [x] **T8**: Verify and implement link click handling and styling `[complexity:simple]`

    **Reference**: [design.md#38-link-handling](design.md#38-link-handling)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] `Text(attributedString)` with `.link` attribute produces clickable links that open in default browser (HYP-001 verification)
    - [x] If HYP-001 rejects: manual link handling implemented via Button, Link view, or `.onTapGesture` with `NSWorkspace.shared.open()`
    - [x] Link text styled with `linkColor` from active theme
    - [x] Link text has underline decoration
    - [x] Links open via system default browser mechanism (NFR-003 compliance)

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/MarkdownBlockView.swift`, `mkdn/Features/Viewer/Views/TableBlockView.swift`
    - **Approach**: HYP-001 confirmed -- SwiftUI `Text(attributedString)` with `.link` attribute natively makes links clickable via the `openURL` environment action, which defaults to `NSWorkspace.shared.open()` on macOS. No manual link handling needed. The visitor (T3) already sets `.link`, `.foregroundColor(linkColor)`, and `.underlineStyle(.single)` on link runs. Added `.tint(colors.linkColor)` to paragraph and heading Text views in MarkdownBlockView, and to header/data cell Text views in TableBlockView, ensuring SwiftUI uses the theme's link color for interactive link styling rather than the default system accent color.
    - **Deviations**: None
    - **Tests**: 29/29 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

### Pipeline Extension (Parallel Group 2)

- [x] **T3**: Extend MarkdownVisitor with image, strikethrough, HTML block, enriched table, and combined formatting support `[complexity:complex]`

    **Reference**: [design.md#33-visitor-changes-markdownvisitor](design.md#33-visitor-changes-markdownvisitor), [design.md#39-parsing-options](design.md#39-parsing-options)

    **Effort**: 10 hours

    **Acceptance Criteria**:

    - [x] `Image` AST node handled: produces `.image(source: String, alt: String)` block
    - [x] `Strikethrough` inline node handled: applies `.strikethroughStyle = .single` attribute
    - [x] `HTMLBlock` AST node handled: produces `.htmlBlock(content: html.rawHTML)`
    - [x] `convertTable()` extracts column alignments from `table.columnAlignments` into `TableColumn` structs
    - [x] Table cells converted to `AttributedString` (enabling inline formatting in tables)
    - [x] Combined inline formatting works: nested Strong > Emphasis produces bold+italic (bitwise OR of `inlinePresentationIntent`)
    - [x] Link inline conversion sets `.foregroundColor` to `theme.colors.linkColor` and `.underlineStyle = .single`
    - [x] GFM parsing verified: `Strikethrough` nodes appear in AST (adjust parsing options if needed)
    - [x] All new visitor paths produce correctly typed MarkdownBlock values

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/MarkdownVisitor.swift`
    - **Approach**: Extended `convertBlock()` with HTMLBlock handling and standalone-image detection in paragraphs (single Image child promotes to `.image` block). Extended `convertInline()` with Strikethrough (`.strikethroughStyle = .single`), inline Image fallback (renders alt text), and link styling (`.foregroundColor` + `.underlineStyle`). Fixed combined formatting by using per-run `.union()` on `inlinePresentationIntent` instead of whole-string assignment, preserving nested bold+italic. Enriched `convertTable()` to extract `table.columnAlignments` into `TableColumn` structs and use `inlineText()` for cells (AttributedString with full inline formatting). No parsing option changes needed -- swift-markdown registers GFM strikethrough/table extensions by default.
    - **Deviations**: None
    - **Tests**: 29/29 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

- [x] **T4**: Create ImageBlockView with async loading, placeholders, and path security `[complexity:medium]`

    **Reference**: [design.md#35-new-view-imageblockview](design.md#35-new-view-imageblockview)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] New file created at `mkdn/Features/Viewer/Views/ImageBlockView.swift`
    - [x] Local file paths (file:// or relative) load via `NSImage(contentsOf:)` on background task
    - [x] Remote URLs (http/https) load via `URLSession.shared.data(from:)` with 10-second timeout
    - [x] Loading state displays a placeholder indicator
    - [x] Error state displays alt text with broken-image icon (BR-002 compliance)
    - [x] Successfully loaded images display inline at appropriate size within document flow
    - [x] Local file paths resolved relative to currently open Markdown file directory (`AppState.currentFileURL`)
    - [x] Path traversal prevented: resolved path validated to not escape parent directory tree (NFR-004)
    - [x] `MarkdownBlockView` routes `.image` case to `ImageBlockView`
    - [x] `.htmlBlock` case renders as monospace text block in `MarkdownBlockView` (BR-005)

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/ImageBlockView.swift` (new), `mkdn/Features/Viewer/Views/MarkdownBlockView.swift`
    - **Approach**: Created ImageBlockView with three-state rendering (loading/success/error) using `.task` async pattern matching MermaidBlockView conventions. Source resolution handles http/https remote URLs via URLSession (10s timeout), file:// URLs, and relative paths resolved against AppState.currentFileURL. Path traversal prevention validates standardized resolved path has prefix of Markdown file's parent directory. MarkdownBlockView updated to route `.image` case to ImageBlockView. htmlBlock case already rendered as monospace from T1.
    - **Deviations**: None
    - **Tests**: 29/29 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

- [x] **T6**: Enhance TableBlockView with column alignment and AttributedString cells `[complexity:medium]`

    **Reference**: [design.md#36-view-changes-tableblockview](design.md#36-view-changes-tableblockview)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] TableBlockView accepts `columns: [TableColumn], rows: [[AttributedString]]` (new signature)
    - [x] Column alignment applied: `.leading`, `.center`, `.trailing` frame alignment per `TableColumn.alignment`
    - [x] Cells rendered as `Text(attributedString)` enabling inline formatting within table cells
    - [x] Header row remains visually distinct (bold text, different background)
    - [x] Row striping preserved (alternating row backgrounds)
    - [x] Tables with mixed column alignments (left, center, right) render correctly (FR-005 AC-1)

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/TableBlockView.swift`
    - **Approach**: Verified existing implementation already meets all acceptance criteria. T1's downstream fixups to maintain `swift build` success fully implemented the enriched table view: `columns: [TableColumn], rows: [[AttributedString]]` signature, per-column alignment via `swiftUIAlignment()` helper mapping `.left/.center/.right` to `.leading/.center/.trailing`, `Text(attributedString)` for both header and data cells enabling inline formatting, bold header styling with `backgroundSecondary` background, and alternating row striping via `isMultiple(of: 2)`. No additional code changes required.
    - **Deviations**: None
    - **Tests**: 29/29 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

### Verification (Parallel Group 3)

- [x] **T10**: Extend test suite with comprehensive visitor and rendering tests `[complexity:medium]`

    **Reference**: [design.md#7-testing-strategy](design.md#7-testing-strategy)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] New test file `mkdnTests/Unit/Core/MarkdownVisitorTests.swift` created
    - [x] Test: Image AST node produces `.image` block with correct source and alt
    - [x] Test: Strikethrough inline text has `.strikethroughStyle == .single` attribute
    - [x] Test: Table column alignments extracted correctly from Markdown alignment syntax
    - [x] Test: Combined inline formatting (bold+italic) preserves both `inlinePresentationIntent` values
    - [x] Test: HTML block produces `.htmlBlock` with raw content preserved
    - [x] Test: Link AttributedString has `.link` URL and correct foreground color
    - [x] Test: Nested list structure preserved at 4 levels (correct nesting depth and item count)
    - [x] Test: Empty/malformed inputs produce reasonable output (no crashes)
    - [x] Test: Deterministic block IDs return same value for identical input
    - [x] All tests use Swift Testing framework (`@Test`, `#expect`, `@Suite`) -- not XCTest (NFR-010)
    - [x] Existing tests in `MarkdownRendererTests.swift` still pass after all changes
    - [x] `swift test` passes with zero failures

    **Implementation Summary**:

    - **Files**: `mkdnTests/Unit/Core/MarkdownVisitorTests.swift` (new)
    - **Approach**: Created a dedicated `@Suite("MarkdownVisitor")` test suite with 19 tests covering all T10 acceptance criteria. Tests exercise the public `MarkdownRenderer.render(text:theme:)` API to verify visitor behavior end-to-end: image block parsing (source/alt extraction, standalone promotion from paragraph), strikethrough attribute application, table column alignment extraction with header text verification, combined bold+italic formatting via `inlinePresentationIntent` union, HTML block raw content preservation, link URL/underline/foreground color attributes, 4-level nested list structure traversal for both ordered and unordered lists, empty/malformed input resilience (whitespace-only, unclosed formatting, long lines), and deterministic block ID stability across renders and themes.
    - **Deviations**: None
    - **Tests**: 48/48 passing (29 existing + 19 new)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ✅ PASS |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

### User Docs

- [ ] **TD1**: Update modules.md - Core/Markdown, Features/Viewer `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Core/Markdown, Features/Viewer

    **KB Source**: modules.md:Core Layer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] `ImageBlockView.swift` added to Features/Viewer/Views table
    - [ ] `MarkdownVisitorTests.swift` added to test inventory (or noted in module descriptions)
    - [ ] Module descriptions reflect new block types (image, htmlBlock) and enriched table model

- [ ] **TD2**: Update architecture.md - Rendering Pipeline `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Rendering Pipeline > Markdown

    **KB Source**: architecture.md:Rendering Pipeline

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Pipeline description includes image loading (async local + remote) as a rendering step
    - [ ] GFM extensions (tables with alignment, strikethrough) noted in pipeline capabilities

- [ ] **TD3**: Update concept_map.md - Block Elements, Inline Elements `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/concept_map.md`

    **Section**: Block Elements, Inline Elements

    **KB Source**: concept_map.md:Domain Concepts

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Image block added to Block Elements section of concept tree
    - [ ] HTML Block added to Block Elements section of concept tree
    - [ ] Strikethrough added to Inline Elements section of concept tree

## Acceptance Criteria Checklist

### FR-001: Markdown Parsing
- [ ] AC-1: Valid CommonMark document produces complete AST with no errors
- [ ] AC-2: Document containing all supported block types has every block represented in AST
- [ ] AC-3: Document with inline formatting (bold, italic, code, strikethrough) preserves markup in AST

### FR-002: AST-to-Model Conversion
- [ ] AC-1: Headings H1-H6 produce model values with correct level
- [ ] AC-2: Nested lists (up to 4 levels) preserve nesting depth and list type
- [ ] AC-3: Fenced code blocks capture code content and language identifier
- [ ] AC-4: Tables capture headers, rows, and column alignments
- [ ] AC-5: Inline formatting captured within any block type

### FR-003: Native SwiftUI Block Rendering
- [ ] AC-1: Headings display with descending font sizes and appropriate weight
- [ ] AC-2: Paragraphs display with appropriate line spacing and text wrapping
- [ ] AC-3: Blockquotes display with visual left-edge indicator and differentiated styling
- [ ] AC-4: Thematic break displays as horizontal rule
- [ ] AC-5: No WKWebView used anywhere in the rendering pipeline

### FR-004: Code Block Syntax Highlighting
- [ ] AC-1: Supported language (swift) tokens highlighted with theme-consistent colors
- [ ] AC-2: Unsupported or missing language displays in theme-consistent monospace without token highlighting
- [ ] AC-3: Code block background color distinct from document background per active theme

### FR-005: Table Rendering
- [ ] AC-1: Left, center, and right column alignments applied correctly
- [ ] AC-2: Header row visually distinct (bold text, different background)
- [ ] AC-3: Alternating rows have subtle background differentiation (row striping)

### FR-006: Nested List Rendering
- [ ] AC-1: 4-level nested unordered list has increasing indentation per level
- [ ] AC-2: 4-level nested ordered list has correct numbering restart per level
- [ ] AC-3: Inline formatting (bold, italic, code) preserved within list items

### FR-007: Inline Formatting
- [ ] AC-1: Bold text within a list item appears bold
- [ ] AC-2: Inline code within a blockquote appears with monospace font and code-styled background
- [ ] AC-3: Strikethrough text in a table cell appears with strikethrough decoration
- [ ] AC-4: Combined formatting (bold + italic) applies both styles simultaneously

### FR-008: Theme Integration
- [ ] AC-1: Switching from Solarized Dark to Light updates all rendered block views
- [ ] AC-2: No color or font values are hardcoded -- all sourced from active theme
- [ ] AC-3: Both Solarized themes render all block types with visually correct styling

### FR-009: Link Interaction
- [ ] AC-1: Link text visually distinct (colored, underlined per theme)
- [ ] AC-2: Clicked link opens target URL in system default browser

### FR-010: Image Display
- [ ] AC-1: Image with valid URL loads and displays inline
- [ ] AC-2: Image with valid local file path loads and displays inline
- [ ] AC-3: Image with invalid source displays placeholder (not crash or blank space)

### Non-Functional Requirements
- [ ] NFR-001: Rendering < 500 line document completes in under 100ms on Apple Silicon
- [ ] NFR-002: Pipeline is stateless -- same input produces identical output
- [ ] NFR-003: Links use system default browser mechanism (NSWorkspace.shared.open)
- [ ] NFR-004: Local image paths scoped; no path traversal vector
- [ ] NFR-005: Rendered documents are visually beautiful with obsessive spacing/typography/color attention
- [ ] NFR-006: Preview view fills available width and handles window resizing
- [ ] NFR-007: No WKWebView usage anywhere
- [ ] NFR-008: All public APIs are @MainActor-safe
- [ ] NFR-009: All code passes SwiftLint strict mode
- [ ] NFR-010: All unit tests use Swift Testing framework

## Definition of Done

- [ ] All 12 tasks completed (T1, T2, T3, T4, T5, T6, T7, T8, T10, TD1, TD2, TD3)
- [ ] All acceptance criteria verified
- [ ] `swift build` succeeds
- [ ] `swift test` passes with zero failures
- [ ] `swiftlint lint` reports no violations
- [ ] `swiftformat .` produces no changes
- [ ] Code reviewed
- [ ] Knowledge base docs updated (TD1, TD2, TD3)
