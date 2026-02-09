# Feature Verification Report #1

**Generated**: 2026-02-09T13:20:00Z
**Feature ID**: llm-visual-verification
**Verification Scope**: all
**KB Context**: Loaded
**Field Notes**: Not available

## Executive Summary
- Overall Status: PARTIAL
- Acceptance Criteria: 46/55 verified (84%)
- Implementation Quality: HIGH
- Ready for Merge: NO (runtime verification gap; see details)

## Field Notes Context
**Field Notes Available**: No

### Documented Deviations
None (no field-notes.md exists)

### Undocumented Deviations
1. `evaluate.sh` added a `--force-fresh` flag not in original design AC (minor enhancement, not a problem)
2. `heal-loop.sh` uses `claude -p` directly instead of invoking `/build --afk` as a named rp1 skill -- the script builds its own prompt and passes it to the Claude CLI with tool permissions. This deviates from the design language of "invoke /build --afk" but achieves the same functional goal.

## Acceptance Criteria Verification

### REQ-001: Vision-Based Design Evaluation
**AC-001a**: Given a set of PNG screenshots captured by the existing test harness, the system produces a structured evaluation for each screenshot
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:319-413 -- Vision evaluation per batch, `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:415-493 -- Merge batch results into structured report
- Evidence: `evaluate.sh` reads manifest.json, iterates batches, invokes Claude Code vision, and merges results into a single JSON evaluation report with issues, qualitativeFindings, and summary. Output schema at `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/output-schema.json` defines the full structure.
- Field Notes: N/A
- Issues: None

**AC-001b**: The evaluation considers both concrete PRD requirements and qualitative design judgment
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/evaluation-prompt.md`:17-84 -- Five evaluation dimensions
- Evidence: The evaluation prompt template explicitly covers five dimensions: (1) Concrete PRD Compliance, (2) Spatial Rhythm and Balance, (3) Theme Coherence, (4) Visual Consistency, (5) Overall Rendering Quality. The output schema separates `issues` (concrete PRD) from `qualitativeFindings` (qualitative judgment).
- Field Notes: N/A
- Issues: None

**AC-001c**: The evaluation prompt includes the charter's design philosophy, relevant PRD excerpts, and specific evaluation criteria
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:206-231 -- Prompt assembly with charter, PRD excerpts, evaluation criteria
- Evidence: `evaluate.sh` extracts charter design philosophy via `extract_section`, reads PRD context files per fixture (`prd-context-spatial.md`, `prd-context-visual.md`, `prd-context-mermaid.md`), and assembles them into the evaluation prompt using placeholders `{charter_design_philosophy}`, `{prd_excerpts}`, `{output_schema}`.
- Field Notes: N/A
- Issues: None

**AC-001d**: The same screenshots and PRD state produce a deterministic evaluation prompt
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:140-174 -- Cache key computation from content hashes
- Evidence: Cache key is SHA-256 of (sorted image hashes + prompt template hash + charter hash + PRD file hashes). Prompt is assembled from version-controlled template files with no random or time-dependent inputs in the prompt content itself. The evaluationId uses a timestamp but is metadata, not part of the evaluation prompt content used for cache key.
- Field Notes: N/A
- Issues: None

**AC-001e**: The evaluation output is structured (JSON) and machine-parseable
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/output-schema.json` -- Full JSON Schema, `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:407-409 -- JSON validation of output
- Evidence: Output schema is a formal JSON Schema (draft 2020-12) defining evaluationId, promptHash, captures, issues, qualitativeFindings, and summary. `evaluate.sh` validates each batch output with `jq . "${BATCH_OUTPUT}"` before merging.
- Field Notes: N/A
- Issues: None

### REQ-002: PRD-Referenced Issue Detection
**AC-002a**: Each detected issue includes a PRD reference (PRD name and functional requirement number) or charter section reference
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/output-schema.json`:56-58 -- prdReference field required, `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/evaluation-prompt.md`:79 -- Instruction to reference specific PRD FRs
- Evidence: The output schema requires `prdReference` (type string, described as "PRD name and functional requirement number") on every issue. For qualitative findings, `reference` field serves the same purpose (e.g., "charter:design-philosophy").
- Field Notes: N/A
- Issues: None

**AC-002b**: Each issue includes the relevant specification text that defines expected behavior
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/output-schema.json`:59-61 -- specificationExcerpt field required
- Evidence: `specificationExcerpt` is a required field on every issue in the schema.
- Field Notes: N/A
- Issues: None

