#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# verify-visual.sh -- On-demand visual verification of mkdn screenshots.
# Chains capture.sh + evaluate.sh and formats a human-readable summary.
#
# Usage:
#   scripts/visual-verification/verify-visual.sh [flags]
#
# Flags:
#   --dry-run       Capture + show what would be evaluated (no API calls)
#   --skip-build    Skip swift build step
#   --force-fresh   Bypass evaluation cache
#   --json          Output raw JSON instead of summary
#
# Exit codes:
#   0  Clean (no issues detected)
#   1  Issues detected (see summary)
#   2  Infrastructure failure (capture or evaluation failed)
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPORTS_DIR="${PROJECT_ROOT}/.rp1/work/verification/reports"

DRY_RUN=false
SKIP_BUILD=false
FORCE_FRESH=false
JSON_OUTPUT=false

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info() {
    echo "==> $1"
}

error() {
    echo "ERROR: $1" >&2
    exit 2
}

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --force-fresh)
            FORCE_FRESH=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --help|-h)
            echo "Usage: verify-visual.sh [flags]"
            echo ""
            echo "On-demand visual verification of mkdn screenshots."
            echo "Captures screenshots, evaluates against design PRDs,"
            echo "and reports findings."
            echo ""
            echo "Flags:"
            echo "  --dry-run       Capture + show what would be evaluated (no API calls)"
            echo "  --skip-build    Skip swift build step"
            echo "  --force-fresh   Bypass evaluation cache"
            echo "  --json          Output raw JSON instead of summary"
            echo ""
            echo "Exit codes:"
            echo "  0  Clean (no issues detected)"
            echo "  1  Issues detected"
            echo "  2  Infrastructure failure"
            exit 0
            ;;
        *)
            error "Unknown flag: $1"
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Phase 1: Capture
# ---------------------------------------------------------------------------

info "Phase 1: Capture screenshots"

CAPTURE_FLAGS=()
if [ "${SKIP_BUILD}" = true ]; then
    CAPTURE_FLAGS+=("--skip-build")
fi

if ! "${SCRIPT_DIR}/capture.sh" "${CAPTURE_FLAGS[@]+"${CAPTURE_FLAGS[@]}"}"; then
    error "Capture phase failed"
fi

# ---------------------------------------------------------------------------
# Phase 2: Evaluate
# ---------------------------------------------------------------------------

info "Phase 2: Evaluate screenshots"

EVAL_FLAGS=()
if [ "${DRY_RUN}" = true ]; then
    EVAL_FLAGS+=("--dry-run")
fi
if [ "${FORCE_FRESH}" = true ]; then
    EVAL_FLAGS+=("--force-fresh")
fi

if ! "${SCRIPT_DIR}/evaluate.sh" "${EVAL_FLAGS[@]+"${EVAL_FLAGS[@]}"}"; then
    error "Evaluation phase failed"
fi

# ---------------------------------------------------------------------------
# Phase 3: Read report and print summary
# ---------------------------------------------------------------------------

if [ "${DRY_RUN}" = true ]; then
    REPORT=$(ls -t "${REPORTS_DIR}"/*-dryrun.json 2>/dev/null | head -1) || true
    if [ -z "${REPORT}" ] || [ ! -f "${REPORT}" ]; then
        error "No dry-run report produced"
    fi

    if [ "${JSON_OUTPUT}" = true ]; then
        jq . "${REPORT}"
    else
        echo ""
        echo "=========================================="
        echo "  Visual Verification (dry run)"
        echo "=========================================="
        echo ""
        CAPTURES=$(jq -r '.capturesProduced' "${REPORT}")
        BATCHES=$(jq -r '.estimatedApiCalls' "${REPORT}")
        echo "  Captures produced: ${CAPTURES}"
        echo "  Batches to evaluate: ${BATCHES}"
        echo "  API calls required: ${BATCHES}"
        echo ""
        jq -r '.batchComposition[] | "  Batch \(.batchId): \(.fixture) (\(.captures | length) images, PRD: \(.prdContext))"' "${REPORT}"
        echo ""
        echo "  Full report: ${REPORT}"
    fi

    exit 0
fi

REPORT=$(ls -t "${REPORTS_DIR}"/*-evaluation.json 2>/dev/null | head -1) || true
if [ -z "${REPORT}" ] || [ ! -f "${REPORT}" ]; then
    error "No evaluation report produced"
fi

if [ "${JSON_OUTPUT}" = true ]; then
    jq . "${REPORT}"
    ISSUE_COUNT=$(jq '.issues | length' "${REPORT}")
    if [ "${ISSUE_COUNT}" -gt 0 ]; then
        exit 1
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# Human-readable summary
# ---------------------------------------------------------------------------

ISSUE_COUNT=$(jq '.issues | length' "${REPORT}")
QUALITATIVE_COUNT=$(jq '.qualitativeFindings | length' "${REPORT}")
TOTAL=$((ISSUE_COUNT + QUALITATIVE_COUNT))

echo ""
echo "=========================================="
echo "  Visual Verification Results"
echo "=========================================="
echo ""

if [ "${TOTAL}" -eq 0 ]; then
    echo "  Status: CLEAN"
    echo "  No design issues detected."
    echo ""
    echo "  Full report: ${REPORT}"
    exit 0
fi

# Severity counts
SEV_CRITICAL=$(jq '[.issues[], .qualitativeFindings[]] | map(select(.severity == "critical")) | length' "${REPORT}")
SEV_MAJOR=$(jq '[.issues[], .qualitativeFindings[]] | map(select(.severity == "major")) | length' "${REPORT}")
SEV_MINOR=$(jq '[.issues[], .qualitativeFindings[]] | map(select(.severity == "minor")) | length' "${REPORT}")

echo "  Status: ${TOTAL} issue(s) detected"
echo "  Severity: ${SEV_CRITICAL} critical, ${SEV_MAJOR} major, ${SEV_MINOR} minor"
echo ""

# Print concrete issues
if [ "${ISSUE_COUNT}" -gt 0 ]; then
    echo "  Issues:"
    echo "  -------"
    jq -r '.issues[] | "  [\(.severity)/\(.confidence)] \(.prdReference)\n    \(.observation)\n"' "${REPORT}"
fi

# Print qualitative findings
if [ "${QUALITATIVE_COUNT}" -gt 0 ]; then
    echo "  Qualitative Findings:"
    echo "  ----------------------"
    jq -r '.qualitativeFindings[] | "  [\(.severity)/\(.confidence)] \(.reference)\n    \(.observation)\n"' "${REPORT}"
fi

echo "  Full report: ${REPORT}"
exit 1
