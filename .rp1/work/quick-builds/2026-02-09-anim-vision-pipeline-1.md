# Quick Build: Anim Vision Pipeline

**Created**: 2026-02-10T03:07:00Z
**Request**: Create an animation vision verification pipeline that captures entrance animations as frame sequences and evaluates them via LLM vision. This addresses a known bug where code blocks move but don't properly fade in.
**Scope**: Medium

## Plan

**Reasoning**: This touches ~10 files across 2 systems (test infrastructure + visual verification pipeline). The test suite requires a novel capture-before-load pattern that inverts the existing VisionCaptureTests flow, integrating with FrameCaptureSession's SCStream-based capture. Risk is medium due to SCStream startup latency (200-400ms) being a known complication, though the request explicitly addresses this by starting capture before file load and noting the LLM can distinguish app launch state from animation start.

**Files Affected**:
- `mkdnTests/Fixtures/UITest/anim-headings.md` (new)
- `mkdnTests/Fixtures/UITest/anim-blockquotes.md` (new)
- `mkdnTests/Fixtures/UITest/anim-code-swift.md` (new)
- `mkdnTests/Fixtures/UITest/anim-code-python.md` (new)
- `mkdnTests/Fixtures/UITest/anim-code-mixed.md` (new)
- `mkdnTests/Fixtures/UITest/anim-inline-code.md` (new)
- `mkdnTests/UITest/VisionCompliance/AnimationVisionCaptureTests.swift` (new)
- `mkdnTests/UITest/VisionCompliance/AnimationVisionCapturePRD.swift` (new)
- `scripts/visual-verification/prompts/prd-context-animation.md` (new)
- `scripts/visual-verification/evaluate-animation.sh` (new)

**Approach**: Create 6 focused markdown fixtures that each isolate a single element type (headings, blockquotes, Swift code, Python code, mixed code, inline code) sized to fit within a single viewport. **Design decision**: Add split start/stop frame capture commands (`beginFrameCapture`/`endFrameCapture`) to the test harness protocol, since the current `startFrameCapture` is synchronous and blocks the socket for the full duration. This enables the capture-before-load pattern where we start SCStream, then issue loadFile over the socket, then stop capture after animation completes. Build an `AnimationVisionCaptureTests` suite using the new split commands. The test captures 30fps for ~3 seconds per fixture across both themes, writes numbered PNGs to `.rp1/work/verification/captures/animation/`, and generates a manifest compatible with the evaluate pipeline. Create an animation-specific prompt template that instructs the LLM to evaluate fade-in behavior, stagger timing, cover layer color matching, and the specific code-block bug (movement without opacity fade). Create a parallel `evaluate-animation.sh` script that follows the same batch/cache/audit pattern as `evaluate.sh` but uses the animation prompt and frame sequences.

**Estimated Effort**: 5 hours

## Tasks

