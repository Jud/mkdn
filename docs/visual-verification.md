# Visual Verification Workflow

On-demand LLM vision-based design compliance for mkdn. Captures deterministic screenshots via the test harness and evaluates them against PRD specifications and the charter's design philosophy using Claude Code's vision capabilities. Reports findings for developer review.

This is the qualitative counterpart to the existing pixel-level automated UI testing infrastructure: where pixel tests answer "is this margin 32pt?", the vision verification answers "does this look right?" and "does the spatial rhythm feel balanced?"

## Prerequisites

- macOS GUI session (window server required for screenshot capture)
- Screen Recording permission granted to Terminal / CI agent
- Retina display (2x scale factor assumed)
- `jq` installed (standard on macOS)
- Claude Code available for vision evaluation

## Quick Start

```bash
# Full verification: capture, evaluate, print summary
scripts/visual-verification/verify-visual.sh

# Dry run: capture screenshots + preview what would be evaluated (no API calls)
scripts/visual-verification/verify-visual.sh --dry-run

# Skip build step (use existing binary)
scripts/visual-verification/verify-visual.sh --skip-build

# Bypass evaluation cache
scripts/visual-verification/verify-visual.sh --force-fresh

# Raw JSON output instead of human-readable summary
scripts/visual-verification/verify-visual.sh --json
```

## Shell Scripts

### verify-visual.sh

Top-level entry point that chains capture and evaluation, then formats results.

```bash
scripts/visual-verification/verify-visual.sh [options]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--dry-run` | off | Capture + show what would be evaluated (no API calls) |
| `--skip-build` | off | Skip `swift build` in capture phase |
| `--force-fresh` | off | Bypass evaluation cache |
| `--json` | off | Output raw JSON instead of human-readable summary |

**Lifecycle**:

1. **Capture**: Run `capture.sh` to produce screenshots and manifest
2. **Evaluate**: Run `evaluate.sh` to assess screenshots against design specs
3. **Report**: Read evaluation results and print human-readable summary
4. Exit 0 if clean, exit 1 if issues detected, exit 2 on infrastructure failure

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
| `suggestedAssertion` | Structured hint for writing targeted tests (type, metric, expected value, tolerance) |

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
scripts/visual-verification/verify-visual.sh --dry-run
```

Produces a dry-run report showing:

- Number of captures produced
- Batch composition (which captures grouped together)
- Estimated API calls

### Typical API Call Counts

| Scenario | API Calls |
|----------|-----------|
| Fresh run, no cache | 4 (one per fixture batch) |
| All cached | 0 |

## Artifacts

| Location | Purpose | Git-Tracked |
|----------|---------|-------------|
| `.rp1/work/verification/captures/` | Screenshots and `manifest.json` | No (regenerated) |
| `.rp1/work/verification/reports/` | Evaluation and dry-run reports | Yes |
| `.rp1/work/verification/cache/` | Cached evaluation results | Yes |
| `.rp1/work/verification/audit.jsonl` | Audit trail (JSON Lines, append-only) | Yes |
| `mkdnTests/UITest/VisionCompliance/` | Capture orchestrator test suite | Yes |
| `scripts/visual-verification/prompts/` | Prompt templates and output schema | Yes |
