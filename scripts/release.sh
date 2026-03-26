#!/usr/bin/env bash
set -euo pipefail

# Release script for mkdn.
#
# Usage: release.sh --notes-file <path>
#
# The --notes-file flag is required. Before running this script, generate
# release notes by hand or write them as follows:
#
#   1. Read .style in the project root for voice/tone guidance.
#   2. Find the previous release tag and collect the commits since then.
#   3. Read the actual code changes (not just commit subjects) to understand
#      what changed for the user. Commit messages are developer-facing and
#      often misleading -- the diff is the source of truth.
#   4. Write a short changelog for end users. Group by what changed, not by
#      commit. Use bold lowercase headings (**tables rebuilt.**, **fixed.**).
#      Be honest about bug fixes. No marketing language. No commit hashes.
#      Skip internal refactors, test changes, and code cleanup.
#   5. Save to build/release-notes.md and pass via --notes-file.
#
# Set SKIP_CHANGELOG=1 to bypass and use raw commit subjects instead.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Parse flags
NOTES_FILE_ARG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --notes-file)
            NOTES_FILE_ARG="$2"
            [ -f "${NOTES_FILE_ARG}" ] || { echo "ERROR: notes file not found: ${NOTES_FILE_ARG}" >&2; exit 1; }
            shift 2
            ;;
        *)
            echo "ERROR: unknown flag: $1" >&2
            echo "Usage: release.sh [--notes-file <path>]" >&2
            exit 1
            ;;
    esac
done

BUILD_DIR="${PROJECT_ROOT}/build"
APP_BUNDLE="${BUILD_DIR}/mkdn.app"
CLI_SWIFT="${PROJECT_ROOT}/mkdn/Core/CLI/MkdnCLI.swift"
SPM_BUILD_DIR="${PROJECT_ROOT}/.build/arm64-apple-macosx/release"
SIGNING_IDENTITY="Developer ID Application: Jud Stephenson (SYX3424FVV)"
NOTARIZE_PROFILE="mkdn-notarize"

VERSION_INJECTED=false

cleanup() {
    if [ "${VERSION_INJECTED}" = true ]; then
        echo "Reverting version injection in MkdnCLI.swift..."
        git -C "${PROJECT_ROOT}" checkout -- "${CLI_SWIFT}"
        VERSION_INJECTED=false
    fi
}

trap cleanup EXIT

error() {
    echo "ERROR: $1" >&2
    exit 1
}

info() {
    echo "==> $1"
}

# ---------------------------------------------------------------------------
# Phase 1: Pre-flight checks
# ---------------------------------------------------------------------------
info "Pre-flight checks"

command -v gh > /dev/null 2>&1 || error "gh CLI is not installed. Install it with: brew install gh"
gh auth status > /dev/null 2>&1 || error "gh CLI is not authenticated. Run: gh auth login"

cd "${PROJECT_ROOT}"

git diff --quiet || error "Working tree has unstaged changes. Commit or stash them first."
git diff --cached --quiet || error "Working tree has staged but uncommitted changes. Commit or stash them first."

TAG=$(git describe --tags --exact-match HEAD 2>/dev/null) || error "Current commit has no tag. Create one with: git tag v1.0.0"
[[ "${TAG}" == v* ]] || error "Tag '${TAG}' does not match v* pattern. Use semantic version tags like v1.0.0"

VERSION="${TAG#v}"
echo "  Version: ${VERSION} (from tag ${TAG})"

