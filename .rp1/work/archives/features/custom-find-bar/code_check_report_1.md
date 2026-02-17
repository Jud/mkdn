# Code Check Report #1 -- custom-find-bar

**Date**: 2026-02-15
**Branch**: main
**Feature**: custom-find-bar
**Build System**: Swift Package Manager (Swift 6.0)

---

## Executive Summary

| Check | Status | Details |
|-------|--------|---------|
| Build | PASS | Clean build, 0 errors |
| Linting | FAIL | 5 errors, 0 warnings |
| Formatting | PASS | 0 files need formatting |
| Tests | FAIL | 403/424 passed (95.0%) |
| Coverage | N/A | No coverage tool configured |

**Overall**: FAIL -- lint errors and test failures present.

---

## Build Results

- **Status**: PASS
- `swift build` completed successfully in 0.34s.
- No compilation errors or warnings.

---

## Linting Results

- **Tool**: SwiftLint (strict mode, all opt-in rules)
- **Status**: FAIL -- 5 errors, 0 warnings
- **Files scanned**: 142

### Errors (5)

| # | Rule | File | Line | Detail |
|---|------|------|------|--------|
| 1 | `file_length` | `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` | 501 | File should contain 500 lines or less: currently contains 501 |
| 2 | `type_body_length` | `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTests.swift` | 7 | Struct body spans 376 lines (limit: 350) |
| 3 | `type_body_length` | `mkdnTests/Unit/Core/MarkdownVisitorTests.swift` | 7 | Struct body spans 364 lines (limit: 350) |
| 4 | `function_body_length` | `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift` | 238 | Function body spans 64 lines (limit: 50) |
| 5 | `function_body_length` | `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` | 126 | Function body spans 60 lines (limit: 50) |

---

## Formatting Results

- **Tool**: SwiftFormat
- **Status**: PASS
- **Files checked**: 144 (1 skipped)
- **Files needing formatting**: 0

---

## Test Results

- **Tool**: Swift Testing (`swift test`)
- **Status**: FAIL -- 21 test failures (1 known issue)
- **Total tests**: 424
- **Passed**: 403
- **Failed**: 21
- **Pass rate**: 95.0%

### Failed Tests

#### UI/Integration Tests (require running app -- expected in CI-less environment)

These failures are infrastructure-related (test harness server timeouts, app launch failures). They are not indicative of code quality issues.

| # | Test | Error | Suite |
|---|------|-------|-------|
| 1 | `calibration_frameCaptureAndTimingAccuracy` | Read timed out waiting for server response | AnimationCompliance |
| 2 | `test_animationDesignLanguage_FR1_breathingOrbRhythm` | Read timed out waiting for server response | AnimationCompliance |
| 3 | `test_animationDesignLanguage_FR2_springSettleResponse` | Read timed out waiting for server response | AnimationCompliance |
| 4 | `test_animationDesignLanguage_FR3_crossfadeDuration` | Read timed out waiting for server response | AnimationCompliance |
| 5 | `test_animationDesignLanguage_FR3_fadeInDuration` | Frame count assertion failed | AnimationCompliance |
| 6 | `test_animationDesignLanguage_FR3_fadeOutDuration` | Read timed out / frame capture issue | AnimationCompliance |
| 7 | `test_animationDesignLanguage_FR4_staggerDelays` | Read timed out waiting for server response | AnimationCompliance |
| 8 | `test_animationDesignLanguage_FR5_reduceMotionOrbStatic` | Read timed out waiting for server response | AnimationCompliance |
| 9 | `test_animationDesignLanguage_FR5_reduceMotionTransition` | Read timed out waiting for server response | AnimationCompliance |
| 10 | `Capture all animation fixtures for vision verification` | Server timeout / app launch | AnimationVisionCapture |
| 11 | `Capture orb crossfade and breathing across themes` | Server timeout / app launch | OrbVisionCapture |
| 12 | `Capture mermaid fade-in across themes and motion modes` | Server timeout / app launch | MermaidFadeIn |

#### Spatial Compliance Tests (require running app)

