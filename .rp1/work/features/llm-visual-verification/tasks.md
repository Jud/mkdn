# Development Tasks: LLM Visual Verification

**Feature ID**: llm-visual-verification
**Status**: Not Started
**Progress**: 67% (8 of 12 tasks)
**Estimated Effort**: 5 days
**Started**: 2026-02-09

## Overview

An autonomous design compliance workflow that uses Claude Code's built-in vision capabilities to evaluate mkdn's rendered output against design specifications, detect visual deviations, generate failing tests encoding those deviations, invoke `/build --afk` to fix them, and re-verify the result. The workflow operates entirely outside the mkdn application -- it is developer tooling that orchestrates existing infrastructure without modifying mkdn's source architecture.

Three implementation layers: shell scripts in `scripts/visual-verification/` that orchestrate each phase of the workflow, Swift test infrastructure in `mkdnTests/UITest/VisionCompliance/` for deterministic screenshot capture and generated test hosting, and CLAUDE.md documentation that instructs Claude Code how to invoke the workflow. Prompt templates and persistent state live in `scripts/visual-verification/prompts/` and `.rp1/work/verification/` respectively.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. **[T1, T3]** -- Directory structure and prompt templates are independent
2. **[T2, T12]** -- Capture orchestrator and shared test harness depend on T1 (directories) but not on each other
3. **[T9, T10]** -- Shell scripts depend on T2 (capture.sh needs capture suite), T3 (evaluate.sh needs prompts), and T12 (generate-tests.sh references VisionCompliancePRD)
4. **[T11]** -- Heal loop depends on T9 + T10 (chains all phase scripts)
5. **[T13]** -- CLAUDE.md docs depend on T11 (needs final script interfaces)

**Dependencies**:

- T2 -> T1 (Data: capture orchestrator writes to verification directory created in T1)
- T12 -> T1 (Data: shared harness file lives in VisionCompliance/ created in T1)
- T9 -> T2 (Interface: capture.sh invokes `swift test --filter VisionCapture` from T2)
- T9 -> T3 (Interface: evaluate.sh reads prompt templates from T3)
- T10 -> T3 (Interface: generate-tests.sh reads test templates from T3)
- T10 -> T12 (Interface: generated tests reference VisionComplianceHarness from T12)
- T11 -> [T9, T10] (Interface: heal-loop.sh chains capture.sh, evaluate.sh, generate-tests.sh, verify.sh)
- T13 -> T11 (Data: CLAUDE.md documents final script interfaces from T11)

**Critical Path**: T1 -> T2 + T3 (parallel) -> T9 + T10 (parallel) -> T11 -> T13

## Task Breakdown

### Foundation (Parallel Group 1)

