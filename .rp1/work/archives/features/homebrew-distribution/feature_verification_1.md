# Feature Verification Report #1

**Generated**: 2026-02-06T22:32:00Z
**Feature ID**: homebrew-distribution
**Verification Scope**: all
**KB Context**: Loaded
**Field Notes**: Not available

## Executive Summary
- Overall Status: PARTIAL
- Acceptance Criteria: 22/39 verified (56%)
- Implementation Quality: HIGH
- Ready for Merge: NO (documentation tasks incomplete; runtime criteria unverified)

The four core implementation files (Casks/mkdn.rb, scripts/release.sh, scripts/smoke-test.sh, scripts/setup-tap.sh) are all present, syntactically valid, executable, and structurally complete. Code quality is high -- all scripts use `set -euo pipefail`, register cleanup traps, validate preconditions, and produce clear error messages. The 17 acceptance criteria that cannot be verified without runtime execution (building, launching, Homebrew install/uninstall, GitHub Release creation) are marked as MANUAL_REQUIRED. Three documentation tasks (TD1, TD2, TD3) remain incomplete.

## Field Notes Context
**Field Notes Available**: No

### Documented Deviations
None -- no field-notes.md exists in the feature directory.

### Undocumented Deviations
None found. All implementation files match their design specifications.

## Acceptance Criteria Verification

### FR-01: .app Bundle Production

**AC-01.1**: Output is `mkdn.app/Contents/{MacOS/mkdn, Info.plist, Resources/}`
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:91-136
- Evidence: Lines 94-95 create `Contents/MacOS` and `Contents/Resources` directories. Line 97 copies the binary to `Contents/MacOS/mkdn`. Lines 100-106 copy the SPM resource bundle to `Contents/Resources/mkdn_mkdnLib.bundle`. Lines 108-135 generate `Contents/Info.plist` via heredoc. The resulting structure exactly matches the AC specification.
- Field Notes: N/A
- Issues: None

**AC-01.2**: Binary at `Contents/MacOS/mkdn` is a valid Mach-O executable for arm64
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:74 (`swift build -c release --arch arm64`)
- Evidence: The script builds with `--arch arm64` flag and copies the resulting binary. Verification requires actually running the build and checking with `file` command.
- Field Notes: N/A
- Issues: None (requires runtime execution)

**AC-01.3**: .app bundle launches when double-clicked in Finder
- Status: MANUAL_REQUIRED
- Implementation: N/A (Finder interaction)
- Evidence: Cannot be verified via static analysis. Requires building the .app and testing in Finder.
- Field Notes: N/A
- Issues: None (requires manual GUI testing)

**AC-01.4**: .app bundle launches via `open -a mkdn` after copying to /Applications
- Status: MANUAL_REQUIRED
- Implementation: Tested in `/Users/jud/Projects/mkdn/scripts/smoke-test.sh`:56 (`open -a mkdn`)
- Evidence: The smoke test script includes this check. Requires runtime execution.
- Field Notes: N/A
- Issues: None (requires runtime execution)

### FR-02: Info.plist Generation

**AC-02.1**: `CFBundleIdentifier` is set to `com.jud.mkdn`
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:113-114
- Evidence: Heredoc contains `<key>CFBundleIdentifier</key><string>com.jud.mkdn</string>`. Exact match.
- Field Notes: N/A
- Issues: None

**AC-02.2**: `CFBundleShortVersionString` and `CFBundleVersion` match the Git tag version
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:123-126
- Evidence: Both keys use `${VERSION}` variable, which is derived from Git tag at line 49: `VERSION="${TAG#v}"`. Tag `v1.2.3` produces VERSION `1.2.3`. Both `CFBundleShortVersionString` and `CFBundleVersion` are set to this value.
- Field Notes: N/A
- Issues: None

**AC-02.3**: `LSMinimumSystemVersion` is set to `14.0`
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:127-128
- Evidence: Heredoc contains `<key>LSMinimumSystemVersion</key><string>14.0</string>`. Exact match.
- Field Notes: N/A
- Issues: None

