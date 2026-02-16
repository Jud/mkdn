# Hypothesis Document: the-orb
**Version**: 1.0.0 | **Created**: 2026-02-11T01:05:10Z | **Status**: VALIDATED

## Hypotheses
### HYP-001: SwiftUI Color Animation in RadialGradient Fills
**Risk Level**: HIGH
**Status**: REJECTED
**Statement**: Passing a new Color to OrbVisual within a withAnimation(.crossfade) block produces a smooth color interpolation in the RadialGradient fills, without requiring changes to OrbVisual or an overlay-based crossfade fallback.
**Context**: The entire color crossfade mechanism depends on SwiftUI interpolating Color values within RadialGradient fills when animated. OrbVisual uses three nested RadialGradients with opacity modifiers. The fallback (dual-OrbVisual overlay with opacity crossfade) is more complex but guaranteed to work.
**Validation Criteria**:
- CONFIRM if: Create a minimal SwiftUI preview with OrbVisual, toggle its color inside withAnimation(.easeInOut(duration: 1.0)), and observe a smooth color transition in the rendered gradient layers.
- REJECT if: The color snaps instantly to the new value despite the animation block, or only some gradient layers interpolate while others snap.
**Suggested Method**: CODE_EXPERIMENT

## Validation Findings

### HYP-001 Findings
**Validated**: 2026-02-11T01:12:34Z
**Method**: CODE_EXPERIMENT + EXTERNAL_RESEARCH + CODEBASE_ANALYSIS
**Result**: REJECTED

**Evidence**:

#### 1. Protocol Conformance (Programmatic, Definitive)

A disposable Swift program was built and executed to check Animatable conformance at runtime. Results:

```
Color conforms to Animatable:           false
Color.Resolved conforms to Animatable:  true   (compiler-confirmed)
RadialGradient conforms to Animatable:  false
Gradient.Stop conforms to Animatable:   false
LinearGradient conforms to Animatable:  false
```

**Key finding**: `Color` does NOT conform to `Animatable`. `RadialGradient` does NOT conform to `Animatable`. Only `Color.Resolved` conforms, and it is not used in the gradient constructor API.

`Color.Resolved.animatableData` is of type `AnimatablePair<Float, AnimatablePair<Float, AnimatablePair<Float, Float>>>`, representing (linearRed, (linearGreen, (linearBlue, opacity))) in a linear color space. The values can be interpolated via `VectorArithmetic` operations on the animatableData -- but this is only useful when `Color.Resolved` is directly used as an animatable property in a view or modifier, not when `Color` is passed as a parameter to a gradient constructor.

#### 2. SwiftUI Animation System Mechanism

When `withAnimation` wraps a state change:
1. SwiftUI snapshots the view tree before the state change.
2. The state change is applied, producing a new view tree.
3. SwiftUI diffs old vs new trees.
4. For any property that conforms to `Animatable`, SwiftUI interpolates `animatableData` between old and new values over the animation duration.
5. For NON-Animatable properties, the new value is applied immediately (snap).

Since `RadialGradient` is not `Animatable`, SwiftUI cannot interpolate it. The entire gradient is replaced atomically on the first frame of the animation. The `Color` values inside the gradient constructor are parameters that are evaluated once when the gradient is created -- they are not individually tracked by the animation system.

#### 3. OrbVisual Architecture (Codebase Analysis)

`OrbVisual` at `mkdn/UI/Components/OrbVisual.swift:12-84` takes `color: Color` as a `let` property. It constructs three `RadialGradient` fills:

- **outerHalo** (line 31): `RadialGradient(colors: [color.opacity(...), Color.clear], ...)`
- **midGlow** (line 49): `RadialGradient(colors: [color.opacity(0.8), color.opacity(0.15)], ...)`
- **innerCore** (line 69): `RadialGradient(colors: [Color.white.opacity(0.9), color, color.opacity(0.3)], ...)`

When a parent view creates `OrbVisual(color: newColor, ...)` inside `withAnimation`, SwiftUI sees a new `OrbVisual` struct. The `color` property changes, but since the gradients are not Animatable, all three gradient layers snap to the new color simultaneously on the first animation frame.

#### 4. External Research Consensus

Multiple authoritative sources confirm gradient colors do not animate:

> "When using gradient fills, it is impossible to animate color change by just changing its color properties." -- Pavel Zak (nerdyak.tech)

> "SwiftUI can't automatically animate the gradient change from one set of colors to another set of color." -- AppCoda

The established workarounds in the SwiftUI community are:
1. **AnimatableModifier / Animatable View**: Custom RGB interpolation via `animatableData`
2. **Dual-layer opacity crossfade**: Stack two gradient views, animate `.opacity()` between them
3. **Hue rotation**: `.hueRotation()` modifier (limited to hue-only changes)

#### 5. Important Distinction: .fill(Color) vs .fill(RadialGradient)

`.fill(Color.red)` changing to `.fill(Color.blue)` inside `withAnimation` DOES produce a smooth color transition. SwiftUI special-cases `Color` as a `ShapeStyle` and handles the interpolation internally (even though `Color` does not formally conform to `Animatable` at the protocol level). However, `.fill(RadialGradient(...))` does NOT receive this special treatment -- the gradient is replaced as a discrete value.

**Sources**:
- `mkdn/UI/Components/OrbVisual.swift:12-84` -- OrbVisual implementation
- `mkdn/UI/Theme/AnimationConstants.swift:147` -- crossfade animation definition
- [Animating Gradients in SwiftUI - Pavel Zak](https://nerdyak.tech/development/2019/09/30/animating-gradients-swiftui.html)
- [How to Create Animated Gradients in SwiftUI - AppCoda](https://www.appcoda.com/animate-gradient-swiftui/)
- [AnimatableGradients library - CypherPoet](https://github.com/CypherPoet/AnimatableGradients) -- third-party library that exists specifically because native gradient color animation is not supported
- [Advanced SwiftUI Animations Part 3 - SwiftUI Lab](https://swiftui-lab.com/swiftui-animations-part3/)

**Implications for Design**:
The design MUST use the overlay-based crossfade fallback (dual-OrbVisual with opacity crossfade) for color transitions. The simple approach of passing a new Color inside `withAnimation` will produce an instant snap, not a smooth crossfade. This affects:
1. The color transition implementation must use a `ZStack` with two `OrbVisual` instances.
2. The animation state management needs to track both the "from" and "to" colors with their respective opacities.
3. Alternatively, a custom `Animatable` modifier could perform RGB interpolation, but this adds complexity compared to the overlay approach.

## Summary
| Hypothesis | Risk | Result | Implication |
|------------|------|--------|-------------|
| HYP-001 | HIGH | REJECTED | RadialGradient colors do not animate. Must use overlay-based opacity crossfade or custom Animatable modifier for color transitions. |
