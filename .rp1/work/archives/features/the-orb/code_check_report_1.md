# Code Check Report #1

**Feature**: the-orb
**Branch**: main
**Date**: 2026-02-10
**Build System**: Swift Package Manager (Swift 6.0)

---

## Executive Summary

| Metric | Result | Status |
|--------|--------|--------|
| Build | Success (0.33s) | PASS |
| Linting | 0 violations in 127 files | PASS |
| Formatting | 0/129 files need formatting | PASS |
| Tests | 344/358 passed (96.1%) | FAIL |
| Coverage | Not measured (no tarpaulin/llvm-cov configured) | N/A |

**Overall Status**: FAIL -- 14 test failures detected.

---

## Linting Results

**Tool**: SwiftLint (strict mode via Xcode 16.3.0 toolchain)
**Status**: PASS

- Files scanned: 127
- Errors: 0
- Warnings: 0
- Serious violations: 0

No linting issues found.

---

## Formatting Results

**Tool**: SwiftFormat (--lint mode)
**Status**: PASS

- Files checked: 129
- Files needing formatting: 0
- Files skipped: 1

All source files conform to the project's SwiftFormat configuration.

---

## Test Results

**Tool**: `swift test` (Swift Testing framework)
**Status**: FAIL

- Total tests: 358
- Passed: 344 (96.1%)
- Failed: 14
- Known issues: 1 (test_visualCompliance_codeBlockStructuralContainer -- counted as passed)
- Duration: ~74 seconds

### Failed Tests

#### Unit Test Failures (1)

| Test | Suite | Issue |
|------|-------|-------|
| Token substitution removes all placeholder tokens | MermaidHTMLTemplate | `Bundle.module.url(forResource: "mermaid-template", ...)` returned nil -- resource not found in test bundle |

#### Spatial Compliance Failures (10)

All spatial compliance tests fail because calibration does not pass in this environment (no running app instance). These are integration/UI tests that require the app harness.

| Test | Suite |
|------|-------|
| test_spatialDesignLanguage_FR2_blockSpacing | SpatialCompliance |
| test_spatialDesignLanguage_FR2_contentMaxWidth | SpatialCompliance |
| test_spatialDesignLanguage_FR2_documentMarginLeft | SpatialCompliance |
| test_spatialDesignLanguage_FR2_documentMarginRight | SpatialCompliance |
| test_spatialDesignLanguage_FR3_h2SpaceAbove | SpatialCompliance |
| test_spatialDesignLanguage_FR3_h2SpaceBelow | SpatialCompliance |
| test_spatialDesignLanguage_FR3_h3SpaceAbove | SpatialCompliance |
| test_spatialDesignLanguage_FR3_h3SpaceBelow | SpatialCompliance |
| test_spatialDesignLanguage_FR6_windowSideInset | SpatialCompliance |
| test_spatialDesignLanguage_FR6_windowTopInset | SpatialCompliance |

Root cause: `calibrationPassed` is false -- these tests require a live app harness connection.

#### Animation Compliance Failures (1)

| Test | Suite | Issue |
|------|-------|-------|
| test_animationDesignLanguage_FR2_springSettleResponse | AnimationCompliance | `layoutChanged` expectation failed (distance=1) -- mode switch did not produce visible layout change |

#### Vision Capture Failures (2)

| Test | Suite | Issue |
|------|-------|-------|
| Capture all animation fixtures for vision verification | AnimationVisionCapture | Requires live app harness |
| Capture mermaid fade-in across themes and motion modes | MermaidFadeIn | Requires live app harness |

### Failure Analysis

The 14 failures break down into two categories:

1. **Environment-dependent (13 tests)**: Spatial compliance, animation compliance, and vision capture tests all require a running app instance with test harness. These are expected to fail in a headless `swift test` invocation.

2. **Genuine unit test failure (1 test)**: The MermaidHTMLTemplate test fails because `Bundle.module` cannot locate `mermaid-template.html` in the test bundle. This is a resource bundling issue in the test target configuration.

---

## Coverage Analysis

**Status**: Not measured

No coverage tooling is configured for this Swift project. SPM does not have built-in coverage reporting without additional flags or tooling (`swift test --enable-code-coverage` + `llvm-cov`). Coverage target was 80%.

---

## Recommendations

1. **MermaidHTMLTemplate test**: The `mermaid-template.html` resource is declared in the `mkdnLib` target's resources, but the test target accesses it via `Bundle.module`. Since `@testable import mkdnLib` does not share the library's resource bundle with the test's `Bundle.module`, the resource lookup fails. Consider accessing the resource through `Bundle(for:)` or `Bundle(identifier:)` targeting the mkdnLib bundle, or copying the resource into the test target's resources.

2. **Coverage measurement**: Add `swift test --enable-code-coverage` and `llvm-cov export` to the CI pipeline to track coverage against the 80% target.

3. **Test tagging for environment**: Consider tagging the harness-dependent tests (SpatialCompliance, AnimationCompliance, VisionCapture) with a trait or tag so they can be excluded in headless CI runs and only executed in environments with a live app harness.

---

## Overall Assessment

| Check | Status |
|-------|--------|
| Build | PASS |
| Linting | PASS |
| Formatting | PASS |
| Tests | FAIL (14 failures: 13 environment-dependent, 1 genuine) |
| Coverage | N/A |

**Verdict**: FAIL -- 1 genuine test failure (MermaidHTMLTemplate resource bundling). The 13 remaining failures are environment-dependent integration tests that require a live app harness and are expected to fail in headless execution.
