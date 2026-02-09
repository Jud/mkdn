# Requirements Specification: Automated UI Testing

**Feature ID**: automated-ui-testing
**Parent PRD**: [Automated UI Testing](../../prds/automated-ui-testing.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-08

## 1. Feature Overview

Automated UI testing infrastructure that enables AI coding agents and the human developer to programmatically launch mkdn, exercise all user-facing interactions, capture rendered output as images and frame sequences, and verify that the visual result complies with the spatial, visual, and animation design specifications defined across the project's design-system PRDs. The system closes a tight iteration loop: an agent modifies rendering or design code, builds, runs the test suite, receives structured pass/fail output anchored to specific PRD requirements, and either proceeds or adjusts -- all without manual visual inspection.

## 2. Business Context

### 2.1 Problem Statement

mkdn's charter demands "obsessive attention to sensory detail" across every visual and interactive element. The project has three design-system PRDs (animation-design-language, spatial-design-language, cross-element-selection) that specify precise timing curves, spacing constants, color values, and layout rules. Currently, there is no automated way to verify that the rendered application matches these specifications. Verification relies entirely on manual visual inspection by the developer, which is time-consuming, error-prone, inconsistent across iterations, and impossible for an AI coding agent to perform independently. As the design system grows in precision and the codebase evolves, the risk of undetected visual regressions increases with every change.

### 2.2 Business Value

- **Confidence in iteration**: The primary user (AI coding agent) can make rendering changes and immediately verify correctness, enabling faster and more reliable iteration cycles without human intervention for each visual check.
- **Design system enforcement**: Design specifications in PRDs become testable contracts rather than aspirational documentation. Spacing, color, and animation values are verified against their source-of-truth constants.
- **Regression prevention**: Visual regressions introduced by code changes are caught before they reach the developer, reducing the manual review burden and protecting the accumulated design quality.
- **Daily-driver readiness**: The charter's success criterion is "personal daily-driver use." Automated visual verification provides confidence that the application maintains the quality bar required for daily-driver status across ongoing development.

### 2.3 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Design-system PRD FR coverage | 80% of spatial-design-language and animation-design-language FRs have at least one automated test | PRD coverage report output by the test suite |
| Agent iteration autonomy | An AI coding agent can complete a modify-build-test-verify cycle without human visual inspection | Successful end-to-end agent workflow completing 3+ iterations on a visual change |
| Spatial measurement accuracy | Margin, spacing, and padding measurements accurate to within 1pt at Retina resolution | Calibration test against known-geometry test fixture |
| Animation timing accuracy | Timing curve measurements accurate to within one frame at the capture framerate | Calibration test against known-duration animation |
| Test determinism | Same inputs produce same pass/fail results across consecutive runs | Zero flaky test failures over 10 consecutive runs of the full suite |
| Test execution time | Full compliance suite completes in under 60 seconds | Wall-clock time from test invocation to structured output |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Primary Needs |
|-----------|-------------|---------------|
| AI Coding Agent | Claude Code or similar AI agent operating in a tight modify-build-test-verify loop. The primary consumer of the test infrastructure. | CLI-driven execution, structured JSON output with machine-parseable pass/fail results, PRD-anchored failure descriptions that enable targeted code fixes, fast turnaround. |
| Human Developer | The project creator who reviews test results, approves visual changes, debugs test failures, and maintains the test infrastructure. | Clear failure diagnostics with captured images, PRD references for every assertion, ability to run subsets of the suite, confidence that passing tests mean correct rendering. |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project creator | Confidence that the design system is faithfully implemented; reduced manual visual inspection burden; ability to delegate visual verification to an AI agent. |
| Design-system PRDs | Their functional requirements become enforceable contracts with automated verification. The animation-design-language, spatial-design-language, and cross-element-selection PRDs are the specifications being tested. |

## 4. Scope Definition

### 4.1 In Scope

- Programmatic control of the mkdn application (launch, mode switching, theme cycling, file reload, Mermaid focus activation, overlay dismissal)
- Capture of rendered window content as bitmap images at native Retina resolution with deterministic timing
- Region-of-interest capture for specific UI elements (code blocks, headings, Mermaid diagrams, orbs)
- Verification of spatial compliance: document margins, block spacing, heading spacing, component padding, window chrome insets, content max width, 8pt grid alignment
- Verification of visual compliance: background colors, text colors, syntax highlighting token colors, selection highlight colors, theme correctness for both Solarized Dark and Solarized Light
- Verification of animation timing: breathing orb sinusoidal rhythm, spring-settle curves, fade transition durations, content load stagger delay, Reduce Motion compliance
- Frame sequence capture at configurable framerates (30-60fps) for animation verification
- CLI-driven test execution producing structured JSON output with pass/fail per test, captured image paths, and PRD-anchored failure descriptions
- PRD-anchored test specifications where every test case traces to a specific PRD functional requirement
- Standardized Markdown test fixtures exercising all element types, checked into the repository
- Swift Testing integration for unit-level assertions alongside XCUITest for UI automation

### 4.2 Out of Scope

- Performance benchmarking (GPU utilization, frame rate measurement as a performance metric)
- Interactive or GUI-based visual diff tools (this is CLI-first, agent-driven)
- Cross-platform testing (macOS only per charter scope guardrails)
- User-facing test UI or in-app test runner
- Network-dependent tests (mkdn has no network features)
- Automated remediation (the agent interprets failures and decides fixes; the test infrastructure only reports)
- Testing of editor-pane text input behavior (typing, cursor movement, text selection within the editor)

### 4.3 Assumptions

| ID | Assumption | Fallback if Wrong |
|----|------------|-------------------|
| A-1 | CGWindowListCreateImage can reliably capture the mkdn window in both local development and CI environments with a window server session | Explore alternative capture mechanisms: Quartz Window Services, IOSurface, or app-side rendering to offscreen buffer |
| A-2 | XCUIApplication can reliably launch, control, and terminate the mkdn executable target despite its custom chromeless window style | Extensive stability testing in Phase 1; fallback to AppleScript-based control or accessibility API if XCUITest is unreliable with hiddenTitleBar windows |
| A-3 | Spatial measurements from captured Retina images can achieve 1pt accuracy using edge detection and color boundary analysis | Use high-contrast test fixtures with known geometry; expose layout metrics via debug accessibility API as an alternative measurement source |
| A-4 | 60fps frame capture provides sufficient temporal resolution to verify spring and fade animation timing curves | Increase capture framerate or use curve-fitting across many frames to compensate for temporal imprecision |
| A-5 | The two-framework split (XCUITest for UI control, Swift Testing for assertions) can coexist in coordinated test targets without build or runner conflicts | Separate into distinct targets with shared utility modules |
| A-6 | SpacingConstants.swift will be implemented (spatial-design-language Phase 1) before spatial compliance tests reference it | Spatial compliance tests initially use hardcoded expected values matching the PRD specs, migrated to SpacingConstants references when available |
| A-7 | The cross-element-selection NSTextView migration may change rendering architecture significantly, requiring animation tests to be architecture-agnostic (verifying visual output, not implementation) | Time animation verification after the cross-element-selection core phase is complete, or accept that some tests will need rewriting |

## 5. Functional Requirements

### REQ-001: Programmatic Application Control
- **Priority**: Must Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: The test infrastructure must provide a harness that can programmatically launch mkdn with a specified Markdown file, wait for stable render completion, switch between Preview and Edit modes, cycle themes, trigger file reload, open files, dismiss overlays and popovers, and activate/deactivate Mermaid diagram focus.
- **Rationale**: Without programmatic control, no automated testing is possible. The agent must be able to exercise all user-facing interactions to reach any testable state.
- **Acceptance Criteria**:
  - AC-001a: The harness launches mkdn with a specified file path and the app reaches a rendered state within a configurable timeout.
  - AC-001b: The harness switches between Preview Only and Side-by-Side modes and the UI reflects the mode change.
  - AC-001c: The harness cycles themes (Solarized Dark to Light and back) and the UI reflects the theme change.
  - AC-001d: The harness triggers file reload and the content is re-rendered.
  - AC-001e: The harness activates and deactivates Mermaid diagram focus.
  - AC-001f: Render stability detection does not rely on fixed delays; the harness waits for a deterministic signal that rendering is complete.

### REQ-002: Rendering Capture
- **Priority**: Must Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: The test infrastructure must capture the mkdn window content as a bitmap image at the window's native Retina resolution, supporting both full-window capture and region-of-interest capture for specific UI elements, with deterministic timing tied to render completion signals rather than fixed delays.
- **Rationale**: Captured images are the raw data for all spatial, visual, and animation verification. Deterministic timing prevents flaky captures of partially-rendered content.
- **Acceptance Criteria**:
  - AC-002a: Full window capture produces a PNG image at native Retina resolution (2x or 3x scale factor).
  - AC-002b: Region-of-interest capture isolates specific UI elements (code blocks, headings, Mermaid diagrams) from the full window capture.
  - AC-002c: Capture occurs only after the app signals render completion, including WKWebView content for Mermaid diagrams.
  - AC-002d: Captured images include metadata: timestamp, source file path, active theme, view mode, window dimensions.
  - AC-002e: Same file + theme + mode + window size produces pixel-identical captures across consecutive runs (excluding known system-level variation).

### REQ-003: Spatial Compliance Verification
- **Priority**: Must Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: The test infrastructure must verify that rendered output matches the spatial-design-language PRD specifications for document margins, block-to-block spacing, heading spacing (above and below for H1-H3), component padding (code blocks, blockquotes), window chrome insets, content max width, and 8pt grid alignment of all measured values.
- **Rationale**: The spatial-design-language PRD defines precise spacing constants grounded in typographic design principles. Automated verification ensures these values are correctly implemented and preserved across code changes.
- **Acceptance Criteria**:
  - AC-003a: Document margins are measured and verified against SpacingConstants.documentMargin (32pt).
  - AC-003b: Block-to-block spacing is measured and verified against SpacingConstants.blockSpacing (16pt).
  - AC-003c: Heading spacing above and below H1, H2, H3 is measured and verified against the corresponding SpacingConstants heading values.
  - AC-003d: Code block and blockquote internal padding is measured and verified against SpacingConstants.componentPadding (12pt).
  - AC-003e: Window chrome insets are measured and verified against windowTopInset (32pt), windowSideInset (32pt), windowBottomInset (24pt).
  - AC-003f: Content width does not exceed contentMaxWidth (~680pt).
  - AC-003g: All measured spatial values are reported as multiples of the 4pt sub-grid.
  - AC-003h: Measurements are accurate to within 1pt at Retina resolution.

### REQ-004: Visual Compliance Verification
- **Priority**: Must Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: The test infrastructure must verify that rendered output matches theme color specifications for background color, text colors (headings, body, code), code block syntax highlighting token colors, and selection highlight color, for both Solarized Dark and Solarized Light themes.
- **Rationale**: Theme consistency is a core differentiator of mkdn (terminal-consistent theming). Automated color verification ensures both themes remain correct as the codebase evolves.
- **Acceptance Criteria**:
  - AC-004a: Background color of the rendered window matches ThemeColors.background for the active theme.
  - AC-004b: Heading text colors match ThemeColors heading specifications for the active theme.
  - AC-004c: Body text colors match ThemeColors body specifications for the active theme.
  - AC-004d: Code block syntax highlighting produces correct token colors (verified against known Swift code tokens).
  - AC-004e: Both Solarized Dark and Solarized Light pass all visual compliance checks.
  - AC-004f: Color comparison uses a configurable tolerance to account for anti-aliasing and sub-pixel rendering.

### REQ-005: Animation Timing Verification
- **Priority**: Should Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: The test infrastructure must capture frame sequences at configurable framerates (30-60fps) and analyze them to verify that animation timing curves match the animation-design-language PRD specifications for breathing orb rhythm, spring-settle transitions, fade durations, content load stagger delays, and Reduce Motion compliance.
- **Rationale**: The animation-design-language PRD specifies exact timing curves and spring parameters. Frame-sequence analysis is the only way to verify these visually without inspecting implementation internals (since all animations are pure SwiftUI and not programmatically inspectable from tests).
- **Acceptance Criteria**:
  - AC-005a: Breathing orb captures at 30fps over one full cycle (~5s) show sinusoidal opacity/scale variation at ~12 cycles/min.
  - AC-005b: Spring-settle transitions (mode overlay, Mermaid focus border) captured at 60fps show response consistent with spring(response: 0.35, dampingFraction: 0.7).
  - AC-005c: Fade transitions (theme crossfade, orb appear/dissolve) captured at 30fps show durations matching AnimationConstants (crossfade: 0.35s, fadeIn: 0.5s, fadeOut: 0.4s).
  - AC-005d: Content load stagger captured at 60fps shows per-block stagger delay of 30ms with fade+drift animation.
  - AC-005e: With Reduce Motion enabled, continuous animations (orb breathing) are static and transitions use reduced durations (0.15s or instant).
  - AC-005f: Animation timing measurements are accurate to within one frame at the capture framerate.

### REQ-006: Structured Agent-Consumable Output
- **Priority**: Must Have
- **User Type**: AI Coding Agent
- **Requirement**: The test infrastructure must produce structured JSON output from CLI-driven test execution, with pass/fail status per test case, captured image file paths, and PRD-anchored failure descriptions that include expected value, actual value, and the specific PRD functional requirement being verified.
- **Rationale**: The primary consumer is an AI coding agent that must parse test results, identify failures, map them to specific design requirements, and make targeted code fixes. Human-readable test runner output is insufficient for agent consumption.
- **Acceptance Criteria**:
  - AC-006a: Test execution is invocable via CLI (e.g., `swift test --filter UITests` or a dedicated runner script).
  - AC-006b: Output is valid JSON with a consistent schema: test name, status (pass/fail), captured image paths, failure details.
  - AC-006c: Failure descriptions include: expected value, actual measured value, and PRD reference (e.g., "spatial-design-language FR-3: headingSpaceAbove(H1) expected 48pt, measured 24pt").
  - AC-006d: Exit code is 0 when all tests pass, non-zero when any test fails.
  - AC-006e: The agent can parse the JSON output, identify which PRD requirement failed, and determine what code change is needed.

### REQ-007: PRD-Anchored Test Specifications
- **Priority**: Must Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: Every test case in the suite must reference the specific PRD and functional requirement it verifies, following a consistent naming convention and including source documentation. A coverage report must show which PRD FRs have tests and which do not.
- **Rationale**: Traceability between tests and design specifications ensures the test suite is complete, meaningful, and maintainable. Without PRD anchoring, tests become disconnected assertions that drift from design intent.
- **Acceptance Criteria**:
  - AC-007a: Test names follow the pattern `test_{prd}_{FR}_{aspect}` (e.g., `test_spatialDesignLanguage_FR3_h1SpaceAbove`).
  - AC-007b: Each test includes documentation (comment or metadata) specifying the PRD name, FR number, and expected value with its source.
  - AC-007c: The suite produces a coverage report listing which PRD FRs have test coverage and which do not.

### REQ-008: Test Fixture Management
- **Priority**: Must Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: The test infrastructure must include standardized Markdown test files that exercise all Markdown element types, checked into the repository in a known location, providing consistent and repeatable test content.
- **Rationale**: Deterministic testing requires known inputs. Standardized fixtures ensure every test run uses the same content, making results comparable across runs and across development environments.
- **Acceptance Criteria**:
  - AC-008a: A canonical test document exists exercising all Markdown elements: headings H1-H6, paragraphs, fenced code blocks with Swift syntax, ordered and unordered lists, blockquotes, tables, thematic breaks, Mermaid diagrams (flowchart and sequence at minimum), inline formatting (bold, italic, code, links).
  - AC-008b: Focused test documents exist for specific scenarios: long document (20+ blocks for stagger animation testing), multiple Mermaid diagrams, theme-sensitive content (code blocks with known token colors).
  - AC-008c: All test fixtures are checked into the repository under a known, documented path.
  - AC-008d: Test fixtures include known-geometry elements suitable for spatial measurement calibration (e.g., headings followed by paragraphs where the expected spacing is unambiguous).

### REQ-009: Test Isolation and Determinism
- **Priority**: Must Have
- **User Type**: AI Coding Agent, Human Developer
- **Requirement**: Each test must operate in isolation with no dependencies on test execution order. Each test must launch a fresh application instance or fully reset application state. Tests must produce deterministic results for the same inputs.
- **Rationale**: Flaky or order-dependent tests undermine confidence in the test suite, especially for an AI agent that relies on test results to make automated decisions. Non-deterministic tests cause wasted iteration cycles.
- **Acceptance Criteria**:
  - AC-009a: Each test launches a fresh app instance or performs a complete state reset before execution.
  - AC-009b: Tests produce identical pass/fail results regardless of execution order.
  - AC-009c: Tests can run in parallel when using separate window instances.
  - AC-009d: Ten consecutive runs of the full suite produce zero flaky failures.

### REQ-010: CI Environment Compatibility
- **Priority**: Should Have
- **User Type**: Human Developer
- **Requirement**: The test suite must be runnable in a headless CI environment (macOS runner with a window server session) and must document the CI setup requirements for any system-level dependencies such as window server access.
- **Rationale**: Continuous integration ensures the design system is verified on every code change, not just when a developer remembers to run tests locally.
- **Acceptance Criteria**:
  - AC-010a: The test suite runs successfully on a macOS CI runner with a screen session.
  - AC-010b: CI setup requirements (window server, screen resolution, accessibility permissions) are documented.
  - AC-010c: CI-specific configuration (e.g., tolerance thresholds for Mermaid WKWebView variation) is documented and configurable.

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| Expectation | Target |
|-------------|--------|
| Full window capture latency | Under 50ms per capture |
| Frame sequence capture at 60fps | No dropped frames; capture mechanism must not cause frame drops in the application |
| Full spatial + visual compliance suite | Under 60 seconds wall-clock time |
| Individual test execution | Under 10 seconds including app launch, render stabilization, capture, and assertion |

### 6.2 Security Requirements

- No special security requirements. All tests run locally with standard user permissions.
- Tests require accessibility permissions for XCUITest app control and screen capture permissions for CGWindowListCreateImage. These must be documented but are standard development/CI permissions.

### 6.3 Usability Requirements

- Test failure messages must be self-contained: a developer or agent reading only the failure message must understand what was expected, what was measured, and which PRD requirement was violated.
- Captured images must be persisted at a known path for post-failure inspection.
- The test suite must support filtering to run subsets (e.g., only spatial tests, only animation tests, only tests for a specific PRD).

### 6.4 Compliance Requirements

- Measurement accuracy: spatial measurements accurate to within 1pt at Retina resolution (2px at 2x scale factor).
- Timing accuracy: animation timing measurements accurate to within one frame at the capture framerate (16.7ms at 60fps, 33.3ms at 30fps).
- WKWebView tolerance: Mermaid diagram capture comparison must support configurable tolerance thresholds to account for WKWebView rendering non-determinism.

## 7. User Stories

### STORY-001: Agent Verifies Spatial Compliance After Code Change

**As an** AI coding agent
**I want to** run the spatial compliance test suite after modifying a layout value and receive structured pass/fail results
**So that** I can confirm my change is correct or identify exactly which spatial requirement I violated

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN the agent has modified a spacing value in the rendering code
- WHEN the agent invokes the spatial compliance test suite via CLI
- THEN the agent receives JSON output listing each spatial test with pass/fail status, and any failure includes the expected value (from SpacingConstants), the measured value, and the PRD FR reference

### STORY-002: Agent Verifies Theme Correctness

**As an** AI coding agent
**I want to** run visual compliance tests for both Solarized Dark and Solarized Light themes
**So that** I can confirm that a theme-related code change renders correctly in both themes

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN the app renders a canonical test document
- WHEN the test harness captures the window in Solarized Dark, cycles to Solarized Light, and captures again
- THEN visual compliance assertions verify background and text colors against ThemeColors for both themes

### STORY-003: Agent Verifies Animation Timing After Constant Change

**As an** AI coding agent
**I want to** run animation verification tests after modifying an AnimationConstants value
**So that** I can confirm the rendered animation timing matches the updated specification

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN the agent has modified a timing constant in AnimationConstants.swift
- WHEN the agent invokes the animation verification test suite
- THEN frame sequence analysis verifies the animation's timing curve matches the updated constant within the measurement tolerance

### STORY-004: Developer Reviews Failing Test Diagnostics

**As a** human developer
**I want to** see captured images and PRD-referenced failure descriptions when a test fails
**So that** I can quickly understand what went wrong and decide whether to fix the code or update the specification

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN a spatial compliance test fails because a heading margin does not match the expected value
- WHEN the developer reviews the test output
- THEN the output includes: the captured image path, the expected value with its SpacingConstants name, the measured value, and the specific spatial-design-language FR reference

### STORY-005: Agent Runs Full Regression Suite

**As an** AI coding agent
**I want to** run the complete test suite (spatial + visual + animation) in a single invocation
**So that** I can verify no regressions were introduced by a broad code change

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN the agent has completed a multi-file code change
- WHEN the agent invokes the full test suite
- THEN the suite completes within 60 seconds and produces a JSON report with per-test results, a summary pass/fail count, and a PRD coverage report

### STORY-006: Developer Runs Subset of Tests

**As a** human developer
**I want to** run only the spatial compliance tests or only the animation tests
**So that** I can iterate quickly on a specific design area without waiting for the full suite

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN the developer is working on spacing adjustments
- WHEN the developer filters the test suite to run only spatial tests
- THEN only spatial compliance tests execute, producing results in the same structured format as the full suite

### STORY-007: Agent Verifies Reduce Motion Compliance

**As an** AI coding agent
**I want to** verify that the application respects the macOS Reduce Motion accessibility preference
**So that** I can confirm all continuous animations are disabled and transitions use reduced durations when Reduce Motion is enabled

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN Reduce Motion is enabled in the test environment
- WHEN the test harness captures the orb element over a 5-second window
- THEN frame analysis shows the orb is static (no breathing animation) and any triggered transitions complete in 0.15s or less

## 8. Business Rules

| Rule ID | Rule | Source |
|---------|------|--------|
| BR-001 | Every test case must trace to a specific PRD functional requirement. Tests without PRD anchoring are not permitted in the compliance suite. | PRD: automated-ui-testing FR-7 |
| BR-002 | Spatial measurements must use the source-of-truth constants (SpacingConstants, AnimationConstants, ThemeColors) as expected values, not hardcoded numbers. If the constants are not yet implemented, tests use the PRD-specified values with a comment indicating the future constant name. | Design system single-source-of-truth principle |
| BR-003 | Mermaid diagram capture must wait for WKWebView render completion signal before capture. Fixed-delay captures are not acceptable. | PRD: automated-ui-testing NFR-1, Risk R-1 |
| BR-004 | Animation verification must use curve-fitting across multiple frames rather than single-frame timing assertions, to compensate for capture timing jitter. | PRD: automated-ui-testing Risk R-2 |
| BR-005 | All test fixtures must be Markdown files checked into the repository. Tests must not generate fixture content dynamically in ways that could introduce variation. | Determinism requirement |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Type | Status | Impact |
|------------|------|--------|--------|
| animation-design-language PRD | Design specification | Complete | Defines all animation timing constants verified by animation tests (REQ-005) |
| spatial-design-language PRD | Design specification | Complete | Defines all spacing constants verified by spatial tests (REQ-003) |
| cross-element-selection PRD | Design specification | Complete | Defines text rendering architecture; its NSTextView migration may change rendering internals |
| AnimationConstants.swift | Source of truth (code) | Implemented | Animation test expected values reference these constants |
| SpacingConstants.swift | Source of truth (code) | Not yet implemented | Spatial test expected values will reference these constants once implemented; until then, use PRD-specified values |
| ThemeColors.swift | Source of truth (code) | Implemented | Visual test expected values reference these constants |
| XCUIApplication (XCTest framework) | Platform API | Available | Required for programmatic app control |
| CGWindowListCreateImage (Quartz) | Platform API | Available | Required for window content capture; needs window server access |
| Swift Testing framework | Test framework | Available | Used for unit-level assertions |
| XCTest/XCUITest framework | Test framework | Available | Used for UI automation (app launch, control, capture) |

### Constraints

| Constraint | Impact |
|------------|--------|
| XCUITest and Swift Testing serve different roles and may require separate test targets | The test architecture must cleanly separate UI automation (XCUITest) from assertion logic. Shared utilities must be accessible from both frameworks. |
| Window server requirement | CGWindowListCreateImage and XCUIApplication require a GUI session. CI environments must provide a window server (logged-in runner or virtual display). |
| WKWebView render timing | Mermaid diagrams render asynchronously in WKWebView. Capture must synchronize with WKWebView completion callback. This is the highest-risk element for test flakiness. |
| Retina resolution | All spatial measurements must account for the display scale factor. A 32pt margin is 64px in a 2x capture. |
| Animation frame capture overhead | Capturing at 60fps must not itself cause frame drops that would invalidate timing measurements. May require AVFoundation screen recording rather than per-frame CGWindowListCreateImage. |
| Pure SwiftUI animations | All mkdn animations are pure SwiftUI. Animation internals are not programmatically inspectable; verification must be visual (captured frames), not programmatic (reading animation state). |
| Two-target architecture | mkdn has mkdnLib (library) + mkdn (executable). UI tests launch the executable target. Unit tests import mkdnLib via @testable import. |
| NSTextView migration risk | The cross-element-selection PRD's NSTextView migration will change rendering internals. Animation tests should verify visual output rather than implementation details to remain architecture-agnostic. |

## 10. Clarifications Log

| ID | Question | Resolution | Source |
|----|----------|------------|--------|
| CL-001 | Should spatial measurement use pixel-level image analysis or should the app expose layout metrics via a debug API? | Deferred to design phase. Both approaches are viable. The requirements specify measurement accuracy (1pt at Retina) without prescribing the measurement mechanism. | PRD OQ-1 |
| CL-002 | What capture mechanism is best for animation frame sequences? | Deferred to design phase. The requirements specify frame capture at configurable framerates without prescribing CGWindowListCreateImage vs AVFoundation vs CAMetalLayer. | PRD OQ-2 |
| CL-003 | How should visual comparison tolerance work -- per-pixel, perceptual hash, or SSIM? | Deferred to design phase. The requirements specify configurable tolerance without prescribing the comparison algorithm. | PRD OQ-3 |
| CL-004 | Should animation timing compare against mathematical curves or golden references? | Deferred to design phase. The requirements specify curve-fitting across frames (BR-004) but do not prescribe whether the reference is mathematical or recorded. | PRD OQ-4 |
| CL-005 | How do animation tests interact with the cross-element-selection NSTextView migration? | Tests should verify visual output (architecture-agnostic) rather than implementation internals. Tests may need updating after the migration but the requirement to verify timing curves remains stable. | PRD OQ-5, Risk R-3 |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | automated-ui-testing.md | Exact filename match with feature ID. Only one PRD matches. |
| Phasing priority | Phase 1 (app control + capture) and Phase 2 (spatial + visual compliance) as Must Have; Phase 3 (animation verification) as Should Have | PRD explicitly sequences phases and notes Phase 1+2 should be usable before design-system migrations. Animation verification is more complex and has higher risk (frame capture overhead, timing jitter). |
| SpacingConstants availability | Tests use PRD-specified values until SpacingConstants.swift is implemented | SpacingConstants is listed as "not yet implemented" in dependencies. Conservative approach avoids blocking test development. |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| REQUIREMENTS parameter was empty -- no raw requirements provided | Derived all requirements from the automated-ui-testing PRD (which is comprehensive and marked Complete) plus the charter and related design-system PRDs | PRD: automated-ui-testing.md, charter.md, animation-design-language.md, spatial-design-language.md |
| Measurement mechanism not specified in requirements (pixel analysis vs debug API) | Left as a design-phase decision; requirements specify accuracy targets (1pt, one frame) without prescribing mechanism | PRD OQ-1 through OQ-4 explicitly flag these as open questions |
| Frame capture technology not specified | Left as a design-phase decision; requirements specify framerate and non-interference constraints | PRD OQ-2, Constraint on frame capture overhead |
| Visual comparison algorithm not specified | Left as a design-phase decision; requirements specify configurable tolerance | PRD OQ-3 |
| Whether animation tests should be written before or after NSTextView migration | Requirements specify architecture-agnostic visual verification to reduce rewrite risk, but acknowledge tests may need updating | PRD OQ-5, Risk R-3, Assumption A-7 |
| Priority of CI compatibility | Assigned Should Have (not Must Have) since the primary user (AI agent) runs locally, and the charter's success criterion is personal daily-driver use, not CI-based deployment | Charter success criteria, PRD NFR-5 |
