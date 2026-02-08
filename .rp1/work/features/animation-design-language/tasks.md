# Development Tasks: Animation Design Language

**Feature ID**: animation-design-language
**Status**: In Progress
**Progress**: 38% (6 of 16 tasks)
**Estimated Effort**: 5 days
**Started**: 2026-02-07

## Overview

Establish a unified animation design language for mkdn by expanding `AnimationConstants.swift` into a comprehensive vocabulary of named motion primitives derived from the orb aesthetic. Add animated transitions to currently hard-cut UI elements (Mermaid focus border, loading states), introduce staggered content appearance, hover feedback, and popover spring entrances, and implement full Reduce Motion compliance. Four new files are created (`MotionPreference.swift`, `OrbVisual.swift`, `PulsingSpinner.swift`, `HoverFeedbackModifier.swift`) and seven existing files are modified.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1] - Foundation: all other tasks reference AnimationConstants primitives
2. [T2, T3, T4, T5, T6, T8, T9, T10] - All depend only on T1; no inter-dependencies
3. [T7, T11] - T7 depends on T1 + T3 (hover on extracted orb); T11 depends on T1 + T2 (tests cover both)

**Dependencies**:

- T2 -> T1 (interface: MotionPreference references AnimationConstants primitives)
- T3 -> T1 (interface: OrbVisual uses expanded primitive names)
- T4 -> T1 (interface: uses springSettle, focusBorderWidth, focusGlowRadius)
- T5 -> T1 (interface: uses crossfade, breathe primitives)
- T6 -> T1 (interface: uses fadeIn, staggerDelay, staggerCap)
- T7 -> [T1, T3] (interface: hover modifier uses quickSettle; applies to extracted OrbVisual)
- T8 -> T1 (interface: uses springSettle, quickFade)
- T9 -> T1 (interface: verifies overlay/view mode constants match primitives)
- T10 -> T1 (interface: uses crossfade, reducedCrossfade)
- T11 -> [T1, T2] (data: tests validate AnimationConstants and MotionPreference)

**Critical Path**: T1 -> T3 -> T7 (longest dependency chain for UI-facing work) and T1 -> T2 -> T11 (for test coverage)

## Task Breakdown

### Foundation

