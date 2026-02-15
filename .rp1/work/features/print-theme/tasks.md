# Development Tasks: Print-Friendly Theme

**Feature ID**: print-theme
**Status**: In Progress
**Progress**: 37% (3 of 8 tasks)
**Estimated Effort**: 3 days
**Started**: 2026-02-15

## Overview

When the user presses Cmd+P, the print operation intercepts the request, rebuilds the NSAttributedString using a dedicated print color palette (white background, black text, ink-efficient syntax colors), and runs the print dialog on a temporary off-screen text view. The on-screen view is never modified -- no flicker, no theme flash. The print palette is fixed and theme-independent: output looks identical whether the user is in Solarized Dark or Solarized Light.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T2] - T1 is pure color data; T2 is builder API refactor. No shared code changes.
2. [T3, T5] - T3 uses T1 palette + T2 builder API; T5 tests T1 palette + T2 builder API.
3. [T4] - View plumbing that depends on T3's `printBlocks` property existing.

**Dependencies**:

- T3 -> T1 (data: print override references `PrintPalette.colors` / `.syntaxColors`)
- T3 -> T2 (interface: print override calls `MarkdownTextStorageBuilder.build(blocks:colors:syntaxColors:)`)
- T4 -> T3 (interface: `SelectableTextView` sets `textView.printBlocks` which T3 adds)
- T5 -> T1 (data: tests verify `PrintPalette` color values and contrast)
- T5 -> T2 (interface: tests call `build(blocks:colors:syntaxColors:)`)

**Critical Path**: T2 -> T3 -> T4

## Task Breakdown

### Foundation (Parallel Group 1)

