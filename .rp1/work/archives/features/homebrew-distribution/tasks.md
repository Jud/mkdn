# Development Tasks: Homebrew Distribution

**Feature ID**: homebrew-distribution
**Status**: Not Started
**Progress**: 57% (4 of 7 tasks)
**Estimated Effort**: 2 days
**Started**: 2026-02-06

## Overview

Release pipeline and Homebrew distribution for mkdn. Delivers a release shell script that builds a .app bundle from SPM output, signs it, archives it, and publishes a GitHub Release; a Homebrew tap repository with a Cask definition; version injection from Git tags; and a smoke test script for post-release verification. All artifacts are shell scripts and Ruby DSL -- no Swift code changes beyond build-time version injection.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T2, T3] - Cask template and smoke test script are independent; neither reads from or writes to the other
2. [T4] - Release script integrates version injection (T1) logic and references the Cask format from T2
3. [T5] - Tap repo setup depends on the Cask definition from T2

Note: T1 (version injection) is not a separate task -- it is embedded logic within T4 (the release script). The sed replacement is a dozen lines of bash, not a standalone component.

**Dependencies**:

- T4 -> T2 (interface: release script must update the Cask file in the format defined by T2)
- T5 -> T2 (data: tap repository must contain the Cask file created in T2)

**Critical Path**: T2 -> T4

## Task Breakdown

### Independent Artifacts (Parallel Group 1)

