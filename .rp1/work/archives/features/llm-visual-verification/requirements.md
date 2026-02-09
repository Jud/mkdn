# Requirements Specification: LLM Visual Verification -- Scope Additions (2026-02-09)

**Feature ID**: llm-visual-verification
**Parent PRD**: [LLM Visual Verification](../../prds/llm-visual-verification.md)
**Version**: 2.0.0
**Status**: Draft
**Created**: 2026-02-09

## 1. Feature Overview

This requirements specification covers five scope additions to the existing LLM visual verification system, identified during a PRD audit on 2026-02-09. The additions address gaps in runtime verification confidence, build invocation robustness, regression detection depth, audit trail completeness, and interactive escalation workflow. Together, they elevate the self-healing loop from a functional prototype to a production-grade autonomous quality gate that the developer can trust to run unattended and produce reliable, traceable results.

## 2. Business Context

### 2.1 Problem Statement

The LLM visual verification system (heal-loop) has been implemented through Phase 3, but five operational gaps reduce confidence in its autonomous behavior:

1. **Runtime verification gap**: The full 8-capture test suite has not been confirmed end-to-end in a macOS GUI session since the render signal race condition was fixed (commit f542e0c). Without this confirmation, the capture phase -- the foundation of the entire pipeline -- remains unvalidated at runtime.

2. **Build invocation fidelity**: The heal-loop's `/build --afk` invocation is a single-shot `claude -p` call. When multiple failing tests are generated in one iteration, a single-shot prompt may not fix all of them, leaving the iteration incomplete and triggering unnecessary escalation.

3. **Shallow regression detection**: `verify.sh` compares only against the immediately-previous evaluation. A previously-resolved issue that reappears after an unrelated fix would be missed because it was not in the comparison baseline.

4. **Incomplete audit trail**: The `buildInvocation` audit entries record the build result and PRD references but omit the input test paths and files modified by the fix. This makes post-hoc investigation of what the autonomous agent changed incomplete.

5. **Incomplete attended mode**: The interactive escalation menu offers "Continue with manual guidance" but prints "not yet implemented" and writes an escalation report instead. Developers who run the loop in attended mode expect interactive continuation.

### 2.2 Business Value

- **Trust**: Confirming the capture suite runs reliably end-to-end gives the developer confidence to run the full heal-loop unattended.
- **Efficiency**: Multi-test build invocation reduces unnecessary heal iterations, saving API costs and wall-clock time.
- **Safety**: Registry-based regression detection catches reintroduced issues that would otherwise slip through.
- **Traceability**: Complete audit entries enable forensic review of autonomous code changes.
- **Usability**: A working attended mode gives the developer a hands-on fallback when the autonomous loop encounters issues beyond its scope.

### 2.3 Success Metrics

| Metric | Target |
|--------|--------|
| 8-capture suite pass rate | 100% on developer workstation with macOS GUI session |
| Multi-test fix rate per iteration | At least 2 failing tests addressed per `/build --afk` invocation |
| Registry regression catch rate | 100% of previously-resolved issues that reappear are flagged |
| Audit completeness | Every build invocation entry includes input test paths and modified file list |
| Attended mode "Continue" functional | Developer can provide guidance text and the loop resumes with that context |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| **rp1 Agent** | The autonomous agent framework that invokes the heal-loop as a quality gate after code changes | Primary consumer of all five additions; benefits from improved robustness and traceability |
| **Developer (attended)** | The human developer running the heal-loop in `--attended` mode for interactive oversight | Direct user of the attended mode "Continue with manual guidance" feature |
| **Developer (reviewing)** | The human developer reviewing audit trails and verification reports after autonomous runs | Benefits from improved audit completeness and registry-based regression detection |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Developer | Confidence that autonomous loop works reliably without supervision; ability to intervene when needed; complete traceability of all autonomous changes |
| rp1 Framework | Reliable capture foundation, efficient multi-test fix iterations, robust regression detection |

## 4. Scope Definition

### 4.1 In Scope

