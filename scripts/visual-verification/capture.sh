#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# capture.sh -- Build mkdn and capture deterministic screenshots for vision
# evaluation via the VisionCapture test suite.
#
# Usage:
#   scripts/visual-verification/capture.sh [--skip-build]
#
# Output:
#   Screenshots in .rp1/work/verification/captures/
#   Manifest at .rp1/work/verification/captures/manifest.json
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VERIFICATION_DIR="${PROJECT_ROOT}/.rp1/work/verification"
CAPTURES_DIR="${VERIFICATION_DIR}/captures"
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
            echo "Usage: capture.sh [--skip-build]"
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
# Phase 3: Run capture test suite
# ---------------------------------------------------------------------------

info "Running VisionCapture test suite"
if ! swift test --filter VisionCapture 2>&1; then
    error "swift test --filter VisionCapture failed"
fi
info "Capture test suite completed"

# ---------------------------------------------------------------------------
# Phase 4: Validate manifest
# ---------------------------------------------------------------------------

info "Validating manifest"

if [ ! -f "${MANIFEST}" ]; then
    error "manifest.json not found at ${MANIFEST}"
fi

CAPTURE_COUNT=$(jq '.captures | length' "${MANIFEST}" 2>/dev/null) || \
    error "Failed to parse manifest.json"

if [ "${CAPTURE_COUNT}" -lt 1 ]; then
    error "manifest.json contains no captures"
fi

info "Capture complete: ${CAPTURE_COUNT} captures in manifest"
exit 0
