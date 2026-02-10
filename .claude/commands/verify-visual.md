---
description: Run visual verification against design PRDs using screenshots and LLM vision
allowed-tools: [Bash, Read, Glob, Grep]
argument-hint: "[--dry-run] [--skip-build] [--force-fresh]"
---

# Visual Verification

Capture deterministic screenshots of the running app and evaluate them against design PRD specifications using vision capabilities.

## Arguments

Flags from `$ARGUMENTS`:
- `--dry-run`: Capture screenshots and show what would be evaluated, but skip the vision API call
- `--skip-build`: Skip the `swift build` step (use existing binary)
- `--force-fresh`: Bypass the evaluation cache and force a fresh evaluation
- If no flags provided, run the full capture + evaluate pipeline

## Instructions

### Step 1: Run verification

Execute the verify-visual.sh script from the project root:

```bash
scripts/visual-verification/verify-visual.sh $ARGUMENTS
```

This chains two phases:
1. **Capture**: Builds the app, launches it via the test harness, captures 8 deterministic screenshots (4 fixtures x 2 themes), and produces a manifest
2. **Evaluate**: Sends screenshots in batches to Claude vision with PRD context, produces a structured evaluation report

### Step 2: Read the evaluation report

Find and read the most recent evaluation report:

```bash
ls -t .rp1/work/verification/reports/*-evaluation.json | head -1
```

Read the JSON report file to understand the findings.

### Step 3: Present findings

Summarize the evaluation for the user:

1. **Overview**: Total captures evaluated, issues found, qualitative findings
2. **Issues by severity**: List critical issues first, then major, then minor
3. **For each issue**: Show the PRD reference, observation, deviation, confidence level
4. **Positive findings**: Briefly note what's working well from qualitative findings
5. **Recommendations**: Suggest which issues to address based on severity and confidence

### Step 4: Offer next steps

After presenting findings, offer:
- Fix specific issues (reference the PRD and FR for each)
- Re-run with `--force-fresh` after making changes to verify fixes
- View the raw screenshots in `.rp1/work/verification/captures/`

## Notes

- The evaluation cache avoids redundant API calls when screenshots haven't changed
- Reports are saved to `.rp1/work/verification/reports/` for historical reference
- Captures are at `.rp1/work/verification/captures/` (8 PNGs + manifest.json)
- PRD context for evaluation is in `scripts/visual-verification/prompts/prd-context-*.md`