[[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || error "Version '${VERSION}' is not valid semver. Expected format: MAJOR.MINOR.PATCH"

echo "  gh CLI: authenticated"
echo "  Working tree: clean"
echo "  Tag: ${TAG}"

# ---------------------------------------------------------------------------
# Phase 2: Version injection
# ---------------------------------------------------------------------------
info "Injecting version ${VERSION} into MkdnCLI.swift"

sed -i '' "s/version: \"[0-9]*\.[0-9]*\.[0-9]*\"/version: \"${VERSION}\"/" "${CLI_SWIFT}"
VERSION_INJECTED=true

grep -q "version: \"${VERSION}\"" "${CLI_SWIFT}" || error "Version injection failed -- pattern not found in MkdnCLI.swift"
echo "  Version injected: ${VERSION}"

# ---------------------------------------------------------------------------
# Phase 3: Build
# ---------------------------------------------------------------------------
info "Building release binary (arm64)"

swift build -c release --arch arm64

[ -f "${SPM_BUILD_DIR}/mkdn" ] || error "Build succeeded but binary not found at ${SPM_BUILD_DIR}/mkdn"
echo "  Binary: ${SPM_BUILD_DIR}/mkdn"

# ---------------------------------------------------------------------------
# Phase 3.5: Patch SPM resource bundle accessors for .app distribution
# ---------------------------------------------------------------------------
info "Patching SPM resource bundle accessors"

# SPM's generated Bundle.module accessor calls fatalError when the bundle
# can't be found.  This breaks when the binary is launched via a symlink
# (e.g. Homebrew's /opt/homebrew/bin/mkdn -> .app/Contents/MacOS/mkdn)
# because Bundle.main doesn't detect the .app structure from the symlink path.
# Replace each generated accessor with one that resolves symlinks.
ACCESSOR_COUNT=0
while IFS= read -r -d '' accessor; do
    BUNDLE_NAME=$(grep -o '"[^"]*\.bundle"' "$accessor" | head -1 | tr -d '"')
    if [ -n "${BUNDLE_NAME}" ]; then
        cat > "$accessor" << SWIFT_ACCESSOR
import Foundation

extension Foundation.Bundle {
    static let module: Bundle = {
        let bundleName = "${BUNDLE_NAME}"

        if let url = Bundle.main.resourceURL,
           let bundle = Bundle(url: url.appendingPathComponent(bundleName)) {
            return bundle
        }

        if let bundle = Bundle(url: Bundle.main.bundleURL.appendingPathComponent(bundleName)) {
            return bundle
        }

        // Resolve symlinks (Homebrew symlink case)
        let execURL = (Bundle.main.executableURL
            ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0]))
            .resolvingSymlinksInPath()
        let resourcesURL = execURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent(bundleName)
        if let bundle = Bundle(url: resourcesURL) {
            return bundle
        }

        Swift.fatalError("could not load resource bundle: \\\(bundleName)")
    }()
}
SWIFT_ACCESSOR
        ACCESSOR_COUNT=$((ACCESSOR_COUNT + 1))
    fi
done < <(find "${SPM_BUILD_DIR}" -name "resource_bundle_accessor.swift" -path "*/DerivedSources/*" -print0)

echo "  Patched ${ACCESSOR_COUNT} resource bundle accessors"

info "Rebuilding with patched accessors"

swift build -c release --arch arm64

# ---------------------------------------------------------------------------
# Phase 4: Revert version injection
# ---------------------------------------------------------------------------
info "Reverting version injection"

git -C "${PROJECT_ROOT}" checkout -- "${CLI_SWIFT}"
VERSION_INJECTED=false
echo "  MkdnCLI.swift restored"

# ---------------------------------------------------------------------------
# Phase 5: Bundle assembly
# ---------------------------------------------------------------------------
info "Assembling .app bundle"

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${SPM_BUILD_DIR}/mkdn" "${APP_BUNDLE}/Contents/MacOS/mkdn"
echo "  Copied binary to Contents/MacOS/mkdn"

