# Quick Build: Fix Prerelease Issues

**Created**: 2026-02-25T00:00:00Z
**Request**: Fix pre-release issues: add screenshots to README, fix silent save-as failure, fix Cask zap trash, remove duplicate comment in main.swift, add Apple Silicon note to README Install section.
**Scope**: Small

## Plan

**Reasoning**: 4 files affected, 1 system (project meta + minor code fix), low risk -- all changes are cosmetic or single-line error handling fixes.
**Files Affected**: README.md, mkdn/App/DocumentState.swift, Casks/mkdn.rb, mkdnEntry/main.swift
**Approach**: Add hero-dark.png screenshot above the fold in README, hero-light.png in theming section, math-dark.png near LaTeX section. Surface save-as errors through modeOverlayLabel in DocumentState. Populate Cask zap trash with preferences plist. Remove duplicate comment line 36 in main.swift. Add Apple Silicon requirement note to Install section. GitHub username casing already correct (lowercase jud/mkdn throughout).
**Estimated Effort**: 1 hour

## Tasks

- [ ] **T1**: Add screenshots to README.md (hero-dark above fold, hero-light in theming, math-dark near LaTeX) `[complexity:simple]`
- [ ] **T2**: Fix silent save-as failure in DocumentState.swift -- surface error via modeOverlayLabel `[complexity:simple]`
- [ ] **T3**: Populate Cask zap trash with ~/Library/Preferences/com.mkdn.app.plist `[complexity:simple]`
- [ ] **T4**: Remove duplicate comment on line 36 of mkdnEntry/main.swift `[complexity:simple]`
- [ ] **T5**: Add "Requires Apple Silicon (M1 or later)" note to README Install section `[complexity:simple]`

## Implementation Summary

{To be added by task-builder}

## Verification

{To be added by task-reviewer if --review flag used}
