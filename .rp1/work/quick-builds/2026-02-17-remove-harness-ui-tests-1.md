# Quick Build: Remove Harness UI Tests

**Created**: 2026-02-17T06:23:41Z
**Request**: Remove all harness-dependent UI tests (AnimationCompliance, SpatialCompliance, VisualCompliance, VisionCapture, AnimationVisionCapture, OrbVisionCapture, MermaidFadeIn, HarnessSmokeTests). Also remove scripts/visual-verification/ and prompt templates. Keep test harness infrastructure (TestHarnessServer, TestHarnessHandler, HarnessCommand, etc.) and support utilities (AppLauncher, TestHarnessClient, ImageAnalyzer, SpatialMeasurement, ColorExtractor, FrameAnalyzer, etc.) as they are still used by mkdn-ctl. Keep unit tests.
**Scope**: Medium

## Plan

**Reasoning**: ~35 files to delete across 3 directories (mkdnTests/UITest/, scripts/visual-verification/, .rp1/work/verification/), plus fixture files only used by those tests. Single system (test infrastructure). Low-medium risk since this is purely deletions with no production code changes. Documentation references in CLAUDE.md, index.md, modules.md, and patterns.md need updating.

**Files Affected**:
- DELETE: `mkdnTests/UITest/` (entire directory -- 20 Swift files including VisionCompliance/ subdirectory)
- DELETE: `mkdnTests/Fixtures/UITest/` (13 fixture .md files only used by UI tests)
- DELETE: `scripts/visual-verification/` (14 files: shell scripts + prompt templates)
- DELETE: `.rp1/work/verification/` (captured screenshots, reports, cache, audit trail)
- DELETE: `docs/visual-verification.md`, `docs/ui-testing.md`
- UPDATE: `CLAUDE.md` (remove visual verification workflow section, script references)
- UPDATE: `.rp1/context/index.md` (remove UI test and vision compliance references)
- UPDATE: `.rp1/context/modules.md` (remove UI Compliance Suites and Vision Compliance sections, fixtures references)
- UPDATE: `.rp1/context/patterns.md` (remove UI Test Pattern section)

**Approach**: Delete all files in the three target directories. Remove the UITest fixtures directory since all 13 fixture files are only referenced by the UI test suites being removed. Update KB and CLAUDE.md to remove references to visual verification scripts, UI compliance test suites, vision compliance, and UITest fixtures. Keep Support/ utilities and test harness app-side code untouched.

**Estimated Effort**: 2-3 hours

## Tasks

- [x] **T1**: Delete all files in `mkdnTests/UITest/` (20 files including VisionCompliance/ subdirectory), `mkdnTests/Fixtures/UITest/` (13 fixture files), `scripts/visual-verification/` (14 files), `.rp1/work/verification/` (all artifacts), and `docs/visual-verification.md` + `docs/ui-testing.md` `[complexity:medium]`
- [x] **T2**: Update `CLAUDE.md` to remove the Visual Verification Workflow section (Quick Reference, Flags table, Artifacts table) and any other references to the removed scripts and UI test suites `[complexity:simple]`
- [x] **T3**: Update `.rp1/context/index.md` to remove Quick Reference entries for UI compliance tests, vision compliance tests, vision verification scripts/artifacts/docs, and UITest fixtures `[complexity:simple]`
- [x] **T4**: Update `.rp1/context/modules.md` to remove the UI Compliance Suites, Vision Compliance, and Fixtures sections from the Test Layer; remove ScreenCaptureKit from Dependencies table `[complexity:simple]`
- [x] **T5**: Update `.rp1/context/patterns.md` to remove the UI Test Pattern section (Suite Structure, Calibration-Gate Pattern, Capture and Analysis, PRD-Driven Assertions) `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdnTests/UITest/` (20), `mkdnTests/Fixtures/UITest/` (13), `scripts/visual-verification/` (14), `.rp1/work/verification/` (all), `docs/visual-verification.md`, `docs/ui-testing.md`, `Package.swift` | Deleted all directories and files; removed orphaned Fixtures resource from Package.swift | Done |
| T2 | `CLAUDE.md` | Already updated (Visual Verification Workflow section previously replaced with mkdn-ctl section); no changes needed | Done |
| T3 | `.rp1/context/index.md` | Removed 7 Quick Reference entries for UI tests, fixtures, vision scripts/artifacts/docs | Done |
| T4 | `.rp1/context/modules.md` | Removed UI Compliance Suites, Vision Compliance, Fixtures sections and ScreenCaptureKit dependency | Done |
| T5 | `.rp1/context/patterns.md` | Removed UI Test Pattern section (68 lines) and cross-reference from Testing Pattern | Done |

**Note**: `.rp1/context/architecture.md` lines 179-197 still contain a "Vision Verification (LLM-Based Design Compliance)" subsection referencing deleted files. This was not in the task scope but should be cleaned up separately.

## Verification

{To be added by task-reviewer if --review flag used}
