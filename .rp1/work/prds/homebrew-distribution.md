# PRD: Homebrew Distribution

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-06

## Surface Overview

The Homebrew Distribution surface covers everything needed to make mkdn installable via `brew install --cask mkdn`. mkdn is a GUI app (SwiftUI window) that's CLI-launchable, so it needs to be distributed as a proper .app bundle via Homebrew Cask. This includes building a .app bundle with Info.plist and embedded resources, a Homebrew Cask definition in a tap repository, release automation to produce versioned .app archives, and a CLI symlink so `mkdn` is available on PATH.

The GitHub CLI (`gh`) is available for creating repositories, releases, and any other GitHub resources needed.

This surface is the final piece of the charter's "Will Do" list -- making mkdn easily installable for terminal-centric developers via the standard macOS package manager.

## Scope

### In Scope
- **Build as .app bundle** -- Info.plist, proper macOS bundle structure, embedded resources (`mermaid.min.js` inside .app/Contents/Resources)
- **Homebrew Cask definition** in a tap repository (e.g., `homebrew-mkdn` on GitHub)
- **CLI symlink** -- Cask creates a symlink so `mkdn` is available on PATH from the terminal (links to the binary inside the .app bundle)
- **Release automation** -- script or GitHub Actions to build the .app, archive it (.zip), create a tagged GitHub Release, and attach the archive
- **Code signing** -- at minimum ad-hoc signing for local distribution; may need Developer ID for Gatekeeper
- **Version tagging strategy** -- semantic versioning, Git tags, version embedded in Info.plist
- **`brew install --cask mkdn` smoke test** -- end-to-end verification that install works, CLI symlink works, and the app launches

### Out of Scope
- Publishing to homebrew-core or homebrew-cask official repos (personal tap only for now)
- Notarization with Apple (future -- needed for wider distribution but not for personal daily-driver use)
- Auto-update mechanism (Sparkle or similar)
- DMG with custom background/layout (plain .zip is sufficient)
- Universal binary (arm64 + x86_64) -- arm64-only is fine for personal use on Apple Silicon

## Requirements

### Functional Requirements

**Build Pipeline**

