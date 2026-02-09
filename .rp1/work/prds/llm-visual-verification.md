# PRD: LLM Visual Verification

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 2.0.0
**Status**: Active
**Created**: 2026-02-09

---

## Surface Overview

An on-demand LLM vision-based verification skill that complements mkdn's existing pixel-level test infrastructure with qualitative design judgment. Where the automated-ui-testing PRD provides deterministic, pixel-exact compliance checks ("is this margin 32pt?"), the LLM visual verification layer answers higher-order design questions that only a vision-capable model can assess: "Does this code block *look right*?" "Does the spatial rhythm feel balanced?" "Does this rendering match the charter's design philosophy of obsessive sensory attention?"

The workflow is developer-initiated: run `verify-visual.sh`, review the findings, and decide what to fix. The output is a structured evaluation report with PRD-referenced issues that the developer acts on -- no autonomous code modification, no test generation, no self-healing loop.

The primary user is the human developer running visual verification during PRD implementation, design audits, or after significant rendering changes. The secondary consumer is the rp1 agent framework, which can invoke the skill programmatically.

---

## Scope

### In Scope

| Capability | Description |
|------------|-------------|
| **Vision evaluation skill** | An rp1 skill that sends captured screenshots to Claude vision with structured prompts containing PRD excerpts, charter design philosophy, and specific evaluation criteria |
| **PRD-referenced issue detection** | When Claude vision identifies a design deviation, the output includes the specific PRD name, functional requirement number, and relevant specification text |
| **Batch evaluation** | Evaluate multiple screenshots in a single Claude vision call to manage API costs. Group related captures into batched requests |
| **Structured output** | JSON evaluation reports with issue severity, PRD references, confidence scores, and deviation descriptions |
| **Human-readable summary** | `verify-visual.sh` formats evaluation results as a terminal-friendly summary with severity counts and per-issue details |
| **Caching** | Hash-based cache to skip re-evaluation of unchanged screenshots, reducing redundant API calls |
| **Dry-run mode** | Preview what would be evaluated without making API calls |

### Out of Scope

| Exclusion | Rationale |
|-----------|-----------|
| **Failing test generation** | Removed in v2.0.0. Generating compilable, correctly-failing Swift tests from qualitative vision observations proved unreliable and expensive. The developer writes targeted tests when needed. |
| **Self-healing loop** | Removed in v2.0.0. The autonomous capture-evaluate-generate-fix-reverify loop was over-engineered for the actual use case. Developers review findings and fix issues directly. |
| **Re-verification cycle** | Removed in v2.0.0. To re-verify after a fix, run `verify-visual.sh` again. No automated comparison or regression detection needed. |
| **Regression registry** | Removed in v2.0.0. The registry tracked loop iterations and resolution status, which is unnecessary for on-demand verification. Evaluation reports in `reports/` provide sufficient history. |
| **Replacing pixel-level tests** | This complements, not replaces, the deterministic automated-ui-testing infrastructure |
| **Real-time monitoring** | On-demand skill invocation, not a continuous daemon |
| **Cross-platform evaluation** | macOS only, per charter scope guardrails |
| **UI for evaluation results** | JSON files and terminal summary. No GUI |

---

## Requirements

### Functional Requirements

**FR-1: Vision Evaluation Skill**

An rp1 skill that:
- Accepts a set of screenshot file paths (PNG) captured by the existing test harness
- Constructs a structured prompt containing: (a) the charter's design philosophy section, (b) relevant PRD excerpts based on what is being evaluated, (c) the specific evaluation criteria (spatial rhythm, visual consistency, theme correctness)
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

**FR-3: Batch Cost Management**

- Group related screenshots into batched vision requests
- Limit images per evaluation call (configurable, default 4)
- Cache evaluation results for unchanged screenshots (hash-based cache keyed on image content hash + prompt hash)
- Support `--dry-run` mode that constructs prompts without making API calls

**FR-4: Human-Readable Output**

`verify-visual.sh` produces a terminal-friendly summary:
- Overall status (clean vs issues detected)
- Issue count by severity
- Per-issue detail: severity, confidence, PRD reference, observation
- Path to full JSON report for detailed review

Exit code 0 for clean, 1 for issues detected, 2 for infrastructure failure.

### Non-Functional Requirements

**NFR-1: Deterministic Captures**
Screenshot captures used for vision evaluation must be deterministic. The same file + theme + view mode + window size must produce consistent captures.

**NFR-2: macOS Window Server**
Visual verification requires a macOS GUI session for screenshot capture. Inherited from automated-ui-testing constraints.

**NFR-3: Graceful Degradation**
If Claude CLI is unavailable, API rate limits are hit, or vision calls fail, the skill must fail gracefully with a clear error message.

---

## Dependencies & Constraints

### Dependencies

