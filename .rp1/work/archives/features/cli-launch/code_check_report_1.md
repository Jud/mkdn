# Code Check Report #1 -- Feature: cli-launch

**Date**: 2026-02-06
**Branch**: main
**Build System**: Swift Package Manager (Swift 6.1)
**Coverage Target**: 80%

---

## Executive Summary

| Check        | Status | Detail                          |
|-------------|--------|---------------------------------|
| Linting     | SKIP   | SwiftLint not installed          |
| Formatting  | PASS   | 0/46 files need formatting       |
| Tests       | PASS   | 96/96 passed (100%)             |
| Coverage    | FAIL   | 23.16% line coverage (target 80%) |
| **Overall** | **FAIL** | Coverage below target          |

---

## Linting Results

**Status**: SKIPPED

SwiftLint is declared as a project requirement (`.swiftlint.yml` exists, `CLAUDE.md` mandates strict mode) but is not installed on this machine. This check could not be executed.

**Action Required**: Install SwiftLint (`brew install swiftlint`) and re-run.

---

## Formatting Results

**Status**: PASS

```
SwiftFormat completed in 0.01s.
0/46 files require formatting, 1 file skipped.
```

All 46 source files conform to the project's SwiftFormat configuration. No changes needed.

---

## Test Results

**Status**: PASS

| Metric         | Value |
|---------------|-------|
| Total Tests    | 96    |
| Passed         | 96    |
| Failed         | 0     |
| Pass Rate      | 100%  |
| Duration       | 0.008s |

### Test Suites (11 suites, all passing)

| Suite              | Tests | Status |
|-------------------|-------|--------|
| AppState           | 3     | PASS   |
| AppTheme           | 4     | PASS   |
| CLIError           | 7     | PASS   |
| EditorViewModel    | 4     | PASS   |
| FileValidator      | 10    | PASS   |
| FileWatcher        | 2     | PASS   |
| MarkdownRenderer   | 8     | PASS   |
| MarkdownVisitor    | 27    | PASS   |
| MermaidCache       | 10    | PASS   |
| MermaidRenderer    | 11    | PASS   |
| ThemeOutputFormat  | 10    | PASS   |

---

## Coverage Analysis

**Status**: FAIL -- 23.16% line coverage (target: 80%)

### Per-Module Breakdown

| File | Line Cover | Lines | Missed |
|------|-----------|-------|--------|
| App/AppState.swift | 100.00% | 20 | 0 |
| App/ContentView.swift | 0.00% | 109 | 109 |
| App/MkdnCommands.swift | 0.00% | 66 | 66 |
| Core/CLI/CLIError.swift | 100.00% | 19 | 0 |
| Core/CLI/FileValidator.swift | 91.30% | 46 | 4 |
| Core/CLI/MkdnCLI.swift | 0.00% | 1 | 1 |
| Core/FileWatcher/FileWatcher.swift | 16.13% | 62 | 52 |
| Core/Markdown/MarkdownBlock.swift | 68.29% | 41 | 13 |
| Core/Markdown/MarkdownRenderer.swift | 100.00% | 11 | 0 |
| Core/Markdown/MarkdownVisitor.swift | 93.05% | 187 | 13 |
| Core/Markdown/ThemeOutputFormat.swift | 100.00% | 21 | 0 |
| Core/Mermaid/MermaidCache.swift | 100.00% | 51 | 0 |
| Core/Mermaid/MermaidRenderer.swift | 35.40% | 113 | 73 |
| Features/Editor/ViewModels/EditorViewModel.swift | 100.00% | 17 | 0 |
| Features/Editor/Views/MarkdownEditorView.swift | 0.00% | 8 | 8 |
| Features/Editor/Views/SplitEditorView.swift | 0.00% | 22 | 22 |
| Features/Theming/ThemePickerView.swift | 0.00% | 18 | 18 |
| Features/Viewer/ViewModels/PreviewViewModel.swift | 0.00% | 6 | 6 |
| Features/Viewer/Views/CodeBlockView.swift | 0.00% | 78 | 78 |
| Features/Viewer/Views/ImageBlockView.swift | 0.00% | 180 | 180 |
| Features/Viewer/Views/MarkdownBlockView.swift | 0.00% | 247 | 247 |
| Features/Viewer/Views/MarkdownPreviewView.swift | 0.00% | 32 | 32 |
| Features/Viewer/Views/MermaidBlockView.swift | 0.00% | 188 | 188 |
| Features/Viewer/Views/TableBlockView.swift | 0.00% | 222 | 222 |
| UI/Components/OutdatedIndicator.swift | 0.00% | 45 | 45 |
| UI/Components/ViewModePicker.swift | 0.00% | 19 | 19 |
| UI/Components/WelcomeView.swift | 0.00% | 94 | 94 |
| UI/Theme/AppTheme.swift | 100.00% | 16 | 0 |
| **TOTAL** | **23.16%** | **1939** | **1490** |

