# PRD: LLM Visual Verification

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-09

---

## Surface Overview

An LLM vision-based verification skill for the rp1 agent framework that complements mkdn's existing pixel-level test infrastructure with qualitative design judgment. Where the automated-ui-testing PRD provides deterministic, pixel-exact compliance checks ("is this margin 32pt?"), the LLM visual verification layer answers higher-order design questions that only a vision-capable model can assess: "Does this code block *look right*?" "Does the spatial rhythm feel balanced?" "Does this rendering match the charter's design philosophy of obsessive sensory attention?"

The skill implements a full autonomous self-healing loop:

1. **Capture**: Run the existing test harness to launch mkdn and capture screenshots.
2. **Evaluate**: Send screenshots to Claude vision for evaluation against the project charter, design PRDs (animation-design-language, spatial-design-language, cross-element-selection), and compliance suites.
3. **Detect**: Claude identifies design deviations, referencing specific PRD functional requirements and charter principles.
4. **Generate**: For each detected issue, automatically generate a failing Swift Testing test that encodes the design intent from the relevant PRD -- transforming qualitative judgment into a concrete, reproducible assertion.
5. **Heal**: Invoke `/build --afk` to autonomously fix the code until the generated tests pass.
6. **Re-verify**: Re-run the vision evaluation to confirm the fix resolves the original issue without introducing new regressions.

This surface serves the charter's success criterion -- "personal daily-driver use" -- by ensuring that design compliance is maintained continuously and autonomously, without requiring the human developer to manually inspect every rendering change. It is the qualitative counterpart to the quantitative automated-ui-testing infrastructure: together, they form a complete design compliance system.

The primary user is the rp1 agent framework itself, running this skill as part of an automated quality loop. The secondary user is the human developer reviewing the generated test cases and verification reports.

---

## Scope

### In Scope

| Capability | Description |
|------------|-------------|
| **Vision evaluation skill** | An rp1 skill (not an mkdn plugin) that sends captured screenshots to Claude vision with structured prompts containing PRD excerpts, charter design philosophy, and specific evaluation criteria |
| **PRD-referenced issue detection** | When Claude vision identifies a design deviation, the output includes the specific PRD name, functional requirement number, and relevant specification text |
| **Failing test generation** | For each detected issue, generate a concrete failing Swift Testing test (`@Test`, `#expect`) that encodes the design intent. The test must be specific enough to fail on the current rendering and pass when the issue is fixed |
| **Self-healing loop via /build --afk** | After generating failing tests, invoke `/build --afk` to autonomously fix the code, run the tests, and iterate until all generated tests pass -- fully autonomous, no human interaction required |
| **Re-verification cycle** | After `/build --afk` reports success, re-capture screenshots, re-evaluate with Claude vision, confirm original issues resolved |
| **Batch evaluation** | Evaluate multiple screenshots in a single Claude vision call to manage API costs. Group related captures into batched requests |
| **Regression guard** | Maintain a registry of previously-verified screenshots and their evaluation results. On re-verification, compare against the registry to detect regressions |
| **Structured output** | JSON evaluation reports with issue severity, PRD references, confidence scores, generated test file paths, and `/build --afk` invocation results |

### Out of Scope

| Exclusion | Rationale |
|-----------|-----------|
| **Replacing pixel-level tests** | This complements, not replaces, the deterministic automated-ui-testing infrastructure |
| **Real-time monitoring** | Batch skill invocation, not a continuous daemon |
| **Cross-platform evaluation** | macOS only, per charter scope guardrails |
| **Training or fine-tuning vision models** | Uses Claude vision as-is |
| **UI for evaluation results** | JSON files consumed by agent framework and human review. No GUI |
| **Modifying the test harness** | Uses existing automated-ui-testing infrastructure as-is |

---

## Requirements

### Functional Requirements

**FR-1: Vision Evaluation Skill**

An rp1 skill that:
- Accepts a set of screenshot file paths (PNG) captured by the existing test harness
- Constructs a structured prompt containing: (a) the charter's design philosophy section, (b) relevant PRD excerpts based on what is being evaluated, (c) the specific evaluation criteria (spatial rhythm, animation quality, visual consistency, theme correctness)
- Sends the prompt + images to Claude CLI with vision capability
- Parses the response into structured evaluation results

Prompt construction must be deterministic: the same screenshots + PRD state must produce the same prompt.

**FR-2: PRD-Referenced Issue Detection**

Each detected issue must include:
- **PRD reference**: The PRD name and functional requirement (e.g., `spatial-design-language FR-3`)
- **Specification excerpt**: The relevant text from the PRD that defines the expected behavior
- **Observation**: What Claude vision actually observed in the screenshot
- **Deviation description**: How the observation differs from the specification
- **Severity**: `critical` (blocks daily-driver use), `major` (noticeable design regression), `minor` (subtle polish issue)
- **Confidence**: `high`, `medium`, `low` -- reflecting certainty about the deviation

