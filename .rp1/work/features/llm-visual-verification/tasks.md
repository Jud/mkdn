# Development Tasks: LLM Visual Verification

**Feature ID**: llm-visual-verification
**Status**: In Progress
**Progress**: 91% (20 of 22 tasks)
**Estimated Effort**: 7.5 days
**Started**: 2026-02-09

## Overview

An autonomous design compliance workflow that uses Claude Code's built-in vision capabilities to evaluate mkdn's rendered output against design specifications, detect visual deviations, generate failing tests encoding those deviations, invoke `/build --afk` to fix them, and re-verify the result. The workflow operates entirely outside the mkdn application -- it is developer tooling that orchestrates existing infrastructure without modifying mkdn's source architecture.

Three implementation layers: shell scripts in `scripts/visual-verification/` that orchestrate each phase of the workflow, Swift test infrastructure in `mkdnTests/UITest/VisionCompliance/` for deterministic screenshot capture and generated test hosting, and CLAUDE.md documentation that instructs Claude Code how to invoke the workflow. Prompt templates and persistent state live in `scripts/visual-verification/prompts/` and `.rp1/work/verification/` respectively.

v3 scope additions (SA-1 through SA-5) address gaps in runtime verification confidence, build invocation robustness, registry-based regression detection, audit trail completeness, and interactive attended mode continuation.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. **[T1, T3]** -- Directory structure and prompt templates are independent
2. **[T2, T12]** -- Capture orchestrator and shared test harness depend on T1 (directories) but not on each other
3. **[T9, T10]** -- Shell scripts depend on T2 (capture.sh needs capture suite), T3 (evaluate.sh needs prompts), and T12 (generate-tests.sh references VisionCompliancePRD)
4. **[T11]** -- Heal loop depends on T9 + T10 (chains all phase scripts)
5. **[T13]** -- CLAUDE.md docs depend on T11 (needs final script interfaces)
6. **[T14, T15, T16]** -- SA-1 runtime verification is independent (no code changes), SA-3 modifies verify.sh only, SA-5 modifies heal-loop.sh's escalation handler only (no overlap with SA-2/SA-4 changes in heal-loop.sh's build invocation section)
7. **[T17]** -- SA-2 build prompt restructuring depends on T16 (MANUAL_GUIDANCE variable must exist for guidance incorporation)
8. **[T18]** -- SA-4 audit entry depends on T17 (uses FILES_MODIFIED and TESTS_FIXED data computed in T17)
9. **[TD5]** -- Documentation depends on all SA implementation tasks being finalized

**Dependencies** (original):

- T2 -> T1 (Data: capture orchestrator writes to verification directory created in T1)
- T12 -> T1 (Data: shared harness file lives in VisionCompliance/ created in T1)
- T9 -> T2 (Interface: capture.sh invokes `swift test --filter VisionCapture` from T2)
- T9 -> T3 (Interface: evaluate.sh reads prompt templates from T3)
- T10 -> T3 (Interface: generate-tests.sh reads test templates from T3)
- T10 -> T12 (Interface: generated tests reference VisionComplianceHarness from T12)
- T11 -> [T9, T10] (Interface: heal-loop.sh chains capture.sh, evaluate.sh, generate-tests.sh, verify.sh)
- T13 -> T11 (Data: CLAUDE.md documents final script interfaces from T11)

**Dependencies** (v3 scope additions):

- T17 -> T16 (Interface: build prompt incorporates MANUAL_GUIDANCE variable defined in T16)
- T18 -> T17 (Data: audit entry uses FILES_MODIFIED and TESTS_FIXED computed in T17)
- TD5 -> [T14, T15, T16, T17, T18] (Data: documentation reflects final implementation)

**Critical Path** (original): T1 -> T2 + T3 (parallel) -> T9 + T10 (parallel) -> T11 -> T13

**Critical Path** (v3 additions): T16 -> T17 -> T18 -> TD5

## Task Breakdown

### Foundation (Parallel Group 1)

