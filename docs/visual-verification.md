# Visual Verification Workflow

LLM vision-based design compliance for mkdn. Captures deterministic screenshots via the test harness, evaluates them against PRD specifications and the charter's design philosophy using Claude Code's vision capabilities, generates failing tests for detected issues, fixes the code autonomously via `/build --afk`, and re-verifies the result.

This is the qualitative counterpart to the existing pixel-level automated UI testing infrastructure: where pixel tests answer "is this margin 32pt?", the vision verification answers "does this look right?" and "does the spatial rhythm feel balanced?"

## Prerequisites

- macOS GUI session (window server required for screenshot capture)
- Screen Recording permission granted to Terminal / CI agent
- Retina display (2x scale factor assumed)
- `jq` installed (standard on macOS)
- Claude Code available for vision evaluation

## Quick Start

```bash
# Full autonomous loop: capture, evaluate, generate tests, fix, verify
scripts/visual-verification/heal-loop.sh

# Dry run: capture screenshots + preview what would be evaluated (no API calls)
scripts/visual-verification/heal-loop.sh --dry-run

# Attended mode: interactive escalation prompts instead of report files
scripts/visual-verification/heal-loop.sh --attended
```

## Shell Scripts

### heal-loop.sh

Top-level orchestrator that chains all phases with bounded iteration.

```bash
scripts/visual-verification/heal-loop.sh [options]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--max-iterations N` | 3 | Maximum heal iterations before escalation |
| `--dry-run` | off | Capture + evaluate only, no test generation or code fixes |
| `--attended` | off | Interactive escalation prompts instead of report files |
| `--skip-build` | off | Skip initial `swift build` in capture phase |

**Lifecycle**:

1. **Capture**: Run `capture.sh` to produce screenshots and manifest
2. **Evaluate**: Run `evaluate.sh` to assess screenshots against design specs
3. If no issues detected: write clean report, exit 0
4. **Generate**: Run `generate-tests.sh` to create failing Swift tests
5. **Commit**: `git add` and `git commit` the generated tests
6. **Fix**: Invoke `/build --afk` with failing test paths and PRD context
7. **Verify**: Run `verify.sh` to re-capture, re-evaluate, and detect regressions
8. If regressions found: loop back to step 4 (up to `--max-iterations`)
9. If clean: write success report, exit 0
10. If max iterations exhausted: write escalation report, exit 1

### capture.sh

Builds mkdn and runs the capture orchestrator test suite.

```bash
scripts/visual-verification/capture.sh [--skip-build]
```

Produces 8 screenshots (4 fixtures x 2 themes) plus `manifest.json` in `.rp1/work/verification/captures/`.

The capture matrix:

| Fixture | Theme: Dark | Theme: Light |
|---------|-------------|--------------|
| `canonical.md` | canonical-solarizedDark-previewOnly.png | canonical-solarizedLight-previewOnly.png |
| `theme-tokens.md` | theme-tokens-solarizedDark-previewOnly.png | theme-tokens-solarizedLight-previewOnly.png |
| `mermaid-focus.md` | mermaid-focus-solarizedDark-previewOnly.png | mermaid-focus-solarizedLight-previewOnly.png |
| `geometry-calibration.md` | geometry-calibration-solarizedDark-previewOnly.png | geometry-calibration-solarizedLight-previewOnly.png |

### evaluate.sh

Assembles evaluation context from prompt templates and PRD files, checks the cache, and coordinates LLM vision evaluation.

```bash
scripts/visual-verification/evaluate.sh [options]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--dry-run` | off | Preview what would be evaluated without API calls |
| `--batch-size N` | 4 | Maximum images per evaluation batch |
| `--force-fresh` | off | Bypass cache, force fresh evaluation |

Batches are grouped by fixture (same fixture, both themes in one batch). Default composition:

