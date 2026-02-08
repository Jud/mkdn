# PRD: Animation Design Language

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-07

---

## Surface Overview

A unified animation design language for mkdn that establishes the orb as the aesthetic touchstone for all motion throughout the application. Every element that moves, glows, fades, or responds to input shares a common visual vocabulary rooted in the orb's breathing, mystical quality -- sinusoidal rhythms timed to human breathing (~12 cycles/min), radial gradients that bloom and recede, spring physics that feel physical and alive.

This PRD serves as both a design principles document and a developer reference. It provides:

- **Shared vocabulary**: Named motion primitives (breathe, bloom, spring-settle, dissolve, crossfade) that the team references consistently.
- **Concrete specs**: Exact timing curves, spring parameters, opacity ranges, and scale factors for every animated element.
- **Design principles**: The "why" behind each motion choice, anchored to the charter's design philosophy ("every visual and interactive element must be crafted with obsessive attention to sensory detail").
- **Developer reference**: A mapping from each animation constant in `AnimationConstants.swift` to its visual intent and usage context.

The goal is that any new animation added to mkdn can be derived from these primitives rather than invented ad hoc -- ensuring the app feels like a single, coherent, living thing.

---

## Scope

### In Scope

All motion within mkdn, specifically:

| Element | Current State | Target State |
|---------|--------------|--------------|
| **Orb animations** (breathing pulse, halo bloom, appear, dissolve) | Implemented in `AnimationConstants.swift`, `FileChangeOrbView`, `DefaultHandlerHintView` | Touchstone -- remains as-is, documented as the canonical reference for all other motion |
| **Mermaid focus border** | Hard cut (`if isFocused` in `MermaidBlockView`) | Animated in/out using the orb's aesthetic -- soft bloom with spring-settle |
| **Mode transition overlay** | Implemented (`ModeTransitionOverlay`) with spring-in + fade-out | Documented, possibly refined to align closer to orb bloom timing |
| **View mode transitions** | Spring-based (`viewModeTransition`) | Documented, ensure spring response feels consistent with overlay spring |
| **Theme crossfade** | easeInOut 0.35s | Documented, ensure non-conflict with concurrent animations |
| **Content load appearance** | Not yet animated (blocks appear instantly) | Staggered fade-in with subtle upward drift, per-block |
| **Error/loading state transitions** | Hard cut in `MermaidBlockView` overlay | Soft crossfade between loading/rendered/error states |
| **Hover feedback** | Cursor change only (NSCursor push/pop on orbs) | Subtle scale/glow response on interactive elements |
| **Popover presentation** | System default | Custom entrance with spring-settle consistent with overlay |
| **Shared vocabulary and design principles** | Implicit | Explicit, documented |
| **Developer reference mapping** | None | Complete mapping from `AnimationConstants` entries to visual intent |

### Out of Scope

- **Scroll-position-based parallax or scroll-triggered animations**: Standard scroll behavior is sufficient. The focus is on state-change and interaction-driven animation.
- **Skeletal/shimmer loading patterns**: These belong in a heavier UI framework. mkdn's loading states should use the orb-inspired bloom aesthetic instead.
- **Sound design or haptics**: macOS does not have a haptic API for trackpads in the way iOS does, and sound is out of scope for a document viewer.
- **Lottie, Rive, or other external animation frameworks**: All motion must be achievable with pure SwiftUI animation primitives.
- **Animation of Markdown content itself** (e.g., animating text as it is typed in the editor pane): Editor responsiveness is a separate concern; this PRD covers chrome and status animations.

---

## Requirements

### Functional Requirements

**FR-1: Motion Primitives Library**
Define a set of named motion primitives in `AnimationConstants.swift` that all animations derive from:

| Primitive | Definition | Derived From |
|-----------|-----------|--------------|
| `breathe` | easeInOut, 2.5s half-cycle, repeats forever, autoreverses | Orb pulse |
| `bloom` | easeInOut, 3.0s half-cycle, repeats forever, autoreverses | Orb halo bloom |
| `springSettle` | spring(response: 0.35, dampingFraction: 0.7) | Overlay spring-in |
| `gentleSpring` | spring(response: 0.4, dampingFraction: 0.85) | View mode transition |
| `fadeIn` | easeOut, 0.5s | Orb appear |
| `fadeOut` | easeIn, 0.4s | Orb dissolve |
| `crossfade` | easeInOut, 0.35s | Theme crossfade |
| `quickSettle` | spring(response: 0.25, dampingFraction: 0.8) | Hover feedback, small interactive elements |