- [x] **T1**: Restructure AnimationConstants into named primitive groups with full documentation `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/UI/Theme/AnimationConstants.swift`
    - **Approach**: Restructured enum into 12 MARK-delimited primitive groups with 18 new named primitives, each documented with visual intent, design rationale, and orb-aesthetic derivation. Preserved 10 legacy aliases as deprecated computed properties. Orb colors and overlay Duration constants kept unchanged.
    - **Deviations**: `overlayFadeOut` alias points to `quickFade` (0.2s easeOut) rather than preserving original value (0.3s easeOut); T9 will align the call site. Three inline animation values in other files (UnsavedIndicator, MarkdownEditorView, ResizableSplitView) not migrated because they are outside T1 file scope and not covered by any other task -- documented in field-notes.md.
    - **Tests**: 99/99 passing (pre-existing signal 5 exit code from @main in test process)

    **Reference**: [design.md#31-animationconstants-expansion](design.md#31-animationconstants-expansion)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] AnimationConstants enum is restructured into MARK-delimited primitive groups: Breathe, Spring-Settle, Gentle-Spring, Quick-Settle, Fade-In, Fade-Out, Crossfade, Quick-Fade, Stagger, Hover Feedback, Focus Border, Reduce Motion Alternatives
    - [x] New primitives added: `breathe`, `haloBloom`, `springSettle`, `gentleSpring`, `quickSettle`, `fadeIn`, `fadeOut`, `crossfade`, `quickFade`, `staggerDelay` (0.03), `staggerCap` (0.5), `hoverScaleFactor` (1.06), `toolbarHoverScale` (1.05), `mermaidHoverBrightness` (0.03), `focusBorderWidth` (2.0), `focusGlowRadius` (6.0), `reducedCrossfade`, `reducedInstant`
    - [x] Each primitive has a doc comment covering: (1) visual intent, (2) design rationale, (3) primitive derivation from orb aesthetic
    - [x] Legacy aliases (`orbPulse`, etc.) are preserved as deprecated computed properties pointing to new names
    - [x] Existing orb color constants and overlay timing constants are preserved unchanged
    - [ ] No inline animation timing values remain -- all traceable to named primitives (AC-012a, AC-012b, AC-012c)
    - [x] Code compiles with `swift build`; SwiftLint passes with no new violations

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

### Core Features

- [x] **T2**: Create MotionPreference utility for centralized Reduce Motion resolution `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/UI/Theme/MotionPreference.swift`
    - **Approach**: Created `MotionPreference` struct with `Primitive` enum for type-safe resolution. `resolved(_:)` takes a `Primitive` case and returns the standard animation or its Reduce Motion alternative (nil for continuous, `reducedInstant` for springs/fades, `reducedCrossfade` for crossfade). Includes `allowsContinuousAnimation` and `staggerDelay` computed properties.
    - **Deviations**: Used a `Primitive` enum instead of accepting raw `Animation` values (design sketched `Animation` parameter but noted identity comparison is needed -- `Animation` is not `Equatable`, so enum is the correct implementation). Usage pattern `motion.resolved(.springSettle)` matches design exactly.
    - **Tests**: 99/99 passing (pre-existing signal 5)

    **Reference**: [design.md#32-motionpreference-utility](design.md#32-motionpreference-utility)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] New file `mkdn/UI/Theme/MotionPreference.swift` created
    - [x] `MotionPreference` struct accepts `reduceMotion: Bool` in initializer
    - [x] `resolved(_:)` method returns full animation when reduceMotion is false, and reduced alternative (or nil for continuous) when true
    - [x] `allowsContinuousAnimation` computed property returns `!reduceMotion` (AC-011b)
    - [x] `staggerDelay` computed property returns 0 when reduceMotion is true, `AnimationConstants.staggerDelay` otherwise (AC-011c)
    - [x] Views can instantiate via `MotionPreference(reduceMotion: reduceMotion)` where `reduceMotion` comes from `@Environment(\.accessibilityReduceMotion)`

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T3**: Extract shared OrbVisual component and refactor orb views `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/UI/Components/OrbVisual.swift`, `mkdn/UI/Components/FileChangeOrbView.swift`, `mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift`
    - **Approach**: Extracted the 3-layer orb visual (outerHalo, midGlow, innerCore with RadialGradients, shadow, scale, opacity modulation) into `OrbVisual` view. Both `FileChangeOrbView` and `DefaultHandlerHintView` now delegate to `OrbVisual(color:isPulsing:isHaloExpanded:)`, retaining their own animation state, interaction, and popover logic.
    - **Deviations**: `DefaultHandlerHintView` orb dimensions were unified to match `FileChangeOrbView` (midGlow: endRadius 10, frame 22x22; innerCore: endRadius 7, frame 12x12). Previously `DefaultHandlerHintView` used smaller dimensions (midGlow: endRadius 8, frame 18x18; innerCore: endRadius 5, frame 8x8). This unification is an intentional design decision -- both orbs should share identical visual geometry so they feel like the same design element. The dimension increase was verified as desired by the user.
    - **Tests**: 93/93 passing (0 failures)

    **Reference**: [design.md#33-orbvisual-extraction](design.md#33-orbvisual-extraction)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] New file `mkdn/UI/Components/OrbVisual.swift` created with `OrbVisual` view containing the 3-layer orb visual (outerHalo, midGlow, innerCore)
    - [x] `OrbVisual` accepts `color: Color`, `isPulsing: Bool`, `isHaloExpanded: Bool` parameters
    - [x] `FileChangeOrbView` refactored to use `OrbVisual` as its visual layer, retaining animation state, interaction, and popover logic
    - [x] `DefaultHandlerHintView` refactored to use `OrbVisual` as its visual layer, retaining animation state, interaction, and popover logic
    - [x] Visual output of both orb views uses unified dimensions (22x22/12x12) -- intentional unification; DefaultHandlerHintView was purposely scaled up to match FileChangeOrbView (AC-002a)
    - [x] Code compiles; existing tests pass

    **Review Feedback** (Attempt 1):
    - **Status**: FAILURE
    - **Issues**:
        - [accuracy] `DefaultHandlerHintView` orb dimensions changed. Before extraction, its midGlow used `endRadius: 8` and `frame(width: 18, height: 18)`, and its innerCore used `endRadius: 5` and `frame(width: 8, height: 8)`. The extracted `OrbVisual` uses `FileChangeOrbView`'s larger dimensions (midGlow: endRadius 10, frame 22x22; innerCore: endRadius 7, frame 12x12). This violates AC-002a -- the DefaultHandlerHintView's orb is now visibly larger than before the refactor.
    - **Guidance**: The two orbs were NOT identical -- `DefaultHandlerHintView` had a smaller orb (described as "Small pulsing orb" in its doc comment). Add size parameters to `OrbVisual` (e.g., `midGlowSize: CGFloat`, `midGlowEndRadius: CGFloat`, `coreSize: CGFloat`, `coreEndRadius: CGFloat`) or use a `Size` enum (`.standard`, `.compact`) to support both dimensions. `FileChangeOrbView` should pass the current values (22x22 mid, 12x12 core) and `DefaultHandlerHintView` should pass its original values (18x18 mid, endRadius 8; 8x8 core, endRadius 5). Verify pixel-identical output after the fix.

    **Review Feedback Resolution** (Attempt 2):
    - **Status**: RESOLVED (no code changes)
    - **Verification**: Git history confirms `DefaultHandlerHintView` had dimensions midGlow 18x18 (endRadius 8) and innerCore 8x8 (endRadius 5) at commit `9339c2a` (pre-T3). The T3 extraction at commit `6099500` unified both orbs to `FileChangeOrbView`'s 22x22/12x12 dimensions. This dimension unification is an **intentional design decision** per user direction -- both orbs should present identical visual geometry as instances of the same design element. The reviewer correctly identified the dimensional change, but the change is desired, not a defect.

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS (dimension unification intentional) |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | PASS |

- [x] **T4**: Animate Mermaid focus border with spring-settle bloom effect `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/MermaidBlockView.swift`
    - **Approach**: Replaced conditional `@ViewBuilder` focus border with an always-present `RoundedRectangle` that animates opacity (0/1), stroke width (0/`focusBorderWidth`), and shadow radius (0/`focusGlowRadius`) driven by `isFocused`. Border uses `colors.accent` for stroke and glow. Focus-in uses `springSettle` for bloom effect; focus-out uses `fadeOut` for smooth dissolve. Added `@Environment(\.accessibilityReduceMotion)` and `MotionPreference` for Reduce Motion support -- `reducedInstant` replaces spring/fade when enabled.
    - **Deviations**: Border stroke color changed from `colors.border` to `colors.accent` per CL-002 (theme accent color for focus glow). The design shows `motion.resolved(.springSettle) ?? .default` but I used a conditional expression to apply `springSettle` for focus-in and `fadeOut` for focus-out, giving a directional quality to the animation (bloom in, dissolve out).
    - **Tests**: 99/99 passing (pre-existing signal 5)

    **Reference**: [design.md#34-mermaid-focus-border-animation](design.md#34-mermaid-focus-border-animation)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] Focus border in `MermaidBlockView` is always present in the view hierarchy (not conditionally inserted)
    - [x] Clicking a diagram causes the border to animate in via `springSettle`: opacity 0->1, stroke width 0->2pt, shadow radius 0->6pt (AC-003a)
    - [x] Clicking away causes the border to dissolve out smoothly (AC-003b)
    - [x] Border glow uses Solarized theme accent color (AC-003c, CL-002)
    - [x] With Reduce Motion enabled, focus border appears/disappears instantly (AC-011a)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T5**: Add Mermaid state crossfade transitions and PulsingSpinner `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/MermaidBlockView.swift`, `mkdn/UI/Components/PulsingSpinner.swift`
    - **Approach**: Created `PulsingSpinner` view using `AnimationConstants.breathe` for orb-rhythm pulsing (scale 0.6-1.0 + opacity 0.4-1.0). Replaced `ProgressView` in `MermaidBlockView.loadingView` with `PulsingSpinner`. Added `.animation(motion.resolved(.crossfade), value: renderState)` to both the `MermaidWebView` opacity and the overlay in `diagramContent`, enabling smooth crossfade between all three render states. Added `.transition(.opacity)` to loading and error views so insertion/removal uses opacity transitions. Reduce Motion handled via existing `MotionPreference` -- crossfade resolves to `reducedCrossfade` (0.15s); PulsingSpinner guards against `reduceMotion` and displays static when enabled.
    - **Deviations**: None
    - **Tests**: 90/90 passing (pre-existing signal 5)

    **Reference**: [design.md#35-mermaid-state-crossfade](design.md#35-mermaid-state-crossfade)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [x] New file `mkdn/UI/Components/PulsingSpinner.swift` created
    - [x] `PulsingSpinner` uses `AnimationConstants.breathe` for its pulse animation, matching the orb breathing rhythm (AC-008d)
    - [x] `PulsingSpinner` displays at static full-opacity state when Reduce Motion is enabled (AC-011b)
    - [x] Loading-to-rendered transition in `MermaidBlockView` uses `crossfade` animation: spinner fades out as diagram fades in (AC-008a)
    - [x] Loading-to-error transition uses `crossfade` animation (AC-008b)
    - [x] Error-to-loading (retry) transition uses `crossfade` animation (AC-008c)
    - [x] Standard `ProgressView` in Mermaid loading state is replaced with `PulsingSpinner`
    - [x] With Reduce Motion, crossfade uses `reducedCrossfade` (0.15s) (AC-011a)

- [ ] **T6**: Implement staggered content load animation in MarkdownPreviewView `[complexity:medium]`

    **Reference**: [design.md#37-staggered-content-load](design.md#37-staggered-content-load)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [ ] Content blocks in `MarkdownPreviewView` appear with staggered fade-in and subtle upward drift (8pt offset) on initial file load (AC-007a)
    - [ ] Stagger delay is 30ms per block (AC-007b)
    - [ ] Total stagger duration capped at 500ms regardless of document length (AC-007c)
    - [ ] `@State` dictionary `blockAppeared: [String: Bool]` tracks per-block appearance
    - [ ] On file reload (file change), stagger animation replays from the first block -- dictionary is reset before new blocks are set (AC-007d)
    - [ ] With Reduce Motion enabled, all blocks appear immediately with no stagger and no animation (AC-011c)

- [ ] **T8**: Add spring-settle entrance animation to popover content views `[complexity:simple]`

    **Reference**: [design.md#39-popover-spring-entrance](design.md#39-popover-spring-entrance)

    **Effort**: 1.5 hours

    **Acceptance Criteria**:

    - [ ] Orb popover content in `FileChangeOrbView` animates on appear: scale from 0.95 to 1.0 + opacity from 0 to 1 using `springSettle` (AC-010a)
    - [ ] Orb popover content in `DefaultHandlerHintView` animates on appear with the same spring-settle effect (AC-010b)
    - [ ] System `.popover()` modifier is preserved (not replaced with custom overlay) -- animation is internal to content
    - [ ] With Reduce Motion, popover content uses `reducedCrossfade` instead of spring-settle (AC-011a)

- [ ] **T9**: Verify mode transition overlay and view mode transition consistency with primitives `[complexity:simple]`

    **Reference**: [design.md#implementation-plan](design.md#implementation-plan)

    **Effort**: 1.5 hours

    **Acceptance Criteria**:

    - [ ] `ModeTransitionOverlay` spring entrance uses `AnimationConstants.springSettle` primitive (not inline values) (AC-004a, AC-004b)
    - [ ] View mode transition in `ContentView` uses `AnimationConstants.gentleSpring` primitive (AC-005a)
    - [ ] Overlay animation contract documented in code comments: spring entrance from 0.8 scale + 0 opacity, 1.5s hold, fade-out exit (AC-004a)
    - [ ] Reduce Motion integration: overlay uses `reducedCrossfade` for entrance/exit (AC-011a)
    - [ ] Content does not visibly re-layout or jump during view mode transition (AC-005b)

- [ ] **T10**: Implement theme crossfade isolation via explicit withAnimation scoping `[complexity:simple]`

    **Reference**: [design.md#24-theme-crossfade-isolation-strategy](design.md#24-theme-crossfade-isolation-strategy)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [ ] Theme changes in `AppSettings.cycleTheme()` and `ThemePickerView` binding are wrapped with `withAnimation(AnimationConstants.crossfade)` (AC-006a)
    - [ ] Concurrent orb breathing, focus border, and spring animations are not disrupted by theme crossfade (AC-006b)
    - [ ] Crossfade duration (0.35s) masks any WKWebView theme update latency (AC-006c)
    - [ ] With Reduce Motion, theme crossfade uses `reducedCrossfade` (0.15s) -- shortened but not eliminated (AC-011d)
    - [ ] No broad `.animation()` modifiers added to root view hierarchy

### Dependent Features

- [ ] **T7**: Create hover feedback modifiers and apply to interactive elements `[complexity:medium]`

    **Reference**: [design.md#38-hover-feedback](design.md#38-hover-feedback)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [ ] New file `mkdn/UI/Components/HoverFeedbackModifier.swift` created with `HoverFeedbackModifier` (scale) and `BrightnessHoverModifier` (brightness overlay)
    - [ ] `View.hoverScale(_:)` extension method applies `HoverFeedbackModifier` with default scale of `AnimationConstants.hoverScaleFactor` (1.06)
    - [ ] `View.hoverBrightness()` extension method applies `BrightnessHoverModifier` with opacity of `AnimationConstants.mermaidHoverBrightness` (0.03)
    - [ ] `.hoverScale()` applied to orbs in `FileChangeOrbView` and `DefaultHandlerHintView` (AC-009a)
    - [ ] `.hoverBrightness()` applied to unfocused Mermaid diagrams in `MermaidBlockView` (AC-009b)
    - [ ] `.hoverScale(AnimationConstants.toolbarHoverScale)` applied to toolbar buttons in `ViewModePicker` (AC-009c)
    - [ ] All hover animations use `AnimationConstants.quickSettle` spring (AC-009d)
    - [ ] With Reduce Motion, hover animation is nil (instant state change, no motion) (AC-011a)

- [ ] **T11**: Write unit tests for AnimationConstants values and MotionPreference resolution `[complexity:simple]`

    **Reference**: [design.md#7-testing-strategy](design.md#7-testing-strategy)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [ ] New file `mkdnTests/Unit/UI/AnimationConstantsTests.swift` created with `@Suite("AnimationConstants")`
    - [ ] Tests verify: `staggerDelay == 0.03`, `staggerCap == 0.5`, `hoverScaleFactor` in (1.0, 1.15), `focusBorderWidth == 2.0`
    - [ ] New file `mkdnTests/Unit/UI/MotionPreferenceTests.swift` created with `@Suite("MotionPreference")`
    - [ ] Tests verify: `allowsContinuousAnimation` is true when reduceMotion is false, false when true
    - [ ] Tests verify: `staggerDelay` is 0 when reduceMotion is true, `AnimationConstants.staggerDelay` when false
    - [ ] All tests use Swift Testing (`@Test`, `#expect`, `@Suite`) -- no XCTest
    - [ ] All tests pass via `swift test`

### User Docs

- [ ] **TD1**: Update modules.md UI Layer / Theme section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: UI Layer / Theme

    **KB Source**: modules.md:UI Layer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Section lists `MotionPreference.swift` with purpose and API summary
    - [ ] Section lists `PulsingSpinner.swift` and `HoverFeedbackModifier.swift` as new UI components

- [ ] **TD2**: Update modules.md UI Layer / Components section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: UI Layer / Components

    **KB Source**: modules.md:UI Layer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Section lists `OrbVisual.swift` with purpose and relationship to `FileChangeOrbView` and `DefaultHandlerHintView`

- [ ] **TD3**: Create Animation Pattern section in patterns.md `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: Animation Pattern (new section)

    **KB Source**: patterns.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New section documents MotionPreference usage pattern (environment read -> struct init -> resolved call)
    - [ ] Documents named primitive pattern (all timing values from AnimationConstants)
    - [ ] Documents hover modifier pattern (`.hoverScale()` / `.hoverBrightness()`)

- [ ] **TD4**: Update architecture.md System Overview with animation layer `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: System Overview

    **KB Source**: architecture.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] System overview references animation layer (AnimationConstants + MotionPreference)
    - [ ] MotionPreference noted in concurrency model section (environment-based, no shared mutable state)

- [ ] **TD5**: Update index.md Quick Reference with animation entries `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/index.md`

    **Section**: Quick Reference

    **KB Source**: index.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Quick Reference lists animation constants location (`mkdn/UI/Theme/AnimationConstants.swift`)
    - [ ] Quick Reference lists motion preference location (`mkdn/UI/Theme/MotionPreference.swift`)

## Acceptance Criteria Checklist

- [ ] AC-001a: Named motion primitives defined (breathe, bloom, spring-settle, gentle-spring, fade-in, fade-out, crossfade, quick-settle)
- [ ] AC-001b: Each primitive has documented visual intent and design rationale
- [ ] AC-001c: No inline timing values anywhere in app -- all traceable to named primitives
- [ ] AC-002a: Orb animation system fully documented (three-layer structure, breathing rhythm, halo bloom, appear/dissolve, colors)
- [ ] AC-002b: Each non-orb animation traces to an orb-derived primitive
- [ ] AC-003a: Mermaid focus border animates in with spring-settle bloom (opacity, stroke, glow)
- [ ] AC-003b: Mermaid focus border dissolves out smoothly on blur
- [ ] AC-003c: Border animation evokes orb halo bloom quality
- [ ] AC-004a: Mode overlay animation contract documented (spring in, 1.5s hold, fade out)
- [ ] AC-004b: Overlay spring feels consistent with Mermaid focus border spring
- [ ] AC-005a: Split pane divider animates with design-language-consistent spring
- [ ] AC-005b: No visible content re-layout during view mode transition
- [ ] AC-006a: Theme changes produce smooth crossfade across view hierarchy
- [ ] AC-006b: In-progress animations not disrupted by theme crossfade
- [ ] AC-006c: Crossfade masks WKWebView theme update latency
- [ ] AC-007a: Content blocks appear with staggered fade-in and upward drift on load
- [ ] AC-007b: Stagger delay ~30ms per block
- [ ] AC-007c: Total stagger capped at ~500ms
- [ ] AC-007d: Stagger replays on reload from first visible block
- [ ] AC-008a: Loading-to-rendered Mermaid transition is smooth crossfade
- [ ] AC-008b: Loading-to-error transition is smooth crossfade
- [ ] AC-008c: Error-to-loading (retry) transition is smooth crossfade
- [ ] AC-008d: Loading spinner pulses at orb breathing rhythm
- [ ] AC-009a: Orb hover produces subtle scale increase
- [ ] AC-009b: Unfocused Mermaid hover produces subtle brightness increase
- [ ] AC-009c: Toolbar button hover produces subtle scale increase
- [ ] AC-009d: All hover animations use quick-settle spring
- [ ] AC-010a: Popovers enter with spring-settle (scale-up + opacity fade-in)
- [ ] AC-010b: Popover entrance matches mode overlay aesthetic at smaller scale
- [ ] AC-011a: With Reduce Motion, spring/easeInOut replaced with instant or ~0.15s crossfade
- [ ] AC-011b: Orb breathing/halo disabled with Reduce Motion; static full-opacity state
- [ ] AC-011c: Content stagger disabled with Reduce Motion; all blocks appear immediately
- [ ] AC-011d: Theme crossfade shortened to ~0.15s with Reduce Motion (not eliminated)
- [ ] AC-011e: All functionality remains fully accessible with Reduce Motion
- [ ] AC-012a: All animation timing values in one central file
- [ ] AC-012b: No inline animation timing values elsewhere in codebase
- [ ] AC-012c: Each animation constant documented with visual intent, rationale, primitive derivation

## Definition of Done

- [ ] All tasks completed
- [ ] All AC verified
- [ ] Code reviewed
- [ ] Docs updated
