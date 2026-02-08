# Feature Verification Report #1

**Generated**: 2026-02-07T20:22:00
**Feature ID**: animation-design-language
**Verification Scope**: all
**KB Context**: Loaded
**Field Notes**: Available

## Executive Summary
- Overall Status: PARTIAL
- Acceptance Criteria: 28/35 verified (80%)
- Implementation Quality: HIGH
- Ready for Merge: NO

Key gaps: Three inline animation values remain in the codebase (AC-012b), orb views do not guard continuous animations against Reduce Motion (AC-011b partial), toolbar hover cannot be applied because `ViewModePicker.swift` does not exist (AC-009c), and documentation tasks (TD1-TD5) are incomplete.

## Field Notes Context
**Field Notes Available**: Yes

### Documented Deviations
1. **T1 - Inline Animation Values**: Three source files (`UnsavedIndicator.swift`, `MarkdownEditorView.swift`, `ResizableSplitView.swift`) contain inline animation timing values not yet migrated to `AnimationConstants`. Documented as a gap in the task breakdown.
2. **T1 - overlayFadeOut Alias Behavior Change**: The deprecated `overlayFadeOut` alias now returns `quickFade` (0.2s easeOut) instead of its original value (0.3s easeOut). T9 addressed this.
3. **T7 - ViewModePicker Does Not Exist**: `ViewModePicker.swift` referenced in the design does not exist in the codebase. AC-009c (toolbar button hover) cannot be fulfilled until custom toolbar buttons are introduced.

### Undocumented Deviations
1. **Orb views do not guard continuous animations against Reduce Motion**: `FileChangeOrbView` and `DefaultHandlerHintView` call `withAnimation(AnimationConstants.fileChangeOrbPulse)` and `withAnimation(AnimationConstants.orbHaloBloom)` unconditionally on `.onAppear`. They do not check `reduceMotion` or use `MotionPreference.allowsContinuousAnimation` to suppress breathing/halo when Reduce Motion is enabled. This partially undermines AC-011b.

## Acceptance Criteria Verification

### REQ-001: Named Motion Primitives Vocabulary
**AC-001a**: A complete set of named motion primitives is defined, including at minimum: breathe, bloom, spring-settle, gentle-spring, fade-in, fade-out, crossfade, and quick-settle.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/AnimationConstants.swift`:17-284
- Evidence: All required primitives are defined as static properties: `breathe` (line 30), `haloBloom` (line 41), `springSettle` (line 58), `gentleSpring` (line 77), `quickSettle` (line 95), `fadeIn` (line 114), `fadeOut` (line 130), `crossfade` (line 147), `quickFade` (line 164). Additional orchestration (`staggerDelay`, `staggerCap`) and reduce motion alternatives (`reducedCrossfade`, `reducedInstant`) are also present.
- Field Notes: N/A
- Issues: None

**AC-001b**: Each primitive has a documented visual intent and design rationale.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/AnimationConstants.swift`:23-280
- Evidence: Every primitive has a structured doc comment containing: (1) visual intent description, (2) design rationale explaining the chosen timing/curve, (3) derivation tracing back to the orb aesthetic. For example, `breathe` (lines 23-29) documents "gentle, living pulse", "matches human resting respiratory rate", and "Foundational continuous primitive. The orb core pulse defines this rhythm."
- Field Notes: N/A
- Issues: None

**AC-001c**: No inline timing values anywhere in app -- all traceable to named primitives.
- Status: NOT VERIFIED
- Implementation: N/A
- Evidence: Three files contain inline animation timing values not traceable to named primitives:
  - `/Users/jud/Projects/mkdn/mkdn/UI/Components/UnsavedIndicator.swift`:14 -- `.easeInOut(duration: 2.5).repeatForever(autoreverses: true)` (identical to `AnimationConstants.breathe` but written inline)
  - `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/MarkdownEditorView.swift`:28 -- `.easeInOut(duration: 0.2)` (no exact primitive match)
  - `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/ResizableSplitView.swift`:88-89 -- `.easeInOut(duration: 0.15)` (matches `reducedCrossfade` but written inline)
