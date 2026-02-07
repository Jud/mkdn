# Quick Build: Enhance Orb Animation

**Created**: 2026-02-07T00:00:00Z
**Request**: Enhance the glowing orb animation for the default Markdown editor selection. Currently it looks like a flat circle fading in and out. Make it feel three-dimensional, spatial, and truly glowing - like a luminous orb that subtly draws attention in a zen-like, mystical but calm fashion. Also adjust the color to be more theme-neutral - something that works across different themes while feeling slightly mystical and calming.
**Scope**: Small

## Plan

**Reasoning**: This touches 2-3 UI view files and 1 animation constants file, all within the same UI layer. No logic changes, no data flow changes, no new modules. Risk is low since it is purely visual.
**Files Affected**:
- `mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift` (primary target -- the default handler orb)
- `mkdn/UI/Components/BreathingOrbView.swift` (apply same 3D treatment for consistency)
- `mkdn/UI/Theme/AnimationConstants.swift` (add/tune animation constants for layered glow)
**Approach**: Replace the flat `Circle().fill()` with a multi-layered `ZStack` compositing concentric radial gradients and soft shadows to simulate a 3D luminous orb. Use a theme-neutral color (soft violet/indigo, e.g. Solarized violet `#6c71c4` or a custom soft-teal blend) that reads well on both dark and light backgrounds. Add a subtle secondary outer glow layer that pulses at a slightly offset cadence from the core, creating depth. Keep the existing `easeInOut` breathing rhythm but layer two animation phases: an inner bright core pulse and an outer halo bloom. The overall feel should be calm, spatial, and slightly mystical.
**Estimated Effort**: 1-1.5 hours

## Tasks

- [x] **T1**: Redesign `DefaultHandlerHintView` orb visual -- replace flat `Circle().fill(accent)` with a `ZStack` of 3 layers: (1) outer soft halo using `RadialGradient` from translucent color to clear, (2) mid glow body with `RadialGradient` simulating light falloff, (3) inner bright core `Circle` with slight white highlight for specular feel. Use a theme-neutral mystical color (soft violet-indigo or teal-violet blend via a static `Color` constant). Apply layered shadow with varying radii keyed to `isPulsing` state. `[complexity:medium]`
- [x] **T2**: Add a second `@State` animation property (e.g. `isHaloExpanded`) to `DefaultHandlerHintView` with a slightly different timing curve or offset duration in `AnimationConstants` so the outer halo and inner core breathe at subtly different rates, creating a spatial/dimensional feel. `[complexity:simple]`
- [x] **T3**: Apply the same 3D orb treatment to `BreathingOrbView` for visual consistency across the app, using the same layered gradient approach and theme-neutral color. `[complexity:simple]`
- [x] **T4**: Update `AnimationConstants` with new timing values: `orbHaloBloom` (slightly slower than core pulse, e.g. 3.0s vs 2.5s), and ensure both orb views reference these shared constants. `[complexity:simple]`
- [x] **T5**: Build, run SwiftLint and SwiftFormat, and visually verify the orb renders correctly in both Solarized Dark and Solarized Light themes. `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `DefaultHandlerHintView.swift` | Replaced flat Circle with 3-layer ZStack: outer halo (RadialGradient to clear), mid glow body (RadialGradient falloff + shadow), inner core (off-center specular RadialGradient). Extracted into `orbVisual`, `outerHalo`, `midGlow`, `innerCore` computed properties. | Done |
| T2 | `DefaultHandlerHintView.swift` | Added `@State isHaloExpanded` animated with `orbHaloBloom` (3.0s) alongside existing `isPulsing` (2.5s) for offset-cadence dimensional breathing. | Done |
| T3 | `BreathingOrbView.swift` | Applied identical 3-layer orb treatment with same extracted computed properties and dual animation states for visual consistency. | Done |
| T4 | `AnimationConstants.swift` | Added `orbGlowColor` (Solarized violet #6c71c4) and `orbHaloBloom` (3.0s easeInOut repeating). Both orb views reference these shared constants. | Done |
| T5 | -- | Build succeeds, SwiftFormat clean (0 formatted), SwiftLint 0 violations on all 3 files, all tests pass. | Done |

## Verification

{To be added by task-reviewer if --review flag used}