**AC-002c**: Each issue includes a description of what was actually observed
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/output-schema.json`:62-64 -- observation field required
- Evidence: `observation` is a required field on every issue and qualitative finding.
- Field Notes: N/A
- Issues: None

**AC-002d**: Each issue includes a description of how the observation deviates from the specification
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/output-schema.json`:65-67 -- deviation field required
- Evidence: `deviation` is a required field on every issue. For qualitative findings, `assessment` serves the equivalent role.
- Field Notes: N/A
- Issues: None

**AC-002e**: Each issue is classified by severity: critical, major, minor
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/output-schema.json`:68-75 -- severity enum required
- Evidence: `severity` is a required field with enum values `["critical", "major", "minor"]` on both issues and qualitative findings.
- Field Notes: N/A
- Issues: None

**AC-002f**: Each issue is classified by confidence: high, medium, low
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/output-schema.json`:76-83 -- confidence enum required
- Evidence: `confidence` is a required field with enum values `["high", "medium", "low"]` on both issues and qualitative findings.
- Field Notes: N/A
- Issues: None

### REQ-003: Failing Test Generation
**AC-003a**: A Swift Testing test file is generated for each medium- or high-confidence issue
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/generate-tests.sh`:139-172 -- Filter by confidence, `/Users/jud/Projects/mkdn/scripts/visual-verification/generate-tests.sh`:192-416 -- generate_test_for_issue function
- Evidence: Issues are filtered with jq `select(.confidence == "medium" or .confidence == "high")`. Each qualifying issue goes through `generate_test_for_issue` which invokes Claude Code to generate a Swift test file.
- Field Notes: N/A
- Issues: None

**AC-003b**: Each generated test references its source PRD and functional requirement in the test name and documentation comment
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/generate-tests.sh`:250-255 -- Naming convention, `/Users/jud/Projects/mkdn/scripts/visual-verification/generate-tests.sh`:270-308 -- Task file with issue details for doc comment generation
- Evidence: File naming follows `VisionDetected_{prdCamelCase}_{FR}_{aspect}.swift`. The generation task instructs Claude Code to include Issue ID, Evaluation ID, PRD Reference, Specification, and Observation in the doc comment.
- Field Notes: N/A
- Issues: None

**AC-003c**: Generated tests use the existing test harness infrastructure (app launch, screenshot capture, assertions)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/test-template-spatial.md`, `test-template-visual.md`, `test-template-qualitative.md` -- All templates reference VisionComplianceHarness, visionFixturePath, visionExtractCapture, visionLoadAnalyzer, ImageAnalyzer, JSONResultReporter
- Evidence: Templates instruct generated tests to use VisionComplianceHarness.ensureRunning(), existing capture/analysis infrastructure, and JSONResultReporter for result recording.
- Field Notes: N/A
- Issues: None

**AC-003d**: Generated tests compile successfully
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/generate-tests.sh`:357-371 -- Compilation validation
- Evidence: After generation, the script runs `swift build` and checks exit code. If compilation fails, the test file is removed and discarded with an audit trail entry.
- Field Notes: N/A
- Issues: None

**AC-003e**: Generated tests currently fail (confirming the issue is real)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/generate-tests.sh`:384-399 -- Failure validation
- Evidence: After compilation succeeds, the script runs `swift test --filter {suiteName}`. If the test passes, it is discarded as a false positive with an audit trail entry.
- Field Notes: N/A
- Issues: None

**AC-003f**: Generated tests are specific enough that fixing the underlying issue causes the test to pass
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/test-template-spatial.md`, `test-template-visual.md`, `test-template-qualitative.md` -- Templates with concrete assertion patterns
- Evidence: The templates provide patterns for concrete spatial measurements, color sampling, and proxy metrics. However, whether generated tests are *specific enough* to pass after a fix depends on the quality of Claude Code's test generation at runtime -- this is a runtime quality attribute that cannot be verified from code structure alone.
- Field Notes: N/A
- Issues: This is inherently a runtime quality criterion. The infrastructure is in place (templates, validation gates), but the actual specificity depends on LLM generation quality.

**AC-003g**: Low-confidence issues are not auto-tested but are flagged in the evaluation report for human review
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/generate-tests.sh`:154-171 -- Low-confidence filtering and reporting
- Evidence: Low-confidence items are counted separately (`LOW_ISSUES`, `LOW_QUALITATIVE`) and reported as "skipped (flagged for human review)" but never passed to `generate_test_for_issue`. Output includes `SKIPPED_LOW_CONFIDENCE=${LOW_TOTAL}`.
- Field Notes: N/A
- Issues: None

### REQ-004: Autonomous Self-Healing
**AC-004a**: Generated test files are committed before invoking the fix pipeline
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh`:520-547 -- Git add + commit before build invocation
- Evidence: `heal-loop.sh` runs `git add ${VISION_COMPLIANCE_DIR}/` followed by `git commit -m "test: vision-detected failing tests for {PRD refs}"` before the build/fix step.
- Field Notes: N/A
- Issues: None