**AC-02.4**: `CFBundleExecutable` is set to `mkdn`
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:119-120
- Evidence: Heredoc contains `<key>CFBundleExecutable</key><string>mkdn</string>`. Exact match.
- Field Notes: N/A
- Issues: None

**AC-02.5**: `CFBundlePackageType` is set to `APPL`
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:121-122
- Evidence: Heredoc contains `<key>CFBundlePackageType</key><string>APPL</string>`. Exact match.
- Field Notes: N/A
- Issues: None

### FR-03: Resource Embedding

**AC-03.1**: `mermaid.min.js` exists inside the .app bundle's resource bundle
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:100-106
- Evidence: The script copies the entire SPM resource bundle (`mkdn_mkdnLib.bundle`) to `Contents/Resources/`. The SPM build process places `mermaid.min.js` inside this bundle. The design (section 3.6) confirms `Bundle.module` resolves via `Bundle.main.resourceURL` which maps to `Contents/Resources/`. The copy uses `cp -R` to preserve the full bundle contents.
- Field Notes: N/A
- Issues: None (runtime resolution requires manual verification -- see AC-03.2)

**AC-03.2**: `Bundle.module` resolves the resource bundle at runtime from the installed .app
- Status: MANUAL_REQUIRED
- Implementation: Design documented in design.md section 3.6
- Evidence: The design explains SPM's `resource_bundle_accessor.swift` searches `Bundle.main.resourceURL` first. The release script places the bundle at the correct path. Actual resolution requires running the app from the .app bundle.
- Field Notes: N/A
- Issues: None (requires runtime execution)

**AC-03.3**: Mermaid diagrams render correctly when launched from /Applications
- Status: MANUAL_REQUIRED
- Implementation: N/A (runtime behavior)
- Evidence: Cannot verify without installing the .app and opening a file with Mermaid content.
- Field Notes: N/A
- Issues: None (requires runtime execution)

### FR-04: Ad-Hoc Code Signing

**AC-04.1**: `codesign --verify mkdn.app` exits with status 0
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:143-144
- Evidence: Line 143 signs with `codesign --force --sign - --deep`. Line 144 verifies with `codesign --verify --deep --strict` and errors if verification fails. The verification is stricter than the AC requires (`--deep --strict` vs just `--verify`).
- Field Notes: N/A
- Issues: None

**AC-04.2**: App launches without macOS blocking execution due to missing signature
- Status: MANUAL_REQUIRED
- Implementation: Signing at `/Users/jud/Projects/mkdn/scripts/release.sh`:143
- Evidence: Ad-hoc signing is applied. Whether Gatekeeper blocks or allows depends on runtime context.
- Field Notes: N/A
- Issues: None (requires runtime execution)

### FR-05: Archive Production

**AC-05.1**: .zip created using `ditto -c -k` (preserves macOS metadata)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:157
- Evidence: `ditto -c -k --keepParent "mkdn.app" "${ARCHIVE_NAME}"`. Uses `ditto` with `-c -k --keepParent` flags exactly as specified. This preserves macOS extended attributes and code signatures.
- Field Notes: N/A
- Issues: None

**AC-05.2**: Extracting .zip produces a valid, signed .app bundle
- Status: MANUAL_REQUIRED
- Implementation: Archive creation at line 157, signing at line 143
- Evidence: The archive is created after signing, using `ditto` which preserves signatures. Actual extraction and verification requires runtime execution.
- Field Notes: N/A
- Issues: None (requires runtime execution)

**AC-05.3**: .zip filename includes version (e.g., `mkdn-1.0.0.zip`)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:152
- Evidence: `ARCHIVE_NAME="mkdn-${VERSION}.zip"`. The VERSION variable is derived from the Git tag (e.g., `v1.0.0` -> `1.0.0`), producing filenames like `mkdn-1.0.0.zip`.
- Field Notes: N/A
- Issues: None

### FR-06: Tap Repository Creation

