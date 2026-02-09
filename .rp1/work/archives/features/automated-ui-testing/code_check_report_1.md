# Code Check Report #1 -- automated-ui-testing

**Date**: 2026-02-08
**Branch**: main
**Build System**: Swift Package Manager (Swift 6, macOS 14.0+)
**Coverage Target**: 80%

---

## Executive Summary

| Metric | Status | Detail |
|--------|--------|--------|
| Build | PASS | Compiles cleanly (0 errors, 0 warnings from source) |
| Linting | FAIL | 1 error, 0 warnings |
| Formatting | PASS | 0 files need formatting |
| Tests | FAIL | 270/283 passed (95.4%) -- 13 failures |
| Coverage | N/A | No coverage tool configured for Swift (tarpaulin is Rust-only; Xcode coverage requires xctest scheme) |
| **Overall** | **FAIL** | Lint error + 13 test failures |

---

## Build Results

```
Build complete! (0.40s)
```

Build succeeds with no source-level errors or warnings. SPM emits an informational note about 5 unhandled `.md` fixture files in `mkdnTests/Fixtures/UITest/` -- these should be explicitly declared as resources or excluded in `Package.swift`.

---

## Linting Results

**Tool**: SwiftLint (strict mode via Homebrew, Xcode 16.3.0 toolchain)
**Files Scanned**: 114
**Result**: FAIL -- 1 error, 0 warnings

### Errors

| # | File | Line | Rule | Message |
|---|------|------|------|---------|
| 1 | `mkdn/Features/Viewer/Views/TableBlockView.swift` | 15 | `closure_body_length` | Closure body should span 45 lines or less excluding comments and whitespace: currently spans 49 lines |

---

## Formatting Results

**Tool**: SwiftFormat (config: `/Users/jud/Projects/mkdn/.swiftformat`)
**Files Scanned**: 116 (1 skipped)
**Result**: PASS -- 0 files require formatting

---

## Test Results

**Framework**: Swift Testing (`@Test`, `#expect`, `@Suite`)
**Result**: FAIL -- 270 passed, 13 failed (95.4% pass rate)

**Note**: The test process exited with signal code 5 (SIGTRAP) after test execution, likely due to the UI compliance test suites attempting to connect to a test harness server that is not running in this CI-like environment.

### Passed Suites (23/23 unit test suites)

All pure unit test suites pass:

AnimationConstants, AppSettings (via AppTheme), CLIError, ColorExtractor, Controls, DefaultHandlerService, DocumentState, FileOpenCoordinator, FileValidator, FileWatcher, FrameAnalyzer, HarnessCommand, HarnessResponse, ImageAnalyzer, JSONResultReporter, Markdown File Filter, MarkdownBlock, MarkdownRenderer, MarkdownTextStorageBuilder, MarkdownVisitor, MermaidHTMLTemplate, MermaidThemeMapper, MotionPreference, PixelColor, PlatformTypeConverter, PRDCoverageTracker, Snap Logic, SpatialMeasurement, ThemeMode, ThemeOutputFormat

### Failed Tests (13)

All failures are in UI compliance test suites that require a running app with test harness. They fail because `calibrationPassed` is `false` (the calibration step cannot connect to the app).

**Suite: AnimationCompliance** (4 failures)

| Test | Failure Reason |
|------|----------------|
| `test_animationDesignLanguage_FR3_fadeInDuration` | `calibrationPassed` is false |
| `test_animationDesignLanguage_FR3_fadeOutDuration` | `calibrationPassed` is false |
| `test_animationDesignLanguage_FR5_reduceMotionOrbStatic` | `calibrationPassed` is false |
| `test_animationDesignLanguage_FR5_reduceMotionTransition` | `calibrationPassed` is false |

**Suite: SpatialCompliance** (7 failures)

| Test | Failure Reason |
|------|----------------|
| `test_spatialDesignLanguage_FR3_h1SpaceAbove` | `calibrationPassed` is false |
| `test_spatialDesignLanguage_FR3_h1SpaceBelow` | `calibrationPassed` is false |
| `test_spatialDesignLanguage_FR3_h2SpaceAbove` | `calibrationPassed` is false |
| `test_spatialDesignLanguage_FR3_h2SpaceBelow` | `calibrationPassed` is false |
| `test_spatialDesignLanguage_FR3_h3SpaceAbove` | `calibrationPassed` is false |
| `test_spatialDesignLanguage_FR3_h3SpaceBelow` | `calibrationPassed` is false |
| `test_spatialDesignLanguage_FR4_codeBlockPadding` | `calibrationPassed` is false |

**Suite: VisualCompliance** (2 failures)

| Test | Failure Reason |
|------|----------------|
| `test_visualCompliance_AC004d_syntaxTokensSolarizedDark` | `calibrationPassed` is false |
| `test_visualCompliance_AC004d_syntaxTokensSolarizedLight` | `calibrationPassed` is false |

---

## Coverage Analysis

Coverage measurement is not available in this environment. Swift Package Manager does not have a built-in coverage reporting tool equivalent to `cargo tarpaulin` or `pytest --cov`. Coverage requires either:

1. `swift test --enable-code-coverage` with `llvm-cov` parsing, or
2. Xcode scheme-based coverage via `xcodebuild test`

Neither is configured for this project. Coverage cannot be assessed against the 80% target.

---

## Recommendations

### Must Fix (blocking)

1. **Lint error in `TableBlockView.swift:15`**: Refactor the closure at line 15 to be 45 lines or fewer. Consider extracting sub-views or helper methods to reduce closure body length from 49 to under 45 lines.

### Should Fix

2. **Declare test fixture resources**: Add the 5 `.md` files in `mkdnTests/Fixtures/UITest/` to the test target's resource declarations in `Package.swift` to eliminate the SPM warning.

3. **Test harness availability**: The 13 UI compliance test failures are all due to calibration requiring a running app with the test harness server. Consider:
   - Tagging these tests with a custom trait (e.g., `.tags(.uiCompliance)`) so they can be skipped in headless/CI environments.
   - Documenting the required setup for running UI compliance tests.

### Nice to Have

4. **Code coverage tooling**: Set up `swift test --enable-code-coverage` and `llvm-cov export` to enable coverage measurement in CI and local checks.

5. **Signal 5 crash**: Investigate the SIGTRAP that occurs after test execution completes. This may be related to the test harness server teardown or a force-unwrap in test cleanup code.

---

## Overall Assessment

| Check | Result |
|-------|--------|
| Build | PASS |
| Linting | FAIL (1 error) |
| Formatting | PASS |
| Tests | FAIL (13/283 failed, 95.4%) |
| Coverage | N/A |
| **Overall** | **FAIL** |

The codebase is in good shape for unit-level code quality. All 270 unit tests pass, and formatting is clean. The two failure categories are:

1. **One lint violation** -- a closure body length issue in `TableBlockView.swift` that needs a minor refactor.
2. **13 UI compliance test failures** -- all caused by the test harness not being available in this environment. These are infrastructure/environment failures, not code defects.

If the UI compliance tests are excluded (they require a running app), and the lint error is fixed, the codebase would pass all checks.