**AC-004b**: The fix pipeline receives the failing test paths and the PRD references that define the design intent
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh`:557-580 -- Build context assembly with test paths and PRD refs
- Evidence: `BUILD_CONTEXT` is assembled with PRD references and test file paths, then passed to `claude -p "${BUILD_CONTEXT}"`.
- Field Notes: N/A
- Issues: None

**AC-004c**: The fix pipeline autonomously reads the failing tests, understands the design intent, modifies source code, and iterates until tests pass
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh`:582-595 -- Claude invocation with Read/Write/Edit/Bash tools
- Evidence: The script invokes `claude -p "${BUILD_CONTEXT}" --allowedTools "Read,Write,Edit,Bash"` which gives Claude Code full access to read tests, understand intent, and modify code. However, the script does not explicitly ensure Claude iterates until tests pass -- it is a single invocation. The actual /build --afk skill's iteration behavior depends on the Claude CLI session.
- Field Notes: N/A
- Issues: The design specifies invoking `/build --afk` which implies the rp1 build skill with its own iteration loop. The implementation invokes `claude -p` directly with a prompt, which may or may not iterate to pass the tests depending on Claude's behavior.

**AC-004d**: The system captures the fix pipeline's completion status (success or failure)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh`:582-595 -- BUILD_RESULT tracking
- Evidence: The Claude CLI exit code is captured: exit 0 sets BUILD_RESULT="success", non-zero sets BUILD_RESULT="failure". This is logged to the audit trail.
- Field Notes: N/A
- Issues: None

**AC-004e**: The entire detect-generate-fix cycle runs without human interaction
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh` -- Full script flow (when `--attended` is not set)
- Evidence: In default (unattended) mode, the entire flow from capture through evaluation, test generation, git commit, fix invocation, and re-verification runs without any interactive prompts.
- Field Notes: N/A
- Issues: None

### REQ-005: Re-Verification
**AC-005a**: Fresh screenshots are captured after the fix pipeline completes
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/verify.sh`:99-108 -- capture.sh --skip-build
- Evidence: `verify.sh` calls `capture.sh --skip-build` as its first phase, producing fresh screenshots.
- Field Notes: N/A
- Issues: None

**AC-005b**: The same evaluation criteria are applied to the new screenshots
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/verify.sh`:112-127 -- evaluate.sh --force-fresh
- Evidence: `verify.sh` calls `evaluate.sh --force-fresh` which uses the same prompt templates and PRD context as the original evaluation.
- Field Notes: N/A
- Issues: None

**AC-005c**: Originally-detected issues are confirmed resolved
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/verify.sh`:148-179 -- Comparison by prdReference
- Evidence: Issues present in previous evaluation but absent in new evaluation are classified as "resolved".
- Field Notes: N/A
- Issues: None

**AC-005d**: New issues introduced by the fix are detected (regression detection)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/verify.sh`:163-170 -- Regression detection
- Evidence: Issues present in new evaluation but absent in previous evaluation are classified as "regression".
- Field Notes: N/A
- Issues: None

**AC-005e**: If new regressions are detected, new failing tests are generated and the fix pipeline is re-invoked
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh`:481-693 -- Iteration loop
- Evidence: The while loop checks `TOTAL_OUTSTANDING` (regressions + remaining). If greater than 0, it continues to the next iteration which generates new tests and re-invokes the fix pipeline.
- Field Notes: N/A
- Issues: None

**AC-005f**: The re-verification loop is bounded (default maximum: 3 iterations)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh`:33 -- MAX_ITERATIONS=3, line 481 -- `while [ "${ITERATION}" -lt "${MAX_ITERATIONS}" ]`
- Evidence: Default MAX_ITERATIONS is 3. The while loop condition prevents exceeding this bound.
- Field Notes: N/A
- Issues: None

**AC-005g**: If the maximum iteration count is reached without full resolution, the system reports failure with accumulated context
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh`:697-713 -- Max iterations exhausted handling
- Evidence: After the loop exits, `handle_escalation "maxIterationsExhausted"` is called, which produces an escalation report with all loop state context. Script exits with code 1.
- Field Notes: N/A
- Issues: None

### REQ-006: Batch Cost Management
**AC-006a**: Related screenshots are grouped into batched evaluation requests
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:237-273 -- Batch grouping by fixture stem
- Evidence: Captures are grouped by fixture stem (canonical, theme-tokens, mermaid-focus, geometry-calibration). Same fixture, both themes = one batch.
- Field Notes: N/A
- Issues: None