| Batch | Captures | PRD Context |
|-------|----------|-------------|
| 1 | canonical (dark + light) | spatial-design-language, cross-element-selection |
| 2 | theme-tokens (dark + light) | terminal-consistent-theming, syntax-highlighting |
| 3 | mermaid-focus (dark + light) | mermaid-rendering |
| 4 | geometry-calibration (dark + light) | spatial-design-language |

Cache keys are computed from SHA-256 hashes of image content, prompt templates, and PRD files. Unchanged inputs return cached results without API calls.

### generate-tests.sh

Reads an evaluation report and generates Swift test files for medium/high confidence issues.

```bash
scripts/visual-verification/generate-tests.sh [evaluation-report-path]
```

If no path is provided, uses the most recent evaluation report in `.rp1/work/verification/reports/`.

For each qualifying issue:

1. Determines test type (spatial, visual, qualitative) from the issue data
2. Reads the corresponding test template from `scripts/visual-verification/prompts/`
3. Generates a Swift test file via Claude Code
4. Validates compilation (`swift build`); discards on failure
5. Validates the test currently fails (`swift test --filter`); discards if it passes (false positive)
6. Moves validated tests from staging to `mkdnTests/UITest/VisionCompliance/`

Generated files follow the naming convention: `VisionDetected_{PRD}_{FR}_{aspect}.swift`

### verify.sh

Re-captures screenshots and re-evaluates after a fix, comparing against the previous evaluation.

```bash
scripts/visual-verification/verify.sh [previous-evaluation-path]
```

Classifies each issue from the previous evaluation:

- **Resolved**: present in previous evaluation, absent in new
- **Regression**: absent in previous evaluation, present in new
- **Remaining**: present in both evaluations

Updates the regression registry with resolution status.

## Interpreting Evaluation Reports

Evaluation reports are written to `.rp1/work/verification/reports/{timestamp}-evaluation.json`.

### Issue Structure

Each detected issue contains:

| Field | Description |
|-------|-------------|
| `issueId` | Unique identifier (e.g., `ISS-001`) |
| `captureId` | Which screenshot the issue was detected in |
| `prdReference` | PRD name and functional requirement (e.g., `spatial-design-language FR-3`) |
| `specificationExcerpt` | The relevant specification text that defines expected behavior |
| `observation` | What was actually observed in the screenshot |
| `deviation` | How the observation differs from the specification |
| `severity` | `critical` (blocks daily-driver use), `major` (noticeable regression), `minor` (subtle polish) |
| `confidence` | `high`, `medium`, `low` |
| `suggestedAssertion` | Structured hint for test generation (type, metric, expected value, tolerance) |

### Qualitative Findings

Qualitative findings assess design qualities that are not tied to specific numerical PRD requirements:

| Field | Description |
|-------|-------------|
| `findingId` | Unique identifier (e.g., `QF-001`) |
| `reference` | Charter section or design principle referenced |
| `observation` | What was observed |
| `assessment` | Qualitative judgment about the observation |
| `severity` | Same scale as issues |
| `confidence` | Same scale as issues |

### Summary

The `summary` object provides aggregate counts:

```json
{
  "totalCaptures": 8,
  "issuesDetected": 3,
  "qualitativeFindings": 2,
  "bySeverity": { "critical": 0, "major": 2, "minor": 3 },
  "byConfidence": { "high": 2, "medium": 2, "low": 1 }
}
```

## Interpreting Escalation Reports

Escalation reports are written to `.rp1/work/verification/reports/{timestamp}-escalation.json` when the self-healing loop cannot fully resolve all issues.

**Escalation triggers**:

- Maximum iterations exhausted with unresolved issues remaining
- All issues are low-confidence (none auto-testable)
- Generated tests fail compilation or pass immediately (false positives)

Each escalation report contains:

- `escalationType`: Why escalation occurred (e.g., `maxIterationsExhausted`)
- `unresolvedIssues`: Each with all fix attempts, iteration history, and suggested next steps
- `lowConfidenceIssues`: Issues flagged for human review (never auto-tested)