| ID | Addition | Description |
|----|----------|-------------|
| SA-1 | Runtime verification | Confirm full 8-capture test suite runs end-to-end on macOS GUI session, producing 8 PNGs + manifest.json |
| SA-2 | Build invocation fidelity | Improve heal-loop.sh `/build --afk` invocation to iterate internally on multiple failing tests |
| SA-3 | Registry-based regression detection | Enhance verify.sh to compare against full registry history, not just previous evaluation |
| SA-4 | Audit completeness | Record input test paths and files modified in build invocation audit entries |
| SA-5 | Attended mode continuation | Implement "Continue with manual guidance" interactive option in heal-loop.sh |

### 4.2 Out of Scope

| Exclusion | Rationale |
|-----------|-----------|
| Changes to the test harness itself | The capture infrastructure (VisionCaptureTests, VisionCapturePRD) is stable; SA-1 is verification, not modification |
| New capture fixtures | The 4-fixture x 2-theme matrix is sufficient for current evaluation needs |
| CI/CD integration | The heal-loop requires a macOS GUI session; headless CI integration is a separate future effort |
| Cost optimization for `/build --afk` | Token efficiency improvements are orthogonal to invocation fidelity |
| Registry schema migration | The current registry.json schema (version 1) supports the needed history; no migration required |

### 4.3 Assumptions

| ID | Assumption |
|----|------------|
| A-1 | The render signal race condition fix (commit f542e0c, TX-fix-warmup-removal) is stable and the VisionCapture test now reliably produces all 8 captures |
| A-2 | The `claude -p` CLI supports multi-paragraph prompts with sufficient context to fix multiple tests |
| A-3 | The registry.json evaluations array per capture preserves enough history for regression comparison |
| A-4 | Git diff output between the pre-build and post-build commits provides the "files modified" data needed for audit completeness |
| A-5 | Developers using `--attended` mode will provide text guidance when prompted; no GUI or rich input is needed |

## 5. Functional Requirements

### SA-1: Runtime Verification

**REQ-SA1-001**: End-to-End Capture Confirmation

| Element | Description |
|---------|-------------|
| **Priority** | Must Have |
| **Actor** | Developer or rp1 agent |
| **Action** | Run the VisionCapture test suite in a macOS GUI session |
| **Outcome** | All 8 captures (4 fixtures x 2 themes) are produced as PNG files with valid dimensions and SHA-256 hashes, and a manifest.json is written with 8 entries |
| **Rationale** | The capture phase is the foundation of the entire verification pipeline; if it fails or produces incomplete results, all downstream phases (evaluate, generate-tests, verify) are meaningless |
| **Acceptance Criteria** | 1. `swift test --filter VisionCapture` exits 0. 2. `.rp1/work/verification/captures/manifest.json` exists and contains exactly 8 entries. 3. Each manifest entry references an existing PNG file. 4. Each PNG file has non-zero dimensions. 5. Each manifest entry has a `sha256:` prefixed hash. 6. The expected capture IDs are: `geometry-calibration-solarizedDark-previewOnly`, `geometry-calibration-solarizedLight-previewOnly`, `theme-tokens-solarizedDark-previewOnly`, `theme-tokens-solarizedLight-previewOnly`, `canonical-solarizedDark-previewOnly`, `canonical-solarizedLight-previewOnly`, `mermaid-focus-solarizedDark-previewOnly`, `mermaid-focus-solarizedLight-previewOnly` |

**REQ-SA1-002**: Capture Stability Regression Guard

| Element | Description |
|---------|-------------|
| **Priority** | Should Have |
| **Actor** | Developer or rp1 agent |
| **Action** | Run the capture suite multiple consecutive times |
| **Outcome** | The same 8 captures are produced each time with consistent image hashes when the source fixtures and app code have not changed |
| **Rationale** | Non-deterministic captures produce flaky evaluations (NFR-1 from parent PRD). Confirming stability validates the race condition fix holds |
| **Acceptance Criteria** | 1. Two consecutive runs of `swift test --filter VisionCapture` produce identical image hashes for all 8 captures. 2. manifest.json structure is identical across runs (aside from timestamp) |

### SA-2: Build Invocation Fidelity

**REQ-SA2-001**: Multi-Test Build Context