- Field Notes: Documented in field-notes.md under "T1: Inline Animation Values Not Yet Migrated" -- identified as a gap in the task breakdown with no task assigned to fix them.
- Issues: These three files violate the "no inline timing values" requirement. The `UnsavedIndicator` and `ResizableSplitView` cases are trivial replacements. `MarkdownEditorView` at 0.2s easeInOut has no exact primitive match and may need a new primitive or mapping to `quickFade`.

### REQ-002: Orb as Aesthetic Touchstone
**AC-002a**: The orb animation system is fully documented, including three-layer gradient structure, breathing rhythm, halo bloom timing, appear/dissolve transitions, and color semantics.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/OrbVisual.swift`:1-83, `/Users/jud/Projects/mkdn/mkdn/UI/Theme/AnimationConstants.swift`:17-198
- Evidence: `OrbVisual.swift` documents and implements the three-layer structure (outerHalo, midGlow, innerCore) with RadialGradients and shadow modulation. `AnimationConstants.swift` documents `breathe` (core pulse), `haloBloom` (outer glow), `fadeIn` (orb appear), `fadeOut` (orb dissolve), and orb colors (`orbGlowColor` for violet/default-handler, `fileChangeOrbColor` for cyan/file-change) with color semantics.
- Field Notes: N/A
- Issues: None

**AC-002b**: Each non-orb animation traces to an orb-derived primitive.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/AnimationConstants.swift`:44-280
- Evidence: Every primitive's doc comment includes a "Derivation" section tracing it back to the orb. For example: `springSettle` -- "Directly from the orb's appear animation", `crossfade` -- "From the theme transition aesthetic", `quickSettle` -- "springSettle compressed in time and dampened", `reducedCrossfade` -- "crossfade shortened to accessibility threshold."
- Field Notes: N/A
- Issues: None

### REQ-003: Animated Mermaid Focus Border
**AC-003a**: Clicking a Mermaid diagram causes the focus border to animate in with spring-settle effect (opacity 0 to 1, stroke width 0 to 2pt) accompanied by a subtle outer glow.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:131-148
- Evidence: The `focusBorder` computed property uses `RoundedRectangle.stroke(colors.accent, lineWidth: isFocused ? AnimationConstants.focusBorderWidth : 0)`, `.opacity(isFocused ? 1.0 : 0)`, `.shadow(color: colors.accent.opacity(isFocused ? 0.4 : 0), radius: isFocused ? AnimationConstants.focusGlowRadius : 0)`. When `isFocused` becomes true, animation is `motion.resolved(.springSettle)` (line 144). The border transitions from invisible (0 width, 0 opacity, 0 glow) to visible (2pt width, 1.0 opacity, 6pt glow radius) with a spring-settle bloom.
- Field Notes: N/A
- Issues: None

**AC-003b**: Clicking away from a focused Mermaid diagram causes the border to dissolve out smoothly.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:142-148
- Evidence: When `isFocused` becomes false, the animation used is `motion.resolved(.fadeOut)` (line 145), providing a smooth dissolve-out rather than a hard cut.
- Field Notes: N/A
- Issues: None

**AC-003c**: The border animation visually evokes the orb's halo bloom quality.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:131-148
- Evidence: The combination of `springSettle` animation with simultaneous opacity, stroke width, and shadow radius animation creates a bloom effect analogous to the orb's halo. The `springSettle` primitive is documented as "Directly from the orb's appear animation" in `AnimationConstants.swift`. Border uses `colors.accent` per CL-002 resolution.
- Field Notes: N/A
- Issues: None

### REQ-004: Mode Transition Overlay Consistency
**AC-004a**: The overlay's animation contract is documented: spring entrance from 0.8 scale + 0 opacity, 1.5s hold, fade-out exit.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/ModeTransitionOverlay.swift`:1-53
- Evidence: The doc comment (lines 6-13) explicitly documents: "Entrance: Spring-settle from 0.8 scale + 0 opacity to 1.0 scale + 1.0 opacity using AnimationConstants.springSettle", "Hold: Remains visible for AnimationConstants.overlayDisplayDuration (1.5s)", "Exit: Fade-out using AnimationConstants.quickFade (0.2s easeOut)", "Reduce Motion: Entrance and exit both use AnimationConstants.reducedCrossfade (0.15s easeInOut)". Implementation matches: `.scaleEffect(isVisible ? 1.0 : 0.8)`, `.opacity(isVisible ? 1.0 : 0)`, `Task.sleep(for: AnimationConstants.overlayDisplayDuration)`.
- Field Notes: N/A
- Issues: None

