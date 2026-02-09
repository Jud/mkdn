# Development Tasks: Code Block Styling

**Feature ID**: code-block-styling
**Status**: Not Started
**Progress**: 25% (2 of 8 tasks)
**Estimated Effort**: 3 days
**Started**: 2026-02-09

## Overview

Replace the current per-run `NSAttributedString.Key.backgroundColor` approach for code blocks with a custom background drawing system that renders continuous rounded-rectangle containers with padding, border, and proper spacing. The implementation uses an `NSTextView` subclass (`CodeBlockBackgroundTextView`) that overrides `drawBackground(in:)` to draw containers behind code block text ranges identified via custom `NSAttributedString.Key` attributes. The existing TextKit 2 text flow is preserved, maintaining cross-block text selection.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T2] - T1 defines the NSTextView subclass and attribute keys; T2 updates the text storage builder to produce the new attributes. Neither depends on the other during development (T2 uses the attribute keys defined in T1, but they are simple constants that can be defined independently).
2. [T3, T4] - T3 wires the subclass into SelectableTextView; T4 writes unit tests for the builder changes. T3 requires T1 (subclass) and T2 (attributes in text storage). T4 requires T2 (builder changes to test).
3. [T5] - Integration verification requires the full pipeline wired up.

**Dependencies**:

- T3 -> [T1, T2] (interface: T3 instantiates CodeBlockBackgroundTextView from T1, and the attributed strings produced by T2 must contain the custom attributes that T1's drawing code enumerates)
- T4 -> T2 (data: T4 tests the attributed string output produced by T2)
- T5 -> [T3, T4] (sequential workflow: integration verification requires the pipeline wired up via T3, and unit tests passing via T4)

**Critical Path**: T2 -> T3 -> T5

## Task Breakdown

### Foundation (Parallel Group 1)

- [x] **T1**: Define custom attribute keys and implement CodeBlockBackgroundTextView `[complexity:medium]`

    **Reference**: [design.md#31-custom-attribute-keys-codeblockattributes](design.md#31-custom-attribute-keys-codeblockattributes), [design.md#32-codeblockbackgroundtextview](design.md#32-codeblockbackgroundtextview)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] New file `mkdn/Core/Markdown/CodeBlockAttributes.swift` defines `CodeBlockAttributes.range` (`NSAttributedString.Key("mkdn.codeBlockRange")`) and `CodeBlockAttributes.colors` (`NSAttributedString.Key("mkdn.codeBlockColors")`)
    - [x] `CodeBlockColorInfo` is an `NSObject` subclass with `background: NSColor` and `border: NSColor` properties
    - [x] New file `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` defines `CodeBlockBackgroundTextView: NSTextView`
    - [x] `drawBackground(in:)` calls `super.drawBackground(in:)` first, then enumerates `CodeBlockAttributes.range` in the text storage
    - [x] Contiguous ranges with the same code block ID are grouped into a single bounding rect
    - [x] Bounding rect is computed from `NSTextLayoutManager.enumerateTextLayoutFragments` fragment frames, extended to text container width (full-width per FR-1)
    - [x] Filled rounded rect drawn with `CodeBlockColorInfo.background`, stroked with `CodeBlockColorInfo.border` at 0.3 opacity
    - [x] Constants: corner radius 6pt, border width 1pt, border opacity 0.3
    - [x] `textContainerOrigin` offset applied correctly to drawing coordinates
    - [x] Code compiles with Swift 6 strict concurrency and passes SwiftLint

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/CodeBlockAttributes.swift`, `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift`
    - **Approach**: Defined `CodeBlockAttributes` enum with `.range` and `.colors` attribute keys, plus `CodeBlockColorInfo` NSObject subclass carrying background/border NSColor values. Implemented `CodeBlockBackgroundTextView` as NSTextView subclass overriding `drawBackground(in:)` to enumerate code block ranges, compute bounding rects from TextKit 2 layout fragment frames, and draw full-width rounded-rect containers (fill + stroke). Dirty rect optimization included.
    - **Deviations**: None
    - **Tests**: N/A (drawing code; tested visually in T5)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T2**: Update MarkdownTextStorageBuilder to produce code block custom attributes `[complexity:medium]`

    **Reference**: [design.md#33-markdowntextstoragebuilder-changes](design.md#33-markdowntextstoragebuilder-changes)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] `appendCodeBlock` in `MarkdownTextStorageBuilder+Blocks.swift` no longer applies per-run `.backgroundColor` to code block content
    - [x] `appendCodeBlock` applies `CodeBlockAttributes.range` with a unique ID string to all code block characters (label + body + trailing newline)
    - [x] `appendCodeBlock` applies `CodeBlockAttributes.colors` with resolved `CodeBlockColorInfo(background:, border:)` from the active theme
    - [x] Paragraph style sets `headIndent` and `firstLineHeadIndent` to 12pt (container padding) for left inset
    - [x] Paragraph style sets `tailIndent` to -12pt for right inset
    - [x] `paragraphSpacingBefore` set to 8pt on first code paragraph (with language label) or 12pt (without label) for top padding
    - [x] `appendCodeLabel` no longer applies per-run `.backgroundColor`; applies same `.codeBlockRange` and `.codeBlockColors` attributes as the code body
    - [x] Language label has matching `headIndent` / `firstLineHeadIndent` paragraph indents
    - [x] Existing syntax highlighting (Splash) foreground colors still apply correctly to Swift code blocks
    - [x] Non-Swift code blocks use `codeForeground` color within the container
    - [x] Container padding constant (12pt) defined as a static constant following existing builder pattern

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`, `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`, `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTests.swift`
    - **Approach**: Replaced per-run `.backgroundColor` with `CodeBlockAttributes.range` (UUID-based block ID) and `CodeBlockAttributes.colors` (CodeBlockColorInfo carrying background/border NSColor). Added `codeBlockPadding` (12pt) and `codeBlockTopPaddingWithLabel` (8pt) constants. Applied paragraph indents (headIndent: 12, firstLineHeadIndent: 12, tailIndent: -12) via `makeCodeBlockParagraphStyle()` helper. Extracted `setFirstParagraphSpacing()` helper for first-paragraph spacing. Updated `appendCodeLabel` to carry same block ID and color info with matching indents. Added `tailIndent` parameter to `makeParagraphStyle`. Updated broken existing test to verify `CodeBlockAttributes.colors` instead of `.backgroundColor`.
    - **Deviations**: None
    - **Tests**: 32/32 passing (MarkdownTextStorageBuilderTests)

### Integration (Parallel Group 2)

- [ ] **T3**: Wire CodeBlockBackgroundTextView into SelectableTextView `[complexity:medium]`

    **Reference**: [design.md#34-selectabletextview-changes](design.md#34-selectabletextview-changes)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [ ] `SelectableTextView.makeNSView` creates `CodeBlockBackgroundTextView` instead of default `NSTextView` from `NSTextView.scrollableTextView()`
    - [ ] Manual `NSScrollView` + `CodeBlockBackgroundTextView` construction applies identical configuration to the current setup (editable: false, selectable: true, textContainerInset, drawsBackground, etc.)
    - [ ] All existing coordinator logic (OverlayCoordinator, EntranceAnimator, render completion signaling) continues to work unchanged
    - [ ] Text selection works within and across code blocks (FR-10)
    - [ ] Scroll behavior is unchanged from pre-change baseline
    - [ ] Code compiles with Swift 6 strict concurrency and passes SwiftLint

- [ ] **T4**: Write unit tests for code block attribute generation `[complexity:medium]`

    **Reference**: [design.md#t4-unit-tests](design.md#t4-unit-tests), [design.md#7-testing-strategy](design.md#7-testing-strategy)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [ ] Test file in `mkdnTests/Unit/` using `@Suite("CodeBlockStyling")` with Swift Testing framework
    - [ ] Test: code block text carries `CodeBlockAttributes.range` attribute with a non-empty string value
    - [ ] Test: code block text carries `CodeBlockAttributes.colors` with correct `background` and `border` NSColor values for both Solarized Dark and Solarized Light themes
    - [ ] Test: code block paragraph style has `headIndent` of 12pt and `tailIndent` of -12pt
    - [ ] Test: code block content does NOT have per-run `.backgroundColor` attribute
    - [ ] Test: Swift code block has syntax highlighting foreground colors (not all the same color)
    - [ ] Test: non-Swift code block uses `codeForeground` color
    - [ ] Test: language label carries same `CodeBlockAttributes.range` value as the code body
    - [ ] All tests pass via `swift test`

### Verification (Parallel Group 3)

- [ ] **T5**: Integration verification and visual compliance `[complexity:simple]`

    **Reference**: [design.md#t5-integration-verification](design.md#t5-integration-verification)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [ ] Application builds and runs successfully with `swift build` and `swift run mkdn`
    - [ ] A document with code blocks renders visible rounded-rectangle containers with background fill, border, and internal padding
    - [ ] Text selection works within and across code blocks
    - [ ] Both Solarized Dark and Solarized Light themes render correctly
    - [ ] `scripts/visual-verification/verify-visual.sh` runs and evaluates code block styling in existing canonical.md and theme-tokens.md fixtures
    - [ ] Entrance animation cover layers still cover the code block container area
    - [ ] SwiftLint (`swiftlint lint`) and SwiftFormat (`swiftformat .`) pass with no violations

### User Docs

- [ ] **TD1**: Update modules.md - Core Layer Markdown module inventory `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Core Layer > Markdown

    **KB Source**: modules.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] `CodeBlockAttributes.swift` added to Core Layer > Markdown table with purpose "Custom NSAttributedString keys and color carrier for code block container rendering"

- [ ] **TD2**: Update modules.md - Features Layer Viewer module inventory `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Features Layer > Viewer

    **KB Source**: modules.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] `CodeBlockBackgroundTextView.swift` added to Features Layer > Viewer table with purpose "NSTextView subclass with custom drawBackground for code block rounded-rect containers"

- [ ] **TD3**: Update architecture.md - code block rendering pipeline `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Rendering Pipeline > Code Blocks

    **KB Source**: architecture.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Code block pipeline description updated to reflect custom background drawing via CodeBlockBackgroundTextView instead of per-run .backgroundColor

## Acceptance Criteria Checklist

- [ ] FR-1: Code blocks render with a visible full-width rounded-rectangle background box
- [ ] FR-2: Code blocks have internal padding (12pt) between box edge and text content on all sides
- [ ] FR-3: Code blocks display a 1pt border around the background box in both themes
- [ ] FR-4: Code blocks have vertical spacing above and below separating them from adjacent content
- [ ] FR-5: Language label appears above code body when a language tag is present
- [ ] FR-6: Swift code blocks display syntax highlighting with token-level coloring
- [ ] FR-7: Non-Swift code blocks render as plain monospaced text in codeForeground color
- [ ] FR-8: Deferred (D5) -- code wraps within container; horizontal scrolling deferred per design decision
- [ ] FR-9: Code block styling consistent across Solarized Dark and Solarized Light themes
- [ ] FR-10: Text within code blocks is selectable, including cross-block selection
- [ ] FR-11: Visual verification workflow evaluates and passes code block styling

## Definition of Done

- [ ] All tasks completed (T1-T5, TD1-TD3)
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] Unit tests pass (`swift test`)
- [ ] Visual verification passes (`scripts/visual-verification/verify-visual.sh`)
- [ ] SwiftLint and SwiftFormat clean
- [ ] Docs updated (modules.md, architecture.md)
- [ ] All changes and `.rp1/` artifacts committed