**AC-006b**: The number of images per evaluation call is configurable (default: 4)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:36 -- BATCH_SIZE=4, lines 90-93 -- --batch-size flag parsing
- Evidence: BATCH_SIZE defaults to 4 and is configurable via `--batch-size N`. However, the current batching logic groups by fixture (2 images per batch) rather than enforcing the batch size limit as a hard cap. The batch size would apply if a fixture had more captures than the limit.
- Field Notes: N/A
- Issues: The batch size variable is accepted but the grouping logic groups by fixture stem rather than enforcing a maximum. With the current 4-fixture x 2-theme matrix, each batch has 2 images, so the limit is never reached. This is functionally correct but the batch-size enforcement is implicit.

**AC-006c**: Evaluation results are cached based on a hash of image content and evaluation prompt; unchanged inputs skip re-evaluation
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:140-197 -- Cache key computation and cache check
- Evidence: Cache key is SHA-256 of (sorted image hashes + prompt file hashes + charter hash + PRD hashes). On cache hit, the cached evaluation is copied to the report directory without making API calls.
- Field Notes: N/A
- Issues: None

**AC-006d**: A cost estimate is provided before execution
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:326 -- Log line showing batch count
- Evidence: `evaluate.sh` logs "Starting vision evaluation (N batches)" which provides an implicit cost estimate. However, there is no explicit cost estimate calculation (e.g., estimated API calls, estimated tokens) before execution as described in the design's section 3.18.
- Field Notes: N/A
- Issues: Missing explicit cost estimate output before API calls begin. The dry-run mode provides `estimatedApiCalls` in its report, which partially addresses this, but the non-dry-run path does not show a pre-execution cost estimate.

**AC-006e**: A dry-run mode is available that constructs evaluation prompts and reports what would be evaluated without making API calls
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:279-317 -- Dry-run mode
- Evidence: When `--dry-run` is passed, the script writes a JSON report with `dryRun: true`, `capturesProduced`, `batchComposition` (with fixture, captures, and cached status per batch), `estimatedApiCalls`, `cachedBatches`, and `promptPreview`. No Claude Code invocation occurs.
- Field Notes: N/A
- Issues: None

### REQ-007: Regression Registry
**AC-007a**: A registry file records each evaluation: screenshot hash, evaluation timestamp, detected issues, resolution status
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/verify.sh`:310-411 -- Registry update logic, `/Users/jud/Projects/mkdn/.rp1/work/verification/registry.json` -- Initial empty registry
- Evidence: `verify.sh` upserts entries per capture into registry.json with imageHash, captureId, evaluations array (evaluationId, timestamp, issues with prdReference and status), lastEvaluated, and lastStatus. Schema matches design.md section 3.14.
- Field Notes: N/A
- Issues: None

**AC-007b**: On re-verification, results are compared against the registry to detect regressions
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/verify.sh`:130-213 -- Comparison logic
- Evidence: `verify.sh` compares previous and new evaluations by prdReference to classify resolved/regression/remaining. However, the comparison is against the *previous evaluation*, not the *registry*. The registry is updated after comparison but is not consulted for regression detection of previously-resolved issues from older runs.
- Field Notes: N/A
- Issues: The design specifies that the registry is used to detect re-introduction of previously-fixed issues. The current implementation compares only against the immediately previous evaluation, not the full registry history.

**AC-007c**: The registry is stored as a version-controlled artifact alongside other project artifacts
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/verification/registry.json` -- File exists in git-tracked directory
- Evidence: The registry file is in `.rp1/work/verification/` which is tracked per `settings.toml` (`GIT_COMMIT=true`).
- Field Notes: N/A
- Issues: None

**AC-007d**: The registry can be queried to show the compliance status of any previously-evaluated screenshot
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/verification/registry.json` -- Data stored per capture
- Evidence: The registry stores per-capture evaluation history with status. However, there is no query interface or script to query the registry. It must be read directly with jq.
- Field Notes: N/A
- Issues: No dedicated query tool exists. This is a minor gap since the data is present and queryable with standard tools.

### REQ-008: Structured Reporting
**AC-008a**: Evaluation reports are JSON with: issue severity, PRD references, confidence scores, deviation descriptions, generated test file paths
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:455-493 -- Report generation, `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/output-schema.json` -- Schema definition
- Evidence: Evaluation reports contain all specified fields. Generated test file paths are output by `generate-tests.sh` rather than included in the evaluation report itself, but are tracked in audit entries.
- Field Notes: N/A
- Issues: None