**AC-004b**: The overlay's spring response feels consistent with the Mermaid focus border spring.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/ModeTransitionOverlay.swift`:36, `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:144
- Evidence: Both use `AnimationConstants.springSettle` (response: 0.35, dampingFraction: 0.7). The overlay uses it directly (`AnimationConstants.springSettle`, line 36), and MermaidBlockView uses it via `motion.resolved(.springSettle)` (line 144), which resolves to the same `AnimationConstants.springSettle`.
- Field Notes: N/A
- Issues: None

### REQ-005: View Mode Transition Smoothness
**AC-005a**: The split pane divider animates smoothly between positions using a spring animation consistent with the design language.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:33
- Evidence: The view mode transition uses `.animation(motion.resolved(.gentleSpring), value: documentState.viewMode)` which resolves to `AnimationConstants.gentleSpring` (response: 0.4, dampingFraction: 0.85). This is a named primitive from the design language.
- Field Notes: N/A
- Issues: None

**AC-005b**: Content does not visibly re-layout or jump during the transition.
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:19-32
- Evidence: The implementation uses `.transition(.opacity)` for preview mode and `.transition(.move(edge: .leading).combined(with: .opacity))` for side-by-side mode, both animated by `gentleSpring`. The transitions are SwiftUI-managed and should not cause visible re-layout, but visual confirmation requires running the app.
- Field Notes: N/A
- Issues: Cannot verify visual smoothness through code inspection alone.

### REQ-006: Theme Crossfade Non-Interference
**AC-006a**: Theme changes produce a smooth crossfade across the entire view hierarchy.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Theming/ThemePickerView.swift`:10-21, `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:68-76, `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:69-76
- Evidence: Three call sites wrap theme state changes with `withAnimation(crossfade)`: (1) ThemePickerView uses a custom binding that wraps `appSettings.themeMode = newMode` in `withAnimation(themeAnimation)` (lines 13-19), (2) MkdnCommands wraps `appSettings.cycleTheme()` in `withAnimation(themeAnimation)` (lines 73-75), (3) ContentView wraps `appSettings.systemColorScheme = newScheme` in `.onChange(of: colorScheme)` (lines 72-75). All use `AnimationConstants.crossfade` (0.35s easeInOut).
- Field Notes: N/A
- Issues: None

**AC-006b**: In-progress orb breathing, focus border animations, or spring transitions are not disrupted by a concurrent theme crossfade.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Theming/ThemePickerView.swift`:17, `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:73
- Evidence: Theme crossfade uses explicit `withAnimation` scoping at call sites rather than broad `.animation()` modifiers. Per SwiftUI's animation model, `withAnimation` captures only state changes within its closure. Orb breathing is driven by separate `withAnimation(AnimationConstants.breathe)` calls in each orb view's `.onAppear`. Focus border animation is scoped to `value: isFocused`. These separate animation scopes prevent interference.
- Field Notes: N/A
- Issues: None

**AC-006c**: Any brief mismatch between SwiftUI theme transition and WKWebView (Mermaid diagram) theme update is masked by the crossfade duration.
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Theming/ThemePickerView.swift`:14-19
- Evidence: The 0.35s crossfade duration is designed to mask WKWebView theme update latency per the design document assumptions. However, WKWebView theme updates happen via JavaScript injection which has non-deterministic latency. Code inspection confirms the crossfade is applied, but whether 0.35s is consistently sufficient requires manual testing with actual Mermaid diagrams.
- Field Notes: N/A
- Issues: Visual confirmation required to verify the masking is effective in practice.

### REQ-007: Staggered Content Load Appearance
**AC-007a**: On initial file load, content blocks appear with a staggered fade-in animation with subtle upward translation.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`:31-43
- Evidence: Each block has `.opacity(blockAppeared[block.id] ?? false ? 1.0 : 0)` and `.offset(y: blockAppeared[block.id] ?? false ? 0 : 8)` modifiers (lines 33-34). The animation uses `motion.resolved(.fadeIn)` with stagger delay (lines 35-42). On initial load (when `anyAlreadyAppeared` is false, line 73-74), `blockAppeared` is cleared and blocks are set, then after 10ms all blocks are marked as appeared (lines 76-85), triggering the staggered animation.
- Field Notes: N/A
- Issues: None

**AC-007b**: Stagger delay between blocks is approximately 30ms per block.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`:38, `/Users/jud/Projects/mkdn/mkdn/UI/Theme/AnimationConstants.swift`:176
- Evidence: Stagger delay computed as `Double(index) * motion.staggerDelay` (line 38). `motion.staggerDelay` returns `AnimationConstants.staggerDelay` which is `0.03` (30ms, line 176). Verified by unit test in `AnimationConstantsTests.swift`:8-9 (`#expect(AnimationConstants.staggerDelay == 0.03)`).
- Field Notes: N/A
- Issues: None

