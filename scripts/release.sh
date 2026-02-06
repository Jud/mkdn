#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BUILD_DIR="${PROJECT_ROOT}/build"
APP_BUNDLE="${BUILD_DIR}/mkdn.app"
CLI_SWIFT="${PROJECT_ROOT}/mkdn/Core/CLI/MkdnCLI.swift"
SPM_BUILD_DIR="${PROJECT_ROOT}/.build/arm64-apple-macosx/release"

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

RESOURCE_BUNDLE="${SPM_BUILD_DIR}/mkdn_mkdnLib.bundle"
if [ -d "${RESOURCE_BUNDLE}" ]; then
    cp -R "${RESOURCE_BUNDLE}" "${APP_BUNDLE}/Contents/Resources/mkdn_mkdnLib.bundle"
    echo "  Copied resource bundle to Contents/Resources/mkdn_mkdnLib.bundle"
else
    error "SPM resource bundle not found at ${RESOURCE_BUNDLE}"
fi

cat > "${APP_BUNDLE}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.jud.mkdn</string>
    <key>CFBundleName</key>
    <string>mkdn</string>
    <key>CFBundleDisplayName</key>
    <string>mkdn</string>
    <key>CFBundleExecutable</key>
    <string>mkdn</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST
echo "  Generated Info.plist (version ${VERSION})"

# ---------------------------------------------------------------------------
# Phase 6: Code signing
# ---------------------------------------------------------------------------
info "Signing .app bundle (ad-hoc)"

codesign --force --sign - --deep "${APP_BUNDLE}"
codesign --verify --deep --strict "${APP_BUNDLE}" || error "Code signature verification failed"
echo "  Signature verified"

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

SHA256=$(shasum -a 256 "${ARCHIVE_PATH}" | awk '{print $1}')
echo "  Archive: ${ARCHIVE_PATH}"
echo "  SHA256: ${SHA256}"

# ---------------------------------------------------------------------------
# Phase 8: Publish GitHub Release
# ---------------------------------------------------------------------------
info "Publishing GitHub Release"

if gh release view "${TAG}" > /dev/null 2>&1; then
    echo "  Release ${TAG} already exists -- skipping creation (idempotent)"
else
    gh release create "${TAG}" "${ARCHIVE_PATH}" \
        --title "mkdn ${TAG}" \
        --generate-notes
    echo "  Created release: ${TAG}"
fi

# ---------------------------------------------------------------------------
# Phase 9: Update Homebrew tap
# ---------------------------------------------------------------------------
info "Updating Homebrew tap"

TAP_DIR=$(mktemp -d)
trap "rm -rf '${TAP_DIR}'; cleanup" EXIT

git clone --depth 1 "https://github.com/jud/homebrew-mkdn.git" "${TAP_DIR}" 2>/dev/null \
    || git clone --depth 1 "git@github.com:jud/homebrew-mkdn.git" "${TAP_DIR}"

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
