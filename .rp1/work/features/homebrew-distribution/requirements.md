# Requirements Specification: Homebrew Distribution

**Feature ID**: homebrew-distribution
**Parent PRD**: [Homebrew Distribution](../../prds/homebrew-distribution.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-06

## 1. Feature Overview

Homebrew Distribution enables mkdn to be installed on macOS via `brew install --cask mkdn` from a personal Homebrew tap. This encompasses building a proper macOS .app bundle from the SPM project, publishing versioned releases to GitHub with attached archives, maintaining a Homebrew Cask definition in a tap repository, and ensuring the CLI symlink (`mkdn` on PATH) works correctly after installation. The goal is zero-friction installation for terminal-centric developers -- the target users identified in the project charter.

## 2. Business Context

### 2.1 Problem Statement

mkdn is currently only usable by cloning the repository and building from source. This creates unacceptable friction for daily-driver use -- the project's primary success criterion. Terminal-centric developers expect to install tools via Homebrew with a single command. Without a distribution mechanism, mkdn cannot fulfill the charter's "Homebrew installable" commitment or reach its goal of being the creator's default Markdown viewer.

### 2.2 Business Value

- Removes installation friction, enabling daily-driver adoption (the project's success criterion).
- Establishes a repeatable release process so that improvements to mkdn can be shipped and consumed quickly.
- Completes the last item on the charter's "Will Do" list, bringing the project to its initial feature-complete state.
- Provides the foundation for future wider distribution (homebrew-cask official, notarization) if desired.

### 2.3 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Install success rate | 100% on the creator's machine | `brew install --cask mkdn` completes without error |
| CLI availability after install | `mkdn` resolves on PATH | `which mkdn` returns a valid path; `mkdn --help` produces output |
| App launch after install | App opens a window | `open -a mkdn` launches the application |
| Release cycle time | Under 5 minutes from tagged commit to published release | Time from `git tag` to GitHub Release with attached .zip |
| Clean uninstall | No residual files | `brew uninstall --cask mkdn` removes .app and symlink |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Developer (installer) | Terminal-centric macOS developer who installs mkdn via Homebrew | Primary consumer of the distribution mechanism |
| Developer (maintainer) | The mkdn project maintainer who publishes releases | Primary operator of the release process |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project maintainer | Single-command release process; minimal ongoing maintenance burden for tap repository |
| End-user developer | Fast, reliable `brew install`; CLI and GUI both work after install; clean uninstall |

## 4. Scope Definition

### 4.1 In Scope

- Building a valid macOS .app bundle from the SPM project output
- Info.plist generation with correct bundle identifier, version, and minimum macOS version
- Embedding `mermaid.min.js` inside the .app bundle so `Bundle.main` resource resolution works
- Ad-hoc code signing of the .app bundle
- Archiving the .app bundle as a .zip file
- Creating a `homebrew-mkdn` tap repository on GitHub
- Writing a Homebrew Cask definition that installs the .app and creates a CLI symlink
- A release script that builds, archives, tags, publishes a GitHub Release, and updates the Cask definition
- End-to-end verification that the full install/launch/uninstall cycle works
- Version derivation from Git tags with embedding into Info.plist

### 4.2 Out of Scope

- Publishing to homebrew-core or the official homebrew-cask repository
- Apple Developer ID code signing and notarization
- Auto-update mechanisms (Sparkle or similar)
- DMG packaging with custom installer UI
- Universal binary (x86_64 + arm64) -- arm64-only is sufficient
- CI/CD pipeline in GitHub Actions (a local release script is sufficient; Actions is a future enhancement)

### 4.3 Assumptions

| ID | Assumption | Impact if Wrong |
|----|------------|-----------------|
| A1 | A valid .app bundle can be assembled from `swift build -c release` output without requiring xcodebuild or an .xcodeproj | May need to generate an .xcodeproj or use xcodebuild; increases build complexity |
| A2 | `Bundle.main.url(forResource:withExtension:)` resolves correctly when the app runs from an installed .app bundle in /Applications | May need to adjust resource loading to use a different bundle lookup strategy |
| A3 | Ad-hoc code signing is sufficient for personal daily-driver use on the maintainer's own machine | Gatekeeper warnings on first launch; may need Developer ID signing sooner than planned |
| A4 | Homebrew Cask's `binary` stanza can create a symlink to a binary inside a .app bundle | May need a wrapper shell script or a different symlink strategy |
| A5 | The `gh` CLI is available and authenticated for creating repositories and releases | Manual GitHub operations would be needed as a fallback |

## 5. Functional Requirements

### FR-01: .app Bundle Production (Must Have)

**Actor**: Project maintainer
**Action**: Run a build command that produces a valid macOS .app bundle from the SPM project
**Outcome**: A self-contained .app bundle exists at a known output path, containing the compiled binary, Info.plist, and all embedded resources
**Rationale**: macOS GUI applications distributed via Homebrew Cask must be .app bundles; SPM alone produces only a bare executable
**Acceptance Criteria**:
- AC-01.1: The output is a directory with the structure `mkdn.app/Contents/{MacOS/mkdn, Info.plist, Resources/}`
- AC-01.2: The binary at `mkdn.app/Contents/MacOS/mkdn` is a valid Mach-O executable for arm64
- AC-01.3: The .app bundle launches when double-clicked in Finder
- AC-01.4: The .app bundle launches when invoked via `open -a mkdn` (after copying to /Applications)

### FR-02: Info.plist Generation (Must Have)

**Actor**: Build process (on behalf of project maintainer)
**Action**: Generate a valid Info.plist with required keys
**Outcome**: The .app bundle contains an Info.plist that macOS recognizes, with the correct version, bundle ID, and minimum OS version
**Rationale**: macOS requires Info.plist for .app bundles to be recognized and launched correctly
**Acceptance Criteria**:
- AC-02.1: `CFBundleIdentifier` is set to `com.jud.mkdn`
- AC-02.2: `CFBundleShortVersionString` and `CFBundleVersion` match the Git tag version (e.g., `1.0.0` from tag `v1.0.0`)
- AC-02.3: `LSMinimumSystemVersion` is set to `14.0`
- AC-02.4: `CFBundleExecutable` is set to `mkdn`
- AC-02.5: `CFBundlePackageType` is set to `APPL`

### FR-03: Resource Embedding (Must Have)

**Actor**: Build process (on behalf of project maintainer)
**Action**: Embed `mermaid.min.js` inside the .app bundle's Resources directory
**Outcome**: The Mermaid rendering pipeline can locate `mermaid.min.js` via `Bundle.main` at runtime when launched from the installed .app
**Rationale**: Mermaid diagram rendering is a core feature of mkdn; the JavaScript file must be discoverable at runtime regardless of how the app is launched
**Acceptance Criteria**:
- AC-03.1: `mermaid.min.js` exists at `mkdn.app/Contents/Resources/mermaid.min.js`
- AC-03.2: `Bundle.main.url(forResource: "mermaid.min", withExtension: "js")` returns a valid URL when running from the installed .app
- AC-03.3: Mermaid diagrams render correctly when the app is launched from /Applications

### FR-04: Ad-Hoc Code Signing (Must Have)

**Actor**: Build process (on behalf of project maintainer)
**Action**: Sign the .app bundle with an ad-hoc signature
**Outcome**: macOS allows the .app to execute without an "unsigned binary" error
**Rationale**: Unsigned .app bundles are rejected by macOS security; ad-hoc signing is the minimum viable signing for personal use
**Acceptance Criteria**:
- AC-04.1: `codesign --verify mkdn.app` exits with status 0
- AC-04.2: The app launches without macOS blocking execution due to missing signature (Gatekeeper right-click override is acceptable for ad-hoc)

### FR-05: Archive Production (Must Have)

**Actor**: Build process (on behalf of project maintainer)
**Action**: Create a .zip archive of the signed .app bundle
**Outcome**: A single .zip file suitable for upload to GitHub Releases, preserving macOS extended attributes and code signature
**Rationale**: Homebrew Cask downloads archives from URLs; .zip is the standard format
**Acceptance Criteria**:
- AC-05.1: The .zip file is created using `ditto -c -k` (preserves macOS metadata) rather than plain `zip`
- AC-05.2: Extracting the .zip produces a valid, signed .app bundle
- AC-05.3: The .zip filename includes the version (e.g., `mkdn-1.0.0.zip`)

### FR-06: Tap Repository Creation (Must Have)

**Actor**: Project maintainer
**Action**: Create a `homebrew-mkdn` repository on GitHub
**Outcome**: A public GitHub repository exists that Homebrew recognizes as a tap when the user runs `brew tap jud/mkdn`
**Rationale**: A personal tap is the standard Homebrew mechanism for distributing software outside homebrew-core/homebrew-cask
**Acceptance Criteria**:
- AC-06.1: The repository `jud/homebrew-mkdn` exists on GitHub
- AC-06.2: `brew tap jud/mkdn` succeeds without error
- AC-06.3: The repository contains a `Casks/` directory with the mkdn Cask definition

### FR-07: Cask Definition (Must Have)

**Actor**: Project maintainer (authoring); end-user developer (consuming)
**Action**: Write a Homebrew Cask definition that installs mkdn
**Outcome**: `brew install --cask mkdn` (after tapping) downloads the .zip, installs the .app to /Applications, and creates a CLI symlink
**Rationale**: The Cask definition is the contract between Homebrew and the mkdn release; it must correctly specify download URL, hash, and post-install actions
**Acceptance Criteria**:
- AC-07.1: The Cask specifies a `url` pointing to the .zip asset on the GitHub Release for the current version
- AC-07.2: The Cask specifies a `sha256` matching the .zip archive
- AC-07.3: The Cask installs `mkdn.app` to `/Applications`
- AC-07.4: The Cask creates a symlink so that `mkdn` is available on PATH (e.g., via Cask `binary` stanza pointing to `mkdn.app/Contents/MacOS/mkdn`)
- AC-07.5: `brew uninstall --cask mkdn` removes the .app and the CLI symlink cleanly

### FR-08: Release Script (Must Have)

**Actor**: Project maintainer
**Action**: Run a single command to publish a new release from a tagged commit
**Outcome**: A GitHub Release exists with the correct tag, the .zip archive is attached, and the Cask definition is updated with the new version and SHA256
**Rationale**: Manual multi-step releases are error-prone and create friction that discourages frequent releases
**Acceptance Criteria**:
- AC-08.1: The script accepts a version tag (or reads the current Git tag) and performs all steps: build, sign, archive, create GitHub Release, attach .zip
- AC-08.2: The script computes the SHA256 of the .zip and updates the Cask definition in the tap repository
- AC-08.3: The script is idempotent -- running it twice for the same tag does not create duplicate releases or corrupt state
- AC-08.4: The script completes in under 5 minutes on the maintainer's machine

### FR-09: Version Derivation from Git Tag (Must Have)

**Actor**: Build process
**Action**: Extract the version number from the current Git tag and embed it in the .app bundle
**Outcome**: The installed app reports the correct version, matching the Git tag and the GitHub Release
**Rationale**: Version consistency across Git, GitHub, Info.plist, and Homebrew is essential for troubleshooting and user trust
**Acceptance Criteria**:
- AC-09.1: A Git tag of `v1.2.3` results in `CFBundleShortVersionString` of `1.2.3` in Info.plist
- AC-09.2: The build fails with a clear error if no Git tag is present on the current commit (prevents unversioned releases)

### FR-10: End-to-End Smoke Test (Should Have)

**Actor**: Project maintainer
**Action**: Run a verification checklist after publishing a release
**Outcome**: Confidence that the full install-launch-uninstall cycle works correctly
**Rationale**: Distribution failures are invisible until a user hits them; proactive verification catches issues early
**Acceptance Criteria**:
- AC-10.1: `brew tap jud/mkdn` succeeds
- AC-10.2: `brew install --cask mkdn` succeeds
- AC-10.3: `which mkdn` returns a valid path
- AC-10.4: `mkdn --help` produces expected output
- AC-10.5: `open -a mkdn` launches the application window
- AC-10.6: `brew uninstall --cask mkdn` succeeds and removes both the .app and the CLI symlink

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| Requirement | Target |
|-------------|--------|
| Build + archive time | Under 3 minutes on Apple Silicon Mac |
| Full release script execution | Under 5 minutes (including GitHub Release creation) |
| `brew install --cask mkdn` download + install | Under 30 seconds on broadband (archive should be small -- target under 20 MB) |

### 6.2 Security Requirements

- The .app bundle must be ad-hoc code-signed at minimum.
- The .zip archive SHA256 hash must be verified by Homebrew during install (standard Cask behavior).
- No secrets (tokens, keys) should be hardcoded in the release script; `gh` CLI uses its own auth.

### 6.3 Usability Requirements

- The release process must be a single command for the maintainer.
- The install process must be the standard two-command Homebrew flow: `brew tap jud/mkdn && brew install --cask mkdn`.
- After install, both CLI (`mkdn file.md`) and GUI (`open -a mkdn`) launch methods must work without additional configuration.
- Error messages in the release script must be clear and actionable.

### 6.4 Compliance Requirements

- The Cask definition must follow Homebrew's Cask DSL conventions and pass `brew audit --cask mkdn`.
- The .app bundle structure must conform to Apple's bundle conventions (Info.plist, Contents/MacOS/, Contents/Resources/).

## 7. User Stories

### STORY-01: Install mkdn via Homebrew

**As a** terminal-centric developer
**I want** to install mkdn with `brew install --cask mkdn`
**So that** I can start using it immediately without cloning a repository or building from source

**Acceptance**:
- GIVEN Homebrew is installed on the developer's macOS machine
- WHEN the developer runs `brew tap jud/mkdn && brew install --cask mkdn`
- THEN mkdn.app is installed in /Applications AND `mkdn` is available on PATH

### STORY-02: Launch mkdn from terminal after Homebrew install

**As a** developer who installed mkdn via Homebrew
**I want** to run `mkdn file.md` from my terminal
**So that** I can view Markdown files in the native viewer as part of my terminal workflow

**Acceptance**:
- GIVEN mkdn was installed via `brew install --cask mkdn`
- WHEN the developer runs `mkdn README.md` in their terminal
- THEN the mkdn application opens and displays the rendered Markdown file

### STORY-03: Publish a new release

**As the** mkdn project maintainer
**I want** to run a single command to publish a new version
**So that** I can ship improvements quickly without manual multi-step processes

**Acceptance**:
- GIVEN the maintainer has committed changes and created a Git tag (e.g., `git tag v1.1.0`)
- WHEN the maintainer runs the release script
- THEN a GitHub Release is created with the correct tag, the .zip archive is attached, and the Cask definition is updated

### STORY-04: Uninstall mkdn cleanly

**As a** developer
**I want** `brew uninstall --cask mkdn` to remove everything
**So that** no stale files remain on my system

**Acceptance**:
- GIVEN mkdn was installed via Homebrew Cask
- WHEN the developer runs `brew uninstall --cask mkdn`
- THEN the .app is removed from /Applications AND the CLI symlink is removed

### STORY-05: View Mermaid diagrams after Homebrew install

**As a** developer who installed mkdn via Homebrew
**I want** Mermaid diagrams to render correctly in files I open
**So that** the full feature set works from a Homebrew install, not just a development build

**Acceptance**:
- GIVEN mkdn was installed via `brew install --cask mkdn`
- WHEN the developer opens a Markdown file containing a Mermaid code block
- THEN the Mermaid diagram renders as a native image (not raw code text)

## 8. Business Rules

| ID | Rule |
|----|------|
| BR-01 | Every release must have a unique semantic version tag. Version tags follow the format `vMAJOR.MINOR.PATCH`. |
| BR-02 | The Cask definition's SHA256 hash must match the .zip archive attached to the corresponding GitHub Release. A mismatch causes install failure. |
| BR-03 | The .app bundle version (Info.plist) must exactly match the Git tag version and the GitHub Release version. No version skew is acceptable. |
| BR-04 | The release script must not publish a release if the working tree has uncommitted changes (prevents dirty builds). |
| BR-05 | The tap repository is personal (`jud/homebrew-mkdn`). No submission to official Homebrew repositories is required or planned. |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Type | Description |
|------------|------|-------------|
| Xcode 16+ / xcodebuild | Build tool | Required for producing .app bundles (or manual assembly from `swift build` output) |
| `codesign` | System tool | macOS built-in; required for ad-hoc signing |
| GitHub CLI (`gh`) | External tool | Creating repositories, releases, uploading assets |
| Homebrew | External tool | Required on consumer's machine for install; required on maintainer's machine for testing |
| SPM two-target layout | Internal | The mkdnLib + mkdn target split must work correctly when the binary is placed inside a .app bundle |
| `mermaid.min.js` | Internal resource | Must be present in the source tree for embedding into the .app bundle |

### Constraints

- SPM does not natively produce .app bundles. A build script must bridge the gap between `swift build` output and a valid .app bundle structure.
- `Bundle.main` resource resolution may behave differently in a .app bundle vs. SPM's build directory. This must be verified and potentially accommodated.
- Ad-hoc signing triggers Gatekeeper warnings on first launch for users who did not build the app themselves. This is acceptable for personal use.
- arm64-only builds limit compatibility to Apple Silicon Macs. This is acceptable for the current scope (personal daily-driver use).

## 10. Clarifications Log

| # | Question | Resolution | Source |
|---|----------|------------|--------|
| 1 | Should the build use xcodebuild or manual bundle assembly? | Requirement is outcome-based: a valid .app bundle must be produced. The method is an implementation decision. | PRD open question -- deferred to design phase |
| 2 | Is Developer ID signing needed? | Not for initial release. Ad-hoc signing is sufficient for personal use. Deferred to future scope. | PRD out-of-scope |
| 3 | What should the tap repository be named? | `homebrew-mkdn` per Homebrew conventions (enables `brew tap jud/mkdn`). | PRD recommendation |
| 4 | Should release automation use GitHub Actions or a local script? | A local release script is the minimum requirement. GitHub Actions is a future enhancement. | Conservative default; PRD says "script or GitHub Actions" |
| 5 | Should the smoke test be automated or manual? | Manual checklist with specific commands. Automation is a future enhancement. | Conservative default |
| 6 | Is universal binary (arm64 + x86_64) needed? | No. arm64-only is sufficient for personal use on Apple Silicon. | PRD out-of-scope |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | `homebrew-distribution.md` | Exact filename match with feature ID; only relevant PRD |
| Release mechanism | Local shell script (not GitHub Actions) | Conservative; avoids CI runner assumptions (PRD assumption A5); single-command requirement still met |
| Code signing level | Ad-hoc only | PRD explicitly defers Developer ID; sufficient for personal daily-driver use |
| Target architecture | arm64 only | PRD out-of-scope for universal binary; personal Apple Silicon use |
| Smoke test format | Manual checklist | Conservative; automated test infrastructure not yet established |
| Tap naming | `homebrew-mkdn` | PRD recommendation; follows Homebrew convention |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| "CLI symlink" mechanism unclear -- Cask `binary` stanza vs wrapper script | Require CLI availability on PATH after install; exact mechanism is implementation detail. Acceptance criteria test `which mkdn` and `mkdn --help`. | PRD assumption A4 |
| Archive format -- `zip` vs `ditto` | Require `ditto -c -k` to preserve macOS extended attributes and code signature integrity | macOS best practice for .app distribution |
| Build failure behavior when no Git tag exists | Build script must fail with clear error; prevents unversioned releases | Conservative default; version consistency is a business rule (BR-03) |
| Dirty working tree behavior | Release script must refuse to publish if uncommitted changes exist | Conservative default; prevents non-reproducible builds |
| .zip file size target | Under 20 MB | Inferred from NFR "fast install"; mkdn is a lightweight app with one JS resource |
