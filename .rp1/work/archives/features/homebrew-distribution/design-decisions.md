# Design Decisions: Homebrew Distribution

**Feature ID**: homebrew-distribution
**Created**: 2026-02-06

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | Build method for .app bundle | `swift build -c release` + manual .app directory assembly | Avoids xcodebuild dependency; SPM is the existing build system; .app is just a well-known directory structure with Info.plist, MacOS/, and Resources/ | xcodebuild (requires .xcodeproj generation, heavier toolchain dependency) |
| D2 | Resource embedding strategy | Copy entire `mkdn_mkdnLib.bundle` into .app/Contents/Resources/ | Preserves SPM's `Bundle.module` resolution path without any Swift code changes. The generated `resource_bundle_accessor.swift` searches `Bundle.main.resourceURL` first, which maps to Contents/Resources/ in a .app bundle | Copy mermaid.min.js directly into Resources/ (breaks `Bundle.module` accessor, would require Swift code changes to use `Bundle.main` instead) |
| D3 | Version injection mechanism | sed replacement in MkdnCLI.swift at build time, reverted after build | Simple, zero new dependencies, works with existing ArgumentParser version display. Revert via git checkout ensures source stays clean | Build-time environment variable (SPM has poor support for injecting values at build time), separate generated version file (adds complexity and a new source file to manage), read from Info.plist at runtime (requires Swift changes and only works in .app context, not development) |
| D4 | Release script language | Bash | All required tools (swift, codesign, ditto, gh, sed, shasum) are CLI commands natively available on macOS. Bash is the natural orchestration layer | Python (unnecessary dependency for simple orchestration), Swift script (adds compilation step, poor fit for shell tool orchestration), Makefile (less readable for sequential pipeline) |
| D5 | CLI symlink mechanism | Homebrew Cask `binary` stanza pointing to `#{appdir}/mkdn.app/Contents/MacOS/mkdn` | Standard Homebrew pattern used by many casks (e.g., Visual Studio Code, iTerm2). Creates a symlink in Homebrew's bin directory which is already on PATH | Wrapper shell script in /usr/local/bin (unnecessary indirection, harder to maintain), Cask post-install hook (non-standard, fragile) |
| D6 | Archive tool for .zip | `ditto -c -k --keepParent` | Apple's recommended tool for creating .zip archives that preserve macOS extended attributes (resource forks, code signatures). Standard practice for distributing .app bundles | `zip` command (strips extended attributes, can corrupt code signatures), `tar.gz` (not a standard Homebrew Cask format) |
| D7 | Tap repository update automation | Release script clones/pulls tap repo locally, updates Cask file via sed, commits, and pushes | Achieves the single-command release requirement. All operations use `gh` and `git` which are already required dependencies | Manual Cask editing after each release (error-prone, violates single-command requirement), GitHub Actions workflow (out of scope per requirements), Homebrew's `brew bump-cask-pr` (designed for official cask repo, not personal taps) |
| D8 | Version source of truth | Git tag is the single source; Info.plist and MkdnCLI.swift are derived from it | Eliminates version skew risk (BR-03). Git tags are immutable once pushed and naturally integrate with GitHub Releases | Version file in repo (another artifact to keep in sync), package.swift version (SPM doesn't expose this to the binary) |

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| Build system | SPM (`swift build`) | Codebase (Package.swift) | Project uses SPM exclusively; no xcodebuild infrastructure exists |
| Script language | Bash | Conservative default | All tools are CLI commands; Bash is pre-installed on macOS and is the simplest orchestration choice |
| Archive format | .zip via ditto | Requirements (AC-05.1) | Requirements explicitly specify `ditto -c -k`; standard for macOS .app distribution |
| Code signing | Ad-hoc (`codesign --sign -`) | Requirements (FR-04) | Requirements explicitly scope to ad-hoc; Developer ID is out of scope |
| Target architecture | arm64 only | Requirements (scope) | Requirements explicitly exclude universal binary; personal Apple Silicon use |
| Tap naming | `homebrew-mkdn` | Requirements (FR-06) | Follows Homebrew naming convention; enables `brew tap jud/mkdn` |
| Smoke test format | Script with manual execution | Conservative default | No CI infrastructure; script provides repeatable verification without automation overhead |
| Tap update method | Local clone + sed + push | Conservative default | Avoids GitHub Actions dependency; works with just `git` and `gh` already required |