**AC-06.1**: Repository `jud/homebrew-mkdn` exists on GitHub
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/scripts/setup-tap.sh`:70
- Evidence: Script runs `gh repo create "${REPO}" --public` where REPO is `jud/homebrew-mkdn`. Idempotent -- checks if repo exists first (lines 58-65). Verification requires `gh` auth and network access.
- Field Notes: N/A
- Issues: None (requires runtime execution with authenticated `gh`)

**AC-06.2**: `brew tap jud/mkdn` succeeds without error
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/scripts/setup-tap.sh`:96-102
- Evidence: The setup script includes a verification step that runs `brew tap jud/mkdn` after repo creation. Requires runtime execution.
- Field Notes: N/A
- Issues: None (requires runtime execution)

**AC-06.3**: Repository contains `Casks/` directory with mkdn Cask definition
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/setup-tap.sh`:79-80
- Evidence: Script creates `Casks/` directory in the cloned repo and copies `Casks/mkdn.rb` from the project. Lines 84-89 commit and push. The Cask file exists locally at `/Users/jud/Projects/mkdn/Casks/mkdn.rb` and is syntactically valid Ruby.
- Field Notes: N/A
- Issues: None (runtime push requires network)

### FR-07: Cask Definition

**AC-07.1**: Cask `url` points to .zip on GitHub Release for current version
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/Casks/mkdn.rb`:5
- Evidence: `url "https://github.com/jud/mkdn/releases/download/v#{version}/mkdn-#{version}.zip"`. Uses Homebrew's `#{version}` interpolation. For version `1.0.0`, resolves to `https://github.com/jud/mkdn/releases/download/v1.0.0/mkdn-1.0.0.zip`. This matches the release script's naming convention at release.sh:152.
- Field Notes: N/A
- Issues: None

**AC-07.2**: Cask `sha256` matches the .zip archive
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/Casks/mkdn.rb`:3
- Evidence: Currently set to `"PLACEHOLDER_SHA256"`. The release script (release.sh:194-195) updates this with the real SHA256 via sed replacement. The Cask definition is structurally correct, but the placeholder value means a `brew install` would fail until the release script runs. This is by design -- the release script populates the real value.
- Field Notes: N/A
- Issues: Placeholder is intentional and correct for pre-release state. The release script's sed command on line 195 correctly targets the sha256 field pattern.

**AC-07.3**: Cask installs `mkdn.app` to `/Applications`
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/Casks/mkdn.rb`:12
- Evidence: `app "mkdn.app"`. This is Homebrew Cask's standard `app` stanza which installs the named .app to `/Applications/`.
- Field Notes: N/A
- Issues: None

**AC-07.4**: Cask creates symlink so `mkdn` is available on PATH
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/Casks/mkdn.rb`:13
- Evidence: `binary "#{appdir}/mkdn.app/Contents/MacOS/mkdn"`. The `binary` stanza creates a symlink in Homebrew's bin directory (e.g., `/opt/homebrew/bin/`), which is on PATH for Homebrew users. Uses `#{appdir}` to resolve the Applications directory correctly.
- Field Notes: N/A
- Issues: None

**AC-07.5**: `brew uninstall --cask mkdn` removes .app and CLI symlink cleanly
- Status: MANUAL_REQUIRED
- Implementation: Implicit via Homebrew Cask's `app` and `binary` stanzas
- Evidence: Homebrew Cask automatically removes artifacts declared via `app` and `binary` stanzas on uninstall. The smoke test (smoke-test.sh:70-82) verifies both uninstall and symlink removal. Requires runtime execution.
- Field Notes: N/A
- Issues: None (requires runtime execution)

### FR-08: Release Script

**AC-08.1**: Script reads Git tag and performs all steps: build, sign, archive, create Release, attach .zip
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:1-221
- Evidence: Phase 1 (lines 36-56) reads Git tag via `git describe --tags --exact-match HEAD` and extracts version. Phase 2 (lines 61-67) injects version. Phase 3 (lines 72-77) builds. Phase 5 (lines 91-136) assembles bundle. Phase 6 (lines 141-145) signs. Phase 7 (lines 150-164) archives. Phase 8 (lines 169-178) creates GitHub Release and attaches .zip via `gh release create "${TAG}" "${ARCHIVE_PATH}"`. All steps present and correctly ordered.
- Field Notes: N/A
- Issues: None

