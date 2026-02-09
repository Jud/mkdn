# Requirements Specification: LLM Visual Verification

**Feature ID**: llm-visual-verification
**Parent PRD**: [LLM Visual Verification](../../prds/llm-visual-verification.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-09

## 1. Feature Overview

An autonomous design compliance skill for the rp1 agent framework that uses LLM vision to evaluate mkdn's rendered output against the project's design specifications, detect visual deviations, encode those deviations as concrete failing tests, automatically fix the code, and re-verify the result -- forming a complete closed loop from detection to resolution with no human intervention required. This is the qualitative counterpart to the existing pixel-level automated UI testing infrastructure: where pixel tests answer "is this margin 32pt?", the vision verification answers "does this look right?" and "does the spatial rhythm feel balanced?"

## 2. Business Context

### 2.1 Problem Statement

mkdn's charter demands "obsessive attention to sensory detail" across every visual element. The existing automated UI testing infrastructure provides deterministic, pixel-exact compliance checks, but cannot assess higher-order design qualities: visual rhythm, spatial balance, theme coherence, and whether a rendering "feels" correct according to the design philosophy. Today, these qualitative assessments require the human developer to manually inspect every rendering change -- an unsustainable burden as the codebase grows and iterates rapidly under agent-driven development.

### 2.2 Business Value

- **Continuous design compliance**: Design quality is maintained autonomously across every code change, without requiring manual visual inspection.
- **Agent-driven development enablement**: The rp1 agent framework can make rendering changes and verify both quantitative and qualitative correctness in a single automated pass.
- **Charter fidelity**: The charter's success criterion -- "personal daily-driver use" -- requires that the app consistently looks and feels right. This skill ensures that standard is maintained continuously.
- **Reduced regression risk**: Design regressions are detected and fixed before they accumulate, preventing the slow drift from "obsessive attention" to "good enough."

### 2.3 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Autonomous issue resolution rate | At least 80% of detected design deviations are resolved by the self-healing loop without human intervention | Ratio of auto-resolved to total detected issues over a rolling 30-day window |
| False positive rate | Less than 20% of detected issues are false positives (issues flagged that are actually correct) | Human review of escalated and auto-generated issues |
| Regression detection rate | 100% of design regressions detectable by visual inspection are also detected by the verification skill | Periodic human audit comparing manual inspection to automated detection |
| End-to-end loop completion | The full capture-evaluate-fix-verify loop completes within a reasonable time bound for a typical evaluation batch | Wall-clock time from invocation to final report |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Interaction Mode |
|-----------|-------------|------------------|
| **rp1 Agent Framework** (Primary) | The autonomous agent that invokes the verification skill as part of its quality loop. Triggers evaluations, receives structured results, acts on findings. | Programmatic: invokes skill, parses JSON output, chains into /build --afk |
| **Human Developer** (Secondary) | Reviews verification reports, audits escalated issues (low-confidence detections), approves or overrides auto-generated test decisions. | Report review: reads JSON reports and audit logs; optionally runs in attended interactive mode |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| **Project Owner** | Design quality is maintained at the charter's "obsessive attention" standard without manual gatekeeping |
| **rp1 Agent Framework** | Clear, structured, actionable evaluation results that can drive autonomous code fixes |
| **Human Developer** | Confidence that autonomous changes preserve design intent; ability to review and override when needed |

## 4. Scope Definition

### 4.1 In Scope

- Vision-based evaluation of rendered mkdn screenshots against design specifications (both concrete PRD compliance and qualitative design judgment)
- Detection of design deviations with severity classification and PRD references
- Automatic generation of failing tests that encode detected design intent
- Autonomous self-healing via /build --afk to fix detected issues
- Re-verification to confirm fixes and detect regressions
- Batch evaluation for cost management
- Regression tracking over time
- Structured reporting for both agent and human consumption
- Escalation to human review for low-confidence detections
- Two escalation modes: report file (default/unattended) and interactive prompt (attended)

### 4.2 Out of Scope

- Replacing or modifying the existing pixel-level automated UI testing infrastructure
- Real-time or continuous monitoring (this is batch/on-demand invocation only)
- Cross-platform evaluation (macOS only per charter)
- Training or fine-tuning vision models
- Any graphical user interface for evaluation results
- Modifications to the existing test harness capture mechanisms
- Performance benchmarking or frame-rate analysis

### 4.3 Assumptions

| ID | Assumption | Impact if Wrong |
|----|------------|-----------------|
| A-1 | An LLM with vision capabilities can reliably identify design deviations from screenshots when given relevant PRD context and design philosophy | The core value proposition fails; mitigation is prompt calibration with known-good and known-bad screenshots |
| A-2 | Qualitative design judgments ("spatial rhythm feels balanced") can be translated into concrete, testable assertions | Highly qualitative issues may need to flag for human review rather than auto-generate pixel-level tests |
| A-3 | The existing test harness produces deterministic screenshot captures sufficient for vision evaluation | Non-deterministic captures produce flaky evaluations; mitigation is hash-based caching and tolerance thresholds |
| A-4 | The /build --afk pipeline can successfully resolve design issues given failing tests and PRD references | Re-verification catches inadequate fixes; bounded iteration limit and human escalation prevent infinite loops |
| A-5 | API costs for vision evaluation are acceptable for regular use as a development quality gate | Batch grouping, caching, and dry-run mode reduce unnecessary API calls |

## 5. Functional Requirements

### REQ-001: Vision-Based Design Evaluation

**Priority**: Must Have
**User Type**: rp1 Agent Framework
**Requirement**: The system must accept a set of captured screenshots and evaluate them against the project's design specifications, producing a structured assessment of design compliance.
**Rationale**: This is the core capability -- translating visual output into actionable design feedback. Without this, no part of the loop functions.
**Acceptance Criteria**:
- Given a set of PNG screenshots captured by the existing test harness, the system produces a structured evaluation for each screenshot
- The evaluation considers both concrete PRD requirements (e.g., "heading spacing matches spatial-design-language FR-3") and qualitative design judgment (e.g., "spatial rhythm feels balanced per charter design philosophy")
- The evaluation prompt includes the charter's design philosophy, relevant PRD excerpts, and specific evaluation criteria
- The same screenshots and PRD state produce a deterministic evaluation prompt
- The evaluation output is structured (JSON) and machine-parseable

### REQ-002: PRD-Referenced Issue Detection

**Priority**: Must Have
**User Type**: rp1 Agent Framework
**Requirement**: Each detected design deviation must be traceable to a specific design specification -- either a named PRD functional requirement or a stated charter design principle.
**Rationale**: Traceability ensures that detected issues are grounded in documented design intent rather than arbitrary aesthetic preference. It also provides the /build --afk pipeline with the context needed to understand what "correct" looks like.
**Acceptance Criteria**:
- Each detected issue includes a PRD reference (PRD name and functional requirement number) or charter section reference
- Each issue includes the relevant specification text that defines expected behavior
- Each issue includes a description of what was actually observed
- Each issue includes a description of how the observation deviates from the specification
- Each issue is classified by severity: critical (blocks daily-driver use), major (noticeable design regression), minor (subtle polish issue)
- Each issue is classified by confidence: high, medium, low

### REQ-003: Failing Test Generation

**Priority**: Must Have
**User Type**: rp1 Agent Framework
**Requirement**: For each detected design deviation with medium or high confidence, the system must produce a concrete, compilable, currently-failing test that encodes the design intent from the referenced PRD.
**Rationale**: Tests are the bridge between qualitative visual judgment and the deterministic build system. A failing test gives /build --afk a concrete, reproducible target to fix against.
**Acceptance Criteria**:
- A Swift Testing test file is generated for each medium- or high-confidence issue
- Each generated test references its source PRD and functional requirement in the test name and documentation comment
- Generated tests use the existing test harness infrastructure (app launch, screenshot capture, assertions)
- Generated tests compile successfully
- Generated tests currently fail (confirming the issue is real)
- Generated tests are specific enough that fixing the underlying issue causes the test to pass
- Low-confidence issues are not auto-tested but are flagged in the evaluation report for human review

### REQ-004: Autonomous Self-Healing

**Priority**: Must Have
**User Type**: rp1 Agent Framework
**Requirement**: After generating failing tests, the system must autonomously invoke the code-fix pipeline, passing the failing tests and PRD context, and monitor the result -- without human interaction.
**Rationale**: The full closed loop is the MVP. Detection without resolution is insufficient; the value is in autonomous maintenance of design quality.
**Acceptance Criteria**:
- Generated test files are committed before invoking the fix pipeline
- The fix pipeline receives the failing test paths and the PRD references that define the design intent
- The fix pipeline autonomously reads the failing tests, understands the design intent, modifies source code, and iterates until tests pass
- The system captures the fix pipeline's completion status (success or failure)
- The entire detect-generate-fix cycle runs without human interaction

### REQ-005: Re-Verification

**Priority**: Must Have
**User Type**: rp1 Agent Framework
**Requirement**: After the fix pipeline reports success, the system must re-capture screenshots and re-evaluate them to confirm the original issues are resolved and no new issues were introduced.
**Rationale**: Self-healing is only trustworthy if the fix is verified. Code changes that fix one issue may introduce another; re-verification closes this gap.
**Acceptance Criteria**:
- Fresh screenshots are captured after the fix pipeline completes
- The same evaluation criteria are applied to the new screenshots
- Originally-detected issues are confirmed resolved
- New issues introduced by the fix are detected (regression detection)
- If new regressions are detected, new failing tests are generated and the fix pipeline is re-invoked
- The re-verification loop is bounded (default maximum: 3 iterations)
- If the maximum iteration count is reached without full resolution, the system reports failure with accumulated context

### REQ-006: Batch Cost Management

**Priority**: Must Have
**User Type**: rp1 Agent Framework
**Requirement**: The system must manage API costs by grouping related evaluations, caching results for unchanged inputs, and providing cost visibility before execution.
**Rationale**: Vision API calls consume credits. Uncontrolled API usage makes the skill impractical for regular use as a development quality gate.
**Acceptance Criteria**:
- Related screenshots are grouped into batched evaluation requests
- The number of images per evaluation call is configurable (default: 4)
- Evaluation results are cached based on a hash of image content and evaluation prompt; unchanged inputs skip re-evaluation
- A cost estimate is provided before execution
- A dry-run mode is available that constructs evaluation prompts and reports what would be evaluated without making API calls

### REQ-007: Regression Registry

**Priority**: Should Have
**User Type**: rp1 Agent Framework, Human Developer
**Requirement**: The system must maintain a persistent registry of evaluation results over time, enabling regression detection and historical tracking of design compliance.
**Rationale**: A registry transforms point-in-time evaluations into a longitudinal compliance record. It enables detection of regressions that re-introduce previously-fixed issues and provides the human developer with a design quality audit trail.
**Acceptance Criteria**:
- A registry file records each evaluation: screenshot hash, evaluation timestamp, detected issues, resolution status
- On re-verification, results are compared against the registry to detect regressions (re-introduction of previously-fixed issues) and confirm fixes
- The registry is stored as a version-controlled artifact alongside other project artifacts
- The registry can be queried to show the compliance status of any previously-evaluated screenshot

### REQ-008: Structured Reporting

**Priority**: Must Have
**User Type**: rp1 Agent Framework, Human Developer
**Requirement**: All evaluation results, generated tests, fix attempts, and re-verification outcomes must be reported in a structured, machine-parseable format.
**Rationale**: The rp1 agent framework consumes reports programmatically. The human developer reviews them for audit purposes. Both need structured, consistent output.
**Acceptance Criteria**:
- Evaluation reports are JSON with: issue severity, PRD references, confidence scores, deviation descriptions, generated test file paths
- Fix pipeline invocation results are included: success/failure, iterations, files modified
- Re-verification outcomes are included: resolved issues, new regressions, final status
- Reports are written to a predictable location within the project's work directory

### REQ-009: Human Escalation

**Priority**: Must Have
**User Type**: Human Developer
**Requirement**: When the system cannot autonomously resolve an issue (low confidence, maximum iterations exhausted, or ambiguous design specification), it must escalate to the human developer with sufficient context for manual resolution.
**Rationale**: Autonomous systems must have a well-defined escalation path. Not all design judgments can be automated; the human developer needs clear, actionable information when intervention is required.
**Acceptance Criteria**:
- Low-confidence issues are flagged for human review rather than auto-generating tests
- When the self-healing loop exhausts its maximum iterations without resolution, a failure report is produced with: all detected issues, all attempted fixes, all re-verification results, and accumulated context
- In unattended mode (default), escalation produces a report file
- In attended mode (optional), escalation prompts the human interactively for guidance
- Escalated reports include enough context for the human to understand the issue, the system's attempts to resolve it, and suggested next steps

### REQ-010: Audit Trail

**Priority**: Should Have
**User Type**: Human Developer
**Requirement**: Every evaluation, test generation, fix invocation, and re-verification must be logged with full traceability from detection to resolution.
**Rationale**: The human developer needs to understand what the autonomous system did, when, and why. An audit trail provides accountability and enables debugging of the verification process itself.
**Acceptance Criteria**:
- Every evaluation call is logged with: timestamp, input screenshots, evaluation prompt (or hash), results
- Every test generation is logged with: timestamp, source issue, generated test file path, compilation result, failure validation result
- Every fix pipeline invocation is logged with: timestamp, input test paths, PRD references, completion status, files modified
- Every re-verification is logged with: timestamp, resolved issues, new regressions, iteration count
- The audit log is stored as a version-controlled artifact

### REQ-011: Qualitative Design Judgment

**Priority**: Must Have
**User Type**: rp1 Agent Framework
**Requirement**: The evaluation must assess qualitative design qualities -- spatial rhythm, visual balance, theme coherence, animation feel -- with the same rigor as concrete PRD compliance checks.
**Rationale**: The charter's design philosophy demands "obsessive attention to sensory detail." Many design qualities that matter for the daily-driver experience are qualitative rather than quantitative. The system must evaluate both.
**Acceptance Criteria**:
- The evaluation prompt includes the charter's design philosophy section as context for qualitative assessment
- Evaluations assess: spatial rhythm and balance, visual consistency across elements, theme coherence (colors, contrast, hierarchy), overall rendering quality ("does this look right?")
- Qualitative findings are reported with the same structure as concrete PRD findings (observation, deviation, severity, confidence)
- Qualitative findings reference the charter design philosophy or specific PRD design principles rather than specific functional requirements

### REQ-012: Deterministic Evaluation Inputs

**Priority**: Must Have
**User Type**: rp1 Agent Framework
**Requirement**: The evaluation process must produce deterministic results for unchanged inputs -- the same screenshots, design specifications, and evaluation criteria must produce the same evaluation prompt.
**Rationale**: Non-deterministic inputs produce flaky evaluations, eroding trust in the system. Determinism enables caching and reproducibility.
**Acceptance Criteria**:
- The evaluation prompt is constructed deterministically from the input screenshots and design specification state
- Prompt construction does not depend on external state (system time, random values, etc.)
- The cache correctly identifies unchanged inputs via content hashing

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| Expectation | Target |
|-------------|--------|
| Single evaluation batch latency | Bounded by LLM API response time; no unnecessary overhead added by the skill |
| Cache hit performance | Cached results returned without API calls; sub-second response |
| Full loop completion | Bounded by (evaluation time + fix pipeline time) x max iterations; the skill itself does not introduce unbounded delays |

### 6.2 Security Requirements

| Requirement | Description |
|-------------|-------------|
| Screenshot handling | Screenshots may contain proprietary content; they are sent only to the configured LLM API and are not stored beyond the local work directory and cache |
| API credential management | LLM API credentials are managed by the existing agent framework; the skill does not store or manage credentials directly |

### 6.3 Usability Requirements

| Requirement | Description |
|-------------|-------------|
| Dry-run mode | The skill can be invoked in dry-run mode to preview what would be evaluated, without making API calls or generating tests |
| Clear escalation reports | Escalation reports must be written for a human reader: plain language descriptions of issues, PRD references linked to actual spec text, and concrete suggested next steps |
| Attended mode option | When running with a human present, the skill can prompt interactively for guidance on ambiguous issues rather than auto-resolving or escalating to a report file |

### 6.4 Compliance Requirements

| Requirement | Description |
|-------------|-------------|
| macOS window server | The full loop requires a macOS GUI session for screenshot capture (inherited from automated-ui-testing infrastructure) |
| Bounded autonomy | The self-healing loop is bounded to a configurable maximum number of iterations (default: 3) to prevent runaway autonomous code modification |
| Graceful degradation | If the LLM API is unavailable, rate-limited, or returns errors, the skill fails cleanly without corrupting the registry, generating partial test files, or leaving the codebase in an inconsistent state |

## 7. User Stories

### STORY-001: Autonomous Design Compliance Check

**As** the rp1 agent framework,
**I want** to evaluate mkdn's rendered output against all design specifications after a code change,
**So that** design regressions are detected before they reach the human developer.

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN a set of screenshots captured by the existing test harness after a code change
- WHEN the vision evaluation skill is invoked with those screenshots
- THEN a structured report is produced identifying any design deviations, with PRD references, severity, and confidence for each

### STORY-002: Autonomous Issue Resolution

**As** the rp1 agent framework,
**I want** detected design issues to be automatically fixed through test generation and the /build --afk pipeline,
**So that** design compliance is restored without human intervention.

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN a set of detected design deviations with medium or high confidence
- WHEN failing tests are generated and the fix pipeline is invoked
- THEN the fix pipeline modifies the source code to resolve the issues, and re-verification confirms the fixes

### STORY-003: Regression Prevention

**As** the rp1 agent framework,
**I want** the re-verification step to detect new issues introduced by a fix,
**So that** the self-healing loop does not trade one design regression for another.

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN a fix has been applied and re-verification screenshots are captured
- WHEN the re-verification evaluation detects a new issue not present in the original evaluation
- THEN a new failing test is generated for the regression and the fix pipeline is re-invoked (up to the maximum iteration bound)

### STORY-004: Human Escalation on Exhausted Loop

**As** a human developer,
**I want** a clear, actionable report when the self-healing loop cannot resolve an issue within its iteration bound,
**So that** I can efficiently understand and manually address the problem.

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN the self-healing loop has reached its maximum iteration count (default: 3) without fully resolving all issues
- WHEN the loop terminates
- THEN a failure report is produced containing: all detected issues, all fix attempts, all re-verification results, and suggested next steps for manual resolution

### STORY-005: Cost-Controlled Evaluation

**As** the rp1 agent framework,
**I want** to manage API costs through batching, caching, and dry-run preview,
**So that** vision verification can be used regularly as a quality gate without excessive cost.

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN a set of screenshots where some are unchanged from a previous evaluation
- WHEN the evaluation skill is invoked
- THEN cached results are returned for unchanged screenshots without making new API calls, and changed screenshots are grouped into batched requests

### STORY-006: Qualitative Design Assessment

**As** the rp1 agent framework,
**I want** the evaluation to assess qualitative design qualities (rhythm, balance, coherence) alongside concrete PRD compliance,
**So that** the charter's "obsessive attention to sensory detail" standard is maintained holistically.

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN a screenshot of mkdn rendering a Markdown document
- WHEN the vision evaluation assesses the screenshot
- THEN the evaluation includes both concrete PRD compliance findings (e.g., "heading spacing matches FR-3") and qualitative design findings (e.g., "spatial rhythm between blocks is uneven"), each with observation, deviation, severity, and confidence

### STORY-007: Attended Interactive Escalation

**As** a human developer running the skill in attended mode,
**I want** to be prompted interactively when the system encounters low-confidence or ambiguous issues,
**So that** I can provide real-time guidance rather than reviewing a report after the fact.

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN the skill is invoked in attended mode and a low-confidence issue is detected
- WHEN the escalation point is reached
- THEN the system prompts the human interactively with the issue details and requests guidance, rather than writing a report file

### STORY-008: Design Compliance History

**As** a human developer,
**I want** to review the history of design evaluations and resolutions over time,
**So that** I can track design quality trends and identify recurring problem areas.

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN the regression registry has accumulated evaluation records from multiple verification runs
- WHEN the human developer reviews the registry
- THEN each entry shows: what was evaluated, what was found, how it was resolved (or escalated), and when

## 8. Business Rules

| Rule ID | Rule | Rationale |
|---------|------|-----------|
| BR-001 | Low-confidence issues are never auto-tested or auto-fixed; they are always escalated for human review | Prevents the system from acting on uncertain judgments that could introduce incorrect changes |
| BR-002 | The self-healing loop is bounded to a configurable maximum number of iterations (default: 3) | Prevents runaway autonomous code modification and unbounded API cost |
| BR-003 | Generated tests must compile and currently fail before being committed | Malformed or non-failing tests corrupt the test suite and provide false signals to the fix pipeline |
| BR-004 | Re-verification is mandatory after every successful fix | A fix that passes tests but introduces visual regressions is not acceptable |
| BR-005 | Cached evaluations are invalidated when screenshots or design specifications change | Stale cache entries would miss real regressions |
| BR-006 | The skill does not modify mkdn source code directly; all code changes are made through the /build --afk pipeline | Separation of concerns: the skill detects and specifies; the build pipeline implements |
| BR-007 | Every evaluation prompt includes both concrete PRD functional requirements and the charter's qualitative design philosophy | Both quantitative compliance and qualitative design judgment are equally important evaluation dimensions |
| BR-008 | Graceful degradation: API failures, rate limits, or unavailability must not corrupt the registry, generate partial test files, or leave the codebase inconsistent | The autonomous system must fail cleanly or not at all |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Type | Impact |
|------------|------|--------|
| Automated UI Testing Infrastructure | Foundation | Provides the test harness, capture service, and compliance suite patterns that this feature builds upon. Must be operational before this feature can function. |
| LLM with Vision Capability | External Service | Core evaluation engine. Must be accessible via CLI with support for multi-image inputs. |
| /build --afk Pipeline | rp1 Skill | The autonomous fix pipeline. Must accept failing test paths and PRD context as input. |
| Design PRDs (animation-design-language, spatial-design-language, cross-element-selection) | Design Specifications | Provide the ground truth for concrete PRD compliance evaluation. Changes to these PRDs affect evaluation criteria. |
| Project Charter | Design Philosophy | Provides the qualitative design philosophy used for higher-order design judgment. |
| Swift Testing Framework | Test Infrastructure | Generated tests must use @Test, #expect, @Suite conventions. |
| Git | Version Control | Generated test files, registry, and audit artifacts are committed to the repository. |
| macOS GUI Session | Platform | Screenshot capture requires a window server. No headless operation for the capture phase. |

### Constraints

| Constraint | Impact |
|------------|--------|
| API cost per evaluation cycle (estimated 2-8 API calls) | Batching, caching, and dry-run mode are essential for sustainable regular use |
| Bounded self-healing iterations (default: 3) | Some complex issues may not be resolvable within the iteration bound; human escalation is the fallback |
| macOS window server requirement | The full loop cannot run in a headless CI environment without a virtual display |
| Deterministic screenshot captures required | Non-deterministic captures (e.g., WKWebView timing variance for Mermaid diagrams) produce flaky evaluations |
| Generated test quality | Malformed tests break the build; compilation and failure validation are mandatory gates |
| LLM evaluation consistency | Vision model behavior may vary across model versions; evaluation baseline may need recalibration on model upgrades |
| This is an rp1 skill, not an mkdn feature | The skill orchestrates existing infrastructure but does not modify mkdn's architecture or add runtime code to the app |

## 10. Clarifications Log

| Question | Answer | Source |
|----------|--------|--------|
| Is Phase 1 (vision evaluation alone) sufficient as MVP? | No. The full capture-evaluate-fix-verify loop is the minimum viable feature. | User clarification |
| Should concrete PRD compliance or qualitative design judgment be prioritized? | Both are equally important. Evaluations must assess concrete PRD requirements and qualitative design qualities with equal rigor. | User clarification |
| Who is the primary actor? | The rp1 agent framework is the primary actor. The human developer is secondary, reviewing reports and handling escalations. | User clarification |
| What format should human escalation use? | Default to report file for unattended operation. Optional interactive mode when running attended. | User clarification |
| Is the 3-iteration maximum for the self-healing loop appropriate? | Yes, 3 iterations is the correct default. | User clarification |
| Can the skill run standalone without the self-healing loop? | Standalone evaluation is not the MVP. The value is in the complete closed loop. | User clarification |