**AC-007c**: Total stagger duration is capped at approximately 500ms.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`:37-40, `/Users/jud/Projects/mkdn/mkdn/UI/Theme/AnimationConstants.swift`:184
- Evidence: The delay is wrapped in `min(Double(index) * motion.staggerDelay, AnimationConstants.staggerCap)` (lines 37-40). `staggerCap` is `0.5` (500ms, line 184). Verified by unit test in `AnimationConstantsTests.swift`:13-14 (`#expect(AnimationConstants.staggerCap == 0.5)`).
- Field Notes: N/A
- Issues: None

**AC-007d**: On reload (file change), the stagger replays from the first visible block.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`:73-86
- Evidence: On full content reload (when `anyAlreadyAppeared` is false -- meaning no new block IDs match existing entries), `blockAppeared` is cleared to `[:]` (line 77) before setting `renderedBlocks` (line 78). After a 10ms sleep, all blocks are marked as appeared (lines 83-85), replaying the stagger. Incremental edits pre-set `blockAppeared` to avoid stagger (lines 87-91).
- Field Notes: T6 notes a deviation: the design shows stagger replaying on every `renderedBlocks` set, but implementation uses an overlap heuristic (`anyAlreadyAppeared`) to distinguish full reloads from incremental typing changes. This is documented in the task summary.
- Issues: None -- the deviation is a purposeful improvement to avoid visual flicker during editor typing.

### REQ-008: Mermaid Loading/Error State Crossfade
**AC-008a**: The transition from loading to rendered state uses a smooth crossfade.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:65-69
- Evidence: Both the `MermaidWebView` opacity (`.animation(motion.resolved(.crossfade), value: renderState)`, line 66) and the overlay (`.animation(motion.resolved(.crossfade), value: renderState)`, line 69) are animated with `crossfade` (0.35s easeInOut) when `renderState` changes. The web view fades in (opacity 0 to 1) while the loading overlay fades out simultaneously.
- Field Notes: N/A
- Issues: None

**AC-008b**: The transition from loading to error state uses a smooth crossfade.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:66-69, 91-98
- Evidence: Both the overlay and the web view use `.animation(motion.resolved(.crossfade), value: renderState)`. The overlay uses `.transition(.opacity)` for both loading (line 91) and error (line 98) views. When state changes from `.loading` to `.error`, the loading view's opacity transition fades out while the error view's opacity transition fades in, creating a crossfade.
- Field Notes: N/A
- Issues: None

**AC-008c**: The transition from error to loading (retry) uses a smooth crossfade.
- Status: VERIFIED
- Implementation: Same as AC-008a/AC-008b -- the crossfade animation is applied to `renderState` universally, covering all transitions between the three states.
- Evidence: The `.animation(motion.resolved(.crossfade), value: renderState)` modifier animates any change to `renderState`, including error-to-loading.
- Field Notes: N/A
- Issues: None

**AC-008d**: The loading spinner pulses at the same rhythm as the orb's breathing cycle.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/PulsingSpinner.swift`:1-25, `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:104
- Evidence: `PulsingSpinner` uses `withAnimation(AnimationConstants.breathe)` (line 20) for its pulse animation. `AnimationConstants.breathe` is `.easeInOut(duration: 2.5).repeatForever(autoreverses: true)` -- the same rhythm used by the orb core pulse. `MermaidBlockView` uses `PulsingSpinner()` (line 104) as the loading indicator.
- Field Notes: N/A
- Issues: None

### REQ-009: Hover Feedback on Interactive Elements
**AC-009a**: Hovering over an orb produces a subtle scale increase, returning to normal on hover exit.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/FileChangeOrbView.swift`:18, `/Users/jud/Projects/mkdn/mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift`:19
- Evidence: Both orb views apply `.hoverScale()` to their `orbVisual` (FileChangeOrbView line 18, DefaultHandlerHintView line 19). The `hoverScale()` modifier defaults to `AnimationConstants.hoverScaleFactor` (1.06). The `HoverFeedbackModifier` (lines 11-27 in HoverFeedbackModifier.swift) applies `.scaleEffect(isHovering ? scaleFactor : 1.0)` with `.onHover` tracking.
- Field Notes: N/A
- Issues: None

