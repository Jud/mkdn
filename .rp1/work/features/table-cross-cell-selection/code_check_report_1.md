# Code Check Report #1 -- table-cross-cell-selection

**Date**: 2026-02-23
**Branch**: main
**Build System**: Swift Package Manager (Swift 6.0)
**Coverage Target**: 80%

---

## Executive Summary

| Check        | Status | Detail                          |
|-------------|--------|---------------------------------|
| Linting     | FAIL   | 10 errors, 0 warnings          |
| Formatting  | FAIL   | 1 file needs formatting         |
| Tests       | FAIL   | 511/512 passed (99.8%)          |
| Coverage    | FAIL   | 21.2% source lines (target 80%) |

**Overall**: FAIL

---

## Linting Results

**Tool**: SwiftLint (strict mode, all opt-in rules)
**Command**: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftlint lint`

**10 errors, 0 warnings**

| # | File | Rule | Detail |
|---|------|------|--------|
| 1 | `Core/TestHarness/TestHarnessHandler.swift:12` | cyclomatic_complexity | Function complexity 19 (limit 15) |
| 2 | `Core/TestHarness/TestHarnessHandler.swift:622` | file_length | 622 lines (limit 500) |
| 3 | `Core/TestHarness/TestHarnessHandler.swift:5` | type_body_length | Enum body 545 lines (limit 500) |
| 4 | `App/DirectoryModeKey.swift:1` | file_name | File name does not match declared type |
| 5 | `Features/Viewer/Views/MarkdownPreviewView.swift:69` | trailing_closure | Trailing closure syntax should be used |
| 6 | `Features/Viewer/Views/CodeBlockBackgroundTextView.swift:22` | type_body_length | Class body 378 lines (limit 350) |
| 7 | `Features/Viewer/Views/SelectableTextView.swift:599` | file_length | 599 lines (limit 500) |
| 8 | `mkdnTests/Unit/Core/MarkdownVisitorTests.swift:6` | type_body_length | Struct body 364 lines (limit 350) |
| 9 | `mkdnTests/Support/JSONResultReporter.swift:67` | trailing_closure | Trailing closure syntax should be used |
| 10 | `mkdnTests/Support/JSONResultReporter.swift:68` | trailing_closure | Trailing closure syntax should be used |

---

## Formatting Results

**Tool**: SwiftFormat 6.0
**Command**: `swiftformat --lint .`

**1 of 159 files needs formatting** (15 files skipped via exclusions)

| File | Issue |
|------|-------|
| `mkdn/App/ContentView.swift:14` | `wrapPropertyBodies`: Wrap single-line property bodies onto multiple lines |
| `mkdn/App/ContentView.swift:15` | `wrapPropertyBodies`: Wrap single-line property bodies onto multiple lines |

---

## Test Results

**Framework**: Swift Testing (`@Test`, `@Suite`)
**Command**: `swift test`
**Result**: 512 tests in 49 suites -- 511 passed, 1 failed (99.8% pass rate)

### Failed Tests

| Test | Suite | File | Issue |
|------|-------|------|-------|
| cycleTheme cycles through auto, dark, light | AppSettings | `AppSettingsTests.swift:114-120` | Theme cycle order mismatch: expected auto->solarizedDark->solarizedLight->auto, got auto->solarizedLight->auto->solarizedLight |

**Failure detail**: The `cycleTheme()` method cycles through theme modes in a different order than the test expects. The test expects `auto -> solarizedDark -> solarizedLight -> auto`, but the actual cycle is `auto -> solarizedLight -> auto -> solarizedLight`. This indicates either the `cycleTheme` implementation was changed or the test was not updated to match the current cycle order.

---

## Coverage Analysis

**Tool**: `llvm-cov` (via `swift test --enable-code-coverage`)
**Source-only line coverage**: 21.2% (2,291 / 10,797 lines)
**Target**: 80%

### Module Breakdown (source files only)

#### Well-covered modules (>= 80%)

| Module | Coverage | Lines |
|--------|----------|-------|
| App/AppSettings.swift | 97.9% | 46/47 |
| App/FileOpenCoordinator.swift | 100.0% | 11/11 |
| App/LaunchItem.swift | 100.0% | 6/6 |
| Core/CLI/CLIError.swift | 95.7% | 22/23 |
| Core/CLI/DirectoryValidator.swift | 82.6% | 19/23 |
| Core/CLI/FileValidator.swift | 91.3% | 42/46 |
| Core/DirectoryScanner/DirectoryScanner.swift | 97.1% | 99/102 |
| Core/DirectoryScanner/FileTreeNode.swift | 100.0% | 9/9 |
| Core/FileWatcher/FileWatcher.swift | 92.8% | 90/97 |
| Core/Highlighting/SyntaxHighlightEngine.swift | 94.1% | 48/51 |
| Core/Highlighting/TokenType.swift | 100.0% | 23/23 |
| Core/Highlighting/TreeSitterLanguageMap.swift | 100.0% | 77/77 |
| Core/Markdown/CodeBlockAttributes.swift | 100.0% | 4/4 |
| Core/Markdown/LinkNavigationHandler.swift | 97.1% | 34/35 |
| Core/Markdown/MarkdownRenderer.swift | 100.0% | 13/13 |
| Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift | 100.0% | 192/192 |
| Core/Markdown/MarkdownTextStorageBuilder+TableInline.swift | 98.1% | 211/215 |
| Core/Markdown/MarkdownVisitor.swift | 93.4% | 185/198 |
| Core/Markdown/PlatformTypeConverter.swift | 100.0% | 32/32 |
| Core/Markdown/TableAttributes.swift | 100.0% | 8/8 |
| Core/Markdown/TableCellMap.swift | 96.1% | 172/179 |
| Core/Markdown/TableColumnSizer.swift | 94.6% | 123/130 |
| Core/Mermaid/MermaidThemeMapper.swift | 95.2% | 20/21 |
| Core/TestHarness/HarnessCommand.swift | 100.0% | 12/12 |
| Core/TestHarness/HarnessError.swift | 81.2% | 13/16 |
| Core/TestHarness/HarnessResponse.swift | 100.0% | 57/57 |
| Features/Viewer/ViewModels/FindState.swift | 100.0% | 59/59 |
| UI/Components/OrbState.swift | 100.0% | 11/11 |
| UI/Theme/AppTheme.swift | 100.0% | 16/16 |
| UI/Theme/MotionPreference.swift | 100.0% | 37/37 |
| UI/Theme/ThemeMode.swift | 100.0% | 17/17 |

#### Feature-relevant coverage (table-cross-cell-selection)

| Module | Coverage | Lines |
|--------|----------|-------|
| Core/Markdown/TableAttributes.swift | 100.0% | 8/8 |
| Core/Markdown/TableCellMap.swift | 96.1% | 172/179 |
| Core/Markdown/TableColumnSizer.swift | 94.6% | 123/130 |
| Core/Markdown/MarkdownTextStorageBuilder+TableInline.swift | 98.1% | 211/215 |
| Core/Markdown/MarkdownTextStorageBuilder.swift | 79.1% | 235/297 |
| Features/Viewer/Views/OverlayCoordinator+TableOverlays.swift | 0.0% | 0/303 |
| Features/Viewer/Views/OverlayCoordinator.swift | 0.0% | 0/315 |
| Features/Viewer/Views/OverlayCoordinator+Observation.swift | 0.0% | 0/97 |
| Features/Viewer/Views/TableBlockView.swift | 0.0% | 0/214 |
| Features/Viewer/Views/TableHeaderView.swift | 0.0% | 0/68 |
| Features/Viewer/Views/TableHighlightOverlay.swift | 0.0% | 0/71 |
| Features/Viewer/Views/SelectableTextView.swift | 0.0% | 0/508 |
| Features/Viewer/Views/CodeBlockBackgroundTextView+TableCopy.swift | 0.0% | 0/238 |
| Features/Viewer/Views/CodeBlockBackgroundTextView+TablePrint.swift | 0.0% | 0/223 |

**Note**: The table-cross-cell-selection feature has strong unit test coverage on the model/data layer (T1: TableAttributes, TableCellMap at 96-100%; T2: TableInline at 98%). The view layer (T3: OverlayCoordinator, TableBlockView, etc.) has 0% coverage, which is expected for SwiftUI views and AppKit NSView subclasses that require a running app or visual testing.

#### Zero-coverage files (0.0%, non-view significant files)

| Module | Lines |
|--------|-------|
| App/MkdnCommands.swift | 508 |
| Core/TestHarness/TestHarnessHandler.swift | 596 |
| Core/TestHarness/TestHarnessServer.swift | 213 |
| Core/TestHarness/FrameCaptureSession.swift | 255 |
| Core/TestHarness/RenderCompletionSignal.swift | 141 |
| Core/TestHarness/CaptureService.swift | 131 |

---

## Recommendations

1. **Fix the failing test** (`cycleThemeModes`): The `cycleTheme()` implementation and test are out of sync. Update the test to match the current cycle order, or fix the implementation if the cycle order is intentional.

2. **Fix SwiftFormat violations**: Run `swiftformat .` to auto-fix the `ContentView.swift` property body wrapping.

3. **Address lint errors** (by priority):
   - `DirectoryModeKey.swift` file_name violation -- rename file or add matching type declaration.
   - `MarkdownPreviewView.swift:69` trailing_closure -- use trailing closure syntax.
   - `JSONResultReporter.swift:67-68` trailing_closure (x2) -- use trailing closure syntax.
   - `TestHarnessHandler.swift` -- refactor to reduce complexity/length (cyclomatic_complexity 19, file_length 622, type_body_length 545). Consider splitting the handler enum into separate files per command group.
   - `CodeBlockBackgroundTextView.swift` type_body_length 378 -- consider extracting helper methods.
   - `SelectableTextView.swift` file_length 599 -- consider splitting into extensions.
   - `MarkdownVisitorTests.swift` type_body_length 364 -- consider splitting into sub-suites.

4. **Coverage gap on the feature**: The table-cross-cell-selection data layer (T1/T2) has excellent coverage (96-100%). The view layer (T3: OverlayCoordinator) is at 0%, which is typical for NSView/SwiftUI code. Consider using `mkdn-ctl` visual testing to verify T3 behavior (load table fixture, capture screenshots, verify overlay rendering).

---

## Overall Assessment

**FAIL** -- 3 of 4 checks did not pass.

| Check | Verdict | Notes |
|-------|---------|-------|
| Linting | FAIL | 10 errors (3 structural, 3 trailing_closure, 1 file_name, 3 in TestHarnessHandler) |
| Formatting | FAIL | 1 file (2 property body wrapping violations) |
| Tests | FAIL | 1 test failure (cycleTheme order mismatch), 511/512 passed |
| Coverage | FAIL | 21.2% source coverage vs 80% target |

The test failure is a single assertion mismatch in `cycleThemeModes` (not related to the table-cross-cell-selection feature). The feature-specific code (TableAttributes, TableCellMap, TableInline) has strong unit test coverage. The overall source coverage is low due to zero coverage on all UI views, commands, and test harness infrastructure -- these are expected gaps for a SwiftUI/AppKit application where views are tested visually rather than via unit tests.
