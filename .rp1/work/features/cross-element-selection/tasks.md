# Development Tasks: Cross-Element Selection

**Feature ID**: cross-element-selection
**Status**: In Progress
**Progress**: 17% (2 of 12 tasks)
**Estimated Effort**: 5 days
**Started**: 2026-02-08

## Overview

Replace the preview pane's rendering layer from independent SwiftUI `Text` views to a single `NSTextView` backed by TextKit 2, enabling native cross-block text selection (click-drag, Shift-click, Cmd+A, Cmd+C). Non-text elements (Mermaid diagrams, images) rendered as overlay views at `NSTextAttachment` placeholder positions. Staggered entrance animation reproduced via per-layout-fragment `CALayer` animations.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1] - Foundation layer, no dependencies on other new components
2. [T2] - Depends on T1 for font/color conversion
3. [T3] - Depends on T2 for attributed string to display
4. [T4, T5] - Both depend on T3 (need text view), independent of each other
5. [T6] - Depends on T3, T4 (needs text view + overlays for functional preview)
6. [T7] - Depends on T1, T2 for unit tests; T6 for integration validation

**Dependencies**:

- T2 -> T1 (Interface: T2 calls PlatformTypeConverter to get NSFont/NSColor for attributes)
- T3 -> T2 (Data: T3 displays the NSAttributedString that T2 produces)
- T4 -> T3 (Interface: T4 reads layout fragment positions from T3's NSTextView)
- T5 -> T3 (Interface: T5 operates on T3's viewport layout controller delegate)
- T6 -> T3 (Build: T6 imports and instantiates SelectableTextView)
- T6 -> T4 (Build: T6 wires OverlayCoordinator for Mermaid rendering)
- T7 -> [T1, T2] (Data: tests verify T1/T2 output correctness)

**Critical Path**: T1 -> T2 -> T3 -> T4 -> T6 -> T7

## Task Breakdown

### Foundation Layer

- [x] **T1**: Create PlatformTypeConverter for SwiftUI-to-AppKit type conversion `[complexity:simple]`

    **Reference**: [design.md#31-platformtypeconverter](design.md#31-platformtypeconverter)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] New file `mkdn/Core/Markdown/PlatformTypeConverter.swift` created as a stateless enum with static methods
    - [x] `nsColor(from:)` converts SwiftUI `Color` to `NSColor` using `NSColor(swiftUIColor)` initializer
    - [x] Font factory methods for all six heading levels (H1-H6) return `NSFont` with correct sizes and weights matching the design table
    - [x] `bodyFont()` returns `NSFont.preferredFont(forTextStyle: .body)`
    - [x] `monospacedFont()` returns `NSFont.monospacedSystemFont` at system font size
    - [x] `captionMonospacedFont()` returns `NSFont.monospacedSystemFont` at small system font size
    - [x] `paragraphStyle(lineSpacing:paragraphSpacing:alignment:)` returns configured `NSParagraphStyle`
    - [x] File passes SwiftLint strict mode and SwiftFormat

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/PlatformTypeConverter.swift`
    - **Approach**: Stateless enum with MARK-delimited sections for color conversion, font factory, and paragraph style. Font sizes and weights match MarkdownBlockView exactly. Uses NSColor(Color) initializer for color conversion and NSMutableParagraphStyle for configurable paragraph styles.
    - **Deviations**: None
    - **Tests**: No dedicated tests for T1 (scheduled in T7); build passes, all existing tests pass

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

### Conversion Layer

- [x] **T2**: Create MarkdownTextStorageBuilder to convert IndexedBlock array to NSAttributedString `[complexity:complex]`

    **Reference**: [design.md#32-markdowntextstoragebuilder](design.md#32-markdowntextstoragebuilder)

    **Effort**: 10 hours

    **Acceptance Criteria**:

    - [x] New file `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` created
    - [x] `AttachmentInfo` struct defined with `blockIndex`, `block`, and `attachment` properties
    - [x] `TextStorageResult` struct defined with `attributedString` and `attachments` properties
    - [x] `MarkdownTextStorageBuilder.build(blocks:theme:)` iterates `[IndexedBlock]` and produces a single `NSAttributedString`
    - [x] Heading blocks use `PlatformTypeConverter` heading fonts with correct color and paragraph spacing
    - [x] Paragraph blocks use body font with foreground color and standard paragraph style
    - [x] Code blocks use monospaced font with code colors and background attribute; language label as separate run above code text
    - [x] Mermaid blocks produce `NSTextAttachment` placeholders with estimated height, recorded in `AttachmentInfo` array
    - [x] Blockquote blocks use indented paragraph style (`headIndent`, `firstLineHeadIndent`)
    - [x] Ordered and unordered list blocks use paragraph indent attributes with number/bullet prefix text runs
    - [x] Thematic break blocks produce `NSTextAttachment` for horizontal rule
    - [x] Table blocks render as selectable text with column alignment
    - [x] Image blocks produce `NSTextAttachment` placeholder recorded in `AttachmentInfo` array
    - [x] HTML blocks use monospaced font with code-style background
    - [x] Inline styles (bold, italic, code, links, strikethrough) from `MarkdownVisitor`'s `AttributedString` are preserved via `NSAttributedString(attributedString)` conversion
    - [x] Blocks separated by `\n` with paragraph spacing attributes (not multiple newlines)
    - [x] File passes SwiftLint strict mode and SwiftFormat

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`, `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`, `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift`
    - **Approach**: Split across three files to stay within SwiftLint file/type body length limits. Main file contains core API (`build`, `convertInlineContent`, `highlightSwiftCode`), paragraph style helpers, and `plainText` fallback. +Blocks extension handles simple block types (heading, paragraph, code, attachment, HTML). +Complex extension handles recursive/composite blocks (blockquote, lists, tables) with `ResolvedColors` and `BlockBuildContext` structs to reduce parameter counts below lint thresholds. Code blocks use `paragraphSpacing: 0` for tight internal lines with `setLastParagraphSpacing` for block separation. Lists use tab stops with `firstLineHeadIndent`/`headIndent` for bullet alignment. Tables use `NSTextTab` for column alignment.
    - **Deviations**: Three files instead of one to comply with SwiftLint file_length (800) and type_body_length (500) limits. Added `ResolvedColors` and `BlockBuildContext` helper structs (not in design) to satisfy function_parameter_count limit (6 warning, 8 error).
    - **Tests**: No dedicated tests for T2 (scheduled in T7); build passes, all existing tests pass

### Rendering Core

- [ ] **T3**: Create SelectableTextView as NSViewRepresentable wrapping NSTextView with TextKit 2 `[complexity:medium]`

    **Reference**: [design.md#33-selectabletextview](design.md#33-selectabletextview)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] New file `mkdn/Features/Viewer/Views/SelectableTextView.swift` created
    - [ ] `SelectableTextView` conforms to `NSViewRepresentable`, accepts `attributedText`, `attachments`, `theme`, `isFullReload`, and `reduceMotion`
    - [ ] `makeNSView` returns `NSScrollView` containing `NSTextView` configured with TextKit 2 (`NSTextLayoutManager`)
    - [ ] NSTextView is non-editable (`isEditable = false`), selectable (`isSelectable = true`), with `drawsBackground = true`
    - [ ] Background color set from theme, `textContainerInset` set to `NSSize(width: 24, height: 24)`
    - [ ] `selectedTextAttributes` themed with accent color at ~30% opacity for background and theme foreground for text
    - [ ] `usesFontPanel`, `usesRuler`, `allowsUndo`, `isAutomaticLinkDetectionEnabled` all disabled
    - [ ] `Coordinator` class implements `NSTextViewportLayoutControllerDelegate` for entrance animation hooks
    - [ ] `updateNSView` applies new attributed text to the text storage, clears selection, and triggers animation or not based on `isFullReload`
    - [ ] Scroll view background matches theme background color
    - [ ] File passes SwiftLint strict mode and SwiftFormat

### Rendering Extensions

- [ ] **T4**: Create OverlayCoordinator for non-text element positioning `[complexity:medium]`

    **Reference**: [design.md#34-overlaycoordinator](design.md#34-overlaycoordinator)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [ ] New file `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` created
    - [ ] `OverlayCoordinator` is `@MainActor`, holds weak reference to `NSTextView` and tracks overlay views by block index
    - [ ] `updateOverlays(attachments:theme:in:)` creates, updates, or removes `NSHostingView` overlays for Mermaid and image blocks
    - [ ] Positioning uses `NSTextLayoutManager.textLayoutFragment(for:)` to find attachment frame in text view coordinates
    - [ ] Overlay width constrained to text container width minus insets
    - [ ] Registers for `NSTextView.didChangeNotification` and `NSScrollView.didLiveScrollNotification` to reposition overlays on scroll/layout changes
    - [ ] `repositionOverlays()` recalculates all overlay positions from current layout fragment geometry
    - [ ] `removeAllOverlays()` cleans up all hosted views
    - [ ] Mermaid `NSHostingView<MermaidBlockView>` overlays receive click events for click-to-focus interaction
    - [ ] Dynamic height updates supported when Mermaid diagram finishes rendering
    - [ ] File passes SwiftLint strict mode and SwiftFormat

- [ ] **T5**: Create EntranceAnimator for per-layout-fragment staggered animation `[complexity:medium]`

    **Reference**: [design.md#35-entranceanimator](design.md#35-entranceanimator)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [ ] New file `mkdn/Features/Viewer/Views/EntranceAnimator.swift` created
    - [ ] `EntranceAnimator` is `@MainActor` with `isAnimating` flag and `animatedFragments` tracking set
    - [ ] `beginEntrance(reduceMotion:)` sets animation state, respecting Reduce Motion preference
    - [ ] `animateFragment(_:at:)` applies `CABasicAnimation` for opacity (0 to 1, 0.5s, ease-out) and transform (8pt upward drift to identity)
    - [ ] Stagger delay calculated as `min(index * 0.03, 0.5)` matching `AnimationConstants.staggerDelay` and `staggerCap`
    - [ ] Each fragment animated only once (tracked via `ObjectIdentifier` in `animatedFragments` set)
    - [ ] When `reduceMotion` is true, opacity set to 1 immediately with no animation
    - [ ] `reset()` clears `animatedFragments` set and resets `isAnimating`
    - [ ] `isAnimating` set to `true` only for full document loads/reloads, `false` for incremental edits
    - [ ] File passes SwiftLint strict mode and SwiftFormat

### Integration

- [ ] **T6**: Refactor MarkdownPreviewView to use SelectableTextView rendering pipeline `[complexity:medium]`

    **Reference**: [design.md#36-updated-markdownpreviewview](design.md#36-updated-markdownpreviewview)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [ ] `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift` modified to replace `ScrollView { VStack { ForEach ... } }` with `SelectableTextView`
    - [ ] `@State` property `blockAppeared` removed (animation handled by `EntranceAnimator`)
    - [ ] `MarkdownTextStorageBuilder.build(blocks:theme:)` called to produce `NSAttributedString` and `AttachmentInfo` from `renderedBlocks`
    - [ ] `.task(id:)` debounce pattern preserved exactly as current implementation
    - [ ] `.onChange(of: theme)` re-render pattern preserved
    - [ ] `isFullReload` flag correctly wired: `true` for document load/reload, `false` for incremental edits in side-by-side mode
    - [ ] Selection clears on file load, reload, and mode switch (handled by `updateNSView` content change)
    - [ ] `MarkdownBlockView` dispatch code retained but no longer called from preview mode
    - [ ] Mermaid diagrams render correctly at placeholder positions via `OverlayCoordinator`
    - [ ] Theme switching triggers full re-render with updated colors, fonts, selection highlight, and background
    - [ ] File passes SwiftLint strict mode and SwiftFormat

### Tests

- [ ] **T7**: Create unit and integration tests for new components `[complexity:medium]`

    **Reference**: [design.md#t7-tests](design.md#t7-tests)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] New file `mkdnTests/Unit/Core/PlatformTypeConverterTests.swift` created using Swift Testing (`@Test`, `#expect`, `@Suite`)
    - [ ] Tests verify each heading level font produces correct size and weight
    - [ ] Tests verify body font matches system body text style
    - [ ] Tests verify monospaced font produces monospaced design
    - [ ] Tests verify color conversion from ThemeColors round-trips correctly
    - [ ] Tests verify paragraph style spacing and alignment are set correctly
    - [ ] New file `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTests.swift` created using Swift Testing
    - [ ] Tests verify heading block produces correct font, heading color, and paragraph spacing attributes
    - [ ] Tests verify paragraph block produces correct body font and foreground color
    - [ ] Tests verify code block produces monospaced font, code colors, and background attribute
    - [ ] Tests verify Mermaid block produces `NSTextAttachment` in attributed string
    - [ ] Tests verify list blocks have correct indentation and bullet/number prefix
    - [ ] Tests verify blockquote has correct indentation and visual styling
    - [ ] Tests verify block separation uses single `\n` with paragraph spacing (not double newlines)
    - [ ] Tests verify inline styles (bold, italic, code, link, strikethrough) preserved in NSAttributedString
    - [ ] Integration test: build attributed string from multi-block document and verify `.string` plain text extraction produces correct content with clean line breaks
    - [ ] All tests pass with `swift test`

### User Docs

- [ ] **TD1**: Update architecture.md - Rendering Pipeline `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Rendering Pipeline > Markdown

    **KB Source**: architecture.md:#rendering-pipeline

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Rendering Pipeline section updated to show MarkdownTextStorageBuilder -> NSTextView step in the pipeline diagram
    - [ ] Pipeline description reflects that preview rendering now uses NSTextView with TextKit 2 instead of SwiftUI Text views

- [ ] **TD2**: Update modules.md - Features Layer Viewer section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Features Layer > Viewer

    **KB Source**: modules.md:#viewer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Viewer section lists new files: SelectableTextView.swift, OverlayCoordinator.swift, EntranceAnimator.swift
    - [ ] File descriptions and responsibilities documented

- [ ] **TD3**: Update modules.md - Core Layer Markdown section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Core Layer > Markdown

    **KB Source**: modules.md:#markdown

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Markdown section lists new files: PlatformTypeConverter.swift, MarkdownTextStorageBuilder.swift
    - [ ] File descriptions and responsibilities documented

- [ ] **TD4**: Update patterns.md - Anti-Patterns clarification `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: Anti-Patterns

    **KB Source**: patterns.md:#anti-patterns

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Anti-Patterns section clarifies WKWebView exception: WKWebView for Mermaid only, NSTextView for preview is the new standard pattern

- [ ] **TD5**: Create patterns.md - NSViewRepresentable Pattern section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: add

    **Target**: `.rp1/context/patterns.md`

    **Section**: NSViewRepresentable Pattern

    **KB Source**: -

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New section documenting SelectableTextView as the canonical NSViewRepresentable + TextKit 2 pattern
    - [ ] Pattern includes key configuration decisions, coordinator usage, and update lifecycle

## Acceptance Criteria Checklist

### FR-001: Multi-Block Text Selection
- [ ] User can click-drag across multiple distinct rendered Markdown blocks to create continuous selection
- [ ] Selection spans heading, paragraph, and code block in sequence when dragged across all three
- [ ] Cmd+C copies selected text spanning multiple blocks as plain text

### FR-002: Standard macOS Selection Behaviors
- [ ] Shift-click extends or contracts existing selection to new position
- [ ] Cmd+A selects all text content in the preview
- [ ] Single click without drag clears selection

### FR-003: Plain Text Copy
- [ ] Copied text from heading + paragraph pastes as plain text with appropriate line breaks
- [ ] Selection spanning non-text element (Mermaid diagram) includes text above and below but not the diagram

### FR-004: Non-Text Element Overlay
- [ ] Mermaid diagram appears at correct vertical position between surrounding text blocks
- [ ] Mermaid click-to-focus interaction works on overlaid diagrams
- [ ] Diagram overlays remain correctly aligned during scrolling

### FR-005: Visual Parity with Current Rendering
- [ ] Fonts, sizes, weights, line spacing, paragraph spacing, text colors, background colors visually equivalent to current SwiftUI rendering
- [ ] No block type exhibits visible layout differences in spacing, alignment, or indentation

### FR-006: Selection Highlight Theming
- [ ] Selection highlight uses color consistent with active theme's Solarized palette
- [ ] Selection highlight color updates when theme is switched

### FR-007: Staggered Entrance Animation
- [ ] Each block fades in with upward drift, staggered by block index on document load
- [ ] New animation is at least as polished as current SwiftUI implementation
- [ ] Reduce Motion preference suppresses motion (fade only or instant)
- [ ] No dropped frames on 1000-line document entrance animation

### FR-008: State Lifecycle Management
- [ ] Selection clears when new file is opened
- [ ] Selection clears on file reload via outdated indicator
- [ ] Selection clears when switching between preview-only and side-by-side mode

### FR-009: Theme Change Re-rendering
- [ ] Theme switch updates all text colors, background colors, code block styling, blockquote styling, and selection highlight color

### FR-010: Content Update on Document Change
- [ ] Side-by-side mode preview updates after debounce interval when user types in editor pane

## Definition of Done

- [ ] All tasks completed
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] Docs updated