| Element | Description |
|---------|-------------|
| **Priority** | Must Have |
| **Actor** | heal-loop.sh orchestrator |
| **Action** | Construct the `/build --afk` prompt with all failing test file paths and their associated PRD references |
| **Outcome** | The build agent receives full context about every failing test and can address multiple failures in a single invocation |
| **Rationale** | A single-shot prompt with incomplete context leads to partial fixes, wasting iterations and increasing API costs |
| **Acceptance Criteria** | 1. The build prompt includes every generated test file path. 2. Each test file path is accompanied by its PRD reference and issue description. 3. The prompt explicitly instructs the build agent to iterate until all listed tests pass |

**REQ-SA2-002**: Build Iteration Instruction

| Element | Description |
|---------|-------------|
| **Priority** | Must Have |
| **Actor** | heal-loop.sh orchestrator |
| **Action** | Include explicit instructions in the `/build --afk` prompt for the build agent to run all failing tests, fix failures, re-run, and repeat until all pass |
| **Outcome** | The build agent performs internal iteration within a single invocation rather than requiring the outer heal-loop to re-invoke for each failing test |
| **Rationale** | The outer heal-loop iteration (capture, evaluate, generate, build, verify) is expensive. Internal build iteration is much cheaper |
| **Acceptance Criteria** | 1. The build prompt contains a clear instruction to iterate internally. 2. The prompt specifies the test filter command to use for validation. 3. The prompt instructs the build agent to report which tests it fixed and which remain |

**REQ-SA2-003**: Build Result Detail Capture

| Element | Description |
|---------|-------------|
| **Priority** | Should Have |
| **Actor** | heal-loop.sh orchestrator |
| **Action** | Capture structured output from the build agent indicating which tests were fixed, which remain failing, and what source files were modified |
| **Outcome** | The heal-loop has granular knowledge of what the build step accomplished, enabling better decisions about whether to re-iterate or escalate |
| **Rationale** | Currently the build result is binary (success/failure). Granular results enable smarter iteration decisions and richer audit entries |
| **Acceptance Criteria** | 1. After `/build --afk` completes, the heal-loop records which tests now pass. 2. The list of modified files is captured (via `git diff --name-only`). 3. This information is passed to the audit entry and loop state |

### SA-3: Registry-Based Regression Detection

**REQ-SA3-001**: Historical Issue Comparison

| Element | Description |
|---------|-------------|
| **Priority** | Must Have |
| **Actor** | verify.sh script |
| **Action** | When comparing a new evaluation against prior state, consult the full registry history (all past evaluations per capture), not just the immediately-previous evaluation |
| **Outcome** | Issues that were previously resolved but have reappeared are flagged as regressions, even if they were not present in the most recent evaluation |
| **Rationale** | A shallow comparison (previous eval only) misses issues that were resolved 3 evaluations ago but reintroduced by a recent fix. The registry exists specifically to provide this historical context |
| **Acceptance Criteria** | 1. verify.sh reads `registry.json` for each capture. 2. For each issue in the new evaluation, the script checks if that PRD reference was previously resolved in any prior evaluation. 3. If a previously-resolved issue reappears, it is classified as a regression (not a new issue). 4. The re-verification report distinguishes between "new issue" and "reintroduced regression" |

**REQ-SA3-002**: Registry History Depth

| Element | Description |
|---------|-------------|
| **Priority** | Should Have |
| **Actor** | verify.sh script |
| **Action** | Use the full evaluation history stored in each registry entry's `evaluations` array |
| **Outcome** | Even if the previous evaluation did not detect an issue, the registry can reveal that this issue was detected and resolved in an earlier cycle |
| **Rationale** | The registry tracks evaluations over time per capture. This history is currently written but never read back for comparison |
| **Acceptance Criteria** | 1. For each capture in the new evaluation, the script loads the matching registry entry's evaluation history. 2. The script scans all historical evaluations for issues with status "resolved". 3. If the new evaluation detects the same PRD reference, it is flagged as a reintroduced regression |

### SA-4: Audit Completeness

**REQ-SA4-001**: Test Paths in Build Audit Entry

| Element | Description |
|---------|-------------|
| **Priority** | Must Have |
| **Actor** | heal-loop.sh orchestrator |
| **Action** | Include the list of failing test file paths in the `buildInvocation` audit entry |
| **Outcome** | The audit trail records exactly which test files were passed to the build agent for each invocation |
| **Rationale** | Without the test paths, a reviewer cannot reconstruct what the build agent was asked to fix |
| **Acceptance Criteria** | 1. The `buildInvocation` audit JSONL entry includes a `testPaths` array. 2. Each element is a project-relative path to a generated test file. 3. The array matches what was passed in the build prompt |