Issues with `low` confidence are flagged for human review rather than auto-generating tests.

**FR-3: Failing Test Generation**

For each detected issue with `medium` or `high` confidence:
- Generate a Swift Testing test file in `mkdnTests/UITest/` following the existing naming convention
- Each test references its source PRD and FR in the test name and documentation comment
- Tests use the existing test harness infrastructure (launch app, capture screenshots, assert against design specifications)
- Generated tests must compile and run -- they are real tests, not pseudocode
- The test must currently fail (validating that the issue is real) and must be specific enough that fixing the underlying issue makes the test pass

**FR-4: Self-Healing Loop**

After generating failing tests:
1. Commit the generated test files
2. Invoke `/build --afk` with context about the failing tests and the PRD references
3. `/build --afk` autonomously: reads the failing tests, understands the design intent from PRD references, modifies the source code, re-runs tests, iterates until passing
4. The skill monitors `/build --afk` completion and captures the result

The entire detect-generate-fix cycle runs without human interaction.

**FR-5: Re-Verification**

After `/build --afk` reports success:
1. Re-run the test harness to capture fresh screenshots of the fixed rendering
2. Re-invoke Claude vision evaluation with the same prompt + new screenshots
3. Verify the originally-detected issues are resolved
4. Check for new issues introduced by the fix (regression detection)
5. If new regressions are detected, generate new failing tests and re-invoke `/build --afk` (bounded loop with configurable max iterations, default 3)

**FR-6: Batch Cost Management**

- Group related screenshots into batched vision requests
- Limit images per evaluation call (configurable, default 4)
- Cache evaluation results for unchanged screenshots (hash-based cache keyed on image content hash + prompt hash)
- Provide cost estimate before execution
- Support `--dry-run` mode that constructs prompts without making API calls

**FR-7: Regression Registry**

Maintain a registry at `.rp1/work/verification/registry.json`:
- Each entry records: screenshot hash, evaluation timestamp, detected issues (if any), resolution status
- On re-verification, compare against registry to detect regressions and confirmed fixes
- Registry is committed to git with other `.rp1/` artifacts

### Non-Functional Requirements

**NFR-1: Deterministic Captures**
Screenshot captures used for vision evaluation must be deterministic. The same file + theme + view mode + window size must produce consistent captures.

**NFR-2: macOS Window Server**
The full self-healing loop requires a macOS GUI session for screenshot capture. Inherited from automated-ui-testing constraints.

**NFR-3: Bounded Iterations**
The self-healing loop must be bounded to prevent infinite cycles. Default maximum: 3 iterations. If issues persist, the skill reports failure with accumulated context for human review.

**NFR-4: Audit Trail**
Every evaluation, test generation, and `/build --afk` invocation must be logged to `.rp1/work/verification/audit.log` with timestamps, inputs, outputs, and outcomes.

**NFR-5: Graceful Degradation**
If Claude CLI is unavailable, API rate limits are hit, or vision calls fail, the skill must fail gracefully without corrupting the registry or generating partial test files.

---

## Dependencies & Constraints

### Dependencies

| Dependency | Type | Description |
|------------|------|-------------|
| **Automated UI Testing Infrastructure** | Foundation | Test harness, capture service, compliance suites from the automated-ui-testing PRD |
| **Claude CLI with Vision** | External service | Claude Code CLI capable of processing image inputs for vision evaluation |
| **/build --afk Pipeline** | rp1 skill | Autonomous build-fix pipeline that accepts failing tests and PRD context |
| **Compliance Suites** | Test infrastructure | Existing spatial, visual, and animation compliance tests provide quantitative baseline |
| **Design PRDs** | Design specs | animation-design-language, spatial-design-language, cross-element-selection PRDs as evaluation ground truth |
| **Project Charter** | Design philosophy | Charter's design philosophy section included in every vision evaluation prompt |
| **Swift Testing** | Test framework | Generated tests use `@Test`, `#expect`, `@Suite` |
| **Git** | Version control | Generated test files and verification artifacts committed to repository |

### Constraints

| Constraint | Impact |
|------------|--------|
| **API cost** | Vision calls consume API credits. Batch grouping and caching are essential. Each cycle may require 2-8 API calls. |
| **Regression guard complexity** | Re-verification can detect new issues, triggering further cycles. Bounded iteration limit prevents runaway loops. |
| **macOS window server** | Full loop requires GUI session. No headless CI without virtual display. |
| **Deterministic captures** | Vision evaluations are only meaningful with deterministic screenshots. Non-determinism produces flaky evaluations. |
| **Generated test quality** | Generated code enters the real codebase. Malformed tests cause build failures. Compilation validation is mandatory. |
| **rp1 skill architecture** | This is an rp1 skill, not an mkdn plugin. Orchestrates the test infrastructure but does not modify mkdn code directly. |

---

## Milestones & Timeline

### Phase 1: Vision Evaluation Skill