- [x] **T1**: Create PrintPalette static color definitions `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/UI/Theme/PrintPalette.swift`
    - **Approach**: Created caseless enum with private static color constants and static `colors`/`syntaxColors` properties, following SolarizedDark/SolarizedLight pattern exactly
    - **Deviations**: None
    - **Tests**: N/A (color definitions only; tested in T5)

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

    **Reference**: [design.md#31-printpalette](design.md#31-printpalette)

    **Effort**: 1.5 hours

    **Acceptance Criteria**:

    - [x] New file `mkdn/UI/Theme/PrintPalette.swift` created as a caseless enum following the `SolarizedDark` / `SolarizedLight` pattern
    - [x] Static `colors: ThemeColors` property populated with all fields: background `#FFFFFF`, foreground `#000000`, headingColor `#000000`, codeBackground `#F5F5F5`, codeForeground `#1A1A1A`, linkColor `#003399`, accent `#003399`, border `#CCCCCC`, backgroundSecondary `#F5F5F5`, foregroundSecondary `#555555`, blockquoteBorder `#999999`, blockquoteBackground `#FAFAFA`
    - [x] Static `syntaxColors: SyntaxColors` property populated with all fields: keyword `#1A6B00`, string `#A31515`, comment `#6A737D`, type `#7B4D00`, number `#6F42C1`, function `#005CC5`, property `#B35900`, preprocessor `#D73A49`
    - [x] All syntax colors meet WCAG AA contrast ratio (>= 4.5:1) against white background
    - [x] PrintPalette color values differ from both SolarizedDark and SolarizedLight
    - [x] File passes SwiftLint and SwiftFormat

- [x] **T2**: Refactor MarkdownTextStorageBuilder to accept explicit colors `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`, `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`, `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift`
    - **Approach**: Added `build(blocks:colors:syntaxColors:)` overload; existing `build(blocks:theme:)` delegates to it. Replaced `theme: AppTheme` parameter with `syntaxColors: SyntaxColors` in `appendBlock`, `appendCodeBlock`, `highlightSwiftCode`, `appendBlockquote`, `appendOrderedList`, `appendUnorderedList`. Updated `BlockBuildContext` to store `syntaxColors` instead of `theme`.
    - **Deviations**: None
    - **Tests**: 40/40 passing (all existing builder and code block styling tests unchanged)

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

    **Reference**: [design.md#32-markdowntextstoragebuilder-refactor](design.md#32-markdowntextstoragebuilder-refactor)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [x] New public overload `build(blocks:colors:syntaxColors:)` accepting `ThemeColors` + `SyntaxColors` directly
    - [x] Existing `build(blocks:theme:)` delegates to the new overload via `build(blocks: blocks, colors: theme.colors, syntaxColors: theme.syntaxColors)`
    - [x] Internal methods refactored to thread `syntaxColors: SyntaxColors` instead of `theme: AppTheme`: `appendBlock`, `appendCodeBlock`, `highlightSwiftCode`, `appendBlockquote`, `appendOrderedList`, `appendUnorderedList`
    - [x] `BlockBuildContext` stores `syntaxColors: SyntaxColors` instead of `theme: AppTheme`
    - [x] Files changed: `MarkdownTextStorageBuilder.swift`, `MarkdownTextStorageBuilder+Blocks.swift`, `MarkdownTextStorageBuilder+Complex.swift`
    - [x] Existing behavior preserved: calling `build(blocks:theme:)` with any `AppTheme` produces identical output to before the refactor
    - [x] All existing tests pass without modification
    - [x] File passes SwiftLint and SwiftFormat

### Print Integration (Parallel Group 2)

- [x] **T3**: Add print interception to CodeBlockBackgroundTextView `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift`
    - **Approach**: Added `printBlocks` property, `draw(_:)` override for offscreen dispatch (HYP-001 caveat), `printView(_:)` override with TextKit 2 clone view and `NSPrintOperation(view:printInfo:)`. Used `printView(_:)` instead of `print(_:)` (correct AppKit NSView override). Used TextKit 2 init pattern instead of TextKit 1 per hypothesis findings.
    - **Deviations**: Three deviations from design.md per hypothesis validation (HYP-001): (1) `printView(_:)` instead of `print(_:)` -- correct overridable NSView method; (2) TextKit 2 init instead of TextKit 1 (D4 revision) -- required for drawCodeBlockContainers to work; (3) `NSPrintOperation(view:printInfo:)` instead of `printView.printOperation(for:)` -- correct AppKit API. Added `draw(_:)` override per caveat 1.
    - **Tests**: 287/287 passing (all existing tests unchanged)

    **Reference**: [design.md#33-codeblockbackgroundtextview-print-override](design.md#33-codeblockbackgroundtextview-print-override)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] `printBlocks: [IndexedBlock]` property added to `CodeBlockBackgroundTextView`, defaulting to empty array
    - [x] `printView(_:)` method overridden to: retrieve `PrintPalette.colors` and `.syntaxColors`, call `MarkdownTextStorageBuilder.build(blocks:colors:syntaxColors:)` with `printBlocks`, create a temporary `CodeBlockBackgroundTextView` via `makePrintTextView`, run `NSPrintOperation` on the temporary view
    - [x] `makePrintTextView(attributedString:size:)` private static method creates a TextKit 2 based text view with: white background from `PrintPalette.colors.background`, 32pt text container inset, width-tracking text container, the print-themed attributed string set on `textStorage`, ensureLayout called before sizeToFit
    - [x] Fallback to `super.printView(sender)` if `printBlocks` is empty
    - [x] On-screen text view is never modified during the print operation (no flicker)
    - [x] File: `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift`
    - [x] File passes SwiftLint and SwiftFormat

- [ ] **T5**: Add unit tests for PrintPalette and builder print integration `[complexity:medium]`

    **Reference**: [design.md#7-testing-strategy](design.md#7-testing-strategy)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [ ] New file `mkdnTests/Unit/Core/PrintPaletteTests.swift` created using Swift Testing (`@Suite`, `@Test`, `#expect`)
    - [ ] Test: print palette background is white (`#FFFFFF`)
    - [ ] Test: print palette foreground is black (`#000000`)
    - [ ] Test: print palette headings are black (`#000000`)
    - [ ] Test: all `ThemeColors` fields are populated (non-nil, non-default)
    - [ ] Test: all `SyntaxColors` fields are populated
    - [ ] Test: print palette differs from `SolarizedDark` (at least `background`, `foreground`, `codeBackground`)
    - [ ] Test: print palette differs from `SolarizedLight`
    - [ ] Test: link color is dark blue (`#003399`)
    - [ ] Test: code background is light gray (`#F5F5F5`)
    - [ ] Test: WCAG AA contrast ratio >= 4.5:1 for each syntax color against white (compute relative luminance per WCAG formula)
    - [ ] Test: comment color lightness > keyword color lightness (visually de-emphasized)
    - [ ] Extended tests in `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTests.swift`: `build(blocks:colors:syntaxColors:)` produces valid non-empty attributed string
    - [ ] Extended test: `build(blocks:theme:)` output matches `build(blocks:colors:syntaxColors:)` with same theme's colors (regression)
    - [ ] Extended test: code block `CodeBlockColorInfo` attribute uses provided palette colors for background and border
    - [ ] All tests pass via `swift test`

### View Wiring (Group 3)

- [ ] **T4**: Wire blocks parameter through SelectableTextView to CodeBlockBackgroundTextView `[complexity:simple]`

    **Reference**: [design.md#34-selectabletextview-plumbing](design.md#34-selectabletextview-plumbing)

    **Effort**: 1.5 hours

    **Acceptance Criteria**:

    - [ ] `SelectableTextView` struct gains a `blocks: [IndexedBlock]` parameter
    - [ ] `makeNSView` sets `textView.printBlocks = blocks`
    - [ ] `updateNSView` sets `textView.printBlocks = blocks` to keep in sync on content changes
    - [ ] `MarkdownPreviewView` passes `renderedBlocks` (or equivalent current blocks) to `SelectableTextView`
    - [ ] Files changed: `mkdn/Features/Viewer/Views/SelectableTextView.swift`, `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`
    - [ ] Existing rendering behavior is unchanged (no visual regression)
    - [ ] File passes SwiftLint and SwiftFormat

### User Docs

- [ ] **TD1**: Create documentation for PrintPalette - UI Layer > Theme `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: add

    **Target**: `.rp1/context/modules.md`

    **Section**: UI Layer > Theme

    **KB Source**: `modules.md`

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] `PrintPalette.swift` added to the Theme table in modules.md with purpose description
    - [ ] Entry follows the existing table format (`| File | Purpose |`)

- [ ] **TD2**: Update patterns.md with print palette access pattern - Theme Access `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: Theme Access

    **KB Source**: `patterns.md`

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Theme Access section documents the print palette access pattern (`PrintPalette.colors`, `PrintPalette.syntaxColors` -- not via `AppTheme`)
    - [ ] Distinction between screen theme access (via `AppState`) and print palette access (direct static) is clear

- [ ] **TD3**: Update architecture.md with print pipeline subsection - Rendering Pipeline `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Rendering Pipeline

    **KB Source**: `architecture.md`

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New Print pipeline subsection documents the print interception flow: Cmd+P -> `CodeBlockBackgroundTextView.print(_:)` -> `PrintPalette` -> `MarkdownTextStorageBuilder.build(blocks:colors:syntaxColors:)` -> temporary view -> `NSPrintOperation`
    - [ ] Section reflects that the on-screen view is never modified

## Acceptance Criteria Checklist

From requirements.md:

- [ ] AC-1.1: Printed document background is white (#FFFFFF or equivalent)
- [ ] AC-1.2: Body text foreground is black (#000000 or near-black)
- [ ] AC-1.3: Heading text is black
- [ ] AC-1.4: The print palette is defined as a complete set of colors covering all ThemeColors fields plus SyntaxColors fields
- [ ] AC-2.1: Printing from Solarized Dark produces the same color palette as printing from Solarized Light
- [ ] AC-2.2: No screen theme colors appear anywhere in the printed output
- [ ] AC-3.1: Code block background is a very light gray (subtle enough to be ink-efficient, visible enough to distinguish from surrounding content)
- [ ] AC-3.2: Code block border is either absent or a thin, light gray line
- [ ] AC-3.3: Code block text uses a monospaced font in black or near-black
- [ ] AC-4.1: Keywords, strings, types, functions, numbers, comments, properties, and preprocessor directives each have a distinct, dark-enough color that is legible on white paper
- [ ] AC-4.2: Comments are visually de-emphasized (e.g., gray) relative to code tokens, consistent with print conventions
- [ ] AC-4.3: All syntax colors pass a minimum contrast ratio against white background for readability
- [ ] AC-5.1: Link text in printed output is dark blue
- [ ] AC-5.2: Link underline styling is preserved in print
- [ ] AC-6.1: The print dialog preview shows the print-friendly palette, not the screen theme
- [ ] AC-6.2: After printing, the on-screen display returns to the active screen theme without any flicker or artifacts
- [ ] AC-6.3: The rebuild uses the same markdown content currently displayed (not stale content)
- [ ] AC-7.1: Code block rounded-rectangle backgrounds in print use the print palette's code block background color
- [ ] AC-7.2: Code block borders in print use the print palette's border color (or are omitted)
- [ ] AC-8.1: Blockquote left border is a medium gray, visible but not heavy
- [ ] AC-8.2: Blockquote background is white or very light gray
- [ ] AC-9.1: Inline code text is monospaced and black
- [ ] AC-9.2: Inline code has subtle visual distinction (e.g., the monospace font itself provides sufficient differentiation)
- [ ] NFR-1: Attributed string rebuild completes within 200ms for a typical document on Apple Silicon
- [ ] NFR-2: No visible flicker or theme flash on screen during print
- [ ] NFR-3: Zero user configuration required
- [ ] NFR-4: Feature is invisible to the user -- Cmd+P just works
- [ ] NFR-5: Print output text colors maintain WCAG AA minimum contrast ratio of 4.5:1

## Definition of Done

- [ ] All tasks completed (T1-T5, TD1-TD3)
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] All existing tests pass (`swift test`)
- [ ] SwiftLint passes (`DEVELOPER_DIR=/Applications/Xcode-16.3.0.app/Contents/Developer swiftlint lint`)
- [ ] SwiftFormat passes (`swiftformat .`)
- [ ] Docs updated (modules.md, patterns.md, architecture.md)