**REQ-SA4-002**: Modified Files in Build Audit Entry

| Element | Description |
|---------|-------------|
| **Priority** | Must Have |
| **Actor** | heal-loop.sh orchestrator |
| **Action** | After `/build --afk` completes, record the list of files modified by the build step in the audit entry |
| **Outcome** | The audit trail records exactly what the autonomous agent changed in the codebase |
| **Rationale** | Autonomous code modification must be fully traceable. Without the modified file list, a reviewer must manually diff commits to understand what changed |
| **Acceptance Criteria** | 1. After build completion, `git diff --name-only HEAD~1 HEAD` (or equivalent) captures the modified files. 2. The `buildInvocation` audit JSONL entry includes a `filesModified` array. 3. Each element is a project-relative file path |

### SA-5: Attended Mode Continuation

**REQ-SA5-001**: Manual Guidance Prompt

| Element | Description |
|---------|-------------|
| **Priority** | Must Have |
| **Actor** | Developer in attended mode |
| **Action** | When selecting "Continue with manual guidance" from the escalation menu, the developer is prompted to enter guidance text |
| **Outcome** | The developer provides textual guidance (e.g., "Focus on the heading spacing, ignore the code block colors") that is incorporated into the next iteration's build prompt |
| **Rationale** | The "Continue" option currently prints "not yet implemented." Developers using attended mode need the ability to steer the autonomous agent when it encounters issues it cannot resolve alone |
| **Acceptance Criteria** | 1. Selecting `c` at the escalation prompt opens a text input. 2. The developer can type multi-line guidance (terminated by an empty line or EOF). 3. The guidance text is non-empty (re-prompt if empty). 4. The loop continues to the next iteration with the guidance incorporated |

**REQ-SA5-002**: Guidance Incorporation into Build Prompt

| Element | Description |
|---------|-------------|
| **Priority** | Must Have |
| **Actor** | heal-loop.sh orchestrator |
| **Action** | Append the developer's manual guidance text to the `/build --afk` prompt for the next iteration |
| **Outcome** | The build agent receives the developer's contextual guidance alongside the standard failing test and PRD reference information |
| **Rationale** | The guidance is only valuable if it reaches the build agent and influences its fix strategy |
| **Acceptance Criteria** | 1. The guidance text appears in the build prompt under a clearly labeled section (e.g., "Developer Guidance"). 2. The guidance is preserved verbatim (no truncation or summarization). 3. The guidance applies only to the next iteration (not carried forward to subsequent iterations) |

**REQ-SA5-003**: Guidance Audit Trail

| Element | Description |
|---------|-------------|
| **Priority** | Should Have |
| **Actor** | heal-loop.sh orchestrator |
| **Action** | Record the manual guidance text in the audit trail |
| **Outcome** | The audit trail captures what guidance the developer provided and when |
| **Rationale** | For traceability, the human input to the autonomous loop must be recorded alongside the autonomous agent's actions |
| **Acceptance Criteria** | 1. An audit entry of type `manualGuidance` is appended when guidance is provided. 2. The entry includes the guidance text, timestamp, loop ID, and iteration number. 3. The loop state is updated to record that manual guidance was used for this iteration |

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| Requirement | Description |
|-------------|-------------|
| Capture suite time | The 8-capture suite should complete within 60 seconds on the developer workstation (current observed time: approximately 30 seconds post-warmup) |
| Build invocation timeout | No explicit timeout on `/build --afk` invocations; bounded by the outer heal-loop's max-iterations limit |

### 6.2 Security Requirements

| Requirement | Description |
|-------------|-------------|
| Audit integrity | Audit entries must be append-only (JSONL format). Existing entries must never be modified |
| Manual guidance sanitization | Developer guidance text must not be able to inject shell commands or corrupt JSON audit entries |

### 6.3 Usability Requirements

| Requirement | Description |
|-------------|-------------|
| Attended mode clarity | The escalation prompt must clearly display unresolved issues, available options, and expected input format |
| Guidance input feedback | After entering guidance, the system must confirm what was captured before proceeding |