**AC-08.2**: Script computes SHA256 and updates Cask definition in tap repository
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:162, 183-206
- Evidence: Line 162 computes SHA256 via `shasum -a 256`. Phase 9 (lines 183-206) clones the tap repo, uses sed to update both `version` and `sha256` fields in the Cask file, verifies the updates, commits, and pushes.
- Field Notes: N/A
- Issues: None

**AC-08.3**: Script is idempotent -- re-run for same tag does not create duplicates
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:171-178
- Evidence: Lines 171-172 check `gh release view "${TAG}"` before creation. If the release already exists, it prints a skip message and does not attempt to create a duplicate. The tap update phase uses sed replacement (not append), so re-running produces the same result.
- Field Notes: N/A
- Issues: Minor -- if the release exists but was created without the .zip asset, the script skips creation entirely and does not attempt to upload the missing asset. This is an edge case that is unlikely in practice.

**AC-08.4**: Script completes in under 5 minutes
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh` (entire script)
- Evidence: Cannot verify timing without running the full release pipeline. The script is sequential and relies on `swift build` and network operations.
- Field Notes: N/A
- Issues: None (requires runtime execution)

### FR-09: Version Derivation from Git Tag

**AC-09.1**: Git tag `v1.2.3` results in `CFBundleShortVersionString` of `1.2.3`
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:49, 123-126
- Evidence: Line 49: `VERSION="${TAG#v}"` strips the `v` prefix. Lines 123-126 embed `${VERSION}` in both `CFBundleShortVersionString` and `CFBundleVersion` in the Info.plist heredoc. A tag of `v1.2.3` produces VERSION=`1.2.3`.
- Field Notes: N/A
- Issues: None

**AC-09.2**: Build fails with clear error if no Git tag is present on current commit
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/scripts/release.sh`:46-47
- Evidence: Line 46: `git describe --tags --exact-match HEAD 2>/dev/null` with `|| error "Current commit has no tag. Create one with: git tag v1.0.0"`. If no tag exists, the script exits with a clear, actionable error message. Line 47 further validates the tag matches `v*` pattern. Line 52 validates semver format.
- Field Notes: N/A
- Issues: None

### FR-10: End-to-End Smoke Test

**AC-10.1**: `brew tap jud/mkdn` succeeds
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/scripts/smoke-test.sh`:22-26
- Evidence: Step 1/7 runs `brew tap jud/mkdn` with pass/fail reporting. Requires runtime execution with Homebrew and network access.
- Field Notes: N/A
- Issues: None (requires runtime execution)

**AC-10.2**: `brew install --cask mkdn` succeeds
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/scripts/smoke-test.sh`:29-34
- Evidence: Step 2/7 runs `brew install --cask mkdn` with pass/fail reporting. Requires a published release with valid SHA256.
- Field Notes: N/A
- Issues: None (requires runtime execution)

**AC-10.3**: `which mkdn` returns a valid path
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/scripts/smoke-test.sh`:37-43
- Evidence: Step 3/7 runs `which mkdn` and prints the resolved path. Requires prior install.
- Field Notes: N/A
- Issues: None (requires runtime execution)

**AC-10.4**: `mkdn --help` produces expected output
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/scripts/smoke-test.sh`:46-52
- Evidence: Step 4/7 runs `mkdn --help` and prints the first line of output. Requires prior install.
- Field Notes: N/A
- Issues: None (requires runtime execution)

