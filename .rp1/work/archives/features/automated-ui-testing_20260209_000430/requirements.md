# Requirements Specification: Automated UI Testing -- End-to-End Validation

**Feature ID**: automated-ui-testing
**Parent PRD**: [Automated UI Testing](../../prds/automated-ui-testing.md)
**Version**: 2.0.0
**Status**: Draft
**Created**: 2026-02-08

## 1. Feature Overview

End-to-end validation of the automated UI testing infrastructure built in the previous iteration. The prior build implemented the complete test harness, compliance suites, and analysis tools but could not actually run the UI tests because Screen Recording permission was not enabled. Screen Recording is now enabled. This iteration focuses on executing the full test infrastructure for the first time, diagnosing and fixing any failures, verifying that the system can autonomously validate mkdn's visual rendering against the animation-design-language, spatial-design-language, and cross-element-selection PRDs, and confirming the end-to-end agent workflow (modify, build, test, parse results, iterate) functions as designed.

## 2. Business Context

### 2.1 Problem Statement

The previous iteration built a comprehensive automated UI testing infrastructure (41 UI compliance tests across 3 suites, a process-based test harness, image analysis libraries, frame sequence capture via ScreenCaptureKit, and structured JSON reporting). However, the entire infrastructure was built and code-reviewed without Screen Recording permission enabled. This means:

- No compliance test has ever actually captured a window or verified a visual assertion against a live render.
- Calibration gates (which verify measurement accuracy before running compliance assertions) have never passed in a real environment.
- Animation frame capture via ScreenCaptureKit has never been exercised against a live application.
- The render completion signal has never been validated under real rendering conditions.
- Test determinism (same inputs produce same results) has never been verified.
- The JSON report output has never been generated from a real test run.

The infrastructure exists in code but has zero empirical validation. It is untested testing infrastructure.

### 2.2 Business Value

- **Infrastructure confidence**: Running the full suite for the first time with Screen Recording enabled will reveal whether the architecture actually works -- socket communication, render completion timing, window capture, image analysis, frame sequence capture, and compliance assertions.
- **Design system enforcement**: Once validated, the test suite becomes an active contract that enforces the animation-design-language, spatial-design-language, and visual compliance specifications on every code change.
- **Agent autonomy**: The charter's design philosophy demands "obsessive attention to sensory detail." A working test infrastructure lets an AI coding agent verify that attention programmatically, enabling autonomous iteration on visual quality without human visual inspection for each change.
- **Regression safety net**: Future work (spatial-design-language migration, cross-element-selection NSTextView migration) will change rendering significantly. A validated test suite provides confidence that these migrations preserve design intent.

### 2.3 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Calibration pass rate | All 3 calibration gates pass (spatial, visual, animation) | First successful run of each calibration test |
| Compliance suite execution | All 41 UI compliance tests execute (pass or fail with meaningful assertions, not infrastructure errors) | `swift test --filter UITest` completes with zero crash/timeout failures |
| End-to-end agent workflow | An AI agent can run the suite, parse JSON output, identify a failure, make a targeted fix, re-run, and confirm the fix | One complete modify-build-test-verify cycle |
| Test determinism | 3 consecutive runs produce identical pass/fail results | Zero flaky tests across 3 runs |
| JSON report generation | Valid JSON report written to `.build/test-results/mkdn-ui-test-report.json` from a real test run | Report contains results for all executed tests with captured image paths |
| PRD coverage report | Coverage report shows which design-system PRD FRs have passing tests | Report embedded in JSON output under `coverage` key |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Primary Needs |
|-----------|-------------|---------------|
| AI Coding Agent | Claude Code operating in a modify-build-test-verify loop. The primary consumer of the validated test infrastructure. | Confidence that test results reflect actual rendering reality. Structured output that enables autonomous iteration. Fast turnaround. |
| Human Developer | The project creator who needs confidence that the test infrastructure works before relying on it for design-system enforcement. | Clear diagnostic output when tests fail. Understanding of which failures are infrastructure issues vs genuine design violations. Confidence in test determinism. |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project creator | Validated testing infrastructure that can be trusted for ongoing design-system enforcement. Confidence that passing tests mean correct rendering and failing tests mean genuine violations. |
| Design-system PRDs | Their functional requirements become empirically verified contracts (not just code that claims to verify but has never run). |