1. **Build .app bundle** -- Build script that produces a proper macOS .app bundle from the SPM project (needs xcodebuild or manual bundle assembly since SPM alone doesn't produce .app bundles).
2. **Embed resources** -- `mermaid.min.js` is correctly placed in .app/Contents/Resources and discoverable by `Bundle.main` at runtime.
3. **Generate Info.plist** -- Bundle identifier (e.g., `com.jud.mkdn`), version string, minimum macOS 14.0, and any required keys for a SwiftUI app.
4. **Ad-hoc codesign** -- `codesign --sign -` the .app bundle so macOS allows it to run.
5. **Archive as .zip** -- Produce a .zip of the .app bundle for upload to GitHub Releases.

**Release Automation**

6. **Single-command release** -- GitHub Actions workflow or shell script that: builds release .app, zips it, creates a Git tag, creates a GitHub Release via `gh release create`, and attaches the .zip.
7. **Version from Git tag** -- Version derived from Git tag (e.g., `v1.0.0`) and embedded in Info.plist automatically.

**Homebrew Tap**

8. **Create tap repository** -- `homebrew-mkdn` repo on GitHub (enables `brew tap jud/mkdn`). Created via `gh repo create`.
9. **Cask definition** -- Downloads .zip from GitHub Release, installs .app to /Applications, creates CLI symlink linking `/usr/local/bin/mkdn` to the binary inside the .app bundle.
10. **SHA256 hash** -- SHA256 of .zip computed and embedded in Cask definition, updated per release.

**Verification**

11. **Smoke test** -- End-to-end: `brew install --cask mkdn` succeeds, `mkdn --help` works via symlink, `open -a mkdn` launches the app.

### Non-Functional Requirements

1. **Deterministic versioning** -- Same Git tag always maps to the same version string in Info.plist. Build script is idempotent.
2. **Single-command release** -- One script/command to go from tagged commit to published GitHub Release with attached .zip.
3. **Fast install** -- `brew install --cask mkdn` completes quickly (small .zip download, no compile-from-source).
4. **No manual steps** -- Release process is fully automated after tagging.

## Dependencies & Constraints

### Build Dependencies
- **Xcode 16+ / xcodebuild** -- needed to produce a .app bundle from the SPM project (or manual bundle assembly via shell script)
- **codesign** -- macOS built-in tool for ad-hoc code signing
- **swift build -c release** -- compiles the executable binary

### External Tools
- **GitHub CLI (`gh`)** -- creating repos, releases, uploading assets
- **Homebrew** -- for testing the Cask install flow

### Internal Dependencies
- **Package.swift** -- defines the two-target layout (mkdnLib + mkdn) and resource bundling
- **mermaid.min.js** -- bundled resource that must end up inside the .app

### Constraints
- SPM alone does not produce .app bundles -- need xcodebuild or manual bundle assembly
- `Bundle.main.url(forResource:)` must resolve correctly when running from the .app bundle (not just from SPM build directory)
- Ad-hoc signing is sufficient for personal use but Gatekeeper will warn on first launch; Developer ID signing is a future concern
- Personal tap only -- no homebrew-core/homebrew-cask submission process needed

## Milestones

### Phase 1: .app Bundle Build
- Build script that produces a proper .app bundle from SPM project
- Info.plist generation with version, bundle ID, min macOS
- Embed `mermaid.min.js` in .app/Contents/Resources
- Ad-hoc codesign
- Zip the .app bundle
- Verify `Bundle.main` resource resolution works from installed .app

### Phase 2: Homebrew Tap + Cask
- Create `homebrew-mkdn` repository on GitHub via `gh repo create`
- Write Cask definition with download URL, SHA256, .app install, CLI symlink
- Test `brew tap jud/mkdn && brew install --cask mkdn` locally

### Phase 3: Release Automation
- Shell script or GitHub Action: build .app, zip, tag, `gh release create`, attach .zip
- Auto-compute SHA256 and update Cask definition
- Version derived from Git tag, embedded in Info.plist

### Phase 4: Smoke Test
- End-to-end verification: `brew install --cask mkdn`
- CLI symlink works: `mkdn --help`, `mkdn file.md`
- App launches: `open -a mkdn`
- Clean uninstall: `brew uninstall --cask mkdn`

## Open Questions

- **xcodebuild vs manual bundle assembly**: Should the build script use `xcodebuild` (requires generating an .xcodeproj or workspace) or manually assemble the .app bundle structure from `swift build` output?
- **Bundle.main resource path**: Does `Bundle.main.url(forResource: "mermaid.min", withExtension: "js")` resolve correctly from an installed .app, or does the resource bundle path differ from SPM's build-time layout?
- **Developer ID signing**: At what point should we invest in proper signing + notarization for wider distribution?
- **Tap naming**: `homebrew-mkdn` or a different convention?

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A1 | Manual .app bundle assembly from SPM output is feasible without xcodebuild | May need to generate .xcodeproj or migrate build to xcodebuild | Will Do: Homebrew installable |
| A2 | `Bundle.main` resource resolution works the same in .app bundle as in SPM build dir | May need to adjust resource loading paths or use a different bundle lookup | Will Do: Mermaid rendering (mermaid.min.js) |
| A3 | Ad-hoc signing is sufficient for personal daily-driver use | Gatekeeper warnings may be annoying; may need Developer ID sooner | Success: daily-driver use |
| A4 | Homebrew Cask CLI symlink (`binary`) works for linking to a binary inside a .app bundle | May need a wrapper script or different symlink strategy | Will Do: CLI-launchable |
| A5 | GitHub Actions macOS runners have Xcode 16+ and Swift 6 available | May need self-hosted runner or local-only release script | Will Do: Homebrew installable |