BUNDLE_COUNT=0
for bundle_dir in "${SPM_BUILD_DIR}"/*.bundle; do
    [ -d "${bundle_dir}" ] || continue
    bundle_name=$(basename "${bundle_dir}")
    cp -R "${bundle_dir}" "${APP_BUNDLE}/Contents/Resources/${bundle_name}"
    BUNDLE_COUNT=$((BUNDLE_COUNT + 1))
done
[ "${BUNDLE_COUNT}" -gt 0 ] || error "No SPM resource bundles found in ${SPM_BUILD_DIR}"
echo "  Copied ${BUNDLE_COUNT} resource bundles to Contents/Resources/"

INFO_PLIST_SRC="${PROJECT_ROOT}/Resources/Info.plist"
[ -f "${INFO_PLIST_SRC}" ] || error "Resources/Info.plist not found at ${INFO_PLIST_SRC}"

cp "${INFO_PLIST_SRC}" "${APP_BUNDLE}/Contents/Info.plist"
sed -i '' "s|<string>[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*</string>|<string>${VERSION}</string>|g" "${APP_BUNDLE}/Contents/Info.plist"
echo "  Installed Info.plist (version ${VERSION})"

ICON_SRC="${PROJECT_ROOT}/Resources/AppIcon.icns"
[ -f "${ICON_SRC}" ] || error "Resources/AppIcon.icns not found at ${ICON_SRC}"
cp "${ICON_SRC}" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
echo "  Installed AppIcon.icns"

# ---------------------------------------------------------------------------
# Phase 6: Code signing
# ---------------------------------------------------------------------------
info "Signing .app bundle with Developer ID"

codesign --force --options runtime --sign "${SIGNING_IDENTITY}" --deep "${APP_BUNDLE}"
codesign --verify --deep --strict "${APP_BUNDLE}" || error "Code signature verification failed"
echo "  Signed with: ${SIGNING_IDENTITY}"

# ---------------------------------------------------------------------------
# Phase 7: Archive
# ---------------------------------------------------------------------------
info "Creating archive"

ARCHIVE_NAME="mkdn-${VERSION}.zip"
ARCHIVE_PATH="${BUILD_DIR}/${ARCHIVE_NAME}"

rm -f "${ARCHIVE_PATH}"
cd "${BUILD_DIR}"
ditto -c -k --keepParent "mkdn.app" "${ARCHIVE_NAME}"
cd "${PROJECT_ROOT}"

[ -f "${ARCHIVE_PATH}" ] || error "Archive creation failed -- ${ARCHIVE_PATH} not found"

echo "  Archive: ${ARCHIVE_PATH}"

# ---------------------------------------------------------------------------
# Phase 7.5: Notarization
# ---------------------------------------------------------------------------
info "Submitting for notarization (this may take a few minutes)"

xcrun notarytool submit "${ARCHIVE_PATH}" \
    --keychain-profile "${NOTARIZE_PROFILE}" \
    --wait || error "Notarization failed. Run 'xcrun notarytool log <submission-id> --keychain-profile ${NOTARIZE_PROFILE}' for details."

echo "  Notarization accepted"

info "Stapling notarization ticket"

xcrun stapler staple "${APP_BUNDLE}" || error "Staple failed"
echo "  Ticket stapled to mkdn.app"

# Re-create the archive with the stapled app
info "Re-archiving with stapled ticket"

rm -f "${ARCHIVE_PATH}"
cd "${BUILD_DIR}"
ditto -c -k --keepParent "mkdn.app" "${ARCHIVE_NAME}"
cd "${PROJECT_ROOT}"

[ -f "${ARCHIVE_PATH}" ] || error "Re-archive creation failed -- ${ARCHIVE_PATH} not found"

SHA256=$(shasum -a 256 "${ARCHIVE_PATH}" | awk '{print $1}')
echo "  Archive: ${ARCHIVE_PATH}"
echo "  SHA256: ${SHA256}"

# ---------------------------------------------------------------------------
# Phase 8: Generate changelog & publish GitHub Release
# ---------------------------------------------------------------------------
info "Preparing release notes"

PREV_TAG=$(git tag --sort=-version:refname | grep -A1 "^${TAG}$" | tail -1)

if [ -n "${NOTES_FILE_ARG}" ]; then
    NOTES_FILE="${NOTES_FILE_ARG}"
    NOTES_FILE_OWNED=false
    echo "  Using provided notes file: ${NOTES_FILE}"
    sed 's/^/    /' "${NOTES_FILE}"
else
    NOTES_FILE=$(mktemp)
    NOTES_FILE_OWNED=true
    trap "rm -f '${NOTES_FILE}'; rm -rf '${TAP_DIR:-}'; cleanup" EXIT

    if [ -z "${PREV_TAG}" ] || [ "${PREV_TAG}" = "${TAG}" ]; then
        COMMIT_LOG=$(git log --oneline "${TAG}")
    else
        COMMIT_LOG=$(git log --oneline "${PREV_TAG}..${TAG}")
    fi

    echo "  No --notes-file provided. Generate notes first:"
    echo ""
    echo "    ./scripts/generate-changelog.sh"
    echo "    ./scripts/release.sh --notes-file build/release-notes.md"
    echo ""
    echo "  Or to skip and use raw commit log, set SKIP_CHANGELOG=1"

    if [ "${SKIP_CHANGELOG:-}" = "1" ]; then
        echo "## What's Changed" > "${NOTES_FILE}"
        echo "" >> "${NOTES_FILE}"
        echo "${COMMIT_LOG}" | sed 's/^[a-f0-9]* /- /' >> "${NOTES_FILE}"
        echo "" >> "${NOTES_FILE}"
        echo "**Full Changelog**: https://github.com/Jud/mkdn/compare/${PREV_TAG:-v0.0.0}...${TAG}" >> "${NOTES_FILE}"
    else
        exit 1
    fi
fi

info "Publishing GitHub Release"

if gh release view "${TAG}" > /dev/null 2>&1; then
    echo "  Release ${TAG} already exists -- skipping creation (idempotent)"
else
    gh release create "${TAG}" "${ARCHIVE_PATH}" \
        --title "mkdn ${TAG}" \
        --notes-file "${NOTES_FILE}"
    echo "  Created release: ${TAG}"
fi

[ "${NOTES_FILE_OWNED}" = true ] && rm -f "${NOTES_FILE}"

# ---------------------------------------------------------------------------
# Phase 9: Update Homebrew tap
# ---------------------------------------------------------------------------
info "Updating Homebrew tap"

TAP_DIR=$(mktemp -d)
trap "rm -rf '${TAP_DIR}'; cleanup" EXIT

git clone --depth 1 "git@github.com:jud/homebrew-mkdn.git" "${TAP_DIR}"

CASK_FILE="${TAP_DIR}/Casks/mkdn.rb"
[ -f "${CASK_FILE}" ] || error "Cask file not found at ${CASK_FILE}"

sed -i '' "s/version \"[^\"]*\"/version \"${VERSION}\"/" "${CASK_FILE}"
sed -i '' "s/sha256 \"[^\"]*\"/sha256 \"${SHA256}\"/" "${CASK_FILE}"

grep -q "version \"${VERSION}\"" "${CASK_FILE}" || error "Failed to update version in Cask file"
grep -q "sha256 \"${SHA256}\"" "${CASK_FILE}" || error "Failed to update SHA256 in Cask file"

cd "${TAP_DIR}"
git add Casks/mkdn.rb
git commit -m "Update mkdn to ${VERSION}"
git push
cd "${PROJECT_ROOT}"

echo "  Tap updated: version ${VERSION}, sha256 ${SHA256}"

# ---------------------------------------------------------------------------
# Phase 10: Cleanup
# ---------------------------------------------------------------------------
rm -rf "${TAP_DIR}"

info "Release complete"
echo ""
echo "  Tag:     ${TAG}"
echo "  Version: ${VERSION}"
echo "  Archive: ${ARCHIVE_PATH}"
echo "  SHA256:  ${SHA256}"
echo ""
echo "  Verify with: ./scripts/smoke-test.sh"
