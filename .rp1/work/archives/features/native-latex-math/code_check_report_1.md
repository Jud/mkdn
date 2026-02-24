# Code Check Report #1 -- native-latex-math

**Date**: 2026-02-24
**Branch**: main
**Build System**: Swift Package Manager (Swift 6.0)
**Coverage Target**: 80%

---

## Executive Summary

| Check | Status | Details |
|-------|--------|---------|
| Linting (SwiftLint) | FAIL | 11 errors, 0 warnings |
| Formatting (SwiftFormat) | FAIL | 1 file needs formatting |
| Tests (Swift Testing) | FAIL | 548/549 passed (99.8%) |
| Coverage | N/A | No coverage tool configured |

**Overall Status**: FAIL

---

## Linting Results

**Tool**: SwiftLint (strict mode, all opt-in rules)
**DEVELOPER_DIR**: `/Applications/Xcode.app/Contents/Developer`
**Result**: 11 violations (all errors), 166 files scanned

### Violations by Rule

| Rule | Count | Severity |
|------|-------|----------|
| `type_body_length` | 3 | Error |
| `file_length` | 3 | Error |
| `trailing_closure` | 3 | Error |
| `cyclomatic_complexity` | 1 | Error |
| `file_name` | 1 | Error |

### Violation Details

| File | Line | Rule | Description |
|------|------|------|-------------|
| `mkdn/Core/TestHarness/TestHarnessHandler.swift` | 12 | `cyclomatic_complexity` | Function complexity 19 (limit: 15) |
| `mkdn/Core/TestHarness/TestHarnessHandler.swift` | 622 | `file_length` | 622 lines (limit: 500) |
| `mkdn/Core/TestHarness/TestHarnessHandler.swift` | 5 | `type_body_length` | Enum body 545 lines (limit: 500) |
| `mkdn/App/DirectoryModeKey.swift` | 1 | `file_name` | File name does not match declared type/extension |
| `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` | 518 | `file_length` | 518 lines (limit: 500) |
| `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` | 22 | `type_body_length` | Class body 390 lines (limit: 350) |
| `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift` | 69 | `trailing_closure` | Trailing closure syntax should be used |
| `mkdn/Features/Viewer/Views/SelectableTextView.swift` | 602 | `file_length` | 602 lines (limit: 500) |
| `mkdnTests/Unit/Core/MarkdownVisitorTests.swift` | 6 | `type_body_length` | Struct body 364 lines (limit: 350) |
| `mkdnTests/Support/JSONResultReporter.swift` | 67 | `trailing_closure` | Trailing closure syntax should be used |
| `mkdnTests/Support/JSONResultReporter.swift` | 68 | `trailing_closure` | Trailing closure syntax should be used |

---

## Formatting Results

**Tool**: SwiftFormat (config: `.swiftformat`)
**Result**: 1 of 168 files requires formatting (17 files skipped)

### Files Needing Formatting

| File | Line | Rule | Issue |
|------|------|------|-------|
| `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` | 336 | `docComments` | Use doc comments for API declarations, otherwise use regular comments |

---

## Test Results

**Tool**: Swift Testing (`swift test`)
**Result**: 548 passed, 1 failed (549 total across 52 suites)
**Pass Rate**: 99.8%

### Failed Tests

| Test | Suite | Issue |
|------|-------|-------|
| `cycleTheme cycles through auto, dark, light` | `AppSettings` | Theme cycle order expectations are stale |

### Failure Details

The test `cycleTheme cycles through auto, dark, light` in `AppSettingsTests.swift` has 3 assertion failures:

1. **Line 114**: Expected `.solarizedDark`, got `.solarizedLight`
2. **Line 117**: Expected `.solarizedLight`, got `.auto`
3. **Line 120**: Expected `.auto`, got `.solarizedLight`

This indicates the theme cycle order was changed (likely to include Solarized themes) but the test expectations were not updated to reflect the new cycle sequence.

---

## Coverage Analysis

**Tool**: N/A -- `swift test` does not produce coverage data by default. Swift does not have a standard `tarpaulin`-equivalent integrated into SPM. Coverage collection would require `swift test --enable-code-coverage` and `llvm-cov` post-processing.

**Coverage**: Not measured
**Target**: 80%

---

## Recommendations

### High Priority (test failure)

1. **Update `cycleTheme` test** (`mkdnTests/Unit/Core/AppSettingsTests.swift`): The theme cycle order has changed to include Solarized themes. Update the expected values at lines 114, 117, and 120 to match the actual cycle sequence.

### Medium Priority (lint errors)

2. **Refactor `TestHarnessHandler.swift`**: This file has 3 violations (complexity, file length, type body length). Extract the switch-case handling into separate methods or split the enum across extensions.

3. **Refactor `SelectableTextView.swift`**: At 602 lines, well over the 500-line limit. Extract helper types or extensions into separate files.

4. **Refactor `CodeBlockBackgroundTextView.swift`**: Over both file length (518) and type body length (390) limits. Also has a formatting issue (docComments rule).

5. **Fix trailing closure violations**: 3 instances across `MarkdownPreviewView.swift` and `JSONResultReporter.swift` -- simple mechanical fixes.

6. **Fix file name mismatch**: `DirectoryModeKey.swift` does not match a declared type. Rename the file or the type.

### Low Priority

7. **Refactor `MarkdownVisitorTests.swift`**: Test struct body at 364 lines (limit 350). Consider splitting into multiple test suites.

8. **Enable code coverage**: Add `swift test --enable-code-coverage` to the workflow and use `llvm-cov export` for coverage reporting.

---

## Overall Assessment

**FAIL** -- The codebase has 1 test failure (stale theme cycle expectations), 11 lint violations (all errors), and 1 formatting issue. The test failure is a logic mismatch between production code and test expectations. The lint violations are predominantly structural (file/type length) rather than correctness issues. The single formatting issue is minor.

The test failure is the most critical item -- it indicates the `cycleTheme` implementation was modified without updating the corresponding test.
