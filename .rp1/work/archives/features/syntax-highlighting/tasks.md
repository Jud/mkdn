# Development Tasks: Syntax Highlighting for Code Blocks

**Feature ID**: syntax-highlighting
**Status**: In Progress
**Progress**: 60% (3 of 5 tasks)
**Estimated Effort**: 1 day
**Started**: 2026-02-06

## Overview

Targeted refactor of the existing syntax highlighting implementation. Rename `SolarizedOutputFormat` to `ThemeOutputFormat`, extract it to its own file for separation of concerns, update `CodeBlockView` to reference the new type, and add the unit tests that are currently missing. No new dependencies, no logic changes, no data model changes.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1] - defines ThemeOutputFormat; no dependencies
2. [T2, T3] - both consume T1 but are independent of each other

**Dependencies**:

- T2 -> T1 (interface: CodeBlockView references ThemeOutputFormat which T1 defines)
- T3 -> T1 (interface: tests import ThemeOutputFormat which T1 defines)

**Critical Path**: T1 -> T2

## Task Breakdown

### Foundation

- [x] **T1**: Extract `SolarizedOutputFormat` from `CodeBlockView.swift` into new file `mkdn/Core/Markdown/ThemeOutputFormat.swift`, renaming to `ThemeOutputFormat` with explicit `Sendable` conformance `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/ThemeOutputFormat.swift`
    - **Approach**: Extracted struct and nested Builder from CodeBlockView.swift, renamed to ThemeOutputFormat, added Sendable conformance. Used `@preconcurrency import Splash` to handle Splash's TokenType not conforming to Sendable.
    - **Deviations**: Added `@preconcurrency import Splash` (not in design) to satisfy Swift 6 strict concurrency since Splash's TokenType lacks Sendable conformance.
    - **Tests**: N/A (tested via T3)

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

    **Reference**: [design.md#31-themeoutputformat-new-file](design.md#31-themeoutputformat-new-file)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] File `mkdn/Core/Markdown/ThemeOutputFormat.swift` exists
    - [x] `ThemeOutputFormat` struct conforms to `OutputFormat` and `Sendable`
    - [x] `ThemeOutputFormat.Builder` nested struct conforms to `OutputBuilder` and `Sendable`
    - [x] Initializer accepts `plainTextColor: SwiftUI.Color` and `tokenColorMap: [TokenType: SwiftUI.Color]`
    - [x] Builder implements `addToken(_:ofType:)`, `addPlainText(_:)`, `addWhitespace(_:)`, `build()`
    - [x] No type, file, or symbol in the codebase contains "SolarizedOutputFormat" (FR-001 AC-1)
    - [x] Project compiles with `swift build`

### Consumers

- [x] **T2**: Update `CodeBlockView.swift` to remove inline `SolarizedOutputFormat` definition and reference `ThemeOutputFormat` from the extracted file `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/CodeBlockView.swift`
    - **Approach**: Removed SolarizedOutputFormat struct + Builder (lines 80-117), changed single reference from SolarizedOutputFormat to ThemeOutputFormat in highlightedCode property.
    - **Deviations**: None
    - **Tests**: N/A (visual verification; no logic changes)

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

    **Reference**: [design.md#32-codeblockview-modified](design.md#32-codeblockview-modified)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] `SolarizedOutputFormat` struct and `Builder` nested struct removed from `CodeBlockView.swift`
    - [x] `highlightedCode` computed property uses `ThemeOutputFormat(` instead of `SolarizedOutputFormat(`
    - [x] No other logic changes in `CodeBlockView.swift`
    - [x] Project compiles with `swift build`
    - [ ] Swift code blocks still render with syntax highlighting (visual verification)

- [x] **T3**: Add unit tests for `ThemeOutputFormat` in `mkdnTests/Unit/Core/ThemeOutputFormatTests.swift` covering token coloring, fallback, plain text, whitespace, build output, and theme reactivity `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdnTests/Unit/Core/ThemeOutputFormatTests.swift`
    - **Approach**: 6 focused tests using Swift Testing. Uses explicit SwiftUI.Color and TokenType qualifications to resolve macOS AppKit/SwiftUI ambiguity. Tests verify builder color mapping, fallback, plain text, whitespace preservation, content accumulation, and theme-reactive color differentiation.
    - **Deviations**: None
    - **Tests**: 6/6 passing (54/54 total suite)

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

    **Reference**: [design.md#33-no-data-model-changes](design.md#33-no-data-model-changes), [design.md#7-testing-strategy](design.md#7-testing-strategy)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] File `mkdnTests/Unit/Core/ThemeOutputFormatTests.swift` exists
    - [x] Uses Swift Testing (`@Suite`, `@Test`, `#expect`) with `@testable import mkdnLib`
    - [x] Test: `addToken` applies correct color from `tokenColorMap` for a mapped `TokenType`
    - [x] Test: `addToken` with unmapped `TokenType` falls back to `plainTextColor`
    - [x] Test: `addPlainText` applies `plainTextColor`
    - [x] Test: `addWhitespace` preserves content without explicit foreground color
    - [x] Test: `build()` returns non-empty `AttributedString` after adding content
    - [x] Test: different color maps produce different `AttributedString` output
    - [x] All tests pass with `swift test`

### User Docs

- [ ] **TD1**: Update modules.md - Core Layer Markdown section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Core Layer - Markdown

    **KB Source**: modules.md:Core/Markdown

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] `ThemeOutputFormat.swift` appears in the `Core/Markdown/` file inventory table with purpose description

- [ ] **TD2**: Update architecture.md - Code Blocks pipeline section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Code Blocks pipeline

    **KB Source**: architecture.md:Code Blocks

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Architecture documentation mentions `ThemeOutputFormat` by name in the code blocks rendering pipeline description

## Acceptance Criteria Checklist

### FR-001: Theme-Agnostic Output Format Naming
- [ ] AC-1: No type, file, or symbol in the codebase contains "SolarizedOutputFormat"
- [ ] AC-2: `ThemeOutputFormat` exists and is the sole syntax highlighting output format type

### FR-002: Generic Token-to-Color Mapping
- [ ] AC-1: `ThemeOutputFormat` initializer accepts a token-to-color map and a plain text color parameter
- [ ] AC-2: Passing different color maps produces correspondingly different `AttributedString` output

### FR-003: Swift Code Block Tokenized Highlighting
- [ ] AC-1: A fenced code block tagged `swift` renders with at least 3 visually distinct colors (manual verification)
- [ ] AC-2: The rendered output uses the active theme's `SyntaxColors` values

### FR-004: Non-Swift Code Block Fallback
- [ ] AC-1: A code block tagged `python` renders entirely in `codeForeground` color with monospaced font (manual verification)
- [ ] AC-2: A code block with no language tag renders entirely in `codeForeground` color with monospaced font (manual verification)
- [ ] AC-3: No tokenization or color differentiation is attempted for non-Swift blocks

### FR-005: Language Label Display
- [ ] AC-1: A fenced code block with language tag "swift" displays "swift" as a label above the code content (manual verification)
- [ ] AC-2: A fenced code block with no language tag displays no language label (manual verification)

### FR-006: Horizontal Scrollability for Long Lines
- [ ] AC-1: A code block with a line wider than the viewport displays a horizontal scroll indicator (manual verification)
- [ ] AC-2: The user can scroll horizontally to reveal the full line content (manual verification)
- [ ] AC-3: Lines are not wrapped (manual verification)

### FR-007: Theme-Reactive Re-Highlighting
- [ ] AC-1: After switching themes, all code block colors reflect the new theme's `SyntaxColors` (manual verification)
- [ ] AC-2: No manual refresh, scroll, or re-open is required to see updated colors (manual verification)

### FR-008: Complete Token Type Coverage in Builder
- [ ] AC-1: Each of the 9 Splash `TokenType` cases has an explicit mapping to a `SyntaxColors` field
- [ ] AC-2: Both Solarized Dark and Solarized Light themes provide distinct, non-identical `SyntaxColors` values

### NFR-006: No Solarized-Specific Naming
- [ ] No Solarized-specific naming in any highlighting code path

### NFR-007: Sendable Compliance
- [ ] `ThemeOutputFormat` and `ThemeOutputFormat.Builder` are `Sendable`-compatible

### NFR-008: SwiftLint
- [ ] All code passes `swiftlint lint` in strict mode

## Definition of Done

- [ ] All tasks completed
- [ ] All AC verified
- [ ] Code reviewed
- [ ] Docs updated