**Goal**: Core capability -- send screenshots to Claude vision, receive structured design evaluations with PRD references.

| Deliverable | Description |
|-------------|-------------|
| Evaluation prompt construction | Structured prompts from charter + PRD excerpts + evaluation criteria. Deterministic and reproducible. |
| Claude vision integration | Invoke Claude CLI with multi-image prompts, parse structured responses. Handle errors and rate limits. |
| Structured evaluation output | JSON reports with issue severity, PRD references, confidence scores, deviation descriptions. |
| Batch grouping | Group related screenshots into batched API calls. Configurable images-per-call limit. |
| Dry-run mode | `--dry-run` flag showing what would be evaluated without making API calls. |
| Caching layer | Hash-based cache to skip re-evaluation of unchanged screenshots. |

### Phase 2: Failing Test Generation

**Goal**: Transform qualitative vision evaluations into concrete, compilable Swift Testing tests.

| Deliverable | Description |
|-------------|-------------|
| Test template engine | Generate Swift Testing test files from evaluation results following compliance suite patterns. |
| Compilation validation | Verify generated tests compile before committing. Skip and log on failure. |
| PRD-anchored test naming | `test_{prd}_{FR}_{aspect}_visionDetected` naming convention with PRD citation comments. |
| Failure validation | Run generated tests to confirm they actually fail. Discard tests that pass immediately (false positives). |

### Phase 3: Self-Healing Loop (/build --afk)

**Goal**: Close the autonomous loop -- detect, generate tests, fix, re-verify.

| Deliverable | Description |
|-------------|-------------|
| /build --afk invocation | After committing failing tests, invoke `/build --afk` with failing test paths and PRD references. |
| Completion monitoring | Monitor `/build --afk` execution, capture success/failure, iterations, and files modified. |
| Re-verification cycle | Re-capture screenshots after fix, re-evaluate with Claude vision, confirm resolution. |
| Regression detection | Check for new issues introduced by fixes. Generate new failing tests if found (bounded by max iterations). |
| Human escalation | If max iterations exhausted, produce detailed report for human review. |

### Phase 4: Continuous Compliance

**Goal**: Integrate into the regular development workflow as a continuous quality gate.

| Deliverable | Description |
|-------------|-------------|
| Regression registry | `.rp1/work/verification/registry.json` tracking evaluations, issues, and resolutions over time. |
| Audit trail | `.rp1/work/verification/audit.log` with full traceability from detection to resolution. |
| Workflow integration | rp1 skill invocable after any code change to verify design compliance. |
| Cost reporting | Summary of API usage per evaluation cycle for budget tracking. |
| Documentation | Guide for how the skill fits into the rp1 workflow alongside `/build --afk` and compliance suites. |

---

## Open Questions

| ID | Question | Impact |
|----|----------|--------|
| OQ-1 | What Claude model version and parameters (temperature, max tokens) produce the most consistent design evaluations? | Phase 1 prompt tuning |
| OQ-2 | Should the vision prompt include full PRD text or curated excerpts? Full text provides maximum context but increases token cost. | Phase 1 prompt construction |
| OQ-3 | How should the skill handle ambiguous design specs? Some PRD requirements are qualitative ("feel physical and natural") rather than quantitative. | Phase 1-2 evaluation consistency |
| OQ-4 | Should generated tests create a new "vision-informed" test category or join existing compliance suites? | Phase 2 test architecture |
| OQ-5 | How does the self-healing loop interact with in-progress feature work? Branch isolation may be needed. | Phase 3 workflow integration |

---

## Assumptions & Risks

| ID | Description | Mitigation |
|----|-------------|------------|
| A-1 | Claude vision can reliably identify design deviations from screenshots with PRD context | Calibrate prompts in Phase 1 with known-good and known-bad screenshots; tune confidence thresholds |
| A-2 | Generated tests can encode qualitative design intent as quantitative assertions | For highly qualitative issues, generate tests that capture and flag for human review rather than asserting pixel values |
| A-3 | `/build --afk` can successfully fix design issues given failing tests and PRD context | Re-verification catches inadequate fixes; human escalation after max iterations |
| A-4 | Existing test harness captures are sufficient for vision evaluation | Phase 1 calibration will identify if additional capture utilities are needed |
| A-5 | API costs are acceptable for regular use as a development quality gate | Batch grouping, caching, and dry-run mode reduce unnecessary calls |
| R-1 | **Model version consistency**: Vision evaluation behavior may change across Claude model versions | Version-pin the Claude model in skill configuration; re-baseline registry on model upgrades |
| R-2 | **Generated code quality**: Malformed tests would break the build | Compilation validation and failure validation before committing |
| R-3 | **Autonomous code modification safety**: Unbounded or poorly-targeted fixes could introduce bugs worse than the original issue | Bounded iterations, re-verification, regression detection, and human escalation |

---

## Discoveries

<!-- Populated during implementation -->
