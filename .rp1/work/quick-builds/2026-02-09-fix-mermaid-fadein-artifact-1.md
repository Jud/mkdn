# Quick Build: Fix Mermaid Fadein Artifact

**Created**: 2026-02-10T05:26:53Z
**Request**: Fix the mermaid fade-in rendering artifact in MermaidBlockView.swift. When renderState becomes .rendered, the frame instantly jumps from maxHeight:100 to full aspectRatio while opacity slowly crossfades, creating a visible empty dark backgroundSecondary rectangle during the transition.
**Scope**: Small

## Plan

**Reasoning**: Single file change (MermaidBlockView.swift), one system (Mermaid view layer), low risk (structural animation layering change with no API surface impact). Estimated under 1 hour.

**Files Affected**: `mkdn/Features/Viewer/Views/MermaidBlockView.swift`

**Approach**: The fix separates the overlay's lifecycle from the diagram's opacity transition so the spinner holds position until the diagram is fully opaque. Introduce a `@State` property `overlayDismissed` that transitions to `true` only after the crossfade animation completes (via `onAnimationCompleted` or a dispatch delay matching the crossfade duration). The overlay's visibility switches on `overlayDismissed` instead of `renderState`, so the spinner remains visible throughout the crossfade. Additionally, the frame size conditional (lines 79-88) should animate the height transition using `gentleSpring` so the container does not jump instantaneously from 100pt to full aspect ratio, further preventing exposed background. The key structural insight: in the ZStack, the overlay (spinner) must fade out AFTER the diagram reaches full opacity, not simultaneously.

**Estimated Effort**: 1 hour

## Tasks

- [x] **T1**: Add a `@State private var overlayDismissed = false` property and a helper that sets it to `true` after the crossfade animation completes (use `DispatchQueue.main.asyncAfter` with a delay matching `AnimationConstants.crossfade` duration, or use `.onChange(of: renderState)` with a `Task` + `try await Task.sleep`). Reset it when renderState changes away from `.rendered`. `[complexity:simple]`
- [x] **T2**: Refactor the `overlay` computed property to key on `overlayDismissed` instead of `renderState` for the `.rendered` case. When `renderState == .rendered` but `overlayDismissed == false`, continue showing `loadingView` (or a frozen snapshot of it). When `overlayDismissed == true`, show `EmptyView()`. The overlay's `.animation` modifier should use `.crossfade` keyed on `overlayDismissed` rather than `renderState`. `[complexity:medium]`
- [x] **T3**: Animate the frame size transition in `diagramContent` so the height change from `maxHeight: 100` to full `aspectRatio` is smooth. Wrap the frame conditional in an animation context (apply `.animation(motion.resolved(.gentleSpring), value: renderState)` to the outer `content` wrapper), or restructure to always use `aspectRatio` but clamp to `minHeight: 100` when loading. The goal is that the container never shows an empty expanded rectangle. `[complexity:medium]`
- [x] **T4**: Verify the fix compiles cleanly (`swift build`), passes SwiftLint strict mode, and passes SwiftFormat. Run `swift test --filter MermaidFadeIn` to validate the artifact is gone. `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Features/Viewer/Views/MermaidBlockView.swift` | Added `@State overlayDismissed` with `.onChange(of: renderState)` handler that sleeps 350ms (matching crossfade duration) then sets flag; resets on non-rendered states | Done |
| T2 | `mkdn/Features/Viewer/Views/MermaidBlockView.swift` | Restructured overlay to use `if/else if` on error and `!overlayDismissed`, keeping loadingView in the view tree across loading->rendered transition; keyed animation on `overlayDismissed` | Done |
| T3 | `mkdn/Features/Viewer/Views/MermaidBlockView.swift` | Replaced `if/else` conditional frame with single view using `.frame(maxHeight: .infinity/.100)` + `.aspectRatio(value/nil)` with `.animation(.gentleSpring, value: renderState)` for smooth height transition | Done |
| T4 | -- | Build clean, SwiftLint 0 violations, SwiftFormat 0 changes, `swift test --filter MermaidFadeIn` passed (57s) | Done |

## Verification

{To be added by task-reviewer if --review flag used}