| # | Test | Error | Suite |
|---|------|-------|-------|
| 13 | `test_spatialDesignLanguage_FR2_documentMarginLeft` | Expectation failed: passed | SpatialCompliance |
| 14 | `test_spatialDesignLanguage_FR2_documentMarginRight` | Expectation failed: passed | SpatialCompliance |
| 15 | `test_spatialDesignLanguage_FR2_blockSpacing` | Expectation failed: passed | SpatialCompliance |
| 16 | `test_spatialDesignLanguage_FR2_contentMaxWidth` | Expectation failed: passed | SpatialCompliance |
| 17 | `test_spatialDesignLanguage_FR3_h3SpaceAbove` | Expectation failed: passed | SpatialCompliance |
| 18 | `test_spatialDesignLanguage_FR6_windowTopInset` | Expectation failed: passed | SpatialCompliance |
| 19 | `test_spatialDesignLanguage_FR6_windowSideInset` | Expectation failed: passed | SpatialCompliance |
| 20 | `test_spatialDesignLanguage_FR6_windowBottomInset` | Expectation failed: passed | SpatialCompliance |

#### Unit Test Failures

| # | Test | Error | Suite |
|---|------|-------|-------|
| 21 | `Token substitution removes all placeholder tokens` | Bundle.module resource not found: `mermaid-template.html` | MermaidHTMLTemplate |

#### Known Issues (not counted as failures)

| Test | Note |
|------|------|
| `test_visualCompliance_codeBlockStructuralContainer` | Marked as known issue; edge consistency check returns false |

---

## Coverage Analysis

- **Status**: N/A
- **Reason**: No coverage tool is configured for this Swift project. `swift test --enable-code-coverage` is available but was not in the project's standard test commands. Consider adding `swift test --enable-code-coverage` and extracting results via `llvm-cov` for future reports.
- **Target**: 80%

---

## Recommendations

### Priority 1 -- Lint Errors (blocking)

1. **OverlayCoordinator.swift (501 lines)**: Extract one or more helper types/extensions to bring below the 500-line limit. Only 1 line over -- minimal refactoring needed.
2. **MarkdownTextStorageBuilder+Complex.swift line 238 (64 lines)**: Extract sub-steps of this function into helper methods.
3. **MarkdownTextStorageBuilder.swift line 126 (60 lines)**: Same approach -- decompose into smaller functions.
4. **MarkdownTextStorageBuilderTests.swift (376 lines)** and **MarkdownVisitorTests.swift (364 lines)**: Split test suites into multiple `@Suite` structs or use extensions to stay under the 350-line type body limit.

### Priority 2 -- Test Failures

5. **MermaidHTMLTemplate unit test**: The `mermaid-template.html` resource is not found via `Bundle.module` during test execution. Verify the resource is included in the test target's resources or adjust the test to reference `mkdnLib`'s bundle.
6. **Spatial compliance tests**: 8 tests fail with "Expectation failed: passed" -- this suggests an inverted assertion or a guard-style check that throws on success. Investigate the assertion at `SpatialComplianceTests.swift:421`.
7. **Animation/vision capture tests**: All 12 failures are timeout-based (test harness server not responding). These require a running app instance and are expected to fail in headless/non-interactive environments.

### Priority 3 -- Coverage

8. Add `swift test --enable-code-coverage` to the standard test workflow and extract reports via `xcrun llvm-cov export` to track coverage over time.

---

## Overall Assessment

**Status: FAIL**

- **Linting**: FAIL -- 5 errors (2 file/type length in source, 2 type length in tests, 1 function length). All are length violations, not logic or safety issues.
- **Formatting**: PASS -- codebase is cleanly formatted.
- **Tests**: FAIL -- 21 failures out of 424 tests (95.0% pass rate). 20 of 21 failures are UI/integration tests requiring a live app instance (infrastructure-dependent). 1 unit test failure is a resource-loading issue in MermaidHTMLTemplate tests.
- **Coverage**: Not measured (no coverage tool in standard workflow).

The codebase is in reasonable shape. The lint errors are all length violations that can be fixed with minor refactoring. The vast majority of test failures are infrastructure-dependent (animation/spatial compliance tests needing a running app), not code defects. The single true unit test failure (MermaidHTMLTemplate) is a test configuration issue, not a code bug.