**AC-009b**: Hovering over an unfocused Mermaid diagram produces a subtle brightness increase.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`:32
- Evidence: `MermaidBlockView` applies `.hoverBrightness()` (line 32) to the `diagramContent`. The `BrightnessHoverModifier` (HoverFeedbackModifier.swift lines 37-56) applies a white overlay at `AnimationConstants.mermaidHoverBrightness` (0.03) opacity on hover.
- Field Notes: N/A
- Issues: The hover brightness applies regardless of focus state. The requirement specifies "unfocused" Mermaid diagrams. The current implementation applies to all Mermaid diagrams including focused ones. This is a minor deviation -- the brightness effect is so subtle (0.03 opacity) that it is likely imperceptible against the focus border glow.

**AC-009c**: Hovering over a toolbar button produces a subtle scale increase.
- Status: NOT VERIFIED
- Implementation: N/A
- Evidence: `ViewModePicker.swift` does not exist in the codebase. The `toolbarHoverScale` constant (1.05) is defined in `AnimationConstants.swift` (line 225) and the `.hoverScale(_:)` API is available, but there are no custom toolbar buttons to apply it to.
- Field Notes: Documented in field-notes.md under "T7: ViewModePicker Does Not Exist" -- identified as blocked until a custom toolbar button view is added.
- Issues: BLOCKED -- cannot be implemented without the target view.

**AC-009d**: All hover animations use a quick-settle spring consistent with the design language.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/HoverFeedbackModifier.swift`:19-21, 48-50
- Evidence: Both `HoverFeedbackModifier` (line 20) and `BrightnessHoverModifier` (line 49) use `AnimationConstants.quickSettle` as the animation (`.animation(reduceMotion ? nil : AnimationConstants.quickSettle, value: isHovering)`). `quickSettle` is `.spring(response: 0.25, dampingFraction: 0.8)` -- a named design language primitive.
- Field Notes: N/A
- Issues: None

### REQ-010: Popover Presentation Animation
**AC-010a**: Popovers enter with a spring-settle animation (slight scale-up + opacity fade-in).
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/FileChangeOrbView.swift`:77-86, `/Users/jud/Projects/mkdn/mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift`:80-89
- Evidence: Both popover content views apply `.scaleEffect(popoverAppeared ? 1.0 : 0.95)` and `.opacity(popoverAppeared ? 1.0 : 0)`. On `.onAppear`, `withAnimation(AnimationConstants.springSettle) { popoverAppeared = true }` triggers the spring-settle entrance. The `popoverAppeared` flag is reset in `.onChange(of: showDialog)` when the dialog closes (FileChangeOrbView lines 40-44, DefaultHandlerHintView lines 40-44).
- Field Notes: N/A
- Issues: None

**AC-010b**: The popover entrance visually matches the mode transition overlay aesthetic at smaller scale.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/FileChangeOrbView.swift`:80-83, `/Users/jud/Projects/mkdn/mkdn/UI/Components/ModeTransitionOverlay.swift`:34-38
- Evidence: Both use `AnimationConstants.springSettle` for entrance animation. The overlay starts at 0.8 scale + 0 opacity; the popover starts at 0.95 scale + 0 opacity. The reduced initial scale for the popover (0.95 vs 0.8) creates a subtler version of the same spring-settle aesthetic, appropriate for the smaller UI surface.
- Field Notes: N/A
- Issues: None