## 4. Scope Definition

### 4.1 In Scope

- Execute all 3 compliance suites (spatial, visual, animation) with Screen Recording enabled for the first time
- Diagnose and fix infrastructure failures revealed by first real execution (socket communication, render timing, capture reliability, image analysis accuracy)
- Validate calibration gates: spatial measurement accuracy within 1pt at Retina, color sampling accuracy, and animation timing accuracy within 1 frame
- Validate the test harness end-to-end: AppLauncher builds and launches mkdn with --test-harness, TestHarnessClient connects via Unix domain socket, commands execute and return responses, RenderCompletionSignal fires after rendering
- Validate window capture: CGWindowListCreateImage produces Retina-resolution PNGs with correct metadata
- Validate frame sequence capture: ScreenCaptureKit SCStream delivers frames at target FPS without dropped frames
- Validate image analysis: ImageAnalyzer, SpatialMeasurement, and ColorExtractor produce accurate measurements against live renders
- Validate animation analysis: FrameAnalyzer correctly detects pulse frequency, transition duration, spring curves, and stagger delays from real frame sequences
- Validate JSON report output: JSONResultReporter writes valid, complete report with PRD-anchored results and coverage data
- Fix genuine compliance failures (test expectations that do not match actual rendering) by either correcting the test expectations to match design intent or identifying rendering bugs to be addressed
- Verify test determinism across consecutive runs
- Validate the agent workflow: run suite via CLI, parse JSON output, identify a failure, trace it to a PRD requirement

### 4.2 Out of Scope

- Writing new compliance tests beyond the existing 41 (the test inventory is complete; this iteration validates it)
- Implementing new design-system features (SpacingConstants migration, NSTextView migration)
- Performance benchmarking (GPU utilization, rendering frame rate)
- New harness commands (Mermaid focus activation is a known gap, not addressed here)
- CI environment setup or validation (local development with Screen Recording is the target)
- Changes to the test harness architecture (socket protocol, command schema, capture mechanisms)

### 4.3 Assumptions

| ID | Assumption | Fallback if Wrong |
|----|------------|-------------------|
| A-1 | Screen Recording permission is now enabled for the terminal/IDE process running `swift test` | Re-grant permission in System Settings > Privacy & Security > Screen Recording. Verify with a manual CGWindowListCreateImage test. |
| A-2 | The existing test infrastructure code (built in prior iteration) is structurally sound and failures will be in calibration/timing/tolerance rather than fundamental architecture | If socket communication or render signaling is fundamentally broken, this iteration becomes a deeper infrastructure repair effort. Scope accordingly. |
| A-3 | Test fixture files (canonical.md, geometry-calibration.md, long-document.md, mermaid-focus.md, theme-tokens.md) are present in mkdnTests/Fixtures/UITest/ | Fixtures were committed in the prior iteration. If missing, regenerate from the archived task descriptions. |
| A-4 | The mkdn application builds and runs correctly in --test-harness mode | Build issues are blocking and must be resolved before any test validation can proceed. |
| A-5 | Current render output may not match all PRD-specified values (e.g., document margin is 24pt in code but 32pt in spatial-design-language PRD) because the spatial-design-language migration has not been done | Compliance failures against un-migrated values are expected and should be documented, not fixed in this iteration. The goal is to validate infrastructure, not enforce pre-migration compliance. |

## 5. Functional Requirements