- [x] **T1**: Create verification directory structure, script directories, and initial empty artifacts `[complexity:simple]`

    **Reference**: [design.md#t1-verification-directory-structure](design.md#t1-verification-directory-structure)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] Directory `.rp1/work/verification/` exists
    - [x] Directory `.rp1/work/verification/captures/` exists for screenshot staging
    - [x] Directory `.rp1/work/verification/cache/` exists for evaluation cache
    - [x] Directory `.rp1/work/verification/reports/` exists for evaluation and escalation reports
    - [x] Directory `.rp1/work/verification/staging/` exists for atomic test generation staging
    - [x] File `.rp1/work/verification/registry.json` exists with initial empty registry (`{"version": 1, "entries": []}`)
    - [x] Directory `scripts/visual-verification/` exists for orchestration shell scripts
    - [x] Directory `scripts/visual-verification/prompts/` exists for prompt templates
    - [x] Directory `mkdnTests/UITest/VisionCompliance/` exists for generated tests
    - [x] All directories and files are committed to git

    **Implementation Summary**:

    - **Files**: `.rp1/work/verification/registry.json`, `.gitkeep` files in `captures/`, `cache/`, `reports/`, `staging/`, `scripts/visual-verification/prompts/`, `mkdnTests/UITest/VisionCompliance/`
    - **Approach**: Created all directories per design spec; added `.gitkeep` sentinel files to empty directories so git tracks them; wrote initial empty registry JSON
    - **Deviations**: None
    - **Tests**: N/A (directory structure only)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ⏭️ N/A |

- [x] **T3**: Create evaluation prompt templates and output schema for vision-based design evaluation `[complexity:medium]`

    **Reference**: [design.md#38-evaluation-prompt-construction](design.md#38-evaluation-prompt-construction)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] File `scripts/visual-verification/prompts/evaluation-prompt.md` exists with the base evaluation prompt template containing placeholders for `{charter_design_philosophy}`, `{prd_excerpts}`, and `{output_schema}`
    - [x] File `scripts/visual-verification/prompts/prd-context-spatial.md` exists with spatial-design-language PRD excerpts relevant to canonical.md and geometry-calibration.md evaluation
    - [x] File `scripts/visual-verification/prompts/prd-context-visual.md` exists with terminal-consistent-theming and syntax-highlighting PRD excerpts relevant to theme-tokens.md evaluation
    - [x] File `scripts/visual-verification/prompts/prd-context-mermaid.md` exists with mermaid-rendering PRD excerpts relevant to mermaid-focus.md evaluation
    - [x] File `scripts/visual-verification/prompts/output-schema.json` exists with the evaluation output JSON schema matching design.md section 3.9
    - [x] File `scripts/visual-verification/prompts/test-template-spatial.md` exists with a template for spatial assertion tests using SpatialMeasurement infrastructure
    - [x] File `scripts/visual-verification/prompts/test-template-visual.md` exists with a template for color/theme assertion tests using ImageAnalyzer and ColorExtractor infrastructure
    - [x] File `scripts/visual-verification/prompts/test-template-qualitative.md` exists with a template for qualitative assessment tests that measure proxy metrics
    - [x] Evaluation criteria cover all five dimensions: concrete PRD compliance, spatial rhythm and balance, theme coherence, visual consistency, overall rendering quality
    - [x] PRD-to-fixture mapping matches design.md section 3.8 table (canonical -> spatial+cross-element, theme-tokens -> theming+syntax, mermaid-focus -> mermaid, geometry-calibration -> spatial)
    - [x] Test templates follow generated test rules from design.md section 3.12: one @Suite per file, VisionDetected_{prdCamelCase}_{FR} naming, doc comments with evaluation ID/PRD ref/spec/observation, JSONResultReporter recording

    **Implementation Summary**:

    - **Files**: `scripts/visual-verification/prompts/evaluation-prompt.md`, `prd-context-spatial.md`, `prd-context-visual.md`, `prd-context-mermaid.md`, `output-schema.json`, `test-template-spatial.md`, `test-template-visual.md`, `test-template-qualitative.md`
    - **Approach**: Created 8 prompt template files per design spec. Evaluation prompt uses three placeholders ({charter_design_philosophy}, {prd_excerpts}, {output_schema}) and covers all five evaluation dimensions. PRD context files extract relevant functional requirements from spatial-design-language, terminal-consistent-theming, syntax-highlighting, and mermaid-rendering PRDs with visual evaluation notes. Output schema is a JSON Schema document matching design.md section 3.9 structure. Test templates follow section 3.12 rules: one @Suite per file, VisionDetected naming convention, doc comments with source traceability, JSONResultReporter recording, and reference existing test infrastructure (ImageAnalyzer, SpatialMeasurement, ColorExtractor, measureVerticalGaps).
    - **Deviations**: None
    - **Tests**: N/A (prompt templates, not compiled code)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ⏭️ N/A |

### Capture and Harness (Parallel Group 2)

- [x] **T2**: Implement the capture orchestrator Swift test suite for deterministic screenshot capture `[complexity:complex]`

    **Reference**: [design.md#37-capture-orchestrator-swift](design.md#37-capture-orchestrator-swift)

    **Effort**: 8 hours

    **Acceptance Criteria**:

    - [x] File `mkdnTests/UITest/VisionCompliance/VisionCaptureTests.swift` exists with a `@Suite("VisionCapture", .serialized)` test suite
    - [x] File `mkdnTests/UITest/VisionCompliance/VisionCapturePRD.swift` exists with `VisionCaptureHarness` singleton (following SpatialHarness/VisualHarness/AnimationHarness pattern), `VisionCaptureConfig` (fixtures, themes), fixture path helpers, and manifest writing logic
    - [x] Capture matrix covers all 4 fixtures (canonical.md, theme-tokens.md, mermaid-focus.md, geometry-calibration.md) x 2 themes (solarizedDark, solarizedLight) x 1 mode (previewOnly) = 8 captures
    - [x] Screenshots saved to `.rp1/work/verification/captures/` with naming convention `{fixture}-{theme}-{mode}.png`
    - [x] Manifest file written to `.rp1/work/verification/captures/manifest.json` with all required metadata fields (id, imagePath, fixture, theme, viewMode, width, height, scaleFactor, imageHash)
    - [x] SHA-256 image hash computed for each capture and included in the manifest
    - [x] 1500ms sleep after loadFile matches existing VisualComplianceTests pattern for entrance animation settling
    - [x] Suite compiles with `swift build`
    - [ ] Suite runs successfully with `swift test --filter VisionCapture` and produces 8 PNG files plus manifest.json
    - [x] Code passes `swiftlint lint` and `swiftformat .`

    **Implementation Summary**:

    - **Files**: `mkdnTests/UITest/VisionCompliance/VisionCaptureTests.swift`, `mkdnTests/UITest/VisionCompliance/VisionCapturePRD.swift`
    - **Approach**: Followed existing SpatialHarness/VisualHarness/AnimationHarness singleton pattern. VisionCapturePRD provides harness, config, fixture paths, SHA-256 hash (CryptoKit), manifest types, and manifest writing. VisionCaptureTests iterates 4 fixtures x 2 themes, captures with 1500ms settle delay, computes hashes, and writes manifest.json. Test validates 8 captures produced with correct metadata.
    - **Deviations**: None
    - **Tests**: Compiles and links; runtime test requires macOS GUI session (swift test --filter VisionCapture)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T12**: Implement the shared test harness for vision-detected generated tests `[complexity:simple]`

    **Reference**: [design.md#312-test-generation](design.md#312-test-generation)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] File `mkdnTests/UITest/VisionCompliance/VisionCompliancePRD.swift` exists with `VisionComplianceHarness` singleton (following existing SpatialHarness/VisualHarness pattern)
    - [x] Harness provides `ensureRunning()` async method returning `TestHarnessClient`
    - [x] Helper function `visionFixturePath(_:)` resolves fixture file paths for generated tests
    - [x] Helper function `visionExtractCapture(from:)` extracts capture data from harness response
    - [x] Helper function `visionLoadAnalyzer(from:)` creates an ImageAnalyzer from capture data
    - [x] File compiles with `swift build`
    - [x] Code passes `swiftlint lint` and `swiftformat .`

    **Implementation Summary**:

    - **Files**: `mkdnTests/UITest/VisionCompliance/VisionCompliancePRD.swift`
    - **Approach**: Followed existing SpatialHarness/VisualHarness singleton pattern exactly. VisionComplianceHarness provides ensureRunning() with ping health check and shutdown(). Free functions visionFixturePath (project-root walk), visionExtractCapture (response validation + .capture extraction), and visionLoadAnalyzer (CGImageSource load + ImageAnalyzer init with scale factor). VisionCompliancePRD empty enum as namespace marker.
    - **Deviations**: None
    - **Tests**: Compiles and links; no runtime test needed (infrastructure file)

### Shell Scripts -- Phase Scripts (Parallel Group 3)

- [x] **T9**: Implement capture.sh and evaluate.sh orchestration scripts `[complexity:medium]`

    **Reference**: [design.md#32-capturesh](design.md#32-capturesh), [design.md#33-evaluatesh](design.md#33-evaluatesh)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] File `scripts/visual-verification/capture.sh` exists, is executable, and uses `set -euo pipefail`
    - [x] capture.sh builds mkdn (`swift build --product mkdn`), supports `--skip-build` flag
    - [x] capture.sh runs `swift test --filter VisionCapture` and validates manifest.json exists with entries
    - [x] capture.sh exits 0 on success, 1 on failure
    - [x] File `scripts/visual-verification/evaluate.sh` exists, is executable, and uses `set -euo pipefail`
    - [x] evaluate.sh reads manifest.json, computes cache key (SHA-256 of sorted image hashes + prompt hash + PRD hashes)
    - [x] evaluate.sh checks cache directory for existing result and returns cached result on hit
    - [x] evaluate.sh assembles evaluation prompt from charter design philosophy, PRD excerpts, evaluation criteria, and output schema
    - [x] evaluate.sh groups captures into batches by fixture (same fixture, both themes = 1 batch), respects `--batch-size` flag (default 4)
    - [x] evaluate.sh supports `--dry-run` mode that writes a dry-run report without making evaluation calls
    - [x] evaluate.sh writes evaluation report to `.rp1/work/verification/reports/{timestamp}-evaluation.json`
    - [x] evaluate.sh populates cache entry and appends audit trail entry
    - [x] Both scripts resolve `PROJECT_ROOT` from `SCRIPT_DIR` and use `info()`/`error()` helper functions
    - [x] Both scripts follow conventions from existing `scripts/release.sh` and `scripts/smoke-test.sh`

    **Implementation Summary**:

    - **Files**: `scripts/visual-verification/capture.sh`, `scripts/visual-verification/evaluate.sh`
    - **Approach**: Both scripts follow release.sh conventions (set -euo pipefail, SCRIPT_DIR/PROJECT_ROOT resolution, info/error helpers). capture.sh: build + swift test --filter VisionCapture + manifest validation via jq. evaluate.sh: manifest parsing, SHA-256 cache key computation (image hashes + prompt template + charter + PRD file hashes), cache check/populate, charter design philosophy extraction via sed, PRD context mapping per fixture, batch grouping by fixture stem, dry-run report generation, Claude Code CLI invocation for vision evaluation per batch, batch result merging with jq, report/cache/audit writing.
    - **Deviations**: Added --force-fresh flag to evaluate.sh (bypasses cache) for debugging convenience; not in original AC but supports the caching workflow. Cache entry includes inputHashes per design schema section 3.10.
    - **Tests**: Validated via bash -n syntax check, --help flag output, and full --dry-run execution with 8-capture test manifest producing correct 4-batch composition

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T10**: Implement generate-tests.sh and verify.sh orchestration scripts `[complexity:medium]`

    **Reference**: [design.md#34-generate-testssh](design.md#34-generate-testssh), [design.md#36-verifysh](design.md#36-verifysh)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] File `scripts/visual-verification/generate-tests.sh` exists, is executable, and uses `set -euo pipefail`
    - [x] generate-tests.sh reads evaluation report JSON and filters for medium/high confidence issues
    - [x] generate-tests.sh reads appropriate test template from `scripts/visual-verification/prompts/test-template-{type}.md` for each issue
    - [x] generate-tests.sh writes generated test files to staging directory (`.rp1/work/verification/staging/`) first
    - [x] generate-tests.sh validates compilation (`swift build`) for each generated test; discards on failure
    - [x] generate-tests.sh validates failure (`swift test --filter {testName}`) for each generated test; discards if test passes (false positive)
    - [x] generate-tests.sh moves validated tests from staging to `mkdnTests/UITest/VisionCompliance/`
    - [x] generate-tests.sh follows naming convention `VisionDetected_{PRD}_{FR}_{aspect}.swift`
    - [x] generate-tests.sh appends audit trail entries for each generation attempt
    - [x] File `scripts/visual-verification/verify.sh` exists, is executable, and uses `set -euo pipefail`
    - [x] verify.sh accepts previous evaluation path as argument
    - [x] verify.sh runs capture.sh with `--skip-build`, then evaluate.sh (fresh, bypasses cache)
    - [x] verify.sh compares new evaluation against previous: resolved, regression, remaining
    - [x] verify.sh writes re-verification report and updates registry with resolution status
    - [x] Both scripts follow existing `scripts/` conventions

    **Implementation Summary**:

    - **Files**: `scripts/visual-verification/generate-tests.sh`, `scripts/visual-verification/verify.sh`
    - **Approach**: Both scripts follow release.sh/capture.sh conventions (set -euo pipefail, SCRIPT_DIR/PROJECT_ROOT resolution, info/error/append_audit helpers). generate-tests.sh: reads evaluation report, filters medium/high confidence issues via jq, determines test type from suggestedAssertion.type or PRD reference inference, reads corresponding test template, invokes Claude Code CLI per issue to generate Swift test files into staging dir, validates compilation (swift build) and failure (swift test --filter), discards invalid tests with audit logging, promotes validated tests to VisionCompliance/. Uses perl for macOS-compatible camelCase conversion. verify.sh: invokes capture.sh --skip-build then evaluate.sh --force-fresh, compares previous vs new evaluation by prdReference (issues) and reference (qualitative findings) to classify resolved/regression/remaining, writes re-verification report JSON, upserts registry entries per capture with status tracking, appends reVerification audit entry. Both scripts output structured key=value summary for caller parsing.
    - **Deviations**: None
    - **Tests**: Validated via bash -n syntax check, --help flag output, jq filtering correctness against mock evaluation data, captureId parsing for all fixture patterns, camelCase conversion, and JSON report construction

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

### Shell Scripts -- Orchestrator (Parallel Group 4)

- [x] **T11**: Implement heal-loop.sh top-level orchestrator script `[complexity:complex]`

    **Reference**: [design.md#35-heal-loopsh](design.md#35-heal-loopsh)

    **Effort**: 8 hours

    **Acceptance Criteria**:

    - [x] File `scripts/visual-verification/heal-loop.sh` exists, is executable, and uses `set -euo pipefail`
    - [x] Supports `--max-iterations` flag (default 3), `--dry-run`, `--attended`, `--skip-build`
    - [x] Chains phases: capture.sh -> evaluate.sh -> generate-tests.sh -> git commit -> /build --afk -> verify.sh
    - [x] Bounded iteration loop: re-capture, re-evaluate, generate new tests for regressions, re-invoke /build --afk, up to max iterations
    - [x] Tracks iteration state in `.rp1/work/verification/current-loop.json` per design.md section 3.5 schema
    - [x] On no issues detected: writes clean report and exits 0
    - [x] On all tests generated discarded (low-confidence or failed validation): writes escalation report and exits 0
    - [x] On max iterations exhausted with remaining issues: writes escalation report to `.rp1/work/verification/reports/{timestamp}-escalation.json` and exits 1
    - [x] On clean resolution: writes success report and exits 0
    - [x] Git commits generated tests before invoking /build --afk: `git add mkdnTests/UITest/VisionCompliance/ && git commit -m "test: vision-detected failing tests for {PRD refs}"`
    - [x] Updates `.rp1/work/verification/registry.json` after each re-verification
    - [x] Appends to `.rp1/work/verification/audit.jsonl` for every operation (JSON Lines format, one object per line)
    - [x] Attended mode (`--attended`): outputs escalation context to stdout and waits for input instead of writing report file
    - [x] Dry-run mode: runs capture.sh + evaluate.sh --dry-run only, no test generation or /build --afk
    - [x] Graceful degradation: capture failure aborts cleanly, /build --afk failure escalates, git failure cleans up staged files, registry corruption reinitializes
    - [x] Follows existing `scripts/` conventions

    **Implementation Summary**:

    - **Files**: `scripts/visual-verification/heal-loop.sh`
    - **Approach**: Top-level orchestrator following release.sh conventions (set -euo pipefail, SCRIPT_DIR/PROJECT_ROOT resolution, info/error/warn helpers). Chains all phase scripts in sequence: capture.sh -> evaluate.sh -> generate-tests.sh -> git commit -> claude CLI for fix -> verify.sh. Bounded iteration loop with configurable max (default 3). Tracks full loop state in current-loop.json (loopId, iterations array with evaluationId, issuesDetected, testsGenerated, buildResult, reVerification). Three report types: clean (no issues), success (resolved), escalation (unresolved). Attended mode outputs escalation context to stdout with interactive read prompt. Dry-run mode runs only capture + evaluate --dry-run. Graceful degradation: capture failure aborts with exit 2, build failure escalates with exit 1, git failure cleans up staged files, corrupt registry reinitializes. Audit trail appended for loopStarted, buildInvocation, escalation, loopCompleted events.
    - **Deviations**: None
    - **Tests**: Validated via bash -n syntax check, --help flag output

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

### Documentation (Parallel Group 5)

- [x] **T13**: Add visual verification workflow section to CLAUDE.md `[complexity:simple]`

    **Reference**: [design.md#320-claudemd-integration](design.md#320-claudemd-integration)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] CLAUDE.md contains a "Visual Verification Workflow" section under the project documentation
    - [x] Section includes quick reference with all script invocations: heal-loop.sh, capture.sh, evaluate.sh, generate-tests.sh, verify.sh
    - [x] Section includes flags: `--dry-run`, `--attended`, `--max-iterations`, `--skip-build`, `--batch-size`
    - [x] Section includes artifact locations: captures, reports, registry, audit, generated tests, prompt templates
    - [x] All script invocations documented with examples

    **Implementation Summary**:

    - **Files**: `CLAUDE.md`
    - **Approach**: Added "Visual Verification Workflow" section after "rp1 Workflow" section. Includes overview paragraph, Quick Reference with bash code block showing all five scripts (heal-loop.sh, capture.sh, evaluate.sh, generate-tests.sh, verify.sh), Flags table covering all flags across all scripts (--max-iterations, --dry-run, --attended, --skip-build, --batch-size, --force-fresh, positional args), and Artifacts table mapping eight locations to their purposes.
    - **Deviations**: Added --force-fresh flag for evaluate.sh (implemented in T9 but not in original AC list); included positional argument documentation for generate-tests.sh and verify.sh
    - **Tests**: N/A (documentation only)

### User Docs

- [ ] **TD1**: Update modules.md - Test Layer `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Test Layer

    **KB Source**: modules.md:Test Layer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] VisionCompliance suite added to the UI Compliance Suites table in modules.md with file paths and purpose descriptions for VisionCaptureTests.swift, VisionCapturePRD.swift, and VisionCompliancePRD.swift
    - [ ] Section reflects the capture orchestrator and generated test hosting roles accurately

- [ ] **TD2**: Update architecture.md - Test Harness Mode `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Test Harness Mode

    **KB Source**: architecture.md:Test Harness Mode

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Vision verification listed as a consumer of the test harness infrastructure alongside existing spatial, visual, and animation compliance suites
    - [ ] Section describes the capture orchestrator's role in producing deterministic screenshots for LLM evaluation

- [ ] **TD3**: Update index.md - Quick Reference `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/index.md`

    **Section**: Quick Reference

    **KB Source**: index.md:Quick Reference

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Entry for `scripts/visual-verification/` directory added to the Quick Reference list
    - [ ] Entry for `.rp1/work/verification/` directory added to the Quick Reference list
    - [ ] Entry for `mkdnTests/UITest/VisionCompliance/` added to the Quick Reference list

- [ ] **TD4**: Create usage guide for the visual verification workflow `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: add

    **Target**: `docs/visual-verification.md`

    **Section**: (new file)

    **KB Source**: -

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New file created at `docs/visual-verification.md`
    - [ ] Covers shell script invocation (heal-loop.sh, capture.sh, evaluate.sh, generate-tests.sh, verify.sh)
    - [ ] Covers configuration flags (--dry-run, --attended, --max-iterations, --skip-build, --batch-size)
    - [ ] Covers interpreting evaluation reports (issue severity, confidence, PRD references)
    - [ ] Covers interpreting escalation reports (unresolved issues, suggested next steps)
    - [ ] Covers the self-healing loop lifecycle (capture -> evaluate -> generate -> fix -> verify)
    - [ ] Covers cost management (caching, dry-run, batch composition)

## Acceptance Criteria Checklist

- [ ] REQ-001: Vision-based evaluation produces structured JSON assessments for each screenshot, considering both concrete PRD requirements and qualitative design judgment, with deterministic prompt construction
- [ ] REQ-002: Each detected issue includes PRD reference, specification text, observation, deviation description, severity (critical/major/minor), and confidence (high/medium/low)
- [ ] REQ-003: For each medium/high confidence issue, a compilable, currently-failing Swift test is generated using existing harness infrastructure; low-confidence issues are flagged only
- [ ] REQ-004: Generated tests are committed and /build --afk is invoked with failing test paths and PRD context; the full cycle runs without human interaction
- [ ] REQ-005: After fix, fresh screenshots are captured and re-evaluated; original issues confirmed resolved; new regressions detected; loop bounded to max 3 iterations
- [ ] REQ-006: Related screenshots batched (by fixture, max 4 per batch); results cached by content hash; cost estimate provided; dry-run mode available
- [ ] REQ-007: Registry records evaluation history with screenshot hash, timestamps, issues, resolution status; regressions detected on re-evaluation
- [ ] REQ-008: All results reported in structured JSON: evaluation reports, fix results, re-verification outcomes at predictable locations
- [ ] REQ-009: Low-confidence issues flagged for human review; max-iterations exhausted produces escalation report; attended mode prompts interactively
- [ ] REQ-010: Every operation logged to audit.jsonl with full traceability: evaluations, test generations, build invocations, re-verifications
- [ ] REQ-011: Evaluation assesses qualitative design qualities (spatial rhythm, visual balance, theme coherence) using charter design philosophy as context
- [ ] REQ-012: Evaluation prompt constructed deterministically from version-controlled files; no external state; cache correctly identifies unchanged inputs

## Definition of Done

- [ ] All tasks completed
- [ ] All AC verified
- [ ] Code reviewed
- [ ] Docs updated