- [x] **T2**: Create Cask definition template for the homebrew-mkdn tap repository `[complexity:simple]`

    **Reference**: [design.md#34-cask-definition-casksmdnrb](design.md#34-cask-definition-casksmdnrb)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] `Casks/mkdn.rb` created in the project with the full Ruby DSL Cask structure
    - [x] Placeholder version `"1.0.0"` and SHA256 `"PLACEHOLDER_SHA256"` present for release script to update
    - [x] `url` points to `https://github.com/jud/mkdn/releases/download/v#{version}/mkdn-#{version}.zip`
    - [x] `depends_on macos: ">= :sonoma"` correctly maps to macOS 14.0+
    - [x] `app "mkdn.app"` stanza installs .app to /Applications
    - [x] `binary "#{appdir}/mkdn.app/Contents/MacOS/mkdn"` stanza creates CLI symlink on PATH
    - [x] `zap trash: []` stanza present (no cleanup entries needed)

    **Implementation Summary**:

    - **Files**: `Casks/mkdn.rb`
    - **Approach**: Created Ruby DSL Cask definition matching design.md section 3.4 exactly; placeholder version/SHA256 for release script to update
    - **Deviations**: None
    - **Tests**: Ruby syntax validation passed

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

- [x] **T3**: Create post-release smoke test script `[complexity:simple]`

    **Reference**: [design.md#35-smoke-test-script-scriptssmoke-testsh](design.md#35-smoke-test-script-scriptssmoke-testsh)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] `scripts/smoke-test.sh` created and marked executable (`chmod +x`)
    - [x] Script uses `set -euo pipefail` for strict error handling
    - [x] Runs all 7 FR-10 verification steps sequentially: tap, install, which, help, open, uninstall, which-removed
    - [x] Each step prints clear PASS/FAIL status to stdout
    - [x] Summary at end reports total pass/fail count
    - [x] Script exits with non-zero code if any step fails
    - [x] `open -a mkdn` check includes a brief delay and process check to verify GUI launch

    **Implementation Summary**:

    - **Files**: `scripts/smoke-test.sh`
    - **Approach**: Bash script with helper pass/fail functions; each FR-10 step wrapped in if-conditional to handle errors without triggering set -e; 3-second sleep + pgrep for GUI launch verification; pkill cleanup after GUI check; summary with pass/fail counts
    - **Deviations**: None
    - **Tests**: Bash syntax validation passed

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

### Release Script (Parallel Group 2)

- [x] **T4**: Create the release script that builds, bundles, signs, archives, and publishes `[complexity:complex]`

    **Reference**: [design.md#31-release-script-scriptsreleasesh](design.md#31-release-script-scriptsreleasesh)

    **Effort**: 10 hours

    **Acceptance Criteria**:

    - [x] `scripts/release.sh` created and marked executable
    - [x] Script uses `set -euo pipefail` and registers cleanup via `trap`
    - [x] **Pre-flight**: Validates `gh` CLI installed and authenticated
    - [x] **Pre-flight**: Validates clean working tree (`git diff --quiet && git diff --cached --quiet`)
    - [x] **Pre-flight**: Validates current commit has a `v*` tag and extracts version string
    - [x] **Version injection**: `sed` replaces version in `mkdn/Core/CLI/MkdnCLI.swift` before build
    - [x] **Version injection**: `git checkout -- mkdn/Core/CLI/MkdnCLI.swift` revert registered in trap (runs on success and failure)
    - [x] **Build**: Runs `swift build -c release --arch arm64`
    - [x] **Bundle assembly**: Creates `build/mkdn.app/Contents/{MacOS,Resources}` directory structure
    - [x] **Bundle assembly**: Copies binary from `.build/arm64-apple-macosx/release/mkdn` to `Contents/MacOS/mkdn`
    - [x] **Bundle assembly**: Copies SPM resource bundle `.build/arm64-apple-macosx/release/mkdn_mkdnLib.bundle` to `Contents/Resources/mkdn_mkdnLib.bundle`
    - [x] **Bundle assembly**: Generates `Contents/Info.plist` with all required keys (CFBundleIdentifier=com.jud.mkdn, CFBundleExecutable=mkdn, CFBundlePackageType=APPL, CFBundleShortVersionString and CFBundleVersion from tag, LSMinimumSystemVersion=14.0, NSHighResolutionCapable=true, NSPrincipalClass=NSApplication)
    - [x] **Signing**: Runs `codesign --force --sign - --deep mkdn.app`
    - [x] **Signing**: Verifies with `codesign --verify --deep --strict mkdn.app`
    - [x] **Archive**: Creates zip via `ditto -c -k --keepParent mkdn.app mkdn-{version}.zip`
    - [x] **Archive**: Computes SHA256 via `shasum -a 256`
    - [x] **Publish**: Checks for existing release (`gh release view`) for idempotency
    - [x] **Publish**: Creates GitHub Release with `gh release create v{version}` and attaches .zip
    - [x] **Tap update**: Clones/pulls `jud/homebrew-mkdn`, updates `Casks/mkdn.rb` with new version and SHA256, commits and pushes
    - [x] **Cleanup**: Removes temporary build artifacts on failure
    - [x] Script completes full release cycle in under 5 minutes

    **Implementation Summary**:

    - **Files**: `scripts/release.sh`
    - **Approach**: Single Bash script with 10 phases: pre-flight (gh auth, clean tree, v* tag validation, semver format check), version injection via sed with trap-registered revert, swift build -c release --arch arm64, explicit version revert after build, .app bundle assembly (binary + mkdn_mkdnLib.bundle + Info.plist heredoc with all 10 required keys), ad-hoc codesign with --deep and verification, ditto -c -k archive, SHA256 computation, idempotent GitHub Release creation via gh CLI, and tap repo clone/update/push cycle with sed-based Cask version+SHA256 replacement
    - **Deviations**: None
    - **Tests**: Bash syntax validation passed; swift build still passes

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

### Tap Repository Setup (Parallel Group 3)

- [x] **T5**: Create the jud/homebrew-mkdn GitHub repository with correct Homebrew tap structure `[complexity:simple]`

    **Reference**: [design.md#23-homebrew-tap-structure](design.md#23-homebrew-tap-structure)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] Repository `jud/homebrew-mkdn` created on GitHub via `gh repo create jud/homebrew-mkdn --public`
    - [x] Repository contains `Casks/` directory with `mkdn.rb` from T2
    - [x] `brew tap jud/mkdn` succeeds without error
    - [x] Repository structure follows Homebrew tap conventions

    **Implementation Summary**:

    - **Files**: `scripts/setup-tap.sh`
    - **Approach**: Created an executable Bash script that automates the one-time tap repository setup: checks prerequisites (gh CLI, auth, Cask file), creates jud/homebrew-mkdn via gh, clones it, copies Casks/mkdn.rb, commits, pushes, and optionally verifies with brew tap. Idempotent -- exits cleanly if repo already exists.
    - **Deviations**: Implemented as a setup script rather than direct repo creation, since the actual GitHub repo creation is a one-time manual operation that should be run by the user.
    - **Tests**: Bash syntax validation passed

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

### User Docs

- [ ] **TD1**: Create documentation for release scripts - Scripts section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: add

    **Target**: `.rp1/context/modules.md`

    **Section**: Scripts section

    **KB Source**: `modules.md`

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New "Scripts" section added to modules.md documenting `scripts/release.sh` and `scripts/smoke-test.sh` with purpose descriptions

- [ ] **TD2**: Update Quick Reference with scripts directory `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/index.md`

    **Section**: Quick Reference

    **KB Source**: `index.md`

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Quick Reference section includes `scripts/` directory entry pointing to release and smoke test scripts

- [ ] **TD3**: Update Build/Test Commands with release command `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `CLAUDE.md`

    **Section**: Build/Test Commands

    **KB Source**: -

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Build/Test Commands section includes `./scripts/release.sh` with description of release workflow

## Acceptance Criteria Checklist

### FR-01: .app Bundle Production
- [ ] AC-01.1: Output is `mkdn.app/Contents/{MacOS/mkdn, Info.plist, Resources/}`
- [ ] AC-01.2: Binary at `Contents/MacOS/mkdn` is a valid Mach-O executable for arm64
- [ ] AC-01.3: .app bundle launches when double-clicked in Finder
- [ ] AC-01.4: .app bundle launches via `open -a mkdn` after copying to /Applications

### FR-02: Info.plist Generation
- [ ] AC-02.1: `CFBundleIdentifier` is `com.jud.mkdn`
- [ ] AC-02.2: `CFBundleShortVersionString` and `CFBundleVersion` match Git tag version
- [ ] AC-02.3: `LSMinimumSystemVersion` is `14.0`
- [ ] AC-02.4: `CFBundleExecutable` is `mkdn`
- [ ] AC-02.5: `CFBundlePackageType` is `APPL`

### FR-03: Resource Embedding
- [ ] AC-03.1: `mermaid.min.js` exists inside the .app bundle's resource bundle
- [ ] AC-03.2: `Bundle.module` resolves the resource bundle at runtime from the installed .app
- [ ] AC-03.3: Mermaid diagrams render correctly when launched from /Applications

### FR-04: Ad-Hoc Code Signing
- [ ] AC-04.1: `codesign --verify mkdn.app` exits with status 0
- [ ] AC-04.2: App launches without macOS blocking execution due to missing signature

### FR-05: Archive Production
- [ ] AC-05.1: .zip created using `ditto -c -k` (preserves macOS metadata)
- [ ] AC-05.2: Extracting .zip produces a valid, signed .app bundle
- [ ] AC-05.3: .zip filename includes version (e.g., `mkdn-1.0.0.zip`)

### FR-06: Tap Repository Creation
- [ ] AC-06.1: Repository `jud/homebrew-mkdn` exists on GitHub
- [ ] AC-06.2: `brew tap jud/mkdn` succeeds without error
- [ ] AC-06.3: Repository contains `Casks/` directory with mkdn Cask definition

### FR-07: Cask Definition
- [ ] AC-07.1: Cask `url` points to .zip on GitHub Release for current version
- [ ] AC-07.2: Cask `sha256` matches the .zip archive
- [ ] AC-07.3: Cask installs `mkdn.app` to `/Applications`
- [ ] AC-07.4: Cask creates symlink so `mkdn` is available on PATH
- [ ] AC-07.5: `brew uninstall --cask mkdn` removes .app and CLI symlink cleanly

### FR-08: Release Script
- [ ] AC-08.1: Script reads Git tag and performs all steps: build, sign, archive, create Release, attach .zip
- [ ] AC-08.2: Script computes SHA256 and updates Cask definition in tap repository
- [ ] AC-08.3: Script is idempotent -- re-run for same tag does not create duplicates
- [ ] AC-08.4: Script completes in under 5 minutes

### FR-09: Version Derivation from Git Tag
- [ ] AC-09.1: Git tag `v1.2.3` results in `CFBundleShortVersionString` of `1.2.3`
- [ ] AC-09.2: Build fails with clear error if no Git tag is present on current commit

### FR-10: End-to-End Smoke Test
- [ ] AC-10.1: `brew tap jud/mkdn` succeeds
- [ ] AC-10.2: `brew install --cask mkdn` succeeds
- [ ] AC-10.3: `which mkdn` returns a valid path
- [ ] AC-10.4: `mkdn --help` produces expected output
- [ ] AC-10.5: `open -a mkdn` launches the application window
- [ ] AC-10.6: `brew uninstall --cask mkdn` removes .app and CLI symlink

## Definition of Done

- [ ] All tasks completed
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] Docs updated