### REQ-001: Test Harness Smoke Test
- **Priority**: Must Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: Verify that the test harness infrastructure functions end-to-end: AppLauncher builds mkdn, launches it with --test-harness, TestHarnessClient connects via Unix domain socket, a ping command receives a pong response, a loadFile command loads a test fixture and signals render completion, a captureWindow command produces a PNG image at Retina resolution, and quit terminates the app cleanly.
- **Rationale**: The entire test infrastructure depends on the harness working. This has never been validated with Screen Recording enabled. A smoke test isolates infrastructure issues from compliance logic.
- **Acceptance Criteria**:
  - AC-001a: `AppLauncher.launch()` successfully builds and launches mkdn with --test-harness within 60 seconds.
  - AC-001b: `TestHarnessClient.ping()` returns a successful pong response.
  - AC-001c: `TestHarnessClient.loadFile(path:)` loads a fixture and the client receives a success response (render completion signal fires).
  - AC-001d: `TestHarnessClient.captureWindow(outputPath:)` produces a PNG file at the specified path with non-zero dimensions and a Retina scale factor (2x).
  - AC-001e: The captured PNG is a valid image that can be loaded by ImageAnalyzer and has pixel data (not a blank/black image).
  - AC-001f: `TestHarnessClient.quit()` terminates the app and AppLauncher cleanup succeeds.

### REQ-002: Calibration Gate Validation
- **Priority**: Must Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: All three calibration gates must pass, confirming that measurement infrastructure is accurate before any compliance assertion runs. Spatial calibration must verify measurement accuracy within 1pt at Retina resolution. Visual calibration must verify background color sampling matches ThemeColors exactly. Animation calibration must verify frame capture infrastructure functions and crossfade timing measurement is accurate within 1 frame at 30fps.
- **Rationale**: Calibration gates are the trust foundation. If they fail, compliance results are meaningless. These have never been validated against a live render.
- **Acceptance Criteria**:
  - AC-002a: Spatial calibration test (`test_spatialDesignLanguage_calibration`) passes: content bounds are detected, vertical gaps are measured, and measurements are accurate within 1pt.
  - AC-002b: Visual calibration test (`test_visualCompliance_calibration`) passes: background color sampled from a live capture matches the ThemeColors.background RGB value for the active theme.
  - AC-002c: Animation calibration test (`test_animationDesignLanguage_calibration`) passes both phases: (1) frame capture infrastructure delivers frames at target FPS with loadable images, and (2) crossfade timing measurement is within 1 frame (33.3ms at 30fps) of expected 0.35s.

### REQ-003: Spatial Compliance Suite Execution
- **Priority**: Must Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: Execute the full spatial compliance suite (16 tests) against live renders and produce meaningful results. Each test must either pass (measurement matches expected value within tolerance) or fail with a diagnostic message that includes the expected value, measured value, and PRD reference. Infrastructure errors (capture failure, socket timeout, image analysis crash) must be diagnosed and resolved so that every test produces a compliance result, not an infrastructure error.
- **Rationale**: The spatial compliance suite verifies document margins, block spacing, heading spacing, component padding, window chrome insets, content max width, and grid alignment against the spatial-design-language PRD. These measurements have never been taken from a live render.
- **Acceptance Criteria**:
  - AC-003a: All 16 spatial compliance tests execute without infrastructure errors (socket timeout, capture failure, image load failure, index-out-of-bounds).
  - AC-003b: Calibration-dependent tests are correctly gated (skipped if calibration fails, not crashed).
  - AC-003c: Each passing test confirms the measured spatial value is within 1pt of the expected PRD value.
  - AC-003d: Each failing test produces a diagnostic message with: measured value, expected value, tolerance, and the specific spatial-design-language FR reference.
  - AC-003e: Failures that reflect un-migrated values (e.g., actual document margin is 24pt but expected is 32pt from spatial-design-language PRD) are identified and documented as pre-migration baseline, not bugs.