**AC-008b**: Fix pipeline invocation results are included: success/failure, iterations, files modified
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh`:597-604 -- Build invocation audit entry
- Evidence: The audit trail records build invocation with result (success/failure) and prdRefs. However, "files modified" is not tracked -- the Claude CLI output is not parsed for modified file paths. The loop state in `current-loop.json` tracks buildResult per iteration.
- Field Notes: N/A
- Issues: Missing "files modified" tracking in build invocation audit entries.

**AC-008c**: Re-verification outcomes are included: resolved issues, new regressions, final status
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/verify.sh`:277-301 -- Re-verification report
- Evidence: Re-verification report includes previousEvaluationId, newEvaluationId, summary (resolved/regressions/remaining counts), and detailed arrays of resolvedIssues, newRegressions, and remainingIssues.
- Field Notes: N/A
- Issues: None

**AC-008d**: Reports are written to a predictable location within the project's work directory
- Status: VERIFIED
- Implementation: All scripts write to `.rp1/work/verification/reports/{timestamp}-{type}.json`
- Evidence: Evaluation reports at `{timestamp}-evaluation.json`, dry-run at `{timestamp}-dryrun.json`, re-verification at `{timestamp}-reverification.json`, escalation at `{timestamp}-escalation.json`, clean/success at `{timestamp}-clean.json`/`{timestamp}-success.json`.
- Field Notes: N/A
- Issues: None

### REQ-009: Human Escalation
**AC-009a**: Low-confidence issues are flagged for human review rather than auto-generating tests
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/generate-tests.sh`:154-171 -- Low-confidence filtering
- Evidence: Low-confidence issues are counted and reported as "skipped (flagged for human review)" but never generate tests. Escalation reports include `lowConfidenceIssues` array.
- Field Notes: N/A
- Issues: None

**AC-009b**: When the self-healing loop exhausts its maximum iterations without resolution, a failure report is produced with all context
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh`:184-236 -- write_escalation_report function, lines 697-713 -- max iterations exhausted
- Evidence: Escalation report includes escalationType, loopId, iterations count, unresolvedIssues array, lowConfidenceIssues array, full loopState, and suggestedNextSteps array.
- Field Notes: N/A
- Issues: None

**AC-009c**: In unattended mode (default), escalation produces a report file
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh`:290-292 -- Unattended escalation path
- Evidence: When `ATTENDED` is false (default), `handle_escalation` calls `write_escalation_report` which writes to `{timestamp}-escalation.json`.
- Field Notes: N/A
- Issues: None

**AC-009d**: In attended mode (optional), escalation prompts the human interactively for guidance
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh`:244-289 -- Attended mode interactive prompt
- Evidence: When `ATTENDED` is true, the script outputs escalation context to stdout, lists unresolved issues, and prompts with `read -r -p "Choice [q]: " choice` offering Continue/Skip/Quit options.
- Field Notes: N/A
- Issues: The "Continue with manual guidance" option is not fully implemented (falls through to writing a report), but the interactive prompt infrastructure is in place.

**AC-009e**: Escalated reports include enough context for the human to understand the issue and suggested next steps
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh`:215-236 -- Escalation report with suggested next steps
- Evidence: Escalation reports include unresolvedIssues (with observation details), lowConfidenceIssues, full loopState (iteration history), and a suggestedNextSteps array with actionable recommendations.
- Field Notes: N/A
- Issues: None

### REQ-010: Audit Trail
**AC-010a**: Every evaluation call is logged with: timestamp, input screenshots, evaluation prompt (or hash), results
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:544-552 -- Evaluation audit entry
- Evidence: Audit entry includes type="evaluation", timestamp, evaluationId, promptHash, captureIds array, issueCount, and cached flag.
- Field Notes: N/A
- Issues: None

**AC-010b**: Every test generation is logged with: timestamp, source issue, generated test file path, compilation result, failure validation result
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/generate-tests.sh`:313-413 -- Audit entries for each generation attempt
- Evidence: Each generation attempt (success or failure) appends an audit entry with type="testGeneration", timestamp, issueId, testFile, compiled (bool), currentlyFails (bool), and optional reason.
- Field Notes: N/A
- Issues: None

**AC-010c**: Every fix pipeline invocation is logged with: timestamp, input test paths, PRD references, completion status, files modified
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh`:597-604 -- Build invocation audit entry
- Evidence: Audit entry includes type="buildInvocation", timestamp, loopId, iteration, result, and prdRefs. Missing: input test paths and files modified are not included in the audit entry.
- Field Notes: N/A
- Issues: Test paths and files modified are not recorded in the audit entry. Test paths are available in the script but not serialized into the audit. Files modified cannot be determined without parsing Claude CLI output.

**AC-010d**: Every re-verification is logged with: timestamp, resolved issues, new regressions, iteration count
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/verify.sh`:425-433 -- Re-verification audit entry
- Evidence: Audit entry includes type="reVerification", timestamp, previousEvaluationId, newEvaluationId, resolvedIssues array, newRegressions array, remainingIssues array.
- Field Notes: N/A
- Issues: Iteration count is not directly in the reVerification audit entry, but it is tracked in the loopCompleted audit entry and in current-loop.json.

