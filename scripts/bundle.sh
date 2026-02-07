#!/usr/bin/env bash
set -euo pipefail

# Assemble mkdn.app bundle from SPM release build output.
# Usage: scripts/bundle.sh
# Requires: swift build -c release to have been run first (or pass --build to build automatically).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="mkdn"
SPM_BUILD_DIR="${PROJECT_ROOT}/.build/arm64-apple-macosx/release"
BUILD_DIR="${PROJECT_ROOT}/build"
BUNDLE_DIR="${BUILD_DIR}/${APP_NAME}.app/Contents"

BUILD_FIRST=false
for arg in "$@"; do
    case "${arg}" in
        --build) BUILD_FIRST=true ;;
        *) echo "Unknown option: ${arg}" >&2; exit 1 ;;
    esac
done

if [ "${BUILD_FIRST}" = true ]; then
    echo "==> Building release binary (arm64)"
    swift build -c release --arch arm64
fi

if [ ! -f "${SPM_BUILD_DIR}/${APP_NAME}" ]; then
    echo "ERROR: Binary not found at ${SPM_BUILD_DIR}/${APP_NAME}" >&2
    echo "Run 'swift build -c release --arch arm64' first, or pass --build." >&2
    exit 1
fi

echo "==> Assembling ${APP_NAME}.app bundle"

rm -rf "${BUILD_DIR}/${APP_NAME}.app"
mkdir -p "${BUNDLE_DIR}/MacOS"
mkdir -p "${BUNDLE_DIR}/Resources"

cp "${SPM_BUILD_DIR}/${APP_NAME}" "${BUNDLE_DIR}/MacOS/"
echo "  Copied binary to Contents/MacOS/${APP_NAME}"

RESOURCE_BUNDLE="${SPM_BUILD_DIR}/mkdn_mkdnLib.bundle"
if [ -d "${RESOURCE_BUNDLE}" ]; then
    cp -R "${RESOURCE_BUNDLE}" "${BUNDLE_DIR}/Resources/mkdn_mkdnLib.bundle"
    echo "  Copied resource bundle to Contents/Resources/mkdn_mkdnLib.bundle"
fi

INFO_PLIST_SRC="${PROJECT_ROOT}/Resources/Info.plist"
if [ ! -f "${INFO_PLIST_SRC}" ]; then
    echo "ERROR: Resources/Info.plist not found at ${INFO_PLIST_SRC}" >&2
    exit 1
fi

cp "${INFO_PLIST_SRC}" "${BUNDLE_DIR}/Info.plist"
echo "  Installed Info.plist"

echo "==> Built ${BUILD_DIR}/${APP_NAME}.app"
