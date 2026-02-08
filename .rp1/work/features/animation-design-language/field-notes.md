# Field Notes: Animation Design Language

## T1: AnimationConstants Expansion

### Inline Animation Values Not Yet Migrated

Three source files contain inline animation timing values that are not yet referencing
AnimationConstants primitives. These were not addressed in T1 because T1's file scope
is limited to `AnimationConstants.swift`. None of these files appear in any other task's
file scope either, so they represent a gap in the task breakdown.

| File | Line | Inline Value | Maps To |
|------|------|--------------|---------|
| `mkdn/UI/Components/UnsavedIndicator.swift` | 14 | `.easeInOut(duration: 2.5).repeatForever(autoreverses: true)` | `AnimationConstants.breathe` (exact match) |
| `mkdn/Features/Editor/Views/MarkdownEditorView.swift` | 28 | `.easeInOut(duration: 0.2)` | No exact primitive; closest is `reducedCrossfade` (0.15s) |
| `mkdn/Features/Editor/Views/ResizableSplitView.swift` | 88-89 | `.easeInOut(duration: 0.15)` | `AnimationConstants.reducedCrossfade` (exact match) |

The `UnsavedIndicator` case is a trivial fix -- the inline value is identical to `breathe`.
The `ResizableSplitView` case matches `reducedCrossfade` exactly. The `MarkdownEditorView`
case at 0.2s easeInOut does not exactly match any primitive (closest are `quickFade` at
0.2s easeOut and `reducedCrossfade` at 0.15s easeInOut).

These should be addressed in a cleanup pass or added to an existing task's scope to achieve
full AC-012b compliance ("No inline animation timing values exist anywhere else in codebase").

### Legacy Alias: overlayFadeOut Behavior Change

The deprecated `overlayFadeOut` alias now returns `quickFade` (0.2s easeOut) instead of
its original value (0.3s easeOut). This subtly shortens the overlay fade-out by 100ms.
T9 will align the `ModeTransitionOverlay` with the proper primitive and update the
`overlayFadeOutDuration` scheduling constant if needed.