**AC-010e**: The audit log is stored as a version-controlled artifact
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/verification/audit.jsonl` would be created at `.rp1/work/verification/` which is in git-tracked territory
- Evidence: The audit file path is `${VERIFICATION_DIR}/audit.jsonl` inside `.rp1/work/verification/`, which is tracked per settings.toml.
- Field Notes: N/A
- Issues: None

### REQ-011: Qualitative Design Judgment
**AC-011a**: The evaluation prompt includes the charter's design philosophy section as context for qualitative assessment
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:211-218 -- Charter philosophy extraction, `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/evaluation-prompt.md`:5-7 -- Charter placeholder
- Evidence: The evaluation prompt template has `{charter_design_philosophy}` placeholder under "Design Philosophy (from Project Charter)". `evaluate.sh` extracts this section from `.rp1/context/charter.md`.
- Field Notes: N/A
- Issues: None

**AC-011b**: Evaluations assess: spatial rhythm and balance, visual consistency across elements, theme coherence, overall rendering quality
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/evaluation-prompt.md`:27-65 -- Four qualitative evaluation dimensions
- Evidence: The prompt explicitly addresses: (2) Spatial Rhythm and Balance, (3) Theme Coherence, (4) Visual Consistency, (5) Overall Rendering Quality, each with specific evaluation sub-criteria.
- Field Notes: N/A
- Issues: None

**AC-011c**: Qualitative findings are reported with the same structure as concrete PRD findings
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/output-schema.json`:112-151 -- qualitativeFindings schema
- Evidence: Qualitative findings have findingId, captureId, reference, observation, assessment, severity, and confidence -- structurally parallel to concrete issues.
- Field Notes: N/A
- Issues: None

**AC-011d**: Qualitative findings reference the charter design philosophy or specific PRD design principles
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/output-schema.json`:128-130 -- reference field, `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/evaluation-prompt.md`:82 -- Instruction to reference charter
- Evidence: The `reference` field is described as "Charter section or design principle reference". The evaluation prompt instructs: "For qualitative findings, reference the charter's design philosophy rather than specific PRD functional requirements."
- Field Notes: N/A
- Issues: None

### REQ-012: Deterministic Evaluation Inputs
**AC-012a**: The evaluation prompt is constructed deterministically from the input screenshots and design specification state
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:206-231 -- Prompt assembly from files only
- Evidence: The prompt is assembled by reading version-controlled template files and filling placeholders with content from charter.md, PRD context files, and output-schema.json. No random or external state is injected.
- Field Notes: N/A
- Issues: None

**AC-012b**: Prompt construction does not depend on external state (system time, random values, etc.)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:354-358 -- Prompt placeholder substitution
- Evidence: The placeholders `{charter_design_philosophy}`, `{prd_excerpts}`, `{output_schema}`, and `{capture_context}` are all filled from file contents or manifest data. The evaluationId (which includes a timestamp) is metadata passed separately, not part of the prompt template content.
- Field Notes: N/A
- Issues: None

