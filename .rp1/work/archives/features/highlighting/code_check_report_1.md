# Code Check Report #1 -- highlighting

**Date**: 2026-02-17
**Branch**: main
**Build System**: Swift Package Manager (Package.swift)
**Coverage Target**: 80%

---

## Executive Summary

| Check        | Status | Detail                          |
|--------------|--------|---------------------------------|
| Linting      | FAIL   | 9 errors, 0 warnings            |
| Formatting   | PASS   | 0 files need formatting         |
| Tests        | FAIL   | 442/443 passed (99.8%)          |
| Coverage     | N/A    | No coverage tool configured     |
| **Overall**  | **FAIL** |                               |

---

## Linting Results

**Tool**: SwiftLint (strict mode, all opt-in rules)
**Total violations**: 9 errors, 0 warnings

### Errors by Rule

| Rule | Count | Severity |
|------|-------|----------|
| type_body_length | 3 | Error |
| function_body_length | 2 | Error |
| file_length | 2 | Error |
| redundant_self | 2 | Error |

### Error Details

1. **type_body_length** -- `mkdn/Core/TestHarness/TestHarnessHandler.swift:5` -- Enum body 375 lines (limit: 350)
2. **type_body_length** -- `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTests.swift:7` -- Struct body 376 lines (limit: 350)
3. **type_body_length** -- `mkdnTests/Unit/Core/MarkdownVisitorTests.swift:7` -- Struct body 364 lines (limit: 350)
4. **function_body_length** -- `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift:238` -- Function body 64 lines (limit: 50)
5. **function_body_length** -- `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift:125` -- Function body 60 lines (limit: 50)
6. **file_length** -- `mkdn/Features/Viewer/Views/OverlayCoordinator.swift:501` -- File 501 lines (limit: 500)
7. **file_length** -- `mkdn/Features/Viewer/Views/SelectableTextView.swift:518` -- File 518 lines (limit: 500)
8. **redundant_self** -- `mkdn/Features/Viewer/Views/SelectableTextView.swift:423` -- Explicit `self` not required
9. **redundant_self** -- `mkdn/Features/Viewer/Views/SelectableTextView.swift:424` -- Explicit `self` not required

---

## Formatting Results

**Tool**: SwiftFormat
**Status**: PASS
**Files needing formatting**: 0 / 146 (1 file skipped)

No formatting issues detected.

---

## Test Results

**Framework**: Swift Testing
**Total tests**: 443
**Passed**: 442
**Failed**: 1
**Pass rate**: 99.8%

### Failed Tests

| Test | Suite | Detail |
|------|-------|--------|
| cycleTheme cycles through auto, dark, light | AppSettings | Failed with 3 assertion issues |

### Suite Summary

All 44 test suites passed except **AppSettings** (1 failure out of its tests).

---

## Coverage Analysis

**Status**: Not available

No code coverage tool is configured for this Swift project. `swift test` does not produce coverage data by default. To enable coverage, run:

```bash
swift test --enable-code-coverage
```

Then extract the report from the profdata/JSON output. Consider integrating `swift test --enable-code-coverage` into the standard workflow.

---

## Recommendations

### Priority 1 -- Fix Failing Test
- **cycleTheme test** in `AppSettings` suite: Investigate the 3 assertion failures. This test validates theme cycling behavior (auto -> dark -> light) which is core UX functionality.

### Priority 2 -- Lint Errors (9 total)
- **redundant_self** (2 issues in `SelectableTextView.swift:423-424`): Remove explicit `self.` references. Trivial fix.
- **file_length** (2 issues): `OverlayCoordinator.swift` (501 lines) and `SelectableTextView.swift` (518 lines) exceed the 500-line limit. Extract helper types or extensions into separate files.
- **function_body_length** (2 issues): Functions in `MarkdownTextStorageBuilder.swift` and `MarkdownTextStorageBuilder+Complex.swift` exceed 50-line limit. Refactor into smaller helper functions.
- **type_body_length** (3 issues): `TestHarnessHandler` enum (375 lines), test structs in `MarkdownTextStorageBuilderTests` (376 lines) and `MarkdownVisitorTests` (364 lines) exceed 350-line limit. Split into extensions or sub-suites.

### Priority 3 -- Coverage Tooling
- Add `--enable-code-coverage` to the standard test command to track coverage metrics against the 80% target.

---

## Overall Assessment

**FAIL**

The codebase has 1 failing test and 9 lint errors. Formatting is clean. The failing test (`cycleTheme`) should be investigated and fixed as a priority. The lint violations are primarily structural (body/file length) and one trivial code style issue (redundant self). No coverage data is available to assess against the 80% target.