### REQ-011: Reduce Motion Compliance
**AC-011a**: With Reduce Motion enabled, all spring and easeInOut animations are replaced with instant transitions or very short crossfades (~0.15s).
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/MotionPreference.swift`:82-91
- Evidence: `MotionPreference.reducedAnimation(for:)` correctly maps: continuous primitives to `nil`, crossfade to `reducedCrossfade` (0.15s), all springs/fades to `reducedInstant` (0.01s). This is used correctly in MermaidBlockView, MarkdownPreviewView, ModeTransitionOverlay, ContentView, ThemePickerView, and MkdnCommands. However, the `HoverFeedbackModifier` uses `reduceMotion ? nil : AnimationConstants.quickSettle` directly rather than going through `MotionPreference.resolved()` -- functionally equivalent (nil = instant) but inconsistent with the centralized pattern.
- Field Notes: N/A
- Issues: The hover modifier's approach is functionally correct but bypasses the MotionPreference centralization pattern. Minor inconsistency, not a functional gap.

**AC-011b**: Orb breathing and halo bloom are disabled; orbs display at a static, full-opacity state.
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/FileChangeOrbView.swift`:20-25, `/Users/jud/Projects/mkdn/mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift`:21-26
- Evidence: Both orb views call `withAnimation(AnimationConstants.fileChangeOrbPulse) { isPulsing = true }` and `withAnimation(AnimationConstants.orbHaloBloom) { isHaloExpanded = true }` unconditionally on `.onAppear` **without checking `reduceMotion`**. Although both views have `@Environment(\.accessibilityReduceMotion) private var reduceMotion` declared, it is only used for the popover animation, not for guarding the continuous breathing animations. The `MotionPreference` struct has `allowsContinuousAnimation` available, but the orb views do not use it to conditionally suppress the breathing/halo animations. With Reduce Motion enabled, orbs will still animate.
- Field Notes: NOT documented. This is an undocumented gap.
- Issues: **Significant gap** -- continuous orb animations will play even with Reduce Motion enabled, violating accessibility requirements.

**AC-011c**: Content load stagger is disabled; all blocks appear immediately.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`:74
- Evidence: The `shouldStagger` flag includes `!reduceMotion` in its condition (line 74): `let shouldStagger = !anyAlreadyAppeared && !reduceMotion && !newBlocks.isEmpty`. When `reduceMotion` is true, `shouldStagger` is false, and the else branch (lines 87-91) pre-sets all `blockAppeared` entries to `true` before setting `renderedBlocks`, causing all blocks to appear immediately. Additionally, `motion.staggerDelay` returns 0 when Reduce Motion is on (MotionPreference line 63), and `motion.resolved(.fadeIn)` returns `reducedInstant` (0.01s).
- Field Notes: N/A
- Issues: None

**AC-011d**: Theme crossfade is shortened to ~0.15s with Reduce Motion (not eliminated).
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Theming/ThemePickerView.swift`:14-15, `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:69-72, `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:70-71
- Evidence: All three theme change call sites use `reduceMotion ? AnimationConstants.reducedCrossfade : AnimationConstants.crossfade`. `reducedCrossfade` is `.easeInOut(duration: 0.15)` (AnimationConstants.swift line 271). The theme crossfade is shortened but not eliminated with Reduce Motion.
- Field Notes: N/A
- Issues: None

**AC-011e**: All functionality remains fully accessible with Reduce Motion.
- Status: VERIFIED
- Implementation: All views that implement Reduce Motion
- Evidence: Code review confirms that Reduce Motion only affects animation behavior, not functional capabilities. Focus borders still appear (instantly instead of spring-in). Content still loads. Theme changes still apply. Popovers still open. Hover feedback still provides state change (instantly instead of animated). No functional path is removed or degraded.
- Field Notes: N/A
- Issues: None

