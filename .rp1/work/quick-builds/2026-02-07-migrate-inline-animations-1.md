# Quick Build: Migrate Inline Animations

**Created**: 2026-02-07T00:00:00Z
**Request**: Migrate unmigrated inline animation values in 3 files to use AnimationConstants primitives. Per field-notes.md from the animation-design-language feature: UnsavedIndicator.swift has an inline animation that matches breathe, MarkdownEditorView.swift has a 0.2s easeInOut with no exact match, and ResizableSplitView.swift has values matching reducedCrossfade. Replace all inline animation timing values with references to AnimationConstants primitives. For MarkdownEditorView.swift 0.2s easeInOut, use quickFade (0.2s easeOut) or add a new primitive if the easing doesn't match.
**Scope**: Small

## Plan

**Reasoning**: 3 source files to modify, 1 system (animation/theming), low risk (replacing inline values with named constants), estimated <1.5 hours including a possible new primitive addition to AnimationConstants.swift.

**Files Affected**:
- `mkdn/UI/Components/UnsavedIndicator.swift` (line 14)
- `mkdn/Features/Editor/Views/MarkdownEditorView.swift` (line 28)
- `mkdn/Features/Editor/Views/ResizableSplitView.swift` (lines 88-89)
- `mkdn/UI/Theme/AnimationConstants.swift` (new primitive if needed)
- `mkdn/UI/Theme/MotionPreference.swift` (new primitive case if added)

**Approach**: Three replacements with different complexity levels. (1) UnsavedIndicator: trivial drop-in of `AnimationConstants.breathe` -- the inline value is identical. (2) ResizableSplitView: the `.easeInOut(duration: 0.15)` matches `reducedCrossfade` numerically, but `reducedCrossfade` is semantically an accessibility alternative, not a general-purpose animation. Add a new `subtleShift` primitive (0.15s easeInOut) for non-RM micro-transitions like divider hover/drag feedback, then use it here. Add `reducedCrossfade` as its RM fallback in MotionPreference. (3) MarkdownEditorView: the inline `.easeInOut(duration: 0.2)` is a focus border transition. The easeInOut curve is more appropriate than quickFade's easeOut because focus borders appear and disappear symmetrically. Add a new `quickShift` primitive (0.2s easeInOut) for symmetric micro-transitions, or use `quickFade` if we decide the easing difference is negligible. Given the request says "use quickFade or add a new primitive if the easing doesn't match" -- the easing does differ (easeInOut vs easeOut), so we should add a `quickShift` primitive. However, to keep the primitive count disciplined, we should evaluate whether `subtleShift` and `quickShift` are both warranted or if one suffices. Final decision: add one new primitive `quickShift` (0.2s easeInOut) for symmetric fast transitions. For ResizableSplitView at 0.15s, use `reducedCrossfade` directly since the divider feedback is genuinely a minimal-motion crossfade between hover states, or introduce `subtleShift`. Decision: use `reducedCrossfade` for the ResizableSplitView case -- the divider color crossfade between idle/hover/drag states is semantically a crossfade, and the 0.15s duration was likely chosen to be fast and subtle. The `reducedCrossfade` primitive at 0.15s easeInOut fits both semantically and numerically. Note this in a code comment.

**Estimated Effort**: 1 hour

## Tasks

- [x] **T1**: Replace inline `.easeInOut(duration: 2.5).repeatForever(autoreverses: true)` in `UnsavedIndicator.swift` (line 14) with `AnimationConstants.breathe`. This is an exact match -- no other changes needed. `[complexity:simple]`
- [x] **T2**: Add a new `quickShift` primitive to `AnimationConstants.swift` -- `.easeInOut(duration: 0.2)` -- for symmetric fast transitions (focus borders, state toggles). Add corresponding `quickShift` case to `MotionPreference.Primitive` and wire it to `reducedInstant` in the RM path. Document with the same doc-comment style as existing primitives. `[complexity:medium]`
- [x] **T3**: Replace inline `.easeInOut(duration: 0.2)` in `MarkdownEditorView.swift` (line 28) with `AnimationConstants.quickShift` (the new primitive from T2). `[complexity:simple]`
- [x] **T4**: Replace both inline `.easeInOut(duration: 0.15)` calls in `ResizableSplitView.swift` (lines 88-89) with `AnimationConstants.reducedCrossfade`. These divider hover/drag transitions are minimal-motion crossfades that match the primitive semantically and numerically. `[complexity:simple]`
- [x] **T5**: Run `swift build` and `swift test` to verify no regressions. Run SwiftLint and SwiftFormat. `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/UI/Components/UnsavedIndicator.swift` | Replaced inline `.easeInOut(duration: 2.5).repeatForever(autoreverses: true)` with `AnimationConstants.breathe` (exact match) | Done |
| T2 | `mkdn/UI/Theme/AnimationConstants.swift`, `mkdn/UI/Theme/MotionPreference.swift` | Added `quickShift` primitive (`.easeInOut(duration: 0.2)`) with full doc-comment; added `.quickShift` case to `MotionPreference.Primitive` wired to `reducedInstant` | Done |
| T3 | `mkdn/Features/Editor/Views/MarkdownEditorView.swift` | Replaced inline `.easeInOut(duration: 0.2)` with `AnimationConstants.quickShift` | Done |
| T4 | `mkdn/Features/Editor/Views/ResizableSplitView.swift` | Replaced both inline `.easeInOut(duration: 0.15)` calls with `AnimationConstants.reducedCrossfade` | Done |
| T5 | (verification) | SwiftFormat clean, build succeeds, all tests pass, SwiftLint clean on modified files | Done |

## Verification

{To be added by task-reviewer if --review flag used}