### 6.4 Compliance Requirements

| Requirement | Description |
|-------------|-------------|
| PRD traceability | All requirements trace back to the scope change section of the parent PRD (2026-02-09 addition) |
| Existing pattern adherence | All script changes must follow existing shell conventions (set -euo pipefail, info/error/warn helpers, jq for JSON, append_audit for trail) |

## 7. User Stories

### STORY-SA1-001: Developer Confirms Capture Suite

**As a** developer who just merged the render signal race condition fix,
**I want** to run the full 8-capture test suite end-to-end and see all 8 captures produced,
**So that** I have confidence the capture phase works reliably before running the full heal-loop.

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN a macOS GUI session with mkdn built successfully
- WHEN `swift test --filter VisionCapture` is executed
- THEN 8 PNG files are created in `.rp1/work/verification/captures/`
- AND `manifest.json` contains exactly 8 entries with valid image hashes
- AND the test exits with code 0

### STORY-SA2-001: Heal-Loop Fixes Multiple Tests in One Iteration

**As a** heal-loop orchestrator handling 3 failing tests,
**I want** the `/build --afk` invocation to fix all 3 tests in a single call,
**So that** I do not waste iterations re-capturing and re-evaluating after each individual fix.

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN 3 generated failing test files from one evaluation
- WHEN the heal-loop invokes `/build --afk` with all 3 test paths and their PRD references
- THEN the build agent attempts to fix all 3 tests
- AND the build prompt includes iteration instructions ("run tests, fix, repeat until all pass")
- AND the audit entry records all 3 test paths

### STORY-SA3-001: Regression from Registry History Detected

**As a** verification system re-evaluating after a fix,
**I want** to check if any current issues were previously resolved in the registry history,
**So that** reintroduced issues are flagged as regressions rather than treated as new findings.

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN a registry entry for capture X with evaluations showing issue "spatial-design-language FR-3" was resolved at timestamp T1
- AND a new evaluation at T2 detects "spatial-design-language FR-3" for capture X again
- WHEN verify.sh compares the new evaluation
- THEN the issue is classified as "reintroduced regression" rather than "new issue"
- AND the re-verification report includes the resolution timestamp T1 for context

### STORY-SA4-001: Reviewer Traces Autonomous Changes

**As a** developer reviewing the audit trail after an autonomous heal-loop run,
**I want** to see exactly which test files were passed to `/build --afk` and which source files were modified,
**So that** I can understand and validate what the autonomous agent changed.

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN a completed heal-loop iteration where `/build --afk` was invoked
- WHEN I read the `buildInvocation` entry in `audit.jsonl`
- THEN the entry includes a `testPaths` array listing the generated test files
- AND the entry includes a `filesModified` array listing the source files changed by the fix

### STORY-SA5-001: Developer Guides the Loop Interactively

**As a** developer running the heal-loop in `--attended` mode,
**I want** to provide manual guidance when the loop encounters an issue it cannot resolve autonomously,
**So that** I can steer the next fix iteration without restarting the entire pipeline.

**Acceptance (GIVEN/WHEN/THEN)**:
- GIVEN the heal-loop is running with `--attended` and reaches an escalation point
- AND the developer selects "c" (Continue with manual guidance)
- WHEN the developer enters "Focus on the heading top margin, the code block is acceptable"
- THEN the system confirms the guidance was received
- AND the next `/build --afk` prompt includes the guidance under a "Developer Guidance" section
- AND an audit entry of type `manualGuidance` is recorded

## 8. Business Rules

| ID | Rule |
|----|------|
| BR-1 | The 8-capture matrix (4 fixtures x 2 themes x 1 mode) is fixed and must not be modified by these scope additions |
| BR-2 | Build invocation fidelity improvements must not change the outer heal-loop iteration structure (capture, evaluate, generate, build, verify) |
| BR-3 | Registry-based regression detection must be additive to the existing previous-evaluation comparison, not replace it |
| BR-4 | Manual guidance applies only to the immediately-following iteration; it does not persist across iterations |
| BR-5 | Audit entries are append-only; existing audit trail entries must never be modified retroactively |
| BR-6 | All shell scripts must maintain `set -euo pipefail` and use the existing helper functions (info, error, warn, append_audit) |