**FR-2: Orb Animation Documentation**
Document the existing orb animation system as the canonical reference:
- Three-layer radial gradient structure (outerHalo, midGlow, innerCore)
- Breathing rhythm: sinusoidal ~12 cycles/min (2.5s half-cycle)
- Halo bloom offset: 3.0s half-cycle (slightly slower than core for dimensional depth)
- Appear: easeOut 0.5s from zero opacity/scale
- Dissolve: easeIn 0.4s to zero
- Color semantics: Solarized violet (#6c71c4) for default handler, Solarized cyan (#2aa198) for file change

**FR-3: Mermaid Focus Border Animation**
Replace the hard-cut focus border in `MermaidBlockView` with an animated border that blooms in and dissolves out:
- **Focus in**: Border opacity 0 -> 1 and stroke width 0 -> 2pt using `springSettle`, with a subtle outer glow that fades in (Solarized accent color at 0.3 opacity, blur radius ~6pt)
- **Focus out**: Reverse using `fadeOut` (easeIn, 0.4s)
- The border should feel like it "breathes into existence" the same way the orb's halo blooms

**FR-4: Mode Transition Overlay Refinement**
The existing `ModeTransitionOverlay` is close to correct. Document its animation contract:
- Entrance: `springSettle` from 0.8 scale + 0 opacity to 1.0 scale + 1.0 opacity
- Hold: 1.5s display duration
- Exit: `fadeOut` over 0.3s
- Ensure the spring response (0.35s) feels consistent with the Mermaid focus border spring

**FR-5: View Mode Transition**
Document and potentially tighten the view mode transition:
- Uses `gentleSpring` (response: 0.4, dampingFraction: 0.85)
- The split pane divider should animate smoothly between positions
- Content should not visibly re-layout during the transition; use matched geometry or container-relative framing

**FR-6: Theme Crossfade**
Document the theme crossfade behavior:
- `crossfade` (easeInOut, 0.35s) applied to the entire view hierarchy
- Must not conflict with any in-progress animations (orb pulses, focus borders)
- WKWebView content (Mermaid diagrams) handles its own theme transition via JS; the SwiftUI crossfade should mask any brief mismatch

**FR-7: Content Load Appearance**
Add staggered entrance animation for Markdown blocks when a file is first loaded or reloaded:
- Each block fades in with `fadeIn` (easeOut, 0.5s) plus a subtle 4pt upward translation
- Stagger delay: 30ms per block (capped at 500ms total for long documents)
- On reload (file change), the stagger should replay from the first visible block

**FR-8: Error/Loading State Crossfade**
Replace the hard opacity cuts in `MermaidBlockView` between loading/rendered/error states:
- `loading -> rendered`: `crossfade` (easeInOut, 0.35s) -- the ProgressView fades out as the diagram fades in
- `loading -> error`: `crossfade`
- `error -> loading` (retry): `crossfade`
- The loading spinner itself should pulse using `breathe` to maintain visual kinship with the orbs

**FR-9: Hover Feedback**
Add subtle hover feedback to interactive elements:
- **Orbs**: In addition to cursor change, scale to 1.08 using `quickSettle` on hover, return to 1.0 on hover exit
- **Mermaid diagrams (unfocused)**: Slight brightness increase (overlay white at 0.03 opacity) on hover, signaling clickability
- **Toolbar buttons**: Scale to 1.05 using `quickSettle`

**FR-10: Popover Presentation**
When popovers appear (orb dialogs, future UI), apply a custom entrance:
- Content scales from 0.95 to 1.0 with `springSettle`
- Opacity 0 to 1 simultaneously
- This matches the mode transition overlay aesthetic at a smaller scale

**FR-11: Reduce Motion Compliance**
When the user has enabled "Reduce Motion" in macOS System Settings:
- Replace all spring/easeInOut animations with instant (duration: 0) or very short crossfades (0.15s)
- Disable orb breathing and halo bloom (show static orb at full opacity)
- Disable content load stagger (show all blocks immediately)
- Maintain crossfade for theme transitions (reduced to 0.15s) because a hard cut between themes is jarring even for motion-sensitive users

### Non-Functional Requirements

**NFR-1: GPU Budget**
All animations must remain under 5% GPU utilization on an M1 MacBook Air when idle (orb breathing only). During active transitions (mode change + theme crossfade simultaneously), peak GPU should not exceed 15%.

**NFR-2: No Dropped Frames**
All animations must target 60fps. Spring animations that resolve to <0.5pt of motion should be considered "settled" and removed from the render loop.

**NFR-3: Single Source of Truth**
Every animation timing value used anywhere in the codebase must be defined in `AnimationConstants.swift`. No inline animation values. Violations should be caught in code review.

**NFR-4: Testability**
Animation constants must be accessible from tests. Integration tests should be able to verify that the correct animation constant is referenced (even if timing itself is not testable in unit tests).

**NFR-5: Documentation**
Each constant in `AnimationConstants.swift` must have a doc comment that includes:
- The visual intent (what the user sees)
- The design rationale (why this timing)
- The primitive it derives from (if applicable)

---

## Dependencies & Constraints

### Dependencies

| Dependency | Type | Notes |
|------------|------|-------|
| **SwiftUI Animation API** | Framework | All motion uses `withAnimation`, `.animation()`, `Animation.spring()`, `Animation.easeInOut()`. No external animation libraries. |
| **`AnimationConstants.swift`** | Internal (SSOT) | Already exists at `mkdn/UI/Theme/AnimationConstants.swift`. Will be expanded with new primitives. All animation values flow from this file. |
| **macOS 14.0+ (Sonoma)** | Platform | Required for `Animation.spring(response:dampingFraction:)` API and `@Observable`. |
| **`@Observable` pattern** | Architecture | Animation state (`isPulsing`, `isHaloExpanded`, etc.) lives in `@State` within views, driven by constants from `AnimationConstants`. |

### Constraints

| Constraint | Impact |
|------------|--------|
| **WKWebView boundary** | Mermaid diagrams render inside WKWebView. SwiftUI cannot animate content inside the web view. The focus border, loading overlay, and error overlay are SwiftUI layers outside/above the WKWebView and can be animated normally. Theme changes inside the WKWebView are handled by JS and cannot be synchronized frame-perfectly with the SwiftUI crossfade -- the crossfade must be long enough (0.35s) to mask any brief mismatch. |
| **GPU budget** | Continuous animations (orb breathing) must be lightweight. Use simple property animations (opacity, scale, shadow radius) rather than complex path or mesh animations. Limit simultaneous continuous animations to 2 (one per visible orb). |
| **Reduce Motion** | macOS `accessibilityReduceMotion` must be respected. The Reduce Motion path should be a first-class implementation, not an afterthought. |
| **Theme crossfade non-conflict** | A theme crossfade applies `.animation(.easeInOut(0.35))` broadly. This must not interfere with in-progress orb pulses or spring animations. Use explicit `animation(_:value:)` scoping rather than implicit `.animation()` to prevent unintended cross-contamination. |
| **No external animation libraries** | All motion must be pure SwiftUI. No Lottie, Rive, Pop, or similar. This keeps the dependency footprint minimal and ensures animations work correctly with SwiftUI's transaction system. |

---

## Milestones & Timeline

### Phase 1: Foundation (Document + Quick Wins)

**Goal**: Establish the animation design language as a living document and implement the simplest high-impact changes.

| Deliverable | Description |
|-------------|-------------|
| Expand `AnimationConstants.swift` | Add named primitives (`quickSettle`, rename existing constants to match the vocabulary) with full doc comments per NFR-5 |
| Mermaid focus border animation (FR-3) | Replace the hard-cut `if isFocused` border with animated bloom-in/dissolve-out |
| Error/loading crossfade (FR-8) | Replace hard opacity cuts in `MermaidBlockView` with crossfade transitions |
| Hover feedback on orbs (FR-9, partial) | Add scale response on hover to `FileChangeOrbView` and `DefaultHandlerHintView` |

### Phase 2: Transitions & Entrance

**Goal**: Animate the moments that currently feel abrupt.

| Deliverable | Description |
|-------------|-------------|
| Content load stagger (FR-7) | Staggered fade-in for Markdown blocks on file load/reload |
| Popover entrance (FR-10) | Spring-settle entrance for orb popovers |
| Hover feedback, remaining elements (FR-9) | Mermaid diagram hover hint, toolbar button feedback |

### Phase 3: Polish & Compliance

**Goal**: Ensure accessibility compliance and performance targets.

| Deliverable | Description |
|-------------|-------------|
| Reduce Motion (FR-11) | Full Reduce Motion implementation with graceful fallbacks |
| GPU profiling (NFR-1) | Profile on M1 Air, verify idle and peak GPU budgets |
| Animation scoping audit | Ensure no implicit `.animation()` modifiers cause cross-contamination (theme crossfade non-conflict constraint) |
| Mode transition overlay refinement (FR-4) | Verify spring consistency with new Mermaid focus border; adjust if needed |

### Phase 4: Documentation & Freeze

**Goal**: Lock the design language for v1.0.

| Deliverable | Description |
|-------------|-------------|
| Developer reference | Complete mapping table: every `AnimationConstants` entry -> visual intent -> usage sites -> primitive derivation |
| Design principles write-up | Prose document covering the "why" -- breathing rhythms, spring physics philosophy, orb-as-touchstone principle |
| Freeze | Animation constants locked for v1.0 release. Changes require PRD amendment. |

### Known Deadlines

None externally imposed. This is driven by the charter's success criterion: "personal daily-driver use." The animation design language should be complete before the app is considered ready for daily-driver status, as the charter demands that "no element is too small to get right."

---

## Open Questions

| ID | Question | Context | Impact |
|----|----------|---------|--------|
| OQ-1 | Should the content load stagger (FR-7) animate on every scroll-into-view, or only on initial file load/reload? | Scroll-into-view animation could feel lively but may also feel busy on fast scrolling. | Phase 2 scope |
| OQ-2 | Should the Mermaid focus border glow use the diagram's theme accent color or always Solarized violet? | Using theme accent creates visual continuity; using violet creates consistency with orbs. | FR-3 implementation detail |
| OQ-3 | What is the right hover feedback for Mermaid diagrams -- brightness overlay, border hint, or subtle scale? | Scale might cause layout shifts; brightness is cheapest. | FR-9 implementation detail |
| OQ-4 | Should popover exit animations match entrance (spring-settle in reverse) or use a simpler fade? | Matching feels more polished but may delay perceived responsiveness. | FR-10 implementation detail |

---

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A-1 | SwiftUI's `Animation.spring()` provides sufficient control for all planned motion without needing `CADisplayLink` or Core Animation directly. | Would need to drop down to AppKit/CA for specific animations, increasing complexity. | Design Philosophy: "animations are timed to human rhythms" |
| A-2 | Two simultaneous continuous animations (orb breathing) will stay within GPU budget on M1. | May need to pause off-screen orb animations or reduce to single-layer pulse. | Scope Guardrails: lightweight tool |
| A-3 | The 0.35s theme crossfade is long enough to mask WKWebView theme update latency. | Visible flash of old theme in Mermaid diagrams during transition. | Design Philosophy: "obsessive attention to sensory detail" |
| A-4 | Staggered content load animation (30ms/block, capped at 500ms) will feel fluid without impacting scroll-to-position or deep-link behavior. | May need to skip stagger when navigating to a specific heading. | Success Criteria: "daily-driver use" |
| A-5 | `accessibilityReduceMotion` is sufficient for compliance; no additional motion preferences need to be respected. | May need per-animation user toggles in settings. | Design Philosophy: inclusive by default |
| A-6 | Explicit `animation(_:value:)` scoping will prevent theme crossfade from interfering with spring animations. | May need to use SwiftUI `Transaction` overrides for finer control. | Design Philosophy: "no element is too small to get right" |