### REQ-004: Visual Compliance Suite Execution
- **Priority**: Must Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: Execute the full visual compliance suite (12 tests) against live renders for both Solarized Dark and Solarized Light themes. Each test must either pass (color matches expected value within tolerance) or fail with a diagnostic message. Theme switching via the harness must be validated (setTheme command changes the active theme and the capture reflects the new theme).
- **Rationale**: Visual compliance verifies background colors, heading text colors, body text colors, code block backgrounds, and syntax highlighting token colors against ThemeColors specifications. Color sampling from live renders has never been validated.
- **Acceptance Criteria**:
  - AC-004a: All 12 visual compliance tests execute without infrastructure errors.
  - AC-004b: Theme switching works correctly: captures taken after setTheme("solarizedDark") and setTheme("solarizedLight") show visually distinct background colors matching the respective ThemeColors.background values.
  - AC-004c: Background color tests pass for both themes (sampled color matches ThemeColors.background within configured tolerance).
  - AC-004d: Text color tests (heading, body) produce meaningful results (color sampled from text regions, not background).
  - AC-004e: Syntax token tests detect at least 2 of 3 expected token colors (keyword, string, type) in code block regions.

### REQ-005: Animation Compliance Suite Execution
- **Priority**: Must Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: Execute the full animation compliance suite (13 tests) against live renders using ScreenCaptureKit frame capture. Validate that frame sequences are captured at target FPS, that FrameAnalyzer correctly extracts animation parameters from real frame data, and that each test produces a meaningful compliance result against AnimationConstants specifications.
- **Rationale**: Animation compliance is the highest-risk area. ScreenCaptureKit frame capture has never been exercised against a live mkdn instance. Frame analysis algorithms (pulse detection, transition duration, spring curve fitting, stagger delay measurement) have only been tested against synthetic data in unit tests. Real-world frame sequences will have noise, timing jitter, and visual complexity not present in synthetic tests.
- **Acceptance Criteria**:
  - AC-005a: Animation calibration passes both phases (frame capture infrastructure + crossfade timing accuracy).
  - AC-005b: ScreenCaptureKit SCStream successfully captures frame sequences from the mkdn window at 30fps and 60fps.
  - AC-005c: Captured frames are valid images with pixel data that reflects the mkdn window content (not blank/black frames).
  - AC-005d: Breathing orb test produces a meaningful pulse analysis (either detecting the expected ~12 CPM rhythm or producing a diagnostic failure with measured CPM).
  - AC-005e: Fade duration tests (crossfade, fadeIn, fadeOut) produce measured durations within the configured tolerance of AnimationConstants values, or diagnostic failures with measured vs expected.
  - AC-005f: Reduce Motion tests correctly detect orb stationarity and reduced transition durations when the RM override is enabled via the harness.

### REQ-006: Infrastructure Failure Diagnosis and Repair
- **Priority**: Must Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: When first-run execution reveals infrastructure failures (as opposed to genuine compliance failures), diagnose the root cause and apply targeted fixes. Infrastructure failures include: socket connection timeouts, render completion signal never firing, CGWindowListCreateImage returning nil or blank images, ScreenCaptureKit permission errors or blank frames, image analysis crashes or measurement errors, and test framework errors. Each fix must preserve the existing test architecture and be minimal in scope.
- **Rationale**: The prior iteration built the infrastructure without being able to run it. First execution will almost certainly reveal issues that code review alone could not catch -- timing races, permission issues, coordinate system mismatches, tolerance values that are too tight or too loose for real-world rendering.
- **Acceptance Criteria**:
  - AC-006a: Each infrastructure failure encountered is diagnosed with a root cause description.
  - AC-006b: Each fix is minimal and targeted -- no architectural redesigns, only the changes needed to make the existing design work.
  - AC-006c: After fixes, the harness smoke test (REQ-001) passes cleanly.
  - AC-006d: After fixes, all three calibration gates (REQ-002) pass.
  - AC-006e: Fixes are documented in field notes with the failure symptom, root cause, and resolution.