## 9. Dependencies & Constraints

| Dependency | Type | Description |
|------------|------|-------------|
| VisionCapture test suite | Foundation | SA-1 validates the existing suite; all other SAs depend on successful capture |
| claude CLI | External tool | SA-2 build invocation uses `claude -p`; must support multi-paragraph prompts |
| git | Tool | SA-4 uses git diff to capture modified files; must be available in the shell environment |
| registry.json | Data | SA-3 reads evaluation history from the registry; depends on correct registry writes by verify.sh |
| Terminal stdin | I/O | SA-5 reads developer guidance from stdin in attended mode; requires interactive terminal |

| Constraint | Impact |
|------------|--------|
| macOS GUI session required | SA-1 (capture) requires a window server; cannot run in headless CI |
| JSONL append-only format | SA-4 audit entries must be valid JSONL and must not break existing entries |
| Shell script conventions | All changes must follow the established patterns in the existing scripts |

## 10. Clarifications Log

| Date | Question | Resolution | Source |
|------|----------|------------|--------|
| 2026-02-09 | What specific render signal race condition was fixed? | Commit f542e0c removed a warm-up step that was causing render timeout in the VisionCapture test | Git history, commit message |
| 2026-02-09 | How many captures does the matrix produce? | 4 fixtures x 2 themes x 1 mode = 8 captures | VisionCaptureConfig in VisionCapturePRD.swift |
| 2026-02-09 | What is the current registry schema? | version 1 with entries array, each entry has captureId, imageHash, evaluations array, lastEvaluated, lastStatus | registry.json and verify.sh registry update logic |
| 2026-02-09 | What audit fields does the current buildInvocation entry have? | type, timestamp, loopId, iteration, result, prdRefs | heal-loop.sh line 616-623 |
| 2026-02-09 | What does the "Continue" option currently do in attended mode? | Prints "not yet implemented" and falls through to write_escalation_report | heal-loop.sh line 280-282 |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | llm-visual-verification.md | Feature ID matches PRD filename directly; only PRD with "Scope Changes" section dated 2026-02-09 |
| Requirement priority weighting | Must Have for core gaps, Should Have for enhancements | Conservative: core gaps (SA-1 confirmation, SA-2 multi-test, SA-3 history check, SA-4 audit fields, SA-5 guidance prompt) are Must Have; ancillary improvements (SA-1 stability, SA-3 depth, SA-5 audit) are Should Have |
| Capture matrix scope | Fixed at 4x2x1=8 | VisionCaptureConfig.fixtures and themes are authoritative; no indication of planned expansion |
| Build iteration approach | Structured prompt with iteration instructions | Conservative approach: improve the prompt rather than changing the invocation mechanism (e.g., multiple claude calls) |
| Registry comparison strategy | Additive to existing comparison | The existing previous-eval comparison is correct for the common case; registry history adds coverage for the edge case of reintroduced regressions |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| "Confirm full 8-capture test suite" -- what does "confirm" mean operationally? | Run the test suite and validate 8 captures with manifest, not just a build-only check | PRD FR-1 (Vision Evaluation Skill) requires screenshot file paths; VisionCaptureTests.swift validates 8 entries |
| "Iterate internally to fix multiple failing tests" -- how should iteration work? | Improve the build prompt to instruct the build agent to iterate (run tests, fix, repeat) within a single invocation | Conservative inference: changing the prompt is lower-risk than restructuring the shell loop |
| "Compare against full registry history" -- what constitutes a registry "history"? | The evaluations array within each registry entry, which records all past evaluations with issue status | verify.sh already writes evaluation entries with status (resolved, remaining, regressed); the data is present but not read back |
| "Record test paths and files modified" -- absolute or relative paths? | Project-relative paths for portability; consistent with existing imagePath format in manifest.json | CaptureManifestEntry.imagePath uses relative paths; audit entries should follow the same convention |
| "Continue with manual guidance" -- what input format? | Multi-line text terminated by an empty line, read from stdin via a simple read loop | Conservative: terminal-based input is the simplest approach consistent with the existing attended mode (which already uses `read -r -p`) |
