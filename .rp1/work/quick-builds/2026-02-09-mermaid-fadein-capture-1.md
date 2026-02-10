# Quick Build: Mermaid Fadein Capture

**Created**: 2026-02-09T00:00:00Z
**Request**: Create a mermaid fade-in animation capture test to reproduce and diagnose a fade-in rendering artifact on Mermaid diagram renders.
**Scope**: Small

## Plan

**Reasoning**: 3 new files (fixture, PRD harness, test suite), 1 system (test harness), low risk (purely additive test code, no app-side changes). All patterns are well-established in existing AnimationVisionCapture and VisionCapture suites.
**Files Affected**:
- `mkdnTests/Fixtures/UITest/mermaid-fadein.md` (new fixture)
- `mkdnTests/UITest/VisionCompliance/MermaidFadeInCapturePRD.swift` (new harness/config)
- `mkdnTests/UITest/VisionCompliance/MermaidFadeInCaptureTests.swift` (new test suite)
**Approach**: Create a minimal single-flowchart fixture to isolate mermaid fade-in without noise. Build a MermaidFadeInHarness (same AppLauncher + TestHarnessClient singleton pattern as AnimationVisionHarness) with config for 1 fixture x 2 themes x 2 motion modes = 4 capture sequences at 30fps for 8s (~240 frames). The test iterates the capture matrix, using setReduceMotion(enabled:) to toggle motion mode, resets between captures by loading geometry-calibration.md, and writes all frame sequences to `.rp1/work/verification/captures/mermaid-fadein/` with a manifest.json. Reduce-motion captures serve as A/B controls: if the artifact vanishes with reduce-motion, it confirms an animation-related root cause.
**Estimated Effort**: 1.5 hours

## Tasks

- [x] **T1**: Create `mkdnTests/Fixtures/UITest/mermaid-fadein.md` with a single flowchart mermaid diagram and minimal surrounding markdown `[complexity:simple]`
- [x] **T2**: Create `mkdnTests/UITest/VisionCompliance/MermaidFadeInCapturePRD.swift` with MermaidFadeInHarness singleton, MermaidFadeInConfig (1 fixture, 2 themes, 30fps, 8s duration), fixture path resolution, output dir pointing to `mermaid-fadein/`, capture ID generation, SHA-256 hashing, frame capture extraction, and manifest types/writing -- all following AnimationVisionCapturePRD patterns `[complexity:medium]`
- [x] **T3**: Create `mkdnTests/UITest/VisionCompliance/MermaidFadeInCaptureTests.swift` with `@Suite("MermaidFadeIn", .serialized)` containing a single test that iterates 4 capture combinations (2 themes x 2 motion modes), uses beginFrameCapture before loadFile, endFrameCapture after 8s, setReduceMotion(enabled:) toggling, geometry-calibration.md reset between captures, and writes manifest.json `[complexity:medium]`
- [x] **T4**: Verify the new files compile with `swift build` and fix any lint/format issues `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdnTests/Fixtures/UITest/mermaid-fadein.md` | Minimal single-flowchart fixture with HTML comment header | Done |
| T2 | `mkdnTests/UITest/VisionCompliance/MermaidFadeInCapturePRD.swift` | Harness singleton, config (1 fixture x 2 themes x 2 motion modes, 30fps, 8s), fixture/output path resolution, capture ID with motionMode dimension, SHA-256 hashing, frame extraction, manifest types+writing | Done |
| T3 | `mkdnTests/UITest/VisionCompliance/MermaidFadeInCaptureTests.swift` | Serialized suite with single test iterating 4 combinations; CaptureIdentity struct to satisfy 6-param lint limit; geometry-calibration reset between captures; beginFrameCapture-before-loadFile pattern; setReduceMotion toggling; validation + result recording | Done |
| T4 | (all above) | swift build clean, swiftformat 0 changes, swiftlint 0 violations (refactored buildEntry to use CaptureIdentity struct for function_parameter_count compliance) | Done |

## Verification

{To be added by task-reviewer if --review flag used}