### REQ-007: JSON Report Validation
- **Priority**: Must Have
- **User Type**: AI Coding Agent
- **Requirement**: After a real test run, verify that the JSON report at `.build/test-results/mkdn-ui-test-report.json` contains valid, complete, and useful data: all executed tests appear in the results array, each result has the correct status (pass/fail), failure descriptions include PRD references with expected and actual values, captured image paths point to real files on disk, and the PRD coverage report accurately reflects which FRs have test coverage.
- **Rationale**: The JSON report is the primary interface between the test infrastructure and the AI coding agent. If the report is incomplete, malformed, or missing data, the agent cannot use it for autonomous iteration. Report generation has never been validated with real test data.
- **Acceptance Criteria**:
  - AC-007a: Report file exists at `.build/test-results/mkdn-ui-test-report.json` after a test run.
  - AC-007b: Report is valid JSON parseable by standard tools.
  - AC-007c: `totalTests` matches the number of tests that actually executed.
  - AC-007d: Each `TestResult` has a non-empty `prdReference` field.
  - AC-007e: Failed results have `expected` and `actual` fields with meaningful values (not empty strings or placeholders).
  - AC-007f: Image paths in results (if any) point to files that exist on disk.
  - AC-007g: `coverage` section contains entries for spatial-design-language, animation-design-language, and automated-ui-testing PRDs with accurate coveredFRs counts.

### REQ-008: Compliance Baseline Documentation
- **Priority**: Must Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: After the first successful full-suite run, document the baseline compliance state: which tests pass, which fail, and why. Separate failures into two categories: (1) infrastructure issues that were fixed during this iteration, and (2) genuine compliance gaps where the current rendering does not match PRD specifications (expected because the spatial-design-language migration has not been done). This baseline becomes the starting point for future design-system work.
- **Rationale**: The first real test run establishes ground truth. Without a documented baseline, future test results have no reference point. The distinction between "infrastructure issue" and "pre-migration compliance gap" is critical for prioritizing work.
- **Acceptance Criteria**:
  - AC-008a: A baseline summary documents: total tests, passing count, failing count, and the category of each failure (infrastructure fix applied, pre-migration gap, genuine bug).
  - AC-008b: Pre-migration compliance gaps are listed with: the test name, PRD reference, expected value (from PRD), actual measured value (from current rendering), and the migration that will address it.
  - AC-008c: The baseline is recorded in field notes for reference by future iterations.

### REQ-009: Agent Workflow Validation
- **Priority**: Should Have
- **User Type**: AI Coding Agent
- **Requirement**: Demonstrate the complete agent iteration workflow: (1) run the test suite via CLI, (2) parse the JSON report, (3) identify a specific failing test, (4) trace the failure to a PRD requirement, (5) determine what code or test-expectation change would address the failure, (6) make the change, (7) re-run the affected test, (8) confirm the failure is resolved. This validates the closed loop that the entire testing infrastructure was designed to enable.
- **Rationale**: The ultimate purpose of the test infrastructure is agent autonomy -- an AI coding agent making visual quality decisions based on structured test output. If the workflow does not function end-to-end, the infrastructure has not achieved its goal.
- **Acceptance Criteria**:
  - AC-009a: The agent runs `swift test --filter UITest` (or a specific suite filter) and receives structured output.
  - AC-009b: The agent reads the JSON report and identifies at least one failing test with its PRD reference, expected value, and actual value.
  - AC-009c: The agent makes a targeted change (code fix or tolerance adjustment) based on the failure diagnostic.
  - AC-009d: Re-running the specific test confirms the change resolved the failure.

