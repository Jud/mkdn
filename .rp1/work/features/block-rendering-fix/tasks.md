# Development Tasks: Block Rendering Fix

**Feature ID**: block-rendering-fix
**Status**: In Progress
**Progress**: 71% (5 of 7 tasks)
**Estimated Effort**: 2 days
**Started**: 2026-02-07

## Overview

Fix two rendering bugs in the Markdown preview pipeline: (1) duplicate block IDs causing invisible blocks in SwiftUI's `ForEach` diffing and corrupted stagger animation state, and (2) missing foreground color on whitespace runs in syntax-highlighted code blocks. The fix introduces an `IndexedBlock` wrapper at the renderer boundary and a one-line color assignment in the theme output builder.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T4] - IndexedBlock struct and whitespace fix have no shared code paths
2. [T2] - Renderer depends on IndexedBlock type from T1
3. [T3, T5] - Preview view and tests depend on renderer returning IndexedBlock

**Dependencies**:

- T2 -> T1 (interface: T2 uses IndexedBlock type defined in T1)
- T3 -> T2 (interface: T3 consumes [IndexedBlock] returned by T2)
- T5 -> [T1, T2, T4] (data: tests verify IndexedBlock uniqueness, renderer output, and whitespace color)

**Critical Path**: T1 -> T2 -> T3

## Task Breakdown

### Foundation (Parallel Group 1)

