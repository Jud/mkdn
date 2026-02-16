# PRD: gh-releases

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-11

## Surface Overview

Automate the existing local release pipeline (`scripts/release.sh`) via GitHub Actions. A GitHub Actions workflow triggers on tag push (v*), builds the release binary in CI, assembles the .app bundle, publishes a GitHub Release with the archive, and updates the Homebrew tap (`jud/homebrew-mkdn`) with the new version and SHA256 -- all without manual intervention.

## Scope

### In Scope
- GitHub Actions workflow file (`.github/workflows/release.yml`)
- Trigger on tag push matching `v*`
- Version injection into `MkdnCLI.swift` during CI build
- Release build: `swift build -c release --arch arm64` on macOS runner
- .app bundle assembly (binary + resource bundle + Info.plist + AppIcon.icns)
- Ad-hoc code signing (`codesign --force --sign - --deep`)
- Zip archive creation via `ditto` with SHA256 computation
- GitHub Release creation via `gh release create` with auto-generated notes
- Homebrew tap update: clone `jud/homebrew-mkdn`, update version + SHA256 in `Casks/mkdn.rb`, commit and push
- Repository secrets/permissions configuration for tap push (PAT)

### Out of Scope
- Post-release smoke test (`scripts/smoke-test.sh`)
- Apple Developer ID signing or notarization (ad-hoc only for now)
- Universal binary (x86_64 + arm64) -- staying arm64-only
- macOS runner caching optimizations
- Automated changelog beyond `gh --generate-notes`
- Windows/Linux builds
- `workflow_dispatch` manual trigger (can be added later)

## Requirements

### Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Workflow triggers on tag push matching `v*` pattern | Must |
| FR-2 | Parse version from tag (strip `v` prefix), validate semver format, fail early if invalid | Must |
| FR-3 | Inject version string into `mkdn/Core/CLI/MkdnCLI.swift` via sed before build | Must |
| FR-4 | Build release binary with `swift build -c release --arch arm64` on macOS runner | Must |
| FR-5 | Assemble mkdn.app bundle: binary, SPM resource bundle (`mkdn_mkdnLib.bundle`), Info.plist (version-stamped), AppIcon.icns | Must |
| FR-6 | Ad-hoc code sign the .app bundle with `codesign --force --sign - --deep` | Must |
| FR-7 | Create `mkdn-{version}.zip` archive via `ditto -c -k --keepParent` and compute SHA256 | Must |
| FR-8 | Publish GitHub Release via `gh release create v{version}` with archive attached and `--generate-notes` | Must |
| FR-9 | Clone `jud/homebrew-mkdn`, update version and SHA256 in `Casks/mkdn.rb`, commit and push | Must |

### Non-Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-1 | Workflow completes end-to-end in under 15 minutes | Should |
| NFR-2 | Workflow is idempotent -- re-running on the same tag does not create duplicate releases | Must |
| NFR-3 | Secrets (PAT for tap repo) stored as GitHub repository secrets, never logged in workflow output | Must |
| NFR-4 | Workflow fails fast on build errors, signing errors, or release creation failures with clear error messages | Must |

## Dependencies & Constraints

### Dependencies
| Dependency | Purpose | Notes |
|------------|---------|-------|
| GitHub Actions macOS runner (`macos-14`+) | arm64 build environment with Xcode + Swift toolchain | Pre-installed on GHA macOS images |
| Xcode toolchain | Swift 6 compiler, `codesign`, `ditto` | Pre-installed on macos-14 runner |
| `gh` CLI | GitHub Release creation | Pre-installed on GHA runners |
| GitHub PAT (repo secret) | Write access to `jud/homebrew-mkdn` for tap updates | Must be created and stored as `HOMEBREW_TAP_TOKEN` secret |
| `scripts/bundle.sh` | .app bundle assembly logic (reused from local pipeline) | Already exists in repo |

### Constraints
| ID | Constraint | Impact |
|----|------------|--------|
| C-1 | macOS runners are ~10x more expensive than Linux runners | Keep workflow lean; no unnecessary steps |
| C-2 | arm64-only build | No x86_64 support; Intel Mac users cannot run the binary |
| C-3 | Ad-hoc code signing | Gatekeeper will warn on first launch for non-Homebrew installs |
| C-4 | Cross-repo push to `jud/homebrew-mkdn` | Requires PAT with `repo` scope stored as repository secret |
| C-5 | Tag-only trigger | No CI on regular pushes or PRs (separate concern) |

## Milestones & Timeline

| Phase | Description | Key Deliverables |
|-------|-------------|------------------|
| Phase 1: Author | Write `.github/workflows/release.yml` with all 9 FR steps | Workflow file committed and pushed |
| Phase 2: Dry Run | Validate workflow on macOS runner via test tag | Build, bundle, archive steps pass; release published to GitHub |
| Phase 3: End-to-End | Push a real `v*` tag, confirm full pipeline | GitHub Release published with archive, homebrew-mkdn tap updated |

No external deadlines. Ships when ready.

## Open Questions

| ID | Question | Impact | Status |
|----|----------|--------|--------|
| OQ-1 | Should the workflow reuse `scripts/release.sh` directly or inline the steps for better CI visibility? | Workflow maintainability vs. DRY with local script | Open |
| OQ-2 | What Xcode version should be pinned on the runner (if any)? | Build reproducibility | Open |
| OQ-3 | Should the PAT be a fine-grained token scoped to `jud/homebrew-mkdn` only? | Security best practice | Open |

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A-1 | `macos-14` GHA runners have arm64 architecture and Swift 6 toolchain | Would need a different runner or manual Xcode install step | Homebrew installable |
| A-2 | `gh` CLI on GHA runners can create releases using the default `GITHUB_TOKEN` | May need explicit token configuration | Homebrew installable |
| A-3 | Ad-hoc signed apps work without issues when installed via `brew install --cask` | Users may encounter Gatekeeper friction; notarization may be needed sooner | CLI-launchable |
| A-4 | PAT with `repo` scope is sufficient for pushing to `jud/homebrew-mkdn` | May need a deploy key or GitHub App token instead | Homebrew installable |
