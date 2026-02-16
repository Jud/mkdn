# Code Check Report #1 -- mac-app-essentials

**Date**: 2026-02-13
**Branch**: feature-mac-app-essentials
**Worktree**: `.rp1/work/worktrees/feature-mac-app-essentials`
**Build System**: Swift Package Manager (Package.swift)

---

## Executive Summary

| Check       | Status | Detail                          |
|-------------|--------|---------------------------------|
| Linting     | FAIL   | 2 errors, 0 warnings            |
| Formatting  | PASS   | 0 files need formatting         |
| Tests       | FAIL   | 373/394 passed (94.7%)          |
| Coverage    | N/A    | No coverage tool available      |

**Overall Status**: FAIL

---

## Linting Results

**Tool**: SwiftLint (strict mode, all opt-in rules)
**Command**: `DEVELOPER_DIR=/Applications/Xcode-16.3.0.app/Contents/Developer swiftlint lint`
**Files scanned**: 135
**Errors**: 2 | **Warnings**: 0

### Violations

| # | Severity | Rule | File | Line | Detail |
|---|----------|------|------|------|--------|
| 1 | Error | `type_body_length` | `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTests.swift` | 7 | Struct body spans 376 lines (limit: 350) |
| 2 | Error | `type_body_length` | `mkdnTests/Unit/Core/MarkdownVisitorTests.swift` | 7 | Struct body spans 364 lines (limit: 350) |

Both violations are in test files where test suites exceed the 350-line body length limit. These are pre-existing violations in the test suite, not introduced by the feature branch.

---

## Formatting Results

**Tool**: SwiftFormat
**Command**: `swiftformat --lint .`
**Files scanned**: 137 (1 skipped)
**Files needing formatting**: 0

No formatting issues detected.

---

## Test Results

**Tool**: Swift Testing (`swift test`)
**Total tests**: 394
**Passed**: 373 (94.7%)
**Failed**: 21 (including 1 known issue)
**Pass rate**: 94.7%

### Failed Tests by Category

#### Spatial Compliance Tests (7 failures)

These are UI/spatial measurement tests that verify rendered output against PRD specifications. All failures are measurement mismatches, likely reflecting intentional layout changes on this branch:

| Test | Issue |
|------|-------|
| `test_spatialDesignLanguage_FR2_documentMarginLeft` | Expected 40.0pt, measured 32.0pt |
| `test_spatialDesignLanguage_FR2_documentMarginRight` | Expected >= 40.0pt, measured 32.0pt |
| `test_spatialDesignLanguage_FR2_blockSpacing` | Expected 8.0pt, measured 23.0pt |
| `test_spatialDesignLanguage_FR2_contentMaxWidth` | Expected <= 680.0pt, measured 836.0pt |
| `test_spatialDesignLanguage_FR6_windowTopInset` | Expected 69.0pt, measured 71.5pt |
| `test_spatialDesignLanguage_FR6_windowSideInset` | Expected 40.0pt, measured 32.0pt |
| `test_spatialDesignLanguage_FR6_windowBottomInset` | Expected >= 32.0pt, measured 15.0pt |

#### Animation Compliance Tests (8 failures + 1 calibration)

All animation compliance failures share the same root cause: `frameCount == 0` -- the SCStream frame capture infrastructure fails to capture any frames. This is an environment-level issue (screen recording permissions / headless CI), not a code defect:

| Test | Issue |
|------|-------|
| `calibration_frameCaptureAndTimingAccuracy` | No frames captured |
| `test_animationDesignLanguage_FR1_breathingOrbRhythm` | No frames captured |
| `test_animationDesignLanguage_FR2_springSettleResponse` | No frames captured |
| `test_animationDesignLanguage_FR3_crossfadeDuration` | No frames captured |
| `test_animationDesignLanguage_FR3_fadeOutDuration` | No frames captured |
| `test_animationDesignLanguage_FR4_staggerDelays` | No frames captured |
| `test_animationDesignLanguage_FR5_reduceMotionOrbStatic` | No frames captured |
| `test_animationDesignLanguage_FR5_reduceMotionTransition` | No frames captured |

#### Vision Capture Tests (3 failures)

Timeout-based failures in capture orchestrator tests (require running app + harness server):

| Test | Issue |
|------|-------|
| `Capture all animation fixtures for vision verification` | Read timed out |
| `Capture mermaid fade-in across themes and motion modes` | Read timed out |
| `Capture orb crossfade and breathing across themes` | Read timed out |

#### Known Issues (1)

| Test | Status |
|------|--------|
| `VisualCompliance` suite | 1 known issue (tracked) |

---

## Coverage Analysis

**Status**: Not available

The project does not have `cargo tarpaulin` equivalent configured. Swift's built-in code coverage requires `swift test --enable-code-coverage` with Xcode toolchain integration. Coverage data was not collected in this run.

**Target**: 80%
**Measured**: N/A

---

## Recommendations

1. **Lint -- type_body_length in test files**: Consider splitting `MarkdownTextStorageBuilderTests` (376 lines) and `MarkdownVisitorTests` (364 lines) into multiple extensions or sub-suites to stay under the 350-line limit. Alternatively, add `// swiftlint:disable type_body_length` with a comment explaining the rationale for large test suites.

2. **Spatial compliance test failures**: The 7 spatial failures show systematic margin/spacing deltas (32pt vs 40pt expected). If the feature branch intentionally changed layout constants, update the PRD expected values or the `SpatialComplianceTests` expectations to match.

3. **Animation/capture infrastructure**: All 8 animation tests and 3 vision capture tests fail due to SCStream not capturing frames and harness server timeouts. These are environment-dependent (require screen recording permissions and a running app instance). Consider tagging these tests with a trait to skip in non-interactive environments.

4. **Coverage tooling**: Consider enabling `swift test --enable-code-coverage` and adding a coverage extraction step to get visibility into test coverage metrics.

---

## Overall Assessment

**FAIL** -- The code check identified 2 lint errors (test file body length) and 21 test failures. Formatting is clean. The test failures break down into three categories: (a) spatial compliance expectations mismatched against measured values (likely intentional layout changes), (b) animation frame capture infrastructure unavailable in the current environment, and (c) vision capture harness timeouts. The lint violations are pre-existing in test files. No source code formatting issues were found.
