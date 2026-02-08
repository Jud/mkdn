# Development Tasks: Automated UI Testing -- End-to-End Validation

**Feature ID**: automated-ui-testing
**Status**: In Progress
**Progress**: 8% (1 of 12 tasks)
**Estimated Effort**: 6 days
**Started**: 2026-02-08

## Overview

End-to-end validation of the automated UI testing infrastructure. The prior iteration built the complete test harness, compliance suites (41 tests across 3 suites), and analysis tools but could not run them because Screen Recording permission was not enabled. This iteration executes the full infrastructure for the first time, diagnoses and fixes failures, verifies determinism, validates the JSON report pipeline, and documents the compliance baseline.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1] - Build verification, prerequisite check (no dependencies)
2. [T2] - Smoke test (validates harness infrastructure end-to-end)
3. [T3, T4, T5] - Suite execution (independent suites, though recommended order is T3->T4->T5 for risk management)
4. [T6] - JSON report validation (needs test results from suites)
5. [T7, T8, T9] - Baseline, determinism, agent workflow (all need completed suite runs + report)

**Dependencies**:

- T2 -> T1 (build must succeed before launching app)
- T3 -> T2 (smoke test validates infrastructure before running suites)
- T4 -> T2 (same infrastructure dependency)
- T5 -> T2 (same infrastructure dependency)
- T6 -> [T3, T4, T5] (report must contain real test results)
- T7 -> [T3, T4, T5, T6] (baseline needs all suite results + validated report)
- T8 -> [T3, T4, T5] (determinism needs passing suites)
- T9 -> T6 (agent workflow needs parseable JSON report)

**Recommended Execution Order**: T1 -> T2 -> T3 -> T4 -> T5 -> T6 -> [T7, T8, T9]

**Critical Path**: T1 -> T2 -> T5 -> T6 -> T7

## Task Breakdown

### Foundation