| Dependency | Type | Description |
|------------|------|-------------|
| **Automated UI Testing Infrastructure** | Foundation | Test harness, capture service from the automated-ui-testing PRD |
| **Claude CLI with Vision** | External service | Claude Code CLI capable of processing image inputs for vision evaluation |
| **Compliance Suites** | Test infrastructure | Existing spatial, visual, and animation compliance tests provide quantitative baseline |
| **Design PRDs** | Design specs | animation-design-language, spatial-design-language, cross-element-selection PRDs as evaluation ground truth |
| **Project Charter** | Design philosophy | Charter's design philosophy section included in every vision evaluation prompt |
| **Git** | Version control | Verification artifacts committed to repository |

### Constraints

| Constraint | Impact |
|------------|--------|
| **API cost** | Vision calls consume API credits. Batch grouping and caching are essential. Each verification run requires 4 API calls (one per fixture batch). |
| **macOS window server** | Verification requires GUI session. No headless CI without virtual display. |
| **Deterministic captures** | Vision evaluations are only meaningful with deterministic screenshots. Non-determinism produces flaky evaluations. |

---

## Milestones & Timeline

### Phase 1: Vision Evaluation Skill (Complete)

**Goal**: Core capability -- send screenshots to Claude vision, receive structured design evaluations with PRD references.

| Deliverable | Status |
|-------------|--------|
| Capture orchestrator (VisionCaptureTests.swift) | Complete |
| Evaluation prompt construction | Complete |
| Claude vision integration (evaluate.sh) | Complete |
| Structured evaluation output (JSON reports) | Complete |
| Batch grouping by fixture | Complete |
| Dry-run mode | Complete |
| Caching layer | Complete |

### Phase 2: Workflow Integration (Complete)

**Goal**: Developer-facing entry point with human-readable output.

| Deliverable | Status |
|-------------|--------|
| verify-visual.sh top-level script | Complete |
| Human-readable terminal summary | Complete |
| --json flag for raw output | Complete |
| Documentation (CLAUDE.md, architecture.md, docs/) | Complete |

---

## Open Questions

| ID | Question | Impact |
|----|----------|--------|
| OQ-1 | What Claude model version and parameters (temperature, max tokens) produce the most consistent design evaluations? | Prompt tuning |
| OQ-2 | Should the vision prompt include full PRD text or curated excerpts? Full text provides maximum context but increases token cost. | Prompt construction |
| OQ-3 | How should the skill handle ambiguous design specs? Some PRD requirements are qualitative ("feel physical and natural") rather than quantitative. | Evaluation consistency |

---

## Assumptions & Risks

| ID | Description | Mitigation |
|----|-------------|------------|
| A-1 | Claude vision can reliably identify design deviations from screenshots with PRD context | Calibrate prompts with known-good and known-bad screenshots; tune confidence thresholds |
| A-2 | Existing test harness captures are sufficient for vision evaluation | Phase 1 calibration identified no additional capture needs |
| A-3 | API costs are acceptable for on-demand use during development | Batch grouping, caching, and dry-run mode reduce unnecessary calls |
| R-1 | **Model version consistency**: Vision evaluation behavior may change across Claude model versions | Re-baseline evaluation expectations on model upgrades |

---

## Discoveries

- **Codebase Discovery: macOS screenshot captures are not bitwise deterministic**: CGWindowListCreateImage captures include sub-pixel rendering variations from Core Text and WKWebView across process launches, making SHA-256 hash comparison unreliable for capture stability checks; perceptual hashing or pixel-level tolerance would be needed for deterministic comparisons. -- *Ref: [field-notes.md](archives/features/llm-visual-verification/field-notes.md)*

---

## Scope Changes

### v2.0.0 Redesign: 2026-02-09

**Rationale**: The autonomous self-healing loop (v1.0.0) was over-engineered for the actual use case. In practice, the workflow burned excessive time and API calls generating tests for all findings (including positive qualitative observations), spawning slow `claude -p` subprocesses per issue. The real need is simpler: capture screenshots, evaluate them against design specs, and report findings to the developer who decides what to do.

**Removed**:
- FR-3 (Failing test generation): Generating compilable, correctly-failing Swift tests from qualitative vision observations proved unreliable
- FR-4 (Self-healing loop via /build --afk): Autonomous code modification unnecessary for on-demand verification
- FR-5 (Re-verification cycle): Developer runs verify-visual.sh again instead
- FR-7 (Regression registry): Loop-specific tracking replaced by evaluation reports history
- NFR-3 (Bounded iterations): No loop, no iteration bound needed
- NFR-4 (Audit trail): Evaluation reports in reports/ provide sufficient history

**Added**:
- FR-4 (Human-readable output): Terminal-friendly summary from verify-visual.sh

**Scripts removed**: heal-loop.sh, generate-tests.sh, verify.sh, test-template-*.md
**Artifacts removed**: registry.json, current-loop.json, staging/, current-prompt.md.template

### Scope Addition: 2026-02-09 (v1.0.0, superseded by v2.0.0)

**Added** (historical, no longer applicable):
- Runtime verification gap, build invocation fidelity, registry-based regression detection, audit completeness, attended mode