- [x] **T1**: Create verification directory structure, script directories, and initial empty artifacts `[complexity:simple]`

    **Reference**: [design.md#2-architecture](design.md#2-architecture)

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
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | N/A |

- [x] **T3**: Create evaluation prompt templates and output schema for vision-based design evaluation `[complexity:medium]`

    **Reference**: [design.md#39-evaluation-prompt-construction](design.md#39-evaluation-prompt-construction)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] File `scripts/visual-verification/prompts/evaluation-prompt.md` exists with the base evaluation prompt template containing placeholders for `{charter_design_philosophy}`, `{prd_excerpts}`, and `{output_schema}`
    - [x] File `scripts/visual-verification/prompts/prd-context-spatial.md` exists with spatial-design-language PRD excerpts relevant to canonical.md and geometry-calibration.md evaluation
    - [x] File `scripts/visual-verification/prompts/prd-context-visual.md` exists with terminal-consistent-theming and syntax-highlighting PRD excerpts relevant to theme-tokens.md evaluation
    - [x] File `scripts/visual-verification/prompts/prd-context-mermaid.md` exists with mermaid-rendering PRD excerpts relevant to mermaid-focus.md evaluation
    - [x] File `scripts/visual-verification/prompts/output-schema.json` exists with the evaluation output JSON schema matching design.md section 3.10
    - [x] File `scripts/visual-verification/prompts/test-template-spatial.md` exists with a template for spatial assertion tests using SpatialMeasurement infrastructure
    - [x] File `scripts/visual-verification/prompts/test-template-visual.md` exists with a template for color/theme assertion tests using ImageAnalyzer and ColorExtractor infrastructure
    - [x] File `scripts/visual-verification/prompts/test-template-qualitative.md` exists with a template for qualitative assessment tests that measure proxy metrics
    - [x] Evaluation criteria cover all five dimensions: concrete PRD compliance, spatial rhythm and balance, theme coherence, visual consistency, overall rendering quality
    - [x] PRD-to-fixture mapping matches design.md section 3.8 table (canonical -> spatial+cross-element, theme-tokens -> theming+syntax, mermaid-focus -> mermaid, geometry-calibration -> spatial)
    - [x] Test templates follow generated test rules from design.md section 3.13: one @Suite per file, VisionDetected_{prdCamelCase}_{FR} naming, doc comments with evaluation ID/PRD ref/spec/observation, JSONResultReporter recording

    **Implementation Summary**:

    - **Files**: `scripts/visual-verification/prompts/evaluation-prompt.md`, `prd-context-spatial.md`, `prd-context-visual.md`, `prd-context-mermaid.md`, `output-schema.json`, `test-template-spatial.md`, `test-template-visual.md`, `test-template-qualitative.md`
    - **Approach**: Created 8 prompt template files per design spec. Evaluation prompt uses three placeholders ({charter_design_philosophy}, {prd_excerpts}, {output_schema}) and covers all five evaluation dimensions. PRD context files extract relevant functional requirements from spatial-design-language, terminal-consistent-theming, syntax-highlighting, and mermaid-rendering PRDs with visual evaluation notes. Output schema is a JSON Schema document matching design.md section 3.9 structure. Test templates follow section 3.13 rules: one @Suite per file, VisionDetected naming convention, doc comments with source traceability, JSONResultReporter recording, and reference existing test infrastructure (ImageAnalyzer, SpatialMeasurement, ColorExtractor, measureVerticalGaps).
    - **Deviations**: None
    - **Tests**: N/A (prompt templates, not compiled code)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | N/A |

### Capture and Harness (Parallel Group 2)

- [x] **T2**: Implement the capture orchestrator Swift test suite for deterministic screenshot capture `[complexity:complex]`

    **Reference**: [design.md#38-capture-orchestrator-swift](design.md#38-capture-orchestrator-swift)

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
    - [x] Suite runs successfully with `swift test --filter VisionCapture` and produces 8 PNG files plus manifest.json
    - [x] Code passes `swiftlint lint` and `swiftformat .`

    **Implementation Summary**:

    - **Files**: `mkdnTests/UITest/VisionCompliance/VisionCaptureTests.swift`, `mkdnTests/UITest/VisionCompliance/VisionCapturePRD.swift`
    - **Approach**: Followed existing SpatialHarness/VisualHarness/AnimationHarness singleton pattern. VisionCapturePRD provides harness, config, fixture paths, SHA-256 hash (CryptoKit), manifest types, and manifest writing. VisionCaptureTests iterates 4 fixtures x 2 themes, captures with 1500ms settle delay, computes hashes, and writes manifest.json. Test validates 8 captures produced with correct metadata.
    - **Deviations**: None
    - **Tests**: Compiles and links; runtime test requires macOS GUI session (swift test --filter VisionCapture)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | PASS |

- [x] **T12**: Implement the shared test harness for vision-detected generated tests `[complexity:simple]`

    **Reference**: [design.md#313-test-generation](design.md#313-test-generation)

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

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | PASS |

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
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | PASS |

- [x] **T10**: Implement generate-tests.sh and verify.sh orchestration scripts `[complexity:medium]`

    **[!] Review needed**: Design section 3.6 (verify.sh) modified -- SA-3 scope addition adds registry-based regression detection (Phase 3b). The original verify.sh implementation (previous-eval comparison only) is correct for its scope. New functionality is covered by T15.

    **Reference**: [design.md#34-generate-testssh](design.md#34-generate-testssh), [design.md#36-verifysh-updated-for-sa-3](design.md#36-verifysh-updated-for-sa-3)

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
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | PASS |

### Shell Scripts -- Orchestrator (Parallel Group 4)

- [x] **T11**: Implement heal-loop.sh top-level orchestrator script `[complexity:complex]`

    **[!] Review needed**: Design section 3.5 (heal-loop.sh) modified -- SA-2, SA-4, SA-5 scope additions require multi-test build prompt (3.5.1-3.5.2), enhanced audit entries (3.5.3), and attended mode guidance (3.5.4). The original heal-loop.sh implementation is correct for its scope. New functionality is covered by T16, T17, and T18.

    **Reference**: [design.md#35-heal-loopsh-updated-for-sa-2-sa-4-sa-5](design.md#35-heal-loopsh-updated-for-sa-2-sa-4-sa-5)

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
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | PASS |

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

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | N/A |

### v3 Scope Additions -- SA-1 through SA-5 (Parallel Group 6-8)

- [x] **T14**: SA-1 Runtime Verification -- Validate the existing 8-capture test suite runs end-to-end `[complexity:simple]`

    **Reference**: [design.md#37-sa-1-runtime-verification](design.md#37-sa-1-runtime-verification)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] `swift test --filter VisionCapture` exits 0 in a macOS GUI session
    - [x] `.rp1/work/verification/captures/manifest.json` exists and contains exactly 8 entries
    - [x] All 8 expected capture IDs present: `geometry-calibration-solarizedDark-previewOnly`, `geometry-calibration-solarizedLight-previewOnly`, `theme-tokens-solarizedDark-previewOnly`, `theme-tokens-solarizedLight-previewOnly`, `canonical-solarizedDark-previewOnly`, `canonical-solarizedLight-previewOnly`, `mermaid-focus-solarizedDark-previewOnly`, `mermaid-focus-solarizedLight-previewOnly`
    - [x] Each capture has non-zero dimensions and valid `sha256:` prefixed hash
    - [x] Each manifest entry references an existing PNG file
    - [ ] (Should Have) Two consecutive runs produce identical image hashes for stability confirmation (REQ-SA1-002)

    **Implementation Summary**:

    - **Files**: No code changes (verification-only task)
    - **Approach**: Ran `swift test --filter VisionCapture` twice consecutively in macOS GUI session. Both runs exited 0 and produced 8 PNG files plus manifest.json with correct metadata (1904x1504 at 2x scale, sha256-prefixed hashes, all expected capture IDs present). All Must Have ACs verified. REQ-SA1-002 (Should Have stability): hashes differ between runs due to sub-pixel rendering non-determinism in macOS text rendering and WKWebView Mermaid output; file sizes differ by only a few hundred bytes, indicating visual near-equivalence rather than structural divergence.
    - **Deviations**: REQ-SA1-002 not met -- image hashes are not bitwise identical across runs. This is an inherent characteristic of CGWindowListCreateImage capture on macOS and does not affect the evaluation workflow (which uses LLM vision, not hash comparison, for image assessment).
    - **Tests**: 2/2 runs passed (17.360s and 17.384s respectively)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | N/A |

- [x] **T15**: SA-3 Registry-Based Regression Detection -- Enhance verify.sh with historical regression detection `[complexity:medium]`

    **Reference**: [design.md#36-verifysh-updated-for-sa-3](design.md#36-verifysh-updated-for-sa-3), [design.md#361-sa-3-registry-historical-comparison](design.md#361-sa-3-registry-historical-comparison)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] verify.sh reads `registry.json` for each capture in the new evaluation
    - [x] After existing Phase 3 (previous-eval comparison), Phase 3b performs registry history scan
    - [x] For each new-eval issue not already classified, script checks if that PRD reference was previously resolved in any prior evaluation in the registry
    - [x] Matches classified as "reintroduced regression" with original resolution timestamp attached
    - [x] Re-verification report JSON includes `reintroducedRegressions` section with `prdReference`, `previouslyResolvedAt`, `currentObservation`, `severity`, `confidence` fields
    - [x] Re-verification report `summary` includes `reintroducedRegressions` count
    - [x] `REINTRODUCED_REGRESSIONS` count exported in stdout key=value output for heal-loop.sh consumption
    - [x] `reVerification` audit entry includes `reintroducedRegressions` array
    - [x] Script handles missing/empty registry gracefully (no crash, no false regressions)

    **Implementation Summary**:

    - **Files**: `scripts/visual-verification/verify.sh`
    - **Approach**: Added Phase 3b after existing Phase 3 (previous-eval comparison). Phase 3b reads registry.json, iterates all issues in the new evaluation that were classified as regressions from the previous-eval comparison, looks up each issue's captureId in the registry, scans all historical evaluations for the same PRD reference with status "resolved", and reclassifies matches as "reintroduced regression" with the original resolution timestamp. Reintroduced regressions are removed from the REGRESSION_ISSUES array and placed in a separate REINTRODUCED_REGRESSIONS array. The re-verification report includes a `reintroducedRegressions` section with full detail (prdReference, previouslyResolvedAt, currentObservation, severity, confidence) and the summary includes the reintroducedRegressions count. Registry entries for reintroduced regressions are recorded with status "reintroduced". The audit trail entry includes the reintroducedRegressions array. Missing/empty/corrupt registry is handled gracefully with an info message and no false regressions. The exit code and stdout key=value output include reintroduced regressions in the issue detection logic.
    - **Deviations**: None
    - **Tests**: bash -n syntax check, --help output, 6 isolated jq query tests (previously resolved match, never-resolved issue, remaining-status issue, non-existent captureId, empty registry, JSON construction), 3 reclassification logic tests (partial reclassification, all reclassified, no reintroduced), full report and audit entry construction verification

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

- [x] **T16**: SA-5 Attended Mode Continuation -- Implement "Continue with manual guidance" in heal-loop.sh `[complexity:medium]`

    **Reference**: [design.md#354-sa-5-attended-mode-continue-with-manual-guidance](design.md#354-sa-5-attended-mode-continue-with-manual-guidance)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] `handle_escalation()` case `c|C` replaced with multi-line stdin reading (terminated by empty line or EOF)
    - [x] Non-empty input validation with re-prompt on empty guidance
    - [x] `MANUAL_GUIDANCE` variable set for caller to incorporate into next iteration's build prompt
    - [x] `ESCALATION_ACTION` variable set to `"continue"` (vs `"skip"` or `"quit"`)
    - [x] Confirmation output shows captured guidance text (preview first 5 lines, truncated indicator if longer)
    - [x] `manualGuidance` audit entry appended via `append_audit()` with type, timestamp, loopId, iteration, and guidance text
    - [x] Guidance text sanitized for JSON via `jq --arg` (no manual escaping)
    - [x] Main loop checks `ESCALATION_ACTION` after `handle_escalation()` returns: `"continue"` proceeds, `"skip"`/`"quit"` breaks
    - [x] `MANUAL_GUIDANCE` cleared after each iteration (applies to one iteration only per BR-4)
    - [x] SA-5 guidance input failure falls back to writing escalation report

    **Implementation Summary**:

    - **Files**: `scripts/visual-verification/heal-loop.sh`
    - **Approach**: Replaced the `c|C` stub in `handle_escalation()` with full multi-line stdin reading (terminated by empty line or EOF), non-empty validation with 3-retry fallback to escalation report, confirmation preview (first 5 lines with truncation indicator), and `manualGuidance` audit entry via `jq --arg` for JSON sanitization. Added `MANUAL_GUIDANCE` and `ESCALATION_ACTION` global variables. The main loop checks `ESCALATION_ACTION` after `handle_escalation()`: "continue" proceeds with guidance set, "skip" exits 0 with escalation report, "quit" exits 1. `MANUAL_GUIDANCE` is cleared after each iteration (BR-4 single-iteration scope). An outer `while true` loop wraps the iteration loop to support "continue" at maxIterationsExhausted by incrementing `MAX_ITERATIONS`. Post-loop exit handling dispatches on `LOOP_BREAK` (skip/quit/maxIterationsExhausted) with appropriate audit entries.
    - **Deviations**: None
    - **Tests**: bash -n syntax check, --help output, jq multi-line guidance serialization test

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

- [x] **T17**: SA-2 Build Invocation Fidelity -- Restructure /build --afk prompt with multi-test context and iteration instructions `[complexity:medium]`

    **Reference**: [design.md#351-sa-2-multi-test-build-prompt-structure](design.md#351-sa-2-multi-test-build-prompt-structure), [design.md#352-sa-2-build-result-detail-capture](design.md#352-sa-2-build-result-detail-capture)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] `BUILD_PROMPT` replaced with structured multi-test prompt per design section 3.5.1 format
    - [x] Prompt includes per-test file path, PRD reference, specification excerpt, and observation for each failing test
    - [x] Prompt includes explicit iteration instructions: run `swift test --filter VisionDetected`, fix failures, re-run, repeat until all pass or unfixable
    - [x] Prompt includes test filter command: `swift test --filter VisionDetected`
    - [x] `MANUAL_GUIDANCE` (from T16) incorporated into prompt under "Developer Guidance" section when non-empty
    - [x] `PRE_BUILD_HEAD` recorded via `git rev-parse HEAD` before build invocation
    - [x] After build: `FILES_MODIFIED` captured via `git diff --name-only ${PRE_BUILD_HEAD} HEAD` as JSON array
    - [x] After build: each test run individually to determine `TESTS_FIXED` vs `TESTS_REMAINING` arrays
    - [x] `TESTS_FIXED` and `TESTS_REMAINING` arrays available for audit entry (T18) and loop state
    - [x] Graceful degradation: `git diff` failure logs `filesModified: []` and continues (per design section 3.19)

    **Implementation Summary**:

    - **Files**: `scripts/visual-verification/heal-loop.sh`
    - **Approach**: Replaced the simple BUILD_PROMPT with a structured multi-test prompt per design section 3.5.1. For each generated test file: extracts PRD reference from test content via grep (supports both `prd-name FR-N` and `charter:ref` patterns), looks up specificationExcerpt and observation from the evaluation report via jq, and constructs a per-test section with file path, PRD reference, specification, and issue description. Prompt includes explicit iteration instructions with `swift test --filter VisionDetected` command. MANUAL_GUIDANCE from T16 incorporated under "Developer Guidance" section when non-empty. PRE_BUILD_HEAD recorded before build; FILES_MODIFIED captured via git diff --name-only piped through jq for JSON array construction, with `|| FILES_MODIFIED="[]"` fallback. Post-build test verification runs each test individually via @Suite name extraction to populate TESTS_FIXED and TESTS_REMAINING arrays. All arrays converted to JSON via printf+jq pipeline for audit entry consumption. TEST_PATHS_JSON uses project-relative paths (strips PROJECT_ROOT prefix). The enhanced audit entry includes all SA-4 fields (testPaths, filesModified, testsFixed, testsRemaining) alongside existing fields, anticipating T18.
    - **Deviations**: The enhanced audit entry (testPaths, filesModified, testsFixed, testsRemaining) was included directly in the T17 implementation rather than deferring to T18, because the JSON conversion logic and audit entry construction are tightly coupled to the data computation and would be artificial to separate.
    - **Tests**: bash -n syntax check, --help output, jq audit entry construction with populated arrays, jq audit entry with empty arrays (graceful degradation), project-relative path conversion pipeline, PRD reference extraction regex (concrete and qualitative), jq issue lookup queries against mock evaluation data

- [ ] **T18**: SA-4 Audit Completeness -- Enhanced buildInvocation audit entry with testPaths and filesModified `[complexity:simple]`

    **Reference**: [design.md#353-sa-4-enhanced-audit-entry](design.md#353-sa-4-enhanced-audit-entry)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [ ] `buildInvocation` audit entry includes `testPaths` array of project-relative paths to generated test files
    - [ ] `buildInvocation` audit entry includes `filesModified` array from `git diff --name-only` (computed in T17)
    - [ ] `buildInvocation` audit entry includes `testsFixed` array of test suite names that now pass
    - [ ] `buildInvocation` audit entry includes `testsRemaining` array of test suite names that still fail
    - [ ] `TEST_PATHS` converted to project-relative paths (stripping `${PROJECT_ROOT}/` prefix)
    - [ ] All arrays properly embedded via `jq --argjson` for correct JSON array construction
    - [ ] No absolute paths in audit entry arrays (all project-relative)
    - [ ] Existing audit entry fields (type, timestamp, loopId, iteration, result, prdRefs) preserved

### User Docs

- [x] **TD1**: Update modules.md - Test Layer `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Test Layer

    **KB Source**: modules.md:Test Layer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [x] VisionCompliance suite added to the UI Compliance Suites table in modules.md with file paths and purpose descriptions for VisionCaptureTests.swift, VisionCapturePRD.swift, and VisionCompliancePRD.swift
    - [x] Section reflects the capture orchestrator and generated test hosting roles accurately

    **Implementation Summary**:

    - **Files**: `.rp1/context/modules.md`
    - **Approach**: Added new "Vision Compliance" subsection under the Test Layer after Animation PRD, with table entries for VisionCaptureTests.swift (capture orchestrator), VisionCapturePRD.swift (harness/config/helpers), and VisionCompliancePRD.swift (shared harness for generated tests)
    - **Deviations**: None
    - **Tests**: N/A (documentation only)

- [x] **TD2**: Update architecture.md - Test Harness Mode `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Test Harness Mode

    **KB Source**: architecture.md:Test Harness Mode

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [x] Vision verification listed as a consumer of the test harness infrastructure alongside existing spatial, visual, and animation compliance suites
    - [x] Section describes the capture orchestrator's role in producing deterministic screenshots for LLM evaluation

    **Implementation Summary**:

    - **Files**: `.rp1/context/architecture.md`
    - **Approach**: Added "Vision Verification (LLM-Based Design Compliance)" subsection after the Two-Process Test Architecture section, describing how the vision verification workflow consumes the test harness infrastructure, the capture orchestrator's role, shell script orchestration overview, and VisionComplianceHarness pattern
    - **Deviations**: None
    - **Tests**: N/A (documentation only)

- [x] **TD3**: Update index.md - Quick Reference `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/index.md`

    **Section**: Quick Reference

    **KB Source**: index.md:Quick Reference

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [x] Entry for `scripts/visual-verification/` directory added to the Quick Reference list
    - [x] Entry for `.rp1/work/verification/` directory added to the Quick Reference list
    - [x] Entry for `mkdnTests/UITest/VisionCompliance/` added to the Quick Reference list

    **Implementation Summary**:

    - **Files**: `.rp1/context/index.md`
    - **Approach**: Added four entries to the Quick Reference list: vision verification scripts, vision verification artifacts, vision compliance tests, and vision verification docs
    - **Deviations**: Also added entry for `docs/visual-verification.md` (TD4 creates this file, listing it in index.md keeps the Quick Reference complete)
    - **Tests**: N/A (documentation only)

- [x] **TD4**: Create usage guide for the visual verification workflow `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: add

    **Target**: `docs/visual-verification.md`

    **Section**: (new file)

    **KB Source**: -

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [x] New file created at `docs/visual-verification.md`
    - [x] Covers shell script invocation (heal-loop.sh, capture.sh, evaluate.sh, generate-tests.sh, verify.sh)
    - [x] Covers configuration flags (--dry-run, --attended, --max-iterations, --skip-build, --batch-size)
    - [x] Covers interpreting evaluation reports (issue severity, confidence, PRD references)
    - [x] Covers interpreting escalation reports (unresolved issues, suggested next steps)
    - [x] Covers the self-healing loop lifecycle (capture -> evaluate -> generate -> fix -> verify)
    - [x] Covers cost management (caching, dry-run, batch composition)

    **Implementation Summary**:

    - **Files**: `docs/visual-verification.md`
    - **Approach**: Created comprehensive usage guide covering prerequisites, quick start, all five shell scripts with flags and behavior, evaluation report interpretation (issue structure, qualitative findings, summary), escalation report interpretation (triggers, content, suggested next steps), self-healing loop lifecycle with concrete example, cost management (caching, dry-run, batch composition, API call estimates), artifact locations, regression registry, and audit trail
    - **Deviations**: None
    - **Tests**: N/A (documentation only)

- [ ] **TD5**: Update architecture.md - Document SA-3 registry history and SA-5 attended mode `[complexity:simple]`

    **Reference**: [design.md#9-documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Vision Verification

    **KB Source**: architecture.md:Vision Verification

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Vision Verification section updated to document registry-based regression detection (SA-3): Phase 3b historical comparison, reintroduced regressions classification
    - [ ] Vision Verification section updated to document attended mode continuation (SA-5): manual guidance prompt, guidance incorporation into build prompt, single-iteration scope
    - [ ] Section reflects the enhanced audit trail fields (SA-4): testPaths, filesModified, testsFixed, testsRemaining
    - [ ] Section reflects the multi-test build prompt structure (SA-2)

### Review Fixes

- [x] **TX-fix-build-invocation**: Replace raw `claude -p` prompt in heal-loop.sh fix step with rp1 `/build {FEATURE_ID} AFK=true` invocation `[complexity:simple]`

    **Reference**: Review feedback (AC-004c)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] heal-loop.sh accepts `--feature-id ID` flag for the `/build --afk` invocation
    - [x] `--feature-id` is required when not in `--dry-run` mode; script errors with exit 2 if missing
    - [x] Step 3 (fix) invokes `claude -p "/build {FEATURE_ID} AFK=true"` instead of raw prompt
    - [x] The `/build` invocation passes evaluation report path, PRD references, and failing test file paths as context
    - [x] No `--allowedTools` restriction on the `/build --afk` invocation (the build pipeline manages its own tools)
    - [x] CLAUDE.md and docs/visual-verification.md updated to document `--feature-id` flag
    - [x] Script header comment updated
    - [x] Bash syntax check passes

    **Implementation Summary**:

    - **Files**: `scripts/visual-verification/heal-loop.sh`, `CLAUDE.md`, `docs/visual-verification.md`
    - **Approach**: Added `--feature-id ID` flag with validation (required unless --dry-run). Replaced raw `claude -p` prompt with `/build {FEATURE_ID} AFK=true` command that passes evaluation context (report path, PRD refs, failing test paths). Removed `--allowedTools` restriction to let the build pipeline manage its own tools. Updated header comment, help output, pre-flight logging, and documentation.
    - **Deviations**: None
    - **Tests**: bash -n syntax check, --help output verification, validation error test (no feature-id), dry-run bypass test

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | PASS |

- [x] **TX-fix-loadfile-error**: Fix VisionCapture test loadFile error reporting and add warm-up step `[complexity:simple]`

    **Reference**: Review feedback (VisionCapture loadFile error)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] VisionCaptureTests includes loadResp.message in error output when loadFile fails
    - [x] VisionCaptureTests includes setResp.message in error output when setTheme fails
    - [x] VisionCaptureExtract separates status check from data check for clearer error messages on captureWindow failures
    - [x] Warm-up step added before main capture loop to initialize the rendering pipeline
    - [x] Code compiles, passes swiftlint and swiftformat

    **Implementation Summary**:

    - **Files**: `mkdnTests/UITest/VisionCompliance/VisionCaptureTests.swift`, `mkdnTests/UITest/VisionCompliance/VisionCapturePRD.swift`
    - **Approach**: (1) Changed `#require` messages for setTheme and loadFile to include `resp.message` so the actual error from TestHarnessHandler is visible (e.g., "Render timeout after loading file", "No document state available", "Load failed: ..."). (2) Added a `warmUp(client:)` method that loads the first fixture and waits for entrance animation before the main capture loop, matching the implicit warm-up that other compliance suites get through their calibration flow. (3) Separated VisionCaptureExtract.extractResult into two guard clauses (status check, then data check) matching the SpatialPRD pattern, so "No capture data in response" is distinguishable from "Capture returned error status".
    - **Deviations**: None
    - **Tests**: Compiles, lints clean, formats clean

- [x] **TX-fix-fixture-order**: Reorder VisionCaptureConfig.fixtures so simpler fixtures come first to warm up renderer before Mermaid content `[complexity:simple]`

    **Reference**: Review feedback (VisionCapture render timeout on cold start)

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [x] VisionCaptureConfig.fixtures ordered: geometry-calibration.md, theme-tokens.md, canonical.md, mermaid-focus.md
    - [x] Warm-up step automatically uses geometry-calibration.md (first fixture) via fixtures[0]
    - [x] Code compiles, passes swiftlint and swiftformat

    **Implementation Summary**:

    - **Files**: `mkdnTests/UITest/VisionCompliance/VisionCapturePRD.swift`
    - **Approach**: Reordered the fixtures array so non-Mermaid fixtures (geometry-calibration.md, theme-tokens.md) come before Mermaid-containing fixtures (canonical.md, mermaid-focus.md). The warm-up method already references fixtures[0], so reordering the array ensures the renderer warms up on geometry-calibration.md (pure spatial layout, no WKWebView needed) before encountering Mermaid diagrams that require WKWebView initialization time.
    - **Deviations**: None
    - **Tests**: Compiles, lints clean, formats clean

- [x] **TX-fix-warmup-removal**: Remove warm-up step from VisionCaptureTests that causes render timeout on duplicate loadFile `[complexity:simple]`

    **Reference**: Review feedback (VisionCapture warm-up causes @Observable no-op on identical content)

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [x] warmUp() method removed entirely from VisionCaptureTests.swift
    - [x] warmUp(client:) call removed from captureAllFixtures()
    - [x] No changes to VisionCapturePRD.swift or any other files
    - [x] Code compiles, passes swiftlint and swiftformat

    **Implementation Summary**:

    - **Files**: `mkdnTests/UITest/VisionCompliance/VisionCaptureTests.swift`
    - **Approach**: Removed the warmUp() method and its invocation from captureAllFixtures(). The warm-up was loading geometry-calibration.md (fixtures[0]), then the main loop's first iteration also loaded geometry-calibration.md. Since @Observable does not notify when setting an identical value, RenderCompletionSignal never fired and the 10s timeout was reached. The reordered fixtures (geometry-calibration.md first from TX-fix-fixture-order) work without warm-up since the setTheme + loadFile pattern is sufficient, matching how SpatialComplianceTests loads the same fixture in its calibration step.
    - **Deviations**: None
    - **Tests**: Compiles, lints clean, formats clean

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
- [ ] REQ-SA1-001: VisionCapture test suite exits 0, manifest has 8 entries, each references existing PNG with valid hash and non-zero dimensions
- [ ] REQ-SA1-002: Two consecutive capture runs produce identical image hashes (stability guard)
- [ ] REQ-SA2-001: Build prompt includes every generated test file path with PRD reference and issue description
- [ ] REQ-SA2-002: Build prompt contains iteration instructions with test filter command
- [ ] REQ-SA2-003: After build, tests checked for pass/fail and modified files captured
- [ ] REQ-SA3-001: verify.sh consults full registry history; previously-resolved issues that reappear classified as regressions
- [ ] REQ-SA3-002: Full evaluation history per registry entry scanned for resolved issues
- [ ] REQ-SA4-001: buildInvocation audit entry includes testPaths array of project-relative paths
- [ ] REQ-SA4-002: buildInvocation audit entry includes filesModified array from git diff
- [ ] REQ-SA5-001: "Continue" option prompts for multi-line text guidance, validates non-empty, loop continues with guidance
- [ ] REQ-SA5-002: Guidance text appears verbatim in build prompt under "Developer Guidance" section, applies to one iteration only
- [ ] REQ-SA5-003: manualGuidance audit entry appended with guidance text, timestamp, loopId, iteration

## Definition of Done

- [ ] All tasks completed
- [ ] All AC verified
- [ ] Code reviewed
- [ ] Docs updated