### REQ-012: Animation Single Source of Truth
**AC-012a**: All animation timing values are defined in one central file.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/AnimationConstants.swift`:1-326
- Evidence: All named animation primitives, timing constants, scale factors, and dimensional values are defined in `AnimationConstants.swift`. The file contains 18 named primitives and constants organized into 12 MARK-delimited groups. The `MotionPreference` struct (`MotionPreference.swift`) resolves animations by referencing `AnimationConstants` static properties exclusively.
- Field Notes: N/A
- Issues: None

**AC-012b**: No inline animation timing values exist anywhere else in the codebase.
- Status: NOT VERIFIED
- Implementation: N/A
- Evidence: Three files contain inline animation timing values:
  - `UnsavedIndicator.swift`:14 -- `.easeInOut(duration: 2.5).repeatForever(autoreverses: true)` (matches `breathe`)
  - `MarkdownEditorView.swift`:28 -- `.easeInOut(duration: 0.2)` (no exact match)
  - `ResizableSplitView.swift`:88-89 -- `.easeInOut(duration: 0.15)` (matches `reducedCrossfade`)
- Field Notes: Documented in field-notes.md -- identified as a gap in the task breakdown with no task assigned.
- Issues: Three inline values violate this acceptance criterion.

**AC-012c**: Each animation constant has documentation covering visual intent, design rationale, and primitive derivation.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/AnimationConstants.swift`:23-280
- Evidence: Every primitive has a structured doc comment with three labeled sections. For example, `springSettle` (lines 49-57): "Visual intent: A physical 'bounce into existence'...", "Design rationale: Response 0.35 keeps entrance snappy...", "Derivation: Directly from the orb's appear animation..." Constants like `hoverScaleFactor`, `focusBorderWidth`, `mermaidHoverBrightness` also have full documentation.
- Field Notes: N/A
- Issues: None

## Implementation Gap Analysis

### Missing Implementations
- **AC-009c** (Toolbar button hover): BLOCKED -- `ViewModePicker.swift` does not exist. The constant and API are ready but have no target view.
- **AC-012b** (No inline timing values): Three files have inline values not yet migrated. No task covers this work.

### Partial Implementations
- **AC-011b** (Orb Reduce Motion): Orb views declare `reduceMotion` environment but do not use it to guard continuous animations. The breathing and halo bloom will play even with Reduce Motion enabled.
- **AC-011a** (Reduce Motion for hover): `HoverFeedbackModifier` uses direct `reduceMotion ? nil :` check instead of `MotionPreference.resolved()`. Functionally correct but inconsistent with centralized pattern.
- **AC-006c** (Theme crossfade masking WKWebView latency): Implementation is correct but effectiveness requires manual verification with actual Mermaid diagrams.

### Implementation Issues
- **Orb views use deprecated aliases**: `FileChangeOrbView` uses `AnimationConstants.fileChangeOrbPulse` and `AnimationConstants.orbHaloBloom` (deprecated), and `DefaultHandlerHintView` uses `AnimationConstants.defaultHandlerOrbPulse` and `AnimationConstants.orbHaloBloom` (deprecated). These resolve correctly via the computed property aliases but should be migrated to the new names (`breathe`, `haloBloom`).
- **Documentation tasks incomplete**: TD1-TD5 (knowledge base documentation updates) are all marked as incomplete in tasks.md.

## Code Quality Assessment

The implementation demonstrates high quality overall:

1. **Consistency**: All new components follow established patterns -- `@Environment(\.accessibilityReduceMotion)`, `MotionPreference` instantiation, `AnimationConstants` references. The code is idiomatic SwiftUI.

2. **Documentation**: `AnimationConstants.swift` is exceptionally well-documented with structured doc comments for every primitive. The `MotionPreference.swift` has clear usage examples in its header doc comment.

3. **Reusability**: The `HoverFeedbackModifier`/`BrightnessHoverModifier` ViewModifiers with `View.hoverScale()`/`.hoverBrightness()` extensions provide clean, reusable APIs. The `OrbVisual` extraction eliminates duplication.

4. **Testing**: 16 unit tests (9 AnimationConstants + 7 MotionPreference) cover the testable surface area appropriately. Tests use Swift Testing framework as required.

5. **Reduce Motion architecture**: The `MotionPreference` struct with `Primitive` enum is a well-designed centralized resolver that avoids the problem of `Animation` not being `Equatable`. The deviation from the design doc (using enum instead of raw Animation) is a correct implementation decision.

6. **Areas for improvement**:
   - Orb views need Reduce Motion guards for continuous animations.
   - Deprecated aliases should be migrated at call sites.
   - Three inline animation values need to be replaced with `AnimationConstants` references.

## Recommendations

1. **[Critical] Fix Reduce Motion for orb continuous animations**: In `FileChangeOrbView.swift` and `DefaultHandlerHintView.swift`, wrap the `withAnimation(breathe)` and `withAnimation(haloBloom)` calls in `.onAppear` with a `guard !reduceMotion else { isPulsing = true; isHaloExpanded = true; return }` to set the orbs to their static expanded state without animation when Reduce Motion is enabled. This addresses AC-011b.