- [x] **T1**: Create 6 focused animation fixture markdown files in `mkdnTests/Fixtures/UITest/` -- each isolating a single element type (headings, blockquotes, swift code, python code, mixed code, inline code) with enough elements for stagger visibility but few enough to fit in one viewport `[complexity:simple]`
- [x] **T2**: Create `AnimationVisionCapturePRD.swift` in `mkdnTests/UITest/VisionCompliance/` with AnimationVisionHarness singleton (reusing VisionCaptureHarness pattern), AnimationVisionConfig (6 fixtures, 2 themes), fixture path resolution, output directory resolution for `.rp1/work/verification/captures/animation/`, and animation-specific manifest types that extend CaptureManifest with frame sequence metadata (frameCount, fps, duration) `[complexity:medium]`
- [x] **T3a**: Add split start/stop frame capture commands to the test harness protocol. Currently `startFrameCapture(fps:duration:)` is synchronous (blocks the socket for the full duration). Add a new `beginFrameCapture(fps:)` command that starts SCStream capture and returns immediately, and a `endFrameCapture()` command that stops capture and returns the FrameCaptureResult. This requires changes to: `HarnessCommand.swift` (new command cases), `TestHarnessHandler.swift` (new dispatch cases), `CaptureService.swift` (new methods wrapping FrameCaptureSession start/stop), `FrameCaptureSession.swift` (split capture into start/stop lifecycle), and `TestHarnessClient.swift` (new async methods). The existing synchronous `startFrameCapture(fps:duration:)` should remain for backward compatibility. `[complexity:medium]`
- [x] **T3b**: Create `AnimationVisionCaptureTests.swift` in `mkdnTests/UITest/VisionCompliance/` implementing the capture-before-load pattern using the new split commands from T3a: for each fixture+theme combo, (a) call `beginFrameCapture(fps: 30)` which returns immediately, (b) call `loadFile()` to trigger entrance animation, (c) sleep ~3 seconds for animation to complete, (d) call `endFrameCapture()` to stop and get frame paths, (e) save manifest with per-sequence metadata and SHA-256 hashes. Output to `.rp1/work/verification/captures/animation/`. `[complexity:medium]`
- [x] **T4**: Create `scripts/visual-verification/prompts/prd-context-animation.md` -- animation-specific prompt template instructing the LLM to evaluate: (a) do elements fade in from invisible to visible (opacity transition, not just position)? (b) is there visible stagger between successive elements? (c) do code blocks fade properly or just appear/slide in without opacity change? (d) are cover layers matching the correct background color (document background for normal blocks, code background for code blocks)? (e) does the animation complete and settle within ~1.5s? Reference AnimationConstants values (fadeIn 0.5s easeOut, staggerDelay 30ms, staggerCap 0.5s) `[complexity:simple]`
- [x] **T5**: Create `scripts/visual-verification/evaluate-animation.sh` following the same structure as `evaluate.sh` but adapted for frame sequences: reads the animation manifest, groups frame sequences by fixture, assembles prompts with the animation PRD context, invokes Claude Code vision evaluation with the frame sequence images (selecting ~8-10 representative frames per sequence: first frame, frames at 0.1s intervals through 1.5s, and final frame), caches results, writes reports to `.rp1/work/verification/reports/`, appends audit trail `[complexity:medium]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdnTests/Fixtures/UITest/anim-{headings,blockquotes,code-swift,code-python,code-mixed,inline-code}.md` | 6 focused fixtures each isolating one element type with 5-8 blocks for stagger visibility | Done |
| T2 | `mkdnTests/UITest/VisionCompliance/AnimationVisionCapturePRD.swift` | AnimationVisionHarness singleton, AnimationVisionConfig, AnimationFrameSequenceEntry/AnimationCaptureManifest types, fixture/output path resolution, SHA-256 hashing | Done |
| T3a | `HarnessCommand.swift`, `TestHarnessHandler.swift`, `CaptureService.swift`, `FrameCaptureSession.swift`, `TestHarnessClient.swift` | Added `beginFrameCapture(fps:)`/`endFrameCapture` commands. FrameCaptureSession gets `start()`/`stop()` lifecycle methods (synchronous helpers for NSLock in async context). Existing `capture()` preserved for backward compat. Handler dispatch refactored via `processCapture()` sub-method to stay under cyclomatic complexity limit. | Done |
| T3b | `mkdnTests/UITest/VisionCompliance/AnimationVisionCaptureTests.swift` | Capture-before-load pattern: beginFrameCapture -> loadFile -> sleep(3s) -> endFrameCapture. 6 fixtures x 2 themes = 12 sequences. Resets animation state between captures. Writes manifest with per-frame SHA-256 hashes. | Done |
| T4 | `scripts/visual-verification/prompts/prd-context-animation.md` | Animation PRD context covering fade-in evaluation, stagger cascade, cover layer color correctness, code block fade bug detection, completion timing. References AnimationConstants values. | Done |
| T5 | `scripts/visual-verification/evaluate-animation.sh` | Follows evaluate.sh structure. Reads animation manifest, groups by fixture, selects ~10 representative frames per sequence (first, 0.1s intervals through 1.5s, final), cache/audit/report pipeline. | Done |

## Verification

{To be added by task-reviewer if --review flag used}