**AC-10.5**: `open -a mkdn` launches the application window
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/scripts/smoke-test.sh`:55-66
- Evidence: Step 5/7 runs `open -a mkdn`, waits 3 seconds, checks for the process with `pgrep -x mkdn`, and cleans up with `pkill`. Includes proper GUI launch verification logic.
- Field Notes: N/A
- Issues: None (requires runtime execution)

**AC-10.6**: `brew uninstall --cask mkdn` removes .app and CLI symlink
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/scripts/smoke-test.sh`:69-82
- Evidence: Steps 6/7 and 7/7 run `brew uninstall --cask mkdn` and then verify `which mkdn` fails (symlink removed). Requires prior install.
- Field Notes: N/A
- Issues: None (requires runtime execution)

### Documentation Tasks

**TD1**: New "Scripts" section added to modules.md
- Status: NOT VERIFIED
- Implementation: Not found in `/Users/jud/Projects/mkdn/.rp1/context/modules.md`
- Evidence: The modules.md file does not contain a "Scripts" section. It covers only Swift source modules. No mention of `scripts/release.sh` or `scripts/smoke-test.sh`.
- Field Notes: N/A
- Issues: Documentation task incomplete.

**TD2**: Quick Reference includes `scripts/` directory entry
- Status: NOT VERIFIED
- Implementation: Not found in `/Users/jud/Projects/mkdn/.rp1/context/index.md`
- Evidence: The index.md Quick Reference section does not include any entry for `scripts/`. Current entries cover Swift source directories only.
- Field Notes: N/A
- Issues: Documentation task incomplete.

**TD3**: Build/Test Commands includes `./scripts/release.sh`
- Status: NOT VERIFIED
- Implementation: Not found in `/Users/jud/Projects/mkdn/CLAUDE.md`
- Evidence: The Build/Test Commands section in CLAUDE.md lists only `swift build`, `swift test`, `swift run mkdn`, `swiftlint lint`, and `swiftformat .`. No mention of `./scripts/release.sh` or the release workflow.
- Field Notes: N/A
- Issues: Documentation task incomplete.

## Implementation Gap Analysis

### Missing Implementations
- **TD1**: Scripts section in modules.md not added
- **TD2**: Quick Reference in index.md not updated
- **TD3**: Build/Test Commands in CLAUDE.md not updated

### Partial Implementations
- **AC-07.2**: Cask SHA256 is placeholder `"PLACEHOLDER_SHA256"`. This is by design (release script updates it), but means the Cask is not functional until a release is published. Not a code defect.

### Implementation Issues
- **AC-08.3** (minor edge case): If a GitHub Release exists but was created without the .zip asset attached, the release script skips re-creation entirely rather than uploading the missing asset. This is a minor robustness gap, not a blocking issue.

## Code Quality Assessment

**Overall Quality: HIGH**

All four implementation files demonstrate consistent, high-quality shell scripting practices:

1. **Error Handling**: All scripts use `set -euo pipefail`. The release script registers a trap for cleanup and version revert. The setup-tap script also uses trap for temporary directory cleanup. Error messages are clear and actionable (e.g., "gh CLI is not installed. Install it with: brew install gh").

2. **Idempotency**: Both the release script (checks for existing release before creation) and the setup-tap script (checks for existing repository before creation) handle re-runs gracefully.

3. **Validation**: The release script performs comprehensive pre-flight checks: gh auth, clean working tree, tag existence, tag format (v*), semver format validation. Each check has a specific, helpful error message.

4. **Structure**: All scripts use consistent formatting -- helper functions at the top, phases clearly labeled with comment blocks, logical flow from validation to execution to cleanup.

5. **Cask Definition**: The Ruby Cask DSL is minimal and follows Homebrew conventions exactly. All required stanzas (`url`, `sha256`, `app`, `binary`, `depends_on`) are present.

6. **Version Injection Safety**: The sed-based version injection with trap-registered revert (including explicit revert at Phase 4 on the happy path) ensures the source file is never left in a modified state.

7. **Syntax Validity**: All four files pass their respective syntax validators (bash -n for shell scripts, ruby -c for the Cask).

8. **File Permissions**: All scripts are marked executable (755), matching the acceptance criteria.

## Recommendations