### REQ-010: Test Determinism Verification
- **Priority**: Should Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: Run the full compliance suite 3 consecutive times and verify that all tests produce identical pass/fail results across all runs. Any test that flips between pass and fail across runs is flagged as flaky, and the source of non-determinism is diagnosed.
- **Rationale**: Flaky tests undermine agent confidence. If a test passes on one run and fails on the next with identical code, the agent cannot trust the results to make code change decisions. Determinism has never been verified because the tests have never run.
- **Acceptance Criteria**:
  - AC-010a: 3 consecutive runs of `swift test --filter UITest` produce identical pass/fail results for every test.
  - AC-010b: Any flaky test identified during verification has its root cause diagnosed (timing race, tolerance too tight, render non-determinism).
  - AC-010c: Flaky tests are either fixed (if the fix is minimal) or documented with a mitigation plan.

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| Expectation | Target |
|-------------|--------|
| Harness smoke test (REQ-001) | Under 30 seconds including build, launch, connect, capture, and quit |
| Individual compliance suite | Under 90 seconds per suite (spatial, visual, animation) |
| Full compliance run (all 3 suites) | Under 5 minutes wall-clock time |
| Frame capture at 30/60fps | No dropped frames; captured frame count within 10% of expected (fps * duration) |

### 6.2 Security Requirements

- Screen Recording permission must be granted to the terminal or IDE process running `swift test`. This is a standard development permission, not an elevated privilege.
- No other special security requirements beyond what the prior iteration documented.

### 6.3 Usability Requirements

- When a test fails, the failure message alone (without reading source code) must be sufficient for a developer or agent to understand: what was tested, what was expected, what was measured, and which PRD requirement was violated.
- Captured images from failing tests must be persisted at a known path for visual inspection by the developer.

### 6.4 Compliance Requirements

- Spatial measurement accuracy: within 1pt at Retina resolution (verified by calibration gate).
- Color measurement accuracy: within configured tolerance (10 for background, 15 for text, 25 for syntax tokens).
- Animation timing accuracy: within 1 frame at capture framerate (33.3ms at 30fps, 16.7ms at 60fps).

## 7. User Stories

### STORY-001: First Real Test Run

**As a** human developer
**I want to** run the full UI compliance suite for the first time with Screen Recording enabled
**So that** I can see whether the testing infrastructure I built actually works against live renders

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN Screen Recording permission is enabled for the terminal process
- WHEN the developer runs `swift test --filter UITest`
- THEN all 41 tests execute (some may fail, but none crash or timeout due to infrastructure errors), and a JSON report is written with results for every test

### STORY-002: Agent Identifies and Fixes a Compliance Issue

**As an** AI coding agent
**I want to** run the spatial compliance suite, identify a failing margin test, adjust a tolerance or expected value, and re-run to confirm the fix
**So that** I can demonstrate autonomous visual quality iteration

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN the spatial compliance suite has a test that fails because the current document margin (24pt) does not match the PRD-specified value (32pt)
- WHEN the agent parses the JSON report, identifies the failure as a pre-migration gap, and adjusts the test's expected value to match the current implementation (with a migration comment)
- THEN re-running the spatial compliance suite shows the adjusted test passes

### STORY-003: Developer Inspects Captured Images

**As a** human developer
**I want to** view the captured PNG images from a test run
**So that** I can visually confirm that the test infrastructure is capturing real window content, not blank or corrupted images

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN the compliance suite has executed and captured window images
- WHEN the developer opens the PNG files at the paths listed in the JSON report
- THEN the images show recognizable mkdn window content (Markdown text, code blocks, headings) at Retina resolution

### STORY-004: Diagnosing a Flaky Animation Test

**As a** human developer
**I want to** identify why an animation timing test passes on one run but fails on the next
**So that** I can fix the non-determinism and trust animation compliance results

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN an animation test that produces different results across consecutive runs
- WHEN the developer examines the captured frame sequences from both runs
- THEN the root cause is identified (e.g., ScreenCaptureKit startup latency causes first N frames to be missed, or IPC delay between animation trigger and capture start introduces timing jitter)

## 8. Business Rules

