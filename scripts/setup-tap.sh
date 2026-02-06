#!/usr/bin/env bash
# setup-tap.sh -- One-time setup for the jud/homebrew-mkdn Homebrew tap repository.
#
# This script creates the GitHub repository jud/homebrew-mkdn, populates it
# with the Cask definition from this project's Casks/mkdn.rb, and pushes.
# After running, `brew tap jud/mkdn` will work.
#
# Prerequisites:
#   - gh CLI installed and authenticated (`gh auth status`)
#   - Casks/mkdn.rb exists in this project (created by T2)
#
# Usage:
#   ./scripts/setup-tap.sh
#
# This is a one-time operation. If the repository already exists, the script
# will exit without making changes.

set -euo pipefail

REPO="jud/homebrew-mkdn"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CASK_SOURCE="${PROJECT_ROOT}/Casks/mkdn.rb"
TMPDIR_TAP="${TMPDIR:-/tmp}/homebrew-mkdn-setup"

# -- Helpers ------------------------------------------------------------------

info() { printf "==> %s\n" "$1"; }
error() { printf "ERROR: %s\n" "$1" >&2; exit 1; }

cleanup() {
    if [[ -d "${TMPDIR_TAP}" ]]; then
        rm -rf "${TMPDIR_TAP}"
    fi
}
trap cleanup EXIT

# -- Pre-flight checks --------------------------------------------------------

info "Checking prerequisites..."

if ! command -v gh &>/dev/null; then
    error "gh CLI is not installed. Install it with: brew install gh"
fi

if ! gh auth status &>/dev/null; then
    error "gh CLI is not authenticated. Run: gh auth login"
fi

if [[ ! -f "${CASK_SOURCE}" ]]; then
    error "Cask definition not found at ${CASK_SOURCE}. Run T2 first to create it."
fi

# -- Check if repository already exists ---------------------------------------

info "Checking if ${REPO} already exists..."

if gh repo view "${REPO}" &>/dev/null; then
    info "Repository ${REPO} already exists. Nothing to do."
    info ""
    info "To verify the tap works:"
    info "  brew tap jud/mkdn"
    info "  brew info --cask mkdn"
    exit 0
fi

# -- Create the repository ----------------------------------------------------

info "Creating GitHub repository ${REPO}..."
gh repo create "${REPO}" --public --description "Homebrew tap for mkdn -- Mac-native Markdown viewer"

# -- Clone, populate, and push ------------------------------------------------

info "Cloning ${REPO} into temporary directory..."
cleanup  # remove stale tmpdir if present
gh repo clone "${REPO}" "${TMPDIR_TAP}"

info "Creating Casks/ directory and copying mkdn.rb..."
mkdir -p "${TMPDIR_TAP}/Casks"
cp "${CASK_SOURCE}" "${TMPDIR_TAP}/Casks/mkdn.rb"

info "Committing and pushing..."
cd "${TMPDIR_TAP}"
git add Casks/mkdn.rb
git commit -m "Add mkdn Cask definition

Initial Homebrew Cask for mkdn with placeholder version and SHA256.
The release script (scripts/release.sh) updates these on each release."
git push origin main

cd "${PROJECT_ROOT}"

# -- Verify -------------------------------------------------------------------

info "Verifying tap is accessible..."
if brew tap jud/mkdn 2>/dev/null; then
    info "PASS: brew tap jud/mkdn succeeded"
    brew untap jud/mkdn 2>/dev/null || true
else
    info "NOTE: brew tap verification skipped or failed."
    info "      You can verify manually with: brew tap jud/mkdn"
fi

# -- Done ---------------------------------------------------------------------

info ""
info "Tap repository setup complete!"
info ""
info "Repository: https://github.com/${REPO}"
info ""
info "Users can now install mkdn with:"
info "  brew tap jud/mkdn"
info "  brew install --cask mkdn"
info ""
info "Next steps:"
info "  1. Run ./scripts/release.sh to publish a release"
info "  2. The release script will update the Cask with the real version and SHA256"
info "  3. Run ./scripts/smoke-test.sh to verify the full install cycle"