**Suggested next steps** in escalation reports are actionable recommendations:

- Review the referenced PRD specification for ambiguity
- Check if the rendering approach conflicts with the requirement
- Consider whether the PRD value needs updating based on implementation constraints

## Self-Healing Loop Lifecycle

The full loop runs bounded iterations (default: 3 max):

```
Iteration 1:
  capture -> evaluate -> 3 issues found
  generate tests -> 2 tests pass validation (1 discarded)
  git commit tests
  /build --afk -> fixes code
  re-capture -> re-evaluate -> 2 resolved, 1 new regression

Iteration 2:
  generate test for regression -> 1 test passes validation
  git commit test
  /build --afk -> fixes regression
  re-capture -> re-evaluate -> all clean

Result: success report, exit 0
```

Loop state is tracked in `.rp1/work/verification/current-loop.json` with per-iteration records of issues detected, tests generated, build results, and re-verification outcomes.

## Cost Management

### Caching

Evaluation results are cached at `.rp1/work/verification/cache/{cacheKey}.json`. The cache key is a SHA-256 hash of:

- Sorted image content hashes from the manifest
- Prompt template content hash
- PRD file content hashes

Unchanged inputs skip API calls entirely. Cache entries are replaced (not updated) when any input changes.

### Dry-Run Mode

Use `--dry-run` to preview evaluation without API calls:

```bash
scripts/visual-verification/heal-loop.sh --dry-run
```

Produces a dry-run report showing:

- Number of captures produced
- Batch composition (which captures grouped together)
- Which batches would hit cache vs require fresh evaluation
- Estimated API calls

### Batch Composition

Screenshots are grouped by fixture (same fixture, both themes = 1 batch). Default: 4 batches of 2 images each. Configurable via `--batch-size`.

### Typical API Call Counts

| Scenario | API Calls |
|----------|-----------|
| Clean run, no cache | 4 (one per fixture batch) |
| Clean run, all cached | 0 |
| Full loop, 1 iteration | 8 (4 initial + 4 re-verification) |
| Full loop, max 3 iterations | Up to 16 |

## Artifacts

| Location | Purpose | Git-Tracked |
|----------|---------|-------------|
| `.rp1/work/verification/captures/` | Screenshots and `manifest.json` | No (regenerated) |
| `.rp1/work/verification/reports/` | Evaluation, escalation, success, dry-run reports | Yes |
| `.rp1/work/verification/cache/` | Cached evaluation results | Yes |
| `.rp1/work/verification/registry.json` | Regression registry (compliance history) | Yes |
| `.rp1/work/verification/audit.jsonl` | Audit trail (JSON Lines, append-only) | Yes |
| `.rp1/work/verification/staging/` | Atomic test generation staging area | No (temporary) |
| `.rp1/work/verification/current-loop.json` | Current loop iteration state | No (temporary) |
| `mkdnTests/UITest/VisionCompliance/` | Capture orchestrator and generated tests | Yes |
| `scripts/visual-verification/prompts/` | Prompt templates and output schema | Yes |

## Regression Registry

The registry at `.rp1/work/verification/registry.json` records evaluation history per capture:

- Screenshot content hash and capture ID
- Evaluation timestamps and detected issues
- Resolution status for each issue (resolved, regressed, remaining)
- Last evaluation timestamp and overall status

When re-evaluating a capture whose hash exists in the registry, `verify.sh` detects regressions: previously-resolved issues that reappear are flagged with `"status": "regressed"`.

## Audit Trail

Every operation is logged to `.rp1/work/verification/audit.jsonl` in JSON Lines format (one JSON object per line, append-only for crash resilience).

Entry types: `capture`, `evaluation`, `testGeneration`, `buildInvocation`, `reVerification`, `escalation`, `loopStarted`, `loopCompleted`.

Each entry includes a timestamp and operation-specific metadata for full traceability from detection to resolution.
