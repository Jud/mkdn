# Code Check Report #1

**Feature**: directory-sidebar
**Date**: 2026-02-16
**Branch**: main
**Build System**: Swift Package Manager (Swift 6)

---

## Executive Summary

| Check | Status | Details |
|-------|--------|---------|
| Build | PASS | Clean compilation, no errors or warnings |
| Linting | FAIL | 8 violations (8 errors, 0 warnings) in 161 files |
| Formatting | FAIL | 1 file requires formatting |
| Tests | FAIL | 450/477 passed (94.3%), 27 failures |
| Coverage | N/A | No coverage tool configured (cargo tarpaulin N/A for Swift) |

**Overall Status**: FAIL

---

## Linting Results

**Tool**: SwiftLint (strict mode, all opt-in rules)
**Command**: `DEVELOPER_DIR=/Applications/Xcode-16.3.0.app/Contents/Developer swiftlint lint`
**Result**: 8 errors, 0 warnings across 161 files

### Errors

| # | File | Line | Rule | Description |
|---|------|------|------|-------------|
| 1 | `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift` | 238 | `function_body_length` | Function body spans 64 lines (limit: 50) |
| 2 | `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` | 126 | `function_body_length` | Function body spans 60 lines (limit: 50) |
| 3 | `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` | 501 | `file_length` | File contains 501 lines (limit: 500) |
| 4 | `mkdn/Features/Viewer/Views/SelectableTextView.swift` | 519 | `file_length` | File contains 519 lines (limit: 500) |
| 5 | `mkdn/Features/Viewer/Views/SelectableTextView.swift` | 424 | `redundant_self` | Explicit use of `self` is not required |
| 6 | `mkdn/Features/Viewer/Views/SelectableTextView.swift` | 425 | `redundant_self` | Explicit use of `self` is not required |
| 7 | `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTests.swift` | 7 | `type_body_length` | Struct body spans 376 lines (limit: 350) |
| 8 | `mkdnTests/Unit/Core/MarkdownVisitorTests.swift` | 7 | `type_body_length` | Struct body spans 364 lines (limit: 350) |

---

## Formatting Results

**Tool**: SwiftFormat
**Command**: `swiftformat --lint .`
**Result**: 1 file requires formatting out of 163 files (1 skipped)

### Files Requiring Formatting

| # | File | Line | Issue |
|---|------|------|-------|
| 1 | `mkdn/Features/Viewer/Views/SelectableTextView.swift` | 290 | Missing blank line before/after `MARK:` comment (`blankLinesAroundMark`) |

---

## Test Results

**Framework**: Swift Testing
**Command**: `swift test`
**Total**: 477 tests | **Passed**: 450 | **Failed**: 27 | **Pass Rate**: 94.3%

### Failed Tests (27)

#### UI/Animation Compliance Tests (infrastructure-dependent, require app + SCStream)

These failures are all in UI compliance test suites that require a running app instance and SCStream frame capture. They fail due to infrastructure limitations (no display server, SCStream timeout), not code defects.

| # | Test | Suite | Error |
|---|------|-------|-------|
| 1 | calibration_frameCaptureAndTimingAccuracy | AnimationCompliance | frameCount == 0 |
| 2 | test_animationDesignLanguage_FR1_breathingOrbRhythm | AnimationCompliance | frameCount == 0 |
| 3 | test_animationDesignLanguage_FR2_springSettleResponse | AnimationCompliance | frameCount == 0 |
| 4 | test_animationDesignLanguage_FR3_crossfadeDuration | AnimationCompliance | frameCount == 0 |
| 5 | test_animationDesignLanguage_FR3_fadeInDuration | AnimationCompliance | capturedFrameCount not in range |
| 6 | test_animationDesignLanguage_FR3_fadeOutDuration | AnimationCompliance | frameCount == 0 |
| 7 | test_animationDesignLanguage_FR4_staggerDelays | AnimationCompliance | frameCount == 0 |
| 8 | test_animationDesignLanguage_FR5_reduceMotionOrbStatic | AnimationCompliance | frameCount == 0 |
| 9 | test_animationDesignLanguage_FR5_reduceMotionTransition | AnimationCompliance | frameCount == 0 |
| 10 | Capture all animation fixtures for vision verification | AnimationVisionCapture | Read timed out |
| 11 | Capture mermaid fade-in across themes and motion modes | MermaidFadeIn | Read timed out |
| 12 | Capture orb crossfade and breathing across themes | OrbVisionCapture | Read timed out |

