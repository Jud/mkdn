# Quick Build: Orb Vision Capture

**Created**: 2026-02-10T00:00:00Z
**Request**: Add visual verification capture tests for the-orb feature: (1) color crossfade between orb states (violet to orange transition when file changes), and (2) auto-reload pulse timing (orb appears orange, breathes for ~5s, then auto-reloads and dismisses). These should use the existing VisionCompliance capture test harness pattern (scripts/visual-verification/ and mkdnTests/UITest/VisionCompliance/). The tests need to capture screenshots at key moments during these animations for LLM vision evaluation against the PRD specs.
**Scope**: Medium

## Plan

**Reasoning**: 5-6 new files needed (PRD config, test suite, fixture, capture script), all within the existing VisionCompliance test system. The main complexity is triggering the file-changed orb state from the test process -- the existing test harness has no `simulateFileChange` command, so the test must write to the fixture file on disk to trigger the FileWatcher's DispatchSource, then capture frames during the resulting crossfade and breathing animations. Timing sensitivity for the 0.35s crossfade and ~5s auto-reload cycle requires careful frame capture orchestration. Single system (test harness), medium risk due to timing dependencies.

**Files Affected**:
- `mkdnTests/UITest/VisionCompliance/OrbVisionCapturePRD.swift` (new -- harness, config, manifest types)
- `mkdnTests/UITest/VisionCompliance/OrbVisionCaptureTests.swift` (new -- capture test suite)
- `mkdnTests/Fixtures/UITest/orb-crossfade.md` (new -- minimal fixture for orb tests)
- `scripts/visual-verification/capture-orb.sh` (new -- shell wrapper for orb capture)
- `scripts/visual-verification/prompts/prd-context-orb.md` (new -- PRD context for LLM evaluation)

**Approach**: Follow the MermaidFadeInCapture pattern (the closest analog since it also captures time-sensitive animation sequences). Create a fixture file, load it via the test harness, then trigger a file change by appending content to the file on disk from the test process. This causes the FileWatcher DispatchSource to fire, setting `isFileOutdated = true`, which activates the orb with a violet-to-orange crossfade (0.35s). Use beginFrameCapture/endFrameCapture around the file modification to capture the crossfade transition frames. For the auto-reload pulse test, ensure `autoReloadEnabled` is true (via UserDefaults or a new harness command), then capture the full 5-second breathing cycle until auto-reload dismisses the orb. Capture across both themes for completeness. The capture matrix is: 2 scenarios (crossfade, auto-reload) x 2 themes = 4 frame sequences.

**Estimated Effort**: 4-6 hours

## Tasks

- [x] **T1**: Create fixture file `mkdnTests/Fixtures/UITest/orb-crossfade.md` -- minimal Markdown content (a heading and paragraph) that the test loads before triggering a file change. Keep it simple so the orb is clearly visible against a non-busy background. `[complexity:simple]`
- [x] **T2**: Create `OrbVisionCapturePRD.swift` with OrbVisionHarness (shared app launcher singleton), OrbVisionConfig (fixtures, themes, captureFPS=30, crossfade duration=2s, autoReload duration=8s), manifest types (OrbFrameSequenceEntry, OrbCaptureManifest), utility functions (fixture paths, output dir at `.rp1/work/verification/captures/orb/`, capture ID generation, SHA-256 hashing, frame capture extraction, manifest writing) -- following the MermaidFadeInCapturePRD pattern exactly. `[complexity:medium]`
- [x] **T3**: Create `OrbVisionCaptureTests.swift` with two capture scenarios: (1) crossfade capture -- load fixture, start frame capture, write additional content to the fixture file on disk to trigger FileWatcher, wait 2s for crossfade animation, end frame capture; (2) auto-reload capture -- load fixture, set `autoReloadEnabled` via UserDefaults, start frame capture, write to file on disk, wait 8s for full breathing cycle + auto-reload + orb dismiss, end frame capture. Run each scenario across both themes. Include validation (frame counts > 0, manifest written) and result recording. `[complexity:medium]`
- [x] **T4**: Create `scripts/visual-verification/capture-orb.sh` shell script following the `capture-animation.sh` pattern -- build mkdn, run `swift test --filter OrbVisionCapture`, validate manifest, report sequence/frame counts. `[complexity:simple]`
- [x] **T5**: Create `scripts/visual-verification/prompts/prd-context-orb.md` with PRD context for LLM vision evaluation -- describe the expected orb visual states (violet default-handler, orange file-changed), the crossfade transition behavior (0.35s easeInOut), the breathing animation (~5s full cycle at ~12 CPM), the auto-reload dismiss behavior, and the expected color values (violet #6c71c4, orange #cb4b16) for the evaluator to check against captured frames. `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdnTests/Fixtures/UITest/orb-crossfade.md` | Minimal heading + paragraph fixture with HTML comment documenting purpose | Done |
| T2 | `mkdnTests/UITest/VisionCompliance/OrbVisionCapturePRD.swift` | Harness singleton, config, fixture/output path resolution, SHA-256 hashing, frame capture extraction, manifest types + writing, temp file copy + file change trigger utilities -- follows MermaidFadeInCapturePRD pattern exactly | Done |
| T3 | `mkdnTests/UITest/VisionCompliance/OrbVisionCaptureTests.swift` | Two scenarios (crossfade 2s, breathing 8s) x 2 themes = 4 sequences. Copies fixture to temp dir, loads via harness, starts frame capture, appends content to trigger FileWatcher, waits for configured duration, ends capture. Validates frame counts and manifest. Cleans up temp files. | Done |
| T4 | `scripts/visual-verification/capture-orb.sh` | Shell wrapper following capture-animation.sh pattern: build, swift test --filter OrbVisionCapture, validate manifest.json, report counts | Done |
| T5 | `scripts/visual-verification/prompts/prd-context-orb.md` | PRD context covering orb states/colors, crossfade (0.35s easeInOut), breathing (~12 CPM), auto-reload, theme backgrounds, and 6 evaluation criteria | Done |

## Verification

{To be added by task-reviewer if --review flag used}