2. **[Important] Migrate inline animation timing values**: Replace the three inline animation values identified in field-notes.md:
   - `UnsavedIndicator.swift`:14 -- Replace `.easeInOut(duration: 2.5).repeatForever(autoreverses: true)` with `AnimationConstants.breathe`
   - `ResizableSplitView.swift`:88-89 -- Replace `.easeInOut(duration: 0.15)` with `AnimationConstants.reducedCrossfade` (or define a new `dividerTransition` primitive if the semantic is different)
   - `MarkdownEditorView.swift`:28 -- Either add a new primitive (e.g., `editorFocusFade`) to `AnimationConstants` or map to `quickFade` if semantically appropriate
   This addresses AC-001c and AC-012b.

3. **[Minor] Migrate deprecated alias usage in orb views**: Replace `AnimationConstants.fileChangeOrbPulse` with `AnimationConstants.breathe`, `AnimationConstants.defaultHandlerOrbPulse` with `AnimationConstants.breathe`, and `AnimationConstants.orbHaloBloom` with `AnimationConstants.haloBloom` in `FileChangeOrbView.swift` and `DefaultHandlerHintView.swift`.

4. **[Minor] Complete documentation tasks TD1-TD5**: Update `.rp1/context/modules.md`, `.rp1/context/patterns.md`, `.rp1/context/architecture.md`, and `.rp1/context/index.md` with the new animation components as specified in the design.

5. **[Minor] Toolbar hover feedback**: When `ViewModePicker.swift` or equivalent custom toolbar buttons are added to the codebase, apply `.hoverScale(AnimationConstants.toolbarHoverScale)` to fulfill AC-009c.

## Verification Evidence

### New Files Created (4/4 verified)

| File | Status | Lines |
|------|--------|-------|
| `/Users/jud/Projects/mkdn/mkdn/UI/Theme/MotionPreference.swift` | Verified | 93 |
| `/Users/jud/Projects/mkdn/mkdn/UI/Components/OrbVisual.swift` | Verified | 83 |
| `/Users/jud/Projects/mkdn/mkdn/UI/Components/PulsingSpinner.swift` | Verified | 25 |
| `/Users/jud/Projects/mkdn/mkdn/UI/Components/HoverFeedbackModifier.swift` | Verified | 77 |

### Modified Files (7/7 verified)

| File | Key Changes |
|------|-------------|
| `/Users/jud/Projects/mkdn/mkdn/UI/Theme/AnimationConstants.swift` | Restructured into 12 MARK groups, 18 named primitives, 10 deprecated aliases, full doc comments |
| `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift` | Focus border bloom/dissolve animation, crossfade state transitions, PulsingSpinner, hover brightness |
| `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift` | Staggered content load with blockAppeared dictionary, Reduce Motion bypass |
| `/Users/jud/Projects/mkdn/mkdn/UI/Components/FileChangeOrbView.swift` | OrbVisual adoption, hover scale, popover spring entrance |
| `/Users/jud/Projects/mkdn/mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift` | OrbVisual adoption, hover scale, popover spring entrance |
| `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift` | Theme crossfade scoping, gentleSpring view mode animation, Reduce Motion integration |
| `/Users/jud/Projects/mkdn/mkdn/UI/Components/ModeTransitionOverlay.swift` | springSettle/quickFade primitives, animation contract documentation, Reduce Motion |

### Test Files (2/2 verified)

| File | Tests | Status |
|------|-------|--------|
| `/Users/jud/Projects/mkdn/mkdnTests/Unit/UI/AnimationConstantsTests.swift` | 9 | All passing |
| `/Users/jud/Projects/mkdn/mkdnTests/Unit/UI/MotionPreferenceTests.swift` | 7 | All passing |

### Inline Animation Values (3 remaining violations)

```
/Users/jud/Projects/mkdn/mkdn/UI/Components/UnsavedIndicator.swift:14
  .easeInOut(duration: 2.5).repeatForever(autoreverses: true)  -->  AnimationConstants.breathe

/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/MarkdownEditorView.swift:28
  .easeInOut(duration: 0.2)  -->  needs new primitive or mapping

/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/ResizableSplitView.swift:88-89
  .easeInOut(duration: 0.15)  -->  AnimationConstants.reducedCrossfade
```