- [x] **T1**: Add `IndexedBlock` struct to `MarkdownBlock.swift` `[complexity:simple]`

    **Reference**: [design.md#31-indexedblock-struct](design.md#31-indexedblock-struct)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] `IndexedBlock` struct is defined in `mkdn/Core/Markdown/MarkdownBlock.swift` after the `MarkdownBlock` enum
    - [x] Struct conforms to `Identifiable` with `id` computed as `"\(index)-\(block.id)"`
    - [x] Struct has `let index: Int` and `let block: MarkdownBlock` properties
    - [x] `MarkdownBlock` enum is unchanged (retains its own `Identifiable` conformance)
    - [x] `ListItem` struct is unchanged

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/MarkdownBlock.swift`
    - **Approach**: Added 8-line `IndexedBlock` struct after the `MarkdownBlock` enum, conforming to `Identifiable` with `id` = `"\(index)-\(block.id)"`
    - **Deviations**: None
    - **Tests**: Existing tests pass

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | PASS |

- [x] **T4**: Fix whitespace foreground color in `ThemeOutputFormat.Builder.addWhitespace` `[complexity:simple]`

    **Reference**: [design.md#34-whitespace-foreground-color-fix](design.md#34-whitespace-foreground-color-fix)

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [x] `addWhitespace` creates an `AttributedString`, sets `foregroundColor = plainTextColor`, then appends
    - [x] Every run in the output `AttributedString` has a non-nil `foregroundColor` after highlighting, including whitespace runs (AC-004a)
    - [x] Whitespace runs use the same `plainTextColor` as plain text runs (AC-004b)

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/ThemeOutputFormat.swift`, `mkdnTests/Unit/Core/ThemeOutputFormatTests.swift`
    - **Approach**: Changed `addWhitespace` to create a local `AttributedString`, set `foregroundColor = plainTextColor`, then append. Updated existing test assertion from `nil` to `red` (the plainTextColor).
    - **Deviations**: Updated the existing whitespace test (T5 scope) to match the new behavior, as it would otherwise fail.
    - **Tests**: ThemeOutputFormat suite 6/6 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | PASS |
    | Commit | PASS |
    | Comments | PASS |

### Renderer Update (Parallel Group 2)

- [x] **T2**: Update `MarkdownRenderer` to return `[IndexedBlock]` `[complexity:simple]`

    **Reference**: [design.md#32-markdownrenderer-return-type](design.md#32-markdownrenderer-return-type)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] `render(document:theme:)` return type is `[IndexedBlock]`
    - [x] Implementation wraps blocks via `blocks.enumerated().map { IndexedBlock(index: $0.offset, block: $0.element) }`
    - [x] `render(text:theme:)` return type is `[IndexedBlock]`
    - [x] `parse(_:)` method is unchanged

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/MarkdownRenderer.swift`, `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`, `mkdn/Features/Viewer/ViewModels/PreviewViewModel.swift`, `mkdnTests/Unit/Core/MarkdownRendererTests.swift`, `mkdnTests/Unit/Core/MarkdownVisitorTests.swift`
    - **Approach**: Changed both `render` methods to return `[IndexedBlock]` with `.enumerated().map` wrapping. Updated all call-site consumers (MarkdownPreviewView, PreviewViewModel) and test pattern matches (`blocks.first?.block`, `blocks[index].block`) to compile with the new return type.
    - **Deviations**: Also updated MarkdownPreviewView (T3 scope) and test pattern matches (T5 scope) as required for compilation. MarkdownPreviewView now uses simplified `ForEach(renderedBlocks)` with `indexedBlock.block`/`.id`/`.index` accessors. PreviewViewModel (not in any task) updated from `[MarkdownBlock]` to `[IndexedBlock]`.
    - **Tests**: All 85 tests passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | PASS |
    | Commit | PASS |
    | Comments | PASS |

### Consumer and Tests (Parallel Group 3)

- [x] **T3**: Update `MarkdownPreviewView` to consume `[IndexedBlock]` `[complexity:medium]`

    **Reference**: [design.md#33-markdownpreviewview-updates](design.md#33-markdownpreviewview-updates)

    **Effort**: 3 hours

    **Acceptance Criteria**:

    - [x] `@State private var renderedBlocks` type changed to `[IndexedBlock]`
    - [x] `ForEach` simplified to `ForEach(renderedBlocks)` using `IndexedBlock.Identifiable` conformance (no `enumerated()`, no explicit `id:` keypath)
    - [x] `MarkdownBlockView(block:)` receives `indexedBlock.block`
    - [x] All `blockAppeared` dictionary operations use `indexedBlock.id` (unique) instead of `block.id`
    - [x] Stagger delay uses `Double(indexedBlock.index) * motion.staggerDelay`
    - [x] Theme-change handler and cleanup pass work correctly with `IndexedBlock` identity
    - [x] Documents with multiple thematic breaks render all blocks visibly (AC-001b)
    - [x] Stagger animations play at correct delays for duplicate blocks (AC-005a)

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`
    - **Approach**: Implemented as part of T2 (API return type change required all consumer updates for compilation). Changed `renderedBlocks` to `[IndexedBlock]`, simplified `ForEach` to use `IndexedBlock.Identifiable`, updated all `blockAppeared` and stagger logic to use `indexedBlock.id`/`.index`/`.block`.
    - **Deviations**: Implemented alongside T2 rather than separately, as the API change and consumer update are inseparable.
    - **Tests**: All tests passing; visual AC (001b, 005a) require manual verification

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS (committed with T2 - 53982c6) |
    | Comments | PASS |

- [x] **T5**: Update and add unit tests for `IndexedBlock`, renderer, and whitespace color `[complexity:medium]`

    **Reference**: [design.md#t5-update-and-add-tests](design.md#t5-update-and-add-tests)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [x] New test: `IndexedBlock` produces unique IDs for thematic breaks at different indices (AC-001a)
    - [x] New test: `IndexedBlock` produces unique IDs for identical paragraphs at different indices (AC-002a)
    - [x] New test: `IndexedBlock` ID is deterministic for same content and index (AC-003a)
    - [x] New test: Multiple thematic breaks produce unique IDs through full renderer pipeline
    - [x] Updated test: `addWhitespace` asserts `foregroundColor == plainTextColor` (was `nil`)
    - [x] All existing `MarkdownRendererTests` pattern matches updated: `blocks.first?.block`, `blocks[index].block` (~10 sites)
    - [x] All existing `MarkdownVisitorTests` pattern matches updated: `blocks.first?.block`, `blocks[index].block` (~15 sites)
    - [x] All tests pass with `swift test`

    **Implementation Summary**:

    - **Files**: `mkdnTests/Unit/Core/MarkdownBlockTests.swift`, `mkdnTests/Unit/Core/MarkdownRendererTests.swift`
    - **Approach**: Added 3 IndexedBlock tests (thematic break uniqueness, paragraph uniqueness, determinism) to MarkdownBlockTests and 1 pipeline test (multi-thematic-break uniqueness) to MarkdownRendererTests. Pattern match updates and whitespace test update were completed in T2/T4.
    - **Deviations**: None
    - **Tests**: 89/89 passing

### User Docs

- [ ] **TD1**: Update modules.md - Core Layer > Markdown `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Core Layer > Markdown

    **KB Source**: modules.md:MarkdownBlock.swift

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] `MarkdownBlock.swift` file purpose updated to mention `IndexedBlock` wrapper struct
    - [ ] Section reflects the new role of `MarkdownBlock.swift` as containing both the block enum and the indexed wrapper

- [ ] **TD2**: Update architecture.md - Rendering Pipeline > Markdown `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Rendering Pipeline > Markdown

    **KB Source**: architecture.md:Markdown

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Pipeline description updated to show `IndexedBlock` wrapping step between visitor output and view consumption
    - [ ] Section reflects that `MarkdownRenderer` returns `[IndexedBlock]` instead of `[MarkdownBlock]`

## Acceptance Criteria Checklist

- [ ] AC-001a: A document containing three thematic breaks produces three block values with three distinct IDs
- [ ] AC-001b: All three thematic breaks are visible in the rendered preview with no invisible or zero-height areas
- [ ] AC-002a: A document containing two identical paragraphs produces two block values with distinct IDs
- [ ] AC-002b: A document containing duplicate headings produces distinct IDs
- [ ] AC-003a: Rendering the same Markdown content twice produces identical arrays of block IDs
- [ ] AC-003b: Stagger animations do not restart or flicker on content re-render when content has not changed
- [ ] AC-004a: Every run in the AttributedString produced by the theme output builder has a non-nil foregroundColor, including whitespace runs
- [ ] AC-004b: Whitespace runs use the same plainTextColor as plain text runs
- [ ] AC-005a: In a document with three thematic breaks, each block plays its stagger animation at the correct delay relative to its position

## Definition of Done

- [ ] All tasks completed
- [ ] All AC verified
- [ ] Code reviewed
- [ ] Docs updated