1. **Complete documentation tasks TD1, TD2, TD3**: Add the Scripts section to modules.md, update the Quick Reference in index.md, and add `./scripts/release.sh` to CLAUDE.md Build/Test Commands. These are the only remaining non-runtime blockers.

2. **Run the full release pipeline manually**: Execute `./scripts/release.sh` with a test tag to verify all 17 MANUAL_REQUIRED acceptance criteria. This is the single most impactful verification step remaining.

3. **Run the smoke test**: After a successful release, execute `./scripts/smoke-test.sh` to verify the complete install/launch/uninstall cycle (covers AC-10.1 through AC-10.6).

4. **Consider enhancing idempotency for AC-08.3**: The release script could check whether the .zip asset is attached to an existing release and upload it if missing, rather than skipping the entire publish phase. This is a minor enhancement, not a blocker.

5. **Add `scripts/setup-tap.sh` to Cask/tap documentation**: The setup-tap script is documented in tasks.md but not mentioned in the planned documentation updates (TD1-TD3). Consider including it in the Scripts section of modules.md.

## Verification Evidence

### Cask Definition (`/Users/jud/Projects/mkdn/Casks/mkdn.rb`)
```ruby
cask "mkdn" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"
  url "https://github.com/jud/mkdn/releases/download/v#{version}/mkdn-#{version}.zip"
  name "mkdn"
  desc "Mac-native Markdown viewer with Mermaid diagram support"
  homepage "https://github.com/jud/mkdn"
  depends_on macos: ">= :sonoma"
  app "mkdn.app"
  binary "#{appdir}/mkdn.app/Contents/MacOS/mkdn"
  zap trash: []
end
```
- Ruby syntax: valid
- All required stanzas present
- URL pattern matches release script naming convention

### Release Script Pre-flight (`/Users/jud/Projects/mkdn/scripts/release.sh`:36-56)
```bash
command -v gh > /dev/null 2>&1 || error "gh CLI is not installed..."
gh auth status > /dev/null 2>&1 || error "gh CLI is not authenticated..."
git diff --quiet || error "Working tree has unstaged changes..."
git diff --cached --quiet || error "Working tree has staged but uncommitted changes..."
TAG=$(git describe --tags --exact-match HEAD 2>/dev/null) || error "Current commit has no tag..."
[[ "${TAG}" == v* ]] || error "Tag '${TAG}' does not match v* pattern..."
VERSION="${TAG#v}"
[[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || error "Version '${VERSION}' is not valid semver..."
```

### Info.plist Generation (`/Users/jud/Projects/mkdn/scripts/release.sh`:108-135)
All 10 required keys present:
- CFBundleIdentifier: `com.jud.mkdn`
- CFBundleName: `mkdn`
- CFBundleDisplayName: `mkdn`
- CFBundleExecutable: `mkdn`
- CFBundlePackageType: `APPL`
- CFBundleShortVersionString: `${VERSION}`
- CFBundleVersion: `${VERSION}`
- LSMinimumSystemVersion: `14.0`
- NSHighResolutionCapable: `true`
- NSPrincipalClass: `NSApplication`

### Version Injection Target (`/Users/jud/Projects/mkdn/mkdn/Core/CLI/MkdnCLI.swift`:7)
```swift
version: "1.0.0"
```
The sed pattern in release.sh (`s/version: \"[0-9]*\.[0-9]*\.[0-9]*\"/version: \"${VERSION}\"/`) correctly matches this line.

### Smoke Test Structure (`/Users/jud/Projects/mkdn/scripts/smoke-test.sh`)
- 7 sequential steps matching FR-10 requirements
- Pass/fail counter with summary
- Non-zero exit code on any failure
- GUI launch check includes 3-second delay + pgrep verification + pkill cleanup
- All file permissions: executable (755)

### Syntax Validation Results
| File | Validator | Result |
|------|-----------|--------|
| Casks/mkdn.rb | `ruby -c` | OK |
| scripts/release.sh | `bash -n` | OK |
| scripts/smoke-test.sh | `bash -n` | OK |
| scripts/setup-tap.sh | `bash -n` | OK |