| Rule ID | Rule | Source |
|---------|------|--------|
| BR-001 | Infrastructure failures must be fixed before compliance results are considered meaningful. A passing compliance test is only trustworthy if the calibration gate also passed. | Calibration-gate pattern from prior iteration |
| BR-002 | Pre-migration compliance gaps (where current rendering does not match PRD specs because the migration has not been done) are documented, not fixed by changing the rendering code. The tests may be adjusted to reflect current reality with migration comments. | Spatial-design-language PRD scope: call-site migration is a separate task |
| BR-003 | Test fixes must be minimal and preserve the existing architecture. This iteration validates the infrastructure, not redesigns it. | Scope constraint: no architectural changes |
| BR-004 | Every infrastructure fix must be documented in field notes with symptom, cause, and resolution. | Institutional knowledge preservation |
| BR-005 | Tolerance adjustments (spatial, color, animation) must be justified by empirical measurement, not guessed. If the configured tolerance is too tight, the new tolerance must be based on observed measurement variance across multiple runs. | Measurement integrity |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Type | Status | Impact |
|------------|------|--------|--------|
| Screen Recording permission | System permission | Now enabled | Required for CGWindowListCreateImage and ScreenCaptureKit. Without it, all capture-dependent tests fail. |
| Prior iteration code (T1-T11) | Infrastructure | Implemented, archived | All test harness, compliance suite, and analysis code from the prior iteration. 11 of 15 tasks completed. |
| animation-design-language PRD | Design specification | Complete | Animation compliance tests verify against these specs |
| spatial-design-language PRD | Design specification | Complete | Spatial compliance tests verify against these specs. SpacingConstants.swift is NOT yet implemented; tests use PRD literal values. |
| AnimationConstants.swift | Source of truth (code) | Implemented | Animation test expected values reference these constants |
| ThemeColors (via getThemeColors command) | Source of truth (code) | Implemented | Visual test expected values reference theme colors returned by the harness |
| Test fixture files | Test data | Committed | 5 Markdown fixtures in mkdnTests/Fixtures/UITest/ |
| docs/ui-testing.md | Documentation | Written | Documents architecture, commands, tolerances, and CI setup |

### Constraints

| Constraint | Impact |
|------------|--------|
| No architectural changes to the test infrastructure | Fixes must work within the existing socket-based harness, CGWindowListCreateImage capture, ScreenCaptureKit frame capture, and image analysis approach. |
| Pre-migration spatial values | The current rendering uses hardcoded spacing values (e.g., 24pt document margin) that differ from the spatial-design-language PRD specs (32pt). Spatial compliance tests may fail against PRD values. The response is to document the gap, not change the rendering code. |
| ScreenCaptureKit permission prompt | First use of ScreenCaptureKit may trigger a macOS permission dialog. This must be accepted for frame capture to function. |
| Window server requirement | Tests must run in a GUI session with a window server. Cannot run in a headless SSH session. |
| Retina display assumption | All spatial measurements assume 2x Retina scale factor. Running on a non-Retina display would invalidate spatial assertions. |

## 10. Clarifications Log

| ID | Question | Resolution | Source |
|----|----------|------------|--------|
| CL-001 | Should failing spatial tests be updated to match current rendering or left as failures? | Tests that fail due to un-migrated spacing values should be documented as pre-migration baseline gaps. Test expected values may be adjusted to current rendering with migration comments (e.g., "// Current: 24pt. Target: SpacingConstants.documentMargin (32pt) after spatial-design-language migration"). | Discussion with user: focus is on validating infrastructure, not enforcing pre-migration compliance |
| CL-002 | How many consecutive runs are needed to verify determinism? | 3 runs (reduced from the prior iteration's 10-run target). The priority is validating that the infrastructure works at all; extensive determinism testing can follow. | Pragmatic scope for this iteration |
| CL-003 | What is the priority ordering for the three compliance suites? | Spatial first (simplest capture: single static image), then Visual (theme switching adds complexity), then Animation (frame sequence capture is highest risk). | Risk-based ordering |
| CL-004 | Should tolerance values be adjusted proactively or only in response to failures? | Only in response to failures. Start with the configured tolerances from the prior iteration (spatial: 1pt, color: 10/15/25, animation: 1 frame). Adjust only if empirical measurement shows they are too tight, and document the justification. | BR-005: tolerance adjustments must be empirically justified |