### Coverage by Layer

| Layer | Covered Lines | Total Lines | Coverage |
|-------|--------------|-------------|----------|
| Core (CLI, Markdown, Mermaid, FileWatcher) | 298 | 551 | 54.08% |
| App (AppState, ContentView, Commands) | 20 | 195 | 10.26% |
| Features (Editor, Viewer, Theming) | 17 | 536 | 3.17% |
| UI (Components, Theme) | 16 | 174 | 9.20% |

### Well-Covered Files (>= 80%)

- `Core/CLI/CLIError.swift` -- 100%
- `Core/CLI/FileValidator.swift` -- 91.30%
- `Core/Markdown/MarkdownRenderer.swift` -- 100%
- `Core/Markdown/MarkdownVisitor.swift` -- 93.05%
- `Core/Markdown/ThemeOutputFormat.swift` -- 100%
- `Core/Mermaid/MermaidCache.swift` -- 100%
- `App/AppState.swift` -- 100%
- `Features/Editor/ViewModels/EditorViewModel.swift` -- 100%
- `UI/Theme/AppTheme.swift` -- 100%

### Zero-Coverage Files (16 files)

All SwiftUI View files (`*View.swift`), `MkdnCommands.swift`, and `MkdnCLI.swift` have 0% coverage. This is expected for View layer code that requires UI testing, but `MkdnCLI.swift` may be testable at the unit level.

---

## Recommendations

1. **Install SwiftLint**: The project mandates SwiftLint strict mode but it is not installed. Run `brew install swiftlint` and verify with `swiftlint lint`.

2. **Coverage Gap**: The 23.16% overall coverage is well below the 80% target. However, the breakdown is informative:
   - **Core logic is well-tested** (54% overall, with most files at 90-100%).
   - **View code is untested** (0% across all SwiftUI views). This is typical for SwiftUI projects without UI test infrastructure.
   - **Actionable gaps**:
     - `Core/FileWatcher/FileWatcher.swift` (16.13%) -- DispatchSource code is hard to unit test per project memory notes, but integration tests could improve this.
     - `Core/Mermaid/MermaidRenderer.swift` (35.40%) -- JSCore rendering pipeline has testable logic.
     - `Core/Markdown/MarkdownBlock.swift` (68.29%) -- Some enum cases/helpers appear untested.
     - `Features/Viewer/ViewModels/PreviewViewModel.swift` (0%) -- ViewModel code should be unit-testable.

3. **Consider Separate Coverage Target**: Excluding SwiftUI View files, the testable code coverage would be significantly higher. Consider setting a per-layer target (e.g., Core >= 80%, ViewModels >= 80%) rather than a blanket overall target.

---

## Overall Assessment

**FAIL** -- The code check fails due to coverage falling below the 80% target (23.16% actual). Formatting is clean (PASS). All 96 tests pass (PASS). Linting could not be verified (SwiftLint not installed). The low overall coverage is driven primarily by untested SwiftUI View code; core business logic coverage is strong at ~54% with key modules at 90-100%.
