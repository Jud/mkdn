# Quick Build: Fix Codeblock Entrance Anim

**Created**: 2026-02-09T12:00:00Z
**Request**: Fix code block entrance animation so the entire code block (background + border + text) fades in together, not just the text.
**Scope**: Small

## Plan

**Reasoning**: 1 file to modify (EntranceAnimator.swift), 1 system (entrance animation), medium risk (visual regression possible but change is well-isolated). The root cause is clearly identified: cover layers use per-fragment sizing with code-block background color, but the code block container (background + border) drawn by CodeBlockBackgroundTextView is not covered, so it pops in at full opacity while only text fades.

**Files Affected**:
- `mkdn/Features/Viewer/Views/EntranceAnimator.swift` (modify)
- `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` (reference only, for bounding rect computation)
- `mkdn/Core/Markdown/CodeBlockAttributes.swift` (reference only, for attribute keys)

**Approach**: Modify `EntranceAnimator` to detect code block fragments and produce a single full-width cover layer per code block (matching `CodeBlockBackgroundTextView.drawCodeBlockContainers` sizing) colored with the document background (not the code block background). This hides both the code block container and the text, so the entire block fades in as a unit. Multiple fragments within the same code block must share one cover layer (deduplicated by block ID) to avoid gaps between fragment covers revealing the background underneath. Non-code-block fragments continue using the existing per-fragment cover logic unchanged.

**Estimated Effort**: 1-2 hours

## Tasks

- [x] **T1**: Add code block detection and block-ID grouping to `animateVisibleFragments` -- enumerate all fragments, detect which belong to a code block via `CodeBlockAttributes.range`, group fragments by block ID, and collect their bounding rects into a union rect per block `[complexity:medium]`
- [x] **T2**: Create `makeCodeBlockCoverLayer` that builds a single cover layer per code block spanning the full container width (matching `CodeBlockBackgroundTextView` geometry: `x = origin.x`, `width = containerWidth`, `y/height` from union of fragment frames), colored with `textView.backgroundColor` (document background) `[complexity:medium]`
- [x] **T3**: Refactor `animateFragment` to skip individual cover creation for code-block fragments (they get the shared block cover from T2), and wire the new code block cover layers into the stagger sequence and cleanup lifecycle `[complexity:medium]`
- [x] **T4**: Build and visually verify the fix renders correctly -- code blocks should fade in as a complete unit (background + border + text together), non-code-block content should animate unchanged `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `EntranceAnimator.swift` | Added `codeBlockID()` method and `CodeBlockGroup` struct; `animateVisibleFragments` now detects code block fragments via `CodeBlockAttributes.range` and groups them by block ID | Done |
| T2 | `EntranceAnimator.swift` | Added `makeCodeBlockCoverLayer(frames:in:)` that creates a single full-width cover layer per code block using union of fragment frames, `textView.backgroundColor`, and 1pt margin to cover border stroke | Done |
| T3 | `EntranceAnimator.swift` | Replaced per-fragment `animateFragment` with inline logic in `animateVisibleFragments`; code block fragments skip individual covers; extracted `addCodeBlockCovers` and `staggerDelay(for:)` helpers; simplified `makeCoverLayer` to always use document background | Done |
| T4 | `EntranceAnimator.swift` | Build passes, SwiftFormat clean, SwiftLint clean, 8/8 CodeBlock unit tests pass, all pre-existing test failures unchanged | Done |

## Verification

{To be added by task-reviewer if --review flag used}