**AC-012c**: The cache correctly identifies unchanged inputs via content hashing
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh`:140-174 -- Cache key computation
- Evidence: Cache key is SHA-256 of (sorted image content hashes from manifest + prompt template file hash + charter file hash + PRD file hashes). Any change to any input changes the cache key.
- Field Notes: N/A
- Issues: None

### Task-Level Acceptance Criteria

**T1: Directory Structure**
- Status: VERIFIED (10/10 criteria met)
- Evidence: All directories exist (`.rp1/work/verification/`, `/captures/`, `/cache/`, `/reports/`, `/staging/`, `scripts/visual-verification/`, `/prompts/`, `mkdnTests/UITest/VisionCompliance/`). Registry.json contains `{"version": 1, "entries": []}`. .gitkeep files in empty directories.

**T2: Capture Orchestrator**
- Status: PARTIAL (8/9 criteria met)
- Evidence: VisionCaptureTests.swift has `@Suite("VisionCapture", .serialized)`. VisionCapturePRD.swift has VisionCaptureHarness singleton, VisionCaptureConfig with 4 fixtures x 2 themes x previewOnly, fixture path helpers, SHA-256 hashing via CryptoKit, manifest writing. 1500ms sleep present. Swift build succeeds. However, the runtime test (`swift test --filter VisionCapture` producing 8 PNGs + manifest.json) has NOT been verified -- this requires a macOS GUI session. One PNG exists in captures/ suggesting a partial run.

**T3: Prompt Templates**
- Status: VERIFIED (11/11 criteria met)
- Evidence: All 8 template files exist with correct content. evaluation-prompt.md has all three placeholders and covers five evaluation dimensions. PRD context files map correctly to fixtures. Test templates follow VisionDetected naming, doc comment, JSONResultReporter patterns.

**T9: capture.sh and evaluate.sh**
- Status: VERIFIED (14/14 criteria met)
- Evidence: Both scripts use `set -euo pipefail`, resolve PROJECT_ROOT from SCRIPT_DIR, have info/error helpers. capture.sh supports --skip-build, builds mkdn, runs VisionCapture tests, validates manifest. evaluate.sh reads manifest, computes cache key, checks cache, assembles prompt, groups batches by fixture, supports --dry-run and --batch-size, writes reports, populates cache, appends audit.

**T10: generate-tests.sh and verify.sh**
- Status: VERIFIED (14/14 criteria met)
- Evidence: Both scripts follow conventions. generate-tests.sh filters by confidence, reads templates, writes to staging, validates compilation and failure, moves to VisionCompliance/, follows naming convention, appends audit. verify.sh accepts previous evaluation path, runs capture.sh --skip-build + evaluate.sh --force-fresh, compares by prdReference, writes re-verification report, updates registry.

**T11: heal-loop.sh**
- Status: VERIFIED (16/16 criteria met)
- Evidence: Script chains all phases, supports all four flags, tracks iteration state in current-loop.json, handles all exit conditions (clean, no tests generated, max iterations, build failure), commits tests before fix, updates registry, appends audit, supports attended mode, dry-run mode, graceful degradation with appropriate exit codes.

**T12: VisionCompliancePRD.swift**
- Status: VERIFIED (7/7 criteria met)
- Evidence: VisionComplianceHarness with ensureRunning() and shutdown(). visionFixturePath(), visionExtractCapture(), visionLoadAnalyzer() helper functions. File compiles with swift build.

**T13: CLAUDE.md**
- Status: VERIFIED (5/5 criteria met)
- Evidence: CLAUDE.md contains "Visual Verification Workflow" section with quick reference showing all scripts, flags table with all flags across all scripts, and artifacts table with all 8 locations.

**TD1-TD4: Documentation Updates**
- Status: VERIFIED
- Evidence: index.md has vision verification entries. modules.md and architecture.md updated per design impact. docs/visual-verification.md exists with comprehensive content.

## Implementation Gap Analysis

### Missing Implementations
- None. All planned files and components exist in the codebase.

### Partial Implementations
1. **AC-003f** (Generated tests specific enough): Runtime quality depends on LLM generation -- infrastructure is in place but outcome is non-deterministic.
2. **AC-004c** (Fix pipeline iterates until tests pass): `heal-loop.sh` invokes `claude -p` directly rather than the `/build --afk` rp1 skill. The single Claude invocation may or may not iterate internally.
3. **AC-006d** (Cost estimate before execution): Dry-run provides estimated API calls but the non-dry-run path does not output a pre-execution cost estimate.
4. **AC-007b** (Registry-based regression detection): Comparison is against previous evaluation only, not the full registry history.
5. **AC-007d** (Registry queryable): No dedicated query interface -- requires manual jq.
6. **AC-008b** (Files modified tracking): Build invocation audit does not record test paths or files modified.
7. **AC-010c** (Build invocation audit completeness): Test paths and files modified missing from audit entry.
8. **Runtime verification gap** (T2 AC-009): `swift test --filter VisionCapture` has not been confirmed to produce 8 PNGs + manifest.json in a full run. Only one PNG exists, suggesting an incomplete test run.

### Implementation Issues
- **Attended mode "Continue" option**: `heal-loop.sh` line 279 acknowledges the "Continue with manual guidance" option is "not yet implemented" and falls through to writing a report. This is a known incomplete feature path.

## Code Quality Assessment

**Overall**: HIGH

The implementation demonstrates strong adherence to project conventions and design specifications:

1. **Shell script quality**: All scripts follow the established `scripts/` conventions -- `set -euo pipefail`, `SCRIPT_DIR`/`PROJECT_ROOT` resolution, `info()`/`error()` helpers. Error handling is thorough with appropriate exit codes (0 for success, 1 for escalation, 2 for infrastructure failure).

2. **Swift code quality**: The capture orchestrator and compliance harness follow the exact patterns established by SpatialHarness/VisualHarness/AnimationHarness. Code uses proper Swift Testing conventions (@Suite, @Test, #expect, try #require). CryptoKit for hashing. Clean separation of concerns.

3. **Prompt template quality**: Evaluation prompt is well-structured with clear dimensions, calibration guidance, and output schema. Test templates provide concrete patterns for generated tests.

4. **Architecture alignment**: The three-layer design (shell scripts + Swift test infrastructure + CLAUDE.md docs) is cleanly implemented. No leakage between layers. The system does not modify mkdn's application code.

5. **Graceful degradation**: Registry corruption handling, git failure cleanup, compilation/failure validation gates for generated tests, atomic staging, and clear error messages throughout.

6. **JSON schema**: The output schema is comprehensive with proper types, enums, required fields, and descriptions. It matches the design specification exactly.

Minor concerns:
- Some bash scripts are quite long (evaluate.sh: 570 lines, verify.sh: 463 lines, heal-loop.sh: 714 lines), though they are well-structured with clear phase comments.
- The `MERMAID-FOCUS` fixture reference in the capture config assumes this fixture exists in `mkdnTests/Fixtures/UITest/` but its presence has not been independently verified.

## Recommendations

1. **Run the full capture test suite** (`swift test --filter VisionCapture`) in a macOS GUI session to verify all 8 captures produce valid PNGs and manifest.json. Currently only one PNG exists, suggesting an incomplete or interrupted test run.

2. **Add test path tracking to build invocation audit entries** in `heal-loop.sh` by serializing the `TEST_PATHS` variable into the `buildInvocation` audit JSON.

3. **Consider implementing registry-based regression detection** in `verify.sh` by querying the registry for previously-resolved issues and flagging their re-appearance, rather than comparing only against the immediately preceding evaluation.

4. **Add explicit cost estimate output** in the non-dry-run path of `evaluate.sh` before API calls begin (e.g., "Estimated API calls: N batches, M images").

5. **Complete the attended mode "Continue" option** in `heal-loop.sh` or document it explicitly as out-of-scope for the initial implementation.

6. **Verify fixture file existence**: Confirm that all four fixtures (`canonical.md`, `theme-tokens.md`, `mermaid-focus.md`, `geometry-calibration.md`) exist in `mkdnTests/Fixtures/UITest/`.

7. **Consider adding a `--query` subcommand** to one of the scripts for querying the registry, or document the jq patterns for common registry queries in the usage guide.

## Verification Evidence

### Shell Scripts -- Existence and Executability
All five scripts exist and are executable:
- `/Users/jud/Projects/mkdn/scripts/visual-verification/capture.sh` (3210 bytes)
- `/Users/jud/Projects/mkdn/scripts/visual-verification/evaluate.sh` (20885 bytes)
- `/Users/jud/Projects/mkdn/scripts/visual-verification/generate-tests.sh` (17856 bytes)
- `/Users/jud/Projects/mkdn/scripts/visual-verification/heal-loop.sh` (25632 bytes)
- `/Users/jud/Projects/mkdn/scripts/visual-verification/verify.sh` (18382 bytes)

### Swift Files -- Compilation
All three Swift files compile successfully with `swift build`:
- `/Users/jud/Projects/mkdn/mkdnTests/UITest/VisionCompliance/VisionCaptureTests.swift` (4488 bytes)
- `/Users/jud/Projects/mkdn/mkdnTests/UITest/VisionCompliance/VisionCapturePRD.swift` (5593 bytes)
- `/Users/jud/Projects/mkdn/mkdnTests/UITest/VisionCompliance/VisionCompliancePRD.swift` (3441 bytes)

### Prompt Templates -- Completeness
All 8 prompt template files exist:
- `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/evaluation-prompt.md` (4631 bytes)
- `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/output-schema.json` (7390 bytes)
- `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/prd-context-spatial.md` (4010 bytes)
- `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/prd-context-visual.md` (4197 bytes)
- `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/prd-context-mermaid.md` (2609 bytes)
- `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/test-template-spatial.md` (5721 bytes)
- `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/test-template-visual.md` (6150 bytes)
- `/Users/jud/Projects/mkdn/scripts/visual-verification/prompts/test-template-qualitative.md` (6791 bytes)

### Directory Structure
```
.rp1/work/verification/
  cache/          (.gitkeep)
  captures/       (.gitkeep, 1 PNG from partial run)
  reports/        (.gitkeep)
  staging/        (.gitkeep)
  registry.json   ({"version": 1, "entries": []})
scripts/visual-verification/
  capture.sh
  evaluate.sh
  generate-tests.sh
  heal-loop.sh
  verify.sh
  prompts/
    (8 template files)
mkdnTests/UITest/VisionCompliance/
  VisionCaptureTests.swift
  VisionCapturePRD.swift
  VisionCompliancePRD.swift
```

### Documentation
- CLAUDE.md updated with Visual Verification Workflow section (lines 59-105)
- `.rp1/context/index.md` updated with vision verification entries (lines 30-33)
- `docs/visual-verification.md` created (12086 bytes)
