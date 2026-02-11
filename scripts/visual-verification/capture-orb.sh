#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# capture-orb.sh -- Build mkdn and capture orb animation frame sequences
# for vision evaluation via the OrbVisionCapture test suite.
#
# Usage:
#   scripts/visual-verification/capture-orb.sh [--skip-build]
#
# Output:
#   Frame sequences in .rp1/work/verification/captures/orb/
#   Manifest at .rp1/work/verification/captures/orb/manifest.json
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VERIFICATION_DIR="${PROJECT_ROOT}/.rp1/work/verification"
CAPTURES_DIR="${VERIFICATION_DIR}/captures/orb"
MANIFEST="${CAPTURES_DIR}/manifest.json"

SKIP_BUILD=false

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info() {
    echo "==> $1"
}

error() {
    echo "ERROR: $1" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------

for arg in "$@"; do
    case "${arg}" in
        --skip-build)
            SKIP_BUILD=true
            ;;
        --help|-h)
            echo "Usage: capture-orb.sh [--skip-build]"
            echo ""
            echo "Flags:"
            echo "  --skip-build    Skip swift build --product mkdn"
            exit 0
            ;;
        *)
            error "Unknown flag: ${arg}"
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Phase 1: Build mkdn
# ---------------------------------------------------------------------------

if [ "${SKIP_BUILD}" = false ]; then
    info "Building mkdn"
    if ! swift build --product mkdn 2>&1; then
        error "swift build --product mkdn failed"
    fi
    info "Build succeeded"
else
    info "Skipping build (--skip-build)"
fi

# ---------------------------------------------------------------------------
# Phase 2: Ensure captures directory exists
# ---------------------------------------------------------------------------

mkdir -p "${CAPTURES_DIR}"

# ---------------------------------------------------------------------------
# Phase 3: Run orb capture test suite
# ---------------------------------------------------------------------------

info "Running OrbVisionCapture test suite"
if ! swift test --filter OrbVisionCapture 2>&1; then
    error "swift test --filter OrbVisionCapture failed"
fi
info "Orb capture test suite completed"

# ---------------------------------------------------------------------------
# Phase 4: Validate manifest and report results
# ---------------------------------------------------------------------------

info "Validating manifest"

if [ ! -f "${MANIFEST}" ]; then
    error "manifest.json not found at ${MANIFEST}"
fi

SEQUENCE_COUNT=$(jq '.sequences | length' "${MANIFEST}" 2>/dev/null) || \
    error "Failed to parse manifest.json"

if [ "${SEQUENCE_COUNT}" -lt 1 ]; then
    error "manifest.json contains no sequences"
fi

TOTAL_FRAMES=$(jq '[.sequences[].frameCount] | add' "${MANIFEST}" 2>/dev/null) || \
    TOTAL_FRAMES="unknown"

info "Capture complete: ${SEQUENCE_COUNT} sequences, ${TOTAL_FRAMES} total frames"
info "Output: ${CAPTURES_DIR}"
exit 0