- [x] **T1**: Verify build succeeds, test fixtures exist, Screen Recording permission is granted, and --test-harness flag launches the app `[complexity:simple]`

    **Reference**: [design.md#t1-build-verification-and-prerequisite-check](design.md#t1-build-verification-and-prerequisite-check)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] `swift build --product mkdn` completes without errors
    - [x] Test fixtures exist in `mkdnTests/Fixtures/UITest/` (canonical.md, geometry-calibration.md, long-document.md, mermaid-focus.md, theme-tokens.md)
    - [x] A minimal CGWindowListCreateImage call returns a non-nil image (Screen Recording permission confirmed)
    - [x] Launching mkdn with `--test-harness` flag starts the app and binds the Unix domain socket

    **Implementation Summary**:

    - **Files**: No code changes -- diagnostic verification only
    - **Approach**: Ran `swift build --product mkdn` (completed in 0.33s). Verified all 5 fixtures exist via glob. Confirmed Screen Recording via ScreenCaptureKit API (20 windows returned; note: `CGWindowListCreateImage` is obsoleted in macOS 15.5 standalone scripts but works within the project via `@available` suppression in `CaptureService.swift`). Launched mkdn with `--test-harness` and confirmed socket at `/tmp/mkdn-test-harness-{pid}.sock` appeared within ~1s.
    - **Deviations**: Screen Recording check used ScreenCaptureKit instead of direct CGWindowListCreateImage (macOS 15.5 marks CGWindowListCreateImage as unavailable for standalone compilation; the project code uses `@available(macOS, deprecated: 14.0)` annotation to compile it).
    - **Tests**: N/A (verification task, no tests to run)

### Infrastructure Validation

- [ ] **T2**: Execute full harness lifecycle smoke test -- build, launch, connect, ping, loadFile, captureWindow, quit -- and verify each step produces expected responses `[complexity:medium]`

    **Reference**: [design.md#t2-harness-smoke-test-req-001](design.md#t2-harness-smoke-test-req-001)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] `AppLauncher.launch()` builds and launches mkdn with --test-harness within 60 seconds (AC-001a)
    - [ ] `TestHarnessClient.ping()` returns a successful pong response (AC-001b)
    - [ ] `TestHarnessClient.loadFile(path:)` loads a fixture and receives a success response with render completion signal (AC-001c)
    - [ ] `TestHarnessClient.captureWindow(outputPath:)` produces a PNG with non-zero dimensions at Retina 2x scale (AC-001d)
    - [ ] Captured PNG is loadable by ImageAnalyzer and contains real pixel data, not blank/black (AC-001e)
    - [ ] `TestHarnessClient.quit()` terminates the app cleanly (AC-001f)
    - [ ] Any infrastructure fixes applied are documented in field notes with symptom, cause, and resolution (BR-004)

### Suite Execution

- [ ] **T3**: Run spatial compliance suite (16 tests), validate calibration gate, diagnose and fix infrastructure failures, categorize compliance failures as pre-migration gaps or genuine bugs `[complexity:medium]`

    **Reference**: [design.md#t3-spatial-compliance-suite----execute-diagnose-fix-req-002-partial-req-003-req-006-partial](design.md#t3-spatial-compliance-suite----execute-diagnose-fix-req-002-partial-req-003-req-006-partial)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] Spatial calibration test passes: content bounds detected, vertical gaps measured, accuracy within 1pt (AC-002a)
    - [ ] All 16 spatial tests execute without infrastructure errors -- no socket timeouts, capture failures, image load failures, or index-out-of-bounds (AC-003a)
    - [ ] Calibration-dependent tests are correctly gated: skipped if calibration fails, not crashed (AC-003b)
    - [ ] Passing tests confirm measured spatial values within 1pt of expected (AC-003c)
    - [ ] Failing tests produce diagnostic messages with measured value, expected value, tolerance, and spatial-design-language FR reference (AC-003d)
    - [ ] Pre-migration gaps (e.g., 24pt actual vs 32pt PRD document margin) are documented with migration comments (AC-003e, CL-001)
    - [ ] Infrastructure fixes are minimal, preserve existing architecture, and are documented (AC-006a, AC-006b, AC-006e, BR-003, BR-004)
    - [ ] Tolerance adjustments (if any) are justified by empirical measurement across multiple captures (BR-005)

- [ ] **T4**: Run visual compliance suite (12 tests), validate calibration gate and theme switching, diagnose and fix infrastructure failures, verify color sampling accuracy `[complexity:medium]`

    **Reference**: [design.md#t4-visual-compliance-suite----execute-diagnose-fix-req-002-partial-req-004-req-006-partial](design.md#t4-visual-compliance-suite----execute-diagnose-fix-req-002-partial-req-004-req-006-partial)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [ ] Visual calibration test passes: background color sampled from live capture matches ThemeColors.background (AC-002b)
    - [ ] All 12 visual tests execute without infrastructure errors (AC-004a)
    - [ ] Theme switching works: captures after setTheme("solarizedDark") and setTheme("solarizedLight") show distinct backgrounds matching ThemeColors (AC-004b)
    - [ ] Background color tests pass for both themes within configured tolerance (AC-004c)
    - [ ] Text color tests sample from text regions, not background (AC-004d)
    - [ ] Syntax token tests detect at least 2 of 3 expected token colors in code block regions (AC-004e)
    - [ ] Infrastructure fixes are minimal, documented with symptom/cause/resolution (AC-006a, AC-006b, AC-006e)

- [ ] **T5**: Run animation compliance suite (13 tests), validate calibration gate (frame capture + crossfade timing), diagnose ScreenCaptureKit issues, verify animation parameter extraction from real frame sequences `[complexity:complex]`

    **Reference**: [design.md#t5-animation-compliance-suite----execute-diagnose-fix-req-002-partial-req-005-req-006-partial](design.md#t5-animation-compliance-suite----execute-diagnose-fix-req-002-partial-req-005-req-006-partial)

    **Effort**: 10 hours

    **Acceptance Criteria**:

    - [ ] Animation calibration passes both phases: frame capture infrastructure delivers frames at target FPS, and crossfade timing measurement is within 1 frame of expected 0.35s (AC-002c, AC-005a)
    - [ ] ScreenCaptureKit SCStream captures frame sequences at 30fps and 60fps (AC-005b)
    - [ ] Captured frames contain real pixel data reflecting mkdn window content, not blank/black (AC-005c)
    - [ ] Breathing orb test produces meaningful pulse analysis: detects ~12 CPM or provides diagnostic failure with measured CPM (AC-005d)
    - [ ] Fade duration tests (crossfade, fadeIn, fadeOut) measure within configured tolerance of AnimationConstants, or produce diagnostic failures with measured vs expected (AC-005e)
    - [ ] Reduce Motion tests detect orb stationarity and reduced transition durations when RM override is enabled (AC-005f)
    - [ ] Infrastructure fixes preserve existing architecture and are documented (AC-006a, AC-006b, AC-006e)
    - [ ] Timing/tolerance adjustments are justified by empirical measurement (BR-005)

### Report Validation

- [ ] **T6**: Validate JSON report at `.build/test-results/mkdn-ui-test-report.json` -- verify structure, completeness, PRD references, failure diagnostics, image paths, and coverage accuracy `[complexity:simple]`

    **Reference**: [design.md#t6-json-report-validation-req-007](design.md#t6-json-report-validation-req-007)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [ ] Report file exists at `.build/test-results/mkdn-ui-test-report.json` after test run (AC-007a)
    - [ ] Report is valid JSON parseable by standard tools (AC-007b)
    - [ ] `totalTests` matches the number of tests that actually executed (AC-007c)
    - [ ] Each TestResult has a non-empty `prdReference` field (AC-007d)
    - [ ] Failed results have `expected` and `actual` fields with meaningful values (AC-007e)
    - [ ] Image paths in results point to files that exist on disk (AC-007f)
    - [ ] Coverage section contains entries for spatial-design-language, animation-design-language, and automated-ui-testing PRDs with accurate coveredFRs counts (AC-007g)
    - [ ] JSONResultReporter or PRDCoverageTracker are fixed if report is incomplete or malformed

### Verification and Documentation

- [ ] **T7**: Compile compliance baseline -- total tests, pass/fail counts, failure categories (infrastructure fix, pre-migration gap, genuine bug), and pre-migration gap details with PRD references and measured values `[complexity:simple]`

    **Reference**: [design.md#t7-compliance-baseline-documentation-req-008](design.md#t7-compliance-baseline-documentation-req-008)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [ ] Baseline summary documents total tests, passing count, failing count, and category of each failure (AC-008a)
    - [ ] Pre-migration gaps listed with: test name, PRD reference, expected value, measured value, and migration dependency (AC-008b)
    - [ ] Baseline recorded in field notes at `.rp1/work/features/automated-ui-testing/field-notes.md` (AC-008c)

- [ ] **T8**: Run `swift test --filter UITest` 3 consecutive times, compare pass/fail results, flag flaky tests, diagnose root causes, fix or document mitigation `[complexity:medium]`

    **Reference**: [design.md#t8-determinism-verification-req-010](design.md#t8-determinism-verification-req-010)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] 3 consecutive runs produce identical pass/fail results for every test (AC-010a)
    - [ ] Any flaky test has root cause diagnosed: timing race, tolerance too tight, render non-determinism (AC-010b)
    - [ ] Flaky tests are either fixed (if minimal) or documented with mitigation plan (AC-010c)
    - [ ] Tolerance adjustments for flakiness are justified by observed variance across runs (BR-005)

- [ ] **T9**: Demonstrate complete agent workflow loop -- run suite via CLI, parse JSON report, identify failing test, trace to PRD requirement, make targeted fix, re-run, confirm fix `[complexity:medium]`

    **Reference**: [design.md#t9-agent-workflow-validation-req-009](design.md#t9-agent-workflow-validation-req-009)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [ ] Agent runs `swift test --filter UITest` and receives structured output (AC-009a)
    - [ ] Agent reads JSON report and identifies at least one failing test with PRD reference, expected value, and actual value (AC-009b)
    - [ ] Agent makes a targeted change (code fix or tolerance adjustment) based on failure diagnostic (AC-009c)
    - [ ] Re-running the specific test confirms the change resolved the failure (AC-009d)

### User Docs

- [ ] **TD1**: Update patterns.md - UI Test Pattern with validated tolerances and discovered gotchas `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: UI Test Pattern

    **KB Source**: patterns.md:UI Test Pattern

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] UI Test Pattern section reflects empirically validated tolerance values
    - [ ] Any gotchas discovered during validation are documented

- [ ] **TD2**: Update architecture.md - Test Harness Mode with empirically validated behavior and timing adjustments `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Test Harness Mode

    **KB Source**: architecture.md:Test Harness Mode

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Test Harness Mode section reflects empirically validated behavior
    - [ ] Any timing adjustments made during validation are documented

- [ ] **TD3**: Update docs/ui-testing.md - Tolerances and Known Issues sections `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `docs/ui-testing.md`

    **Section**: Tolerances, Known Issues

    **KB Source**: -

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Tolerance values updated if adjusted during validation
    - [ ] Known Issues section added with any discovered issues

## Acceptance Criteria Checklist

### REQ-001: Test Harness Smoke Test
- [ ] AC-001a: AppLauncher.launch() builds and launches mkdn with --test-harness within 60 seconds
- [ ] AC-001b: TestHarnessClient.ping() returns successful pong response
- [ ] AC-001c: TestHarnessClient.loadFile(path:) loads fixture with render completion signal
- [ ] AC-001d: captureWindow produces PNG at Retina 2x with non-zero dimensions
- [ ] AC-001e: Captured PNG is valid, loadable, and contains real content
- [ ] AC-001f: quit() terminates app cleanly

### REQ-002: Calibration Gate Validation
- [ ] AC-002a: Spatial calibration passes (measurement accuracy within 1pt)
- [ ] AC-002b: Visual calibration passes (background color matches ThemeColors)
- [ ] AC-002c: Animation calibration passes (frame capture + crossfade timing within 1 frame)

### REQ-003: Spatial Compliance Suite
- [ ] AC-003a: All 16 spatial tests execute without infrastructure errors
- [ ] AC-003b: Calibration-dependent tests correctly gated
- [ ] AC-003c: Passing tests confirm values within 1pt tolerance
- [ ] AC-003d: Failing tests produce diagnostic messages with measured/expected/tolerance/FR reference
- [ ] AC-003e: Pre-migration gaps identified and documented

### REQ-004: Visual Compliance Suite
- [ ] AC-004a: All 12 visual tests execute without infrastructure errors
- [ ] AC-004b: Theme switching produces distinct captures matching ThemeColors
- [ ] AC-004c: Background color tests pass for both themes
- [ ] AC-004d: Text color tests sample from text regions
- [ ] AC-004e: Syntax token tests detect at least 2 of 3 expected token colors

### REQ-005: Animation Compliance Suite
- [ ] AC-005a: Animation calibration passes both phases
- [ ] AC-005b: SCStream captures at 30fps and 60fps
- [ ] AC-005c: Captured frames contain real pixel data
- [ ] AC-005d: Breathing orb test produces meaningful pulse analysis
- [ ] AC-005e: Fade duration tests within configured tolerance or produce diagnostics
- [ ] AC-005f: Reduce Motion tests detect stationarity and reduced durations

### REQ-006: Infrastructure Failure Diagnosis and Repair
- [ ] AC-006a: Each infrastructure failure has root cause description
- [ ] AC-006b: Fixes are minimal and targeted
- [ ] AC-006c: Harness smoke test passes after fixes
- [ ] AC-006d: All three calibration gates pass after fixes
- [ ] AC-006e: Fixes documented in field notes

### REQ-007: JSON Report Validation
- [ ] AC-007a: Report file exists at expected path
- [ ] AC-007b: Report is valid JSON
- [ ] AC-007c: totalTests matches executed count
- [ ] AC-007d: Each result has non-empty prdReference
- [ ] AC-007e: Failed results have meaningful expected/actual values
- [ ] AC-007f: Image paths point to existing files
- [ ] AC-007g: Coverage section has accurate PRD entries

### REQ-008: Compliance Baseline Documentation
- [ ] AC-008a: Baseline summary with totals and failure categories
- [ ] AC-008b: Pre-migration gaps listed with full details
- [ ] AC-008c: Baseline recorded in field notes

### REQ-009: Agent Workflow Validation
- [ ] AC-009a: Agent runs suite and receives structured output
- [ ] AC-009b: Agent identifies failing test from JSON report
- [ ] AC-009c: Agent makes targeted change based on diagnostic
- [ ] AC-009d: Re-run confirms fix

### REQ-010: Test Determinism Verification
- [ ] AC-010a: 3 consecutive runs produce identical results
- [ ] AC-010b: Flaky test root causes diagnosed
- [ ] AC-010c: Flaky tests fixed or documented with mitigation

## Definition of Done

- [ ] All tasks completed
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] Docs updated