#### Spatial Compliance Tests (infrastructure-dependent, require running app)

| # | Test | Suite | Error |
|---|------|-------|-------|
| 13 | test_spatialDesignLanguage_FR2_blockSpacing | SpatialCompliance | Expectation failed |
| 14 | test_spatialDesignLanguage_FR2_contentMaxWidth | SpatialCompliance | Expectation failed |
| 15 | test_spatialDesignLanguage_FR2_documentMarginLeft | SpatialCompliance | Expectation failed |
| 16 | test_spatialDesignLanguage_FR2_documentMarginRight | SpatialCompliance | Expectation failed |
| 17 | test_spatialDesignLanguage_FR3_h1SpaceBelow | SpatialCompliance | Expectation failed |
| 18 | test_spatialDesignLanguage_FR3_h2SpaceAbove | SpatialCompliance | Expectation failed |
| 19 | test_spatialDesignLanguage_FR3_h2SpaceBelow | SpatialCompliance | Expectation failed |
| 20 | test_spatialDesignLanguage_FR3_h3SpaceAbove | SpatialCompliance | Expectation failed |
| 21 | test_spatialDesignLanguage_FR3_h3SpaceBelow | SpatialCompliance | Expectation failed |
| 22 | test_spatialDesignLanguage_FR4_codeBlockPadding | SpatialCompliance | Expectation failed |
| 23 | test_spatialDesignLanguage_FR6_windowBottomInset | SpatialCompliance | Expectation failed |
| 24 | test_spatialDesignLanguage_FR6_windowSideInset | SpatialCompliance | Expectation failed |
| 25 | test_spatialDesignLanguage_FR6_windowTopInset | SpatialCompliance | Expectation failed |

#### Unit Test Failures

| # | Test | Suite | Error |
|---|------|-------|-------|
| 26 | cycleTheme cycles through auto, dark, light | AppSettingsTests | themeMode cycle order mismatch (expected solarizedDark, got solarizedLight) |
| 27 | Token substitution removes all placeholder tokens | MarkdownTextStorageBuilderTests | Token substitution failure |

---

## Coverage Analysis

Coverage measurement is not available. The project uses Swift Package Manager without a configured coverage tool. To enable coverage:

```bash
swift test --enable-code-coverage
xcrun llvm-cov report .build/debug/mkdnPackageTests.xctest/Contents/MacOS/mkdnPackageTests -instr-profile .build/debug/codecov/default.profdata
```

---

## Recommendations

### Priority 1 (Errors - must fix)

1. **SelectableTextView.swift**: Remove redundant `self` references at lines 424-425 and add blank line around `MARK:` at line 290. This file also exceeds the 500-line file length limit (519 lines) -- consider extracting helper types.

2. **OverlayCoordinator.swift**: At 501 lines, just 1 line over the limit. Extract a small helper or move a utility method to reduce below 500.

3. **MarkdownTextStorageBuilder functions**: Two functions exceed 50-line body limit (64 and 60 lines respectively). Extract sub-functions.

### Priority 2 (Test failures to investigate)

4. **AppSettingsTests - cycleTheme**: Unit test failure indicating `themeMode` cycle order is `auto -> solarizedLight -> solarizedDark` but test expects `auto -> solarizedDark -> solarizedLight -> auto`. Likely a code change in theme cycling logic that the test hasn't been updated for.

5. **Token substitution test**: Unit test failure in MarkdownTextStorageBuilderTests needs investigation.

### Priority 3 (Test infrastructure)

6. **UI/Animation/Spatial compliance tests** (25 failures): All require a running app instance with SCStream frame capture. Expected to fail in headless/CLI test runs. Consider marking these with `.enabled(if:)` or a custom trait to skip in CI.

### Priority 4 (Test type body length)

7. **MarkdownTextStorageBuilderTests.swift** and **MarkdownVisitorTests.swift**: Test structs exceed 350-line type body length limit. Split into multiple test suite files.

---

## Overall Assessment

**Status: FAIL**

The codebase has 8 SwiftLint errors and 1 formatting issue that must be resolved. The build compiles cleanly. Of the 27 test failures, 25 are UI/animation compliance tests that require a running app and screen capture infrastructure (expected to fail in CLI context). The 2 unit test failures (`cycleTheme` and token substitution) require investigation as they indicate potential regressions in theme cycling and text storage builder logic.
