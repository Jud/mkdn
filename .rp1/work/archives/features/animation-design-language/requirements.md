# Requirements Specification: Animation Design Language

**Feature ID**: animation-design-language
**Parent PRD**: [Animation Design Language](../../prds/animation-design-language.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-07

## 1. Feature Overview

mkdn needs a unified animation design language that uses the orb as its aesthetic touchstone, establishing shared motion primitives, naming conventions, and design principles so that every animated element in the application -- from breathing orbs to focus borders to content load sequences -- feels like it belongs to a single, coherent, living system. This feature defines the business-level requirements for what users should experience, how motion contributes to the product's identity, and the accessibility and performance expectations that constrain the design.

## 2. Business Context

### 2.1 Problem Statement

mkdn currently has a mix of animated and non-animated UI transitions. Some elements (orbs, mode transition overlay) have carefully tuned motion, while others (Mermaid focus borders, error/loading states, content appearance, hover feedback) use hard cuts or system defaults. This inconsistency undermines the charter's design philosophy that "every visual and interactive element must be crafted with obsessive attention to sensory detail." Users experience a jarring contrast between the polished orb animations and the abrupt state changes elsewhere in the app.

### 2.2 Business Value

- **Product identity**: A coherent animation language makes mkdn feel premium and intentional, differentiating it from utilitarian Markdown viewers.
- **Daily-driver readiness**: The charter's success criterion is "personal daily-driver use." Visual polish directly affects whether the creator feels compelled to use the app every day.
- **Maintainability**: A documented vocabulary of named motion primitives prevents ad hoc animation decisions, reducing inconsistency as new features are added.
- **Accessibility**: Explicit Reduce Motion compliance ensures the app is usable by motion-sensitive users without being an afterthought.

### 2.3 Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| Animation consistency | Every animated element in the app derives from named primitives; no inline timing values | Code review audit |
| Perceived polish | The app "feels like one thing" -- no jarring contrast between animated and non-animated transitions | Subjective daily-driver evaluation |
| Accessibility compliance | Reduce Motion preference is fully respected across all animated elements | Manual testing with macOS Reduce Motion enabled |
| Performance | Idle GPU usage at or below 5% on M1 MacBook Air; peak at or below 15% during simultaneous transitions | Instruments GPU profiling |
| Frame rate | All animations sustain 60fps with no dropped frames | Instruments Core Animation profiling |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Animation Relevance |
|-----------|-------------|---------------------|
| **Daily-driver developer** | Primary user: a developer who opens Markdown files from the terminal multiple times per day to view and edit LLM/agent output | Experiences every animation repeatedly; motion must feel natural and never annoying after the hundredth viewing. Subtlety is paramount. |
| **Motion-sensitive user** | A developer who has enabled "Reduce Motion" in macOS System Settings | Must have a complete, first-class experience with minimal or no animation. Not a degraded experience. |
| **New user** | Someone trying mkdn for the first time after installing via Homebrew | First impressions are shaped by visual polish. Content load animation and hover feedback signal quality. |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| **Creator/maintainer** | The app must meet the charter's design philosophy standard: "if it moves, glows, fades, or responds to input, it deserves the same care as the core rendering engine." |
| **Future contributors** | A documented animation vocabulary with named primitives and design rationale reduces the cognitive load of adding new animations correctly. |

## 4. Scope Definition

### 4.1 In Scope

- Establishing a named vocabulary of motion primitives (breathe, bloom, spring-settle, dissolve, crossfade, etc.) with documented intent and usage.
- Animating the Mermaid diagram focus border (currently a hard cut).
- Documenting and potentially refining the mode transition overlay animation.
- Documenting and ensuring consistency of the view mode transition.
- Documenting the theme crossfade and ensuring it does not conflict with concurrent animations.
- Adding a staggered entrance animation for Markdown content blocks on file load/reload.
- Replacing hard opacity cuts in Mermaid loading/rendered/error states with crossfade transitions.
- Adding subtle hover feedback to interactive elements (orbs, Mermaid diagrams, toolbar buttons).
- Applying a custom spring-settle entrance to popovers.
- Full Reduce Motion compliance for all animated elements.
- Performance budgets for GPU utilization and frame rate.
- A developer reference mapping every animation constant to its visual intent and usage context.

### 4.2 Out of Scope

- Scroll-position-based parallax or scroll-triggered animations.
- Skeletal/shimmer loading patterns.
- Sound design or haptics.
- External animation frameworks (Lottie, Rive, etc.).
- Animation of Markdown text content itself (e.g., typing animation in the editor pane).
- Animation of Mermaid diagram content inside the WKWebView (that is controlled by JS/CSS, not SwiftUI).

### 4.3 Assumptions

- The existing orb animation system is considered the canonical aesthetic reference and will not be redesigned -- only documented and extended.
- SwiftUI's built-in animation APIs (spring, easeInOut, easeIn, easeOut) are sufficient for all planned motion without dropping down to Core Animation.
- Two simultaneous continuous animations (orb breathing) will remain within GPU budget on M1 hardware.
- A 0.35-second theme crossfade is long enough to mask WKWebView theme update latency.
- The staggered content load animation (30ms per block, capped at 500ms) will not interfere with scroll-to-position or deep-link navigation.
- macOS `accessibilityReduceMotion` is the only motion preference that needs to be respected.

## 5. Functional Requirements

### REQ-001: Named Motion Primitives Vocabulary

- **Priority**: Must Have
- **User Type**: All users (experienced indirectly through visual consistency)
- **Requirement**: The application must have a defined set of named motion primitives that serve as the building blocks for all animation in the app. Each primitive must have a documented name, visual intent, and design rationale. All animations throughout the app must derive from these primitives.
- **Rationale**: Ad hoc animation decisions lead to inconsistency. A shared vocabulary ensures every element "speaks the same language" and enables maintainable, coherent motion design.
- **Acceptance Criteria**:
  - AC-001a: A complete set of named motion primitives is defined, including at minimum: breathe, bloom, spring-settle, gentle-spring, fade-in, fade-out, crossfade, and quick-settle.
  - AC-001b: Each primitive has a documented visual intent (what the user sees) and design rationale (why this timing/curve).
  - AC-001c: No animation anywhere in the app uses an inline timing value that is not traceable to a named primitive.

### REQ-002: Orb as Aesthetic Touchstone

- **Priority**: Must Have
- **User Type**: All users
- **Requirement**: The existing orb animation system (breathing pulse, halo bloom, appear, dissolve) must be documented as the canonical reference from which all other motion in the app is derived. The orb's visual qualities -- sinusoidal rhythms timed to human breathing (~12 cycles/min), radial gradients that bloom and recede, spring physics -- define the aesthetic vocabulary.
- **Rationale**: The orb is the most polished animated element in the app. Anchoring all motion to its aesthetic ensures a coherent product identity.
- **Acceptance Criteria**:
  - AC-002a: The orb animation system is fully documented, including: three-layer gradient structure, breathing rhythm, halo bloom timing, appear/dissolve transitions, and color semantics.
  - AC-002b: Each non-orb animation in the app can trace its timing and curve choices back to an orb-derived primitive.

### REQ-003: Animated Mermaid Focus Border

- **Priority**: Must Have
- **User Type**: Daily-driver developer
- **Requirement**: When a user clicks on a Mermaid diagram to focus it (enabling pinch-to-zoom and scroll interaction), the focus border must animate into view with a soft bloom effect rather than appearing as a hard cut. When focus is lost, the border must dissolve out smoothly.
- **Rationale**: The focus border is one of the most frequently triggered visual state changes in the app. A hard cut feels jarring and inconsistent with the orb's polished motion.
- **Acceptance Criteria**:
  - AC-003a: Clicking a Mermaid diagram causes the focus border to animate in with a spring-settle effect (opacity 0 to 1, stroke width 0 to 2pt) accompanied by a subtle outer glow.
  - AC-003b: Clicking away from a focused Mermaid diagram causes the border to dissolve out smoothly.
  - AC-003c: The border animation visually evokes the orb's halo bloom quality -- it "breathes into existence."

### REQ-004: Mode Transition Overlay Consistency

- **Priority**: Should Have
- **User Type**: Daily-driver developer
- **Requirement**: The existing mode transition overlay (shown when switching between preview-only and side-by-side modes) must be documented and verified to be consistent with the animation design language. Its spring entrance must feel consistent with other spring-based animations in the app.
- **Rationale**: The overlay is already mostly correct, but its consistency with other animated elements must be verified and documented to prevent drift.
- **Acceptance Criteria**:
  - AC-004a: The overlay's animation contract is documented: spring entrance from 0.8 scale + 0 opacity, 1.5s hold, fade-out exit.
  - AC-004b: The overlay's spring response feels consistent with the Mermaid focus border spring.

### REQ-005: View Mode Transition Smoothness

- **Priority**: Should Have
- **User Type**: Daily-driver developer
- **Requirement**: When the user switches between preview-only and side-by-side editing modes, the transition must feel smooth and physical. The split pane divider must animate between positions without visible content re-layout.
- **Rationale**: Mode switching is a core interaction. A smooth transition reinforces the app's premium feel and prevents disorientation.
- **Acceptance Criteria**:
  - AC-005a: The split pane divider animates smoothly between positions using a spring animation consistent with the design language.
  - AC-005b: Content does not visibly re-layout or jump during the transition.

### REQ-006: Theme Crossfade Non-Interference

- **Priority**: Must Have
- **User Type**: Daily-driver developer
- **Requirement**: When the user changes themes, the entire view hierarchy must crossfade smoothly between the old and new theme. This crossfade must not interfere with any in-progress animations (orb pulses, focus borders, spring transitions).
- **Rationale**: Theme changes are a deliberate user action. A smooth crossfade signals quality. Interference with other animations would feel broken.
- **Acceptance Criteria**:
  - AC-006a: Theme changes produce a smooth crossfade across the entire view hierarchy.
  - AC-006b: In-progress orb breathing, focus border animations, or spring transitions are not disrupted by a concurrent theme crossfade.
  - AC-006c: Any brief mismatch between SwiftUI theme transition and WKWebView (Mermaid diagram) theme update is masked by the crossfade duration.

### REQ-007: Staggered Content Load Appearance

- **Priority**: Should Have
- **User Type**: New user, daily-driver developer
- **Requirement**: When a Markdown file is first loaded or reloaded (after a file change), the rendered content blocks must appear with a staggered entrance animation rather than all appearing instantly. Each block fades in with a subtle upward drift, with successive blocks appearing slightly after the previous one.
- **Rationale**: Staggered entrance transforms a static "pop" into a living, breathing reveal. It signals that content is being thoughtfully presented, not dumped on screen.
- **Acceptance Criteria**:
  - AC-007a: On initial file load, content blocks appear with a staggered fade-in animation with subtle upward translation.
  - AC-007b: Stagger delay between blocks is small enough to feel fluid (approximately 30ms per block).
  - AC-007c: Total stagger duration is capped (approximately 500ms) so that long documents do not have an excessively long entrance sequence.
  - AC-007d: On reload (file change), the stagger replays from the first visible block.

### REQ-008: Mermaid Loading/Error State Crossfade

- **Priority**: Must Have
- **User Type**: Daily-driver developer
- **Requirement**: Transitions between Mermaid diagram states (loading, rendered, error) must use smooth crossfades rather than hard opacity cuts. The loading spinner itself must pulse in rhythm with the orb's breathing to maintain visual kinship.
- **Rationale**: Mermaid rendering can take noticeable time. Hard cuts between loading and rendered states feel unfinished. A pulsing loader visually connects the wait state to the orb's breathing aesthetic.
- **Acceptance Criteria**:
  - AC-008a: The transition from loading to rendered state uses a smooth crossfade (the spinner fades out as the diagram fades in).
  - AC-008b: The transition from loading to error state uses a smooth crossfade.
  - AC-008c: The transition from error to loading (retry) uses a smooth crossfade.
  - AC-008d: The loading spinner pulses at the same rhythm as the orb's breathing cycle.

### REQ-009: Hover Feedback on Interactive Elements

- **Priority**: Should Have
- **User Type**: Daily-driver developer, new user
- **Requirement**: Interactive elements must provide subtle visual feedback on mouse hover to signal interactivity. This includes orbs (scale response), Mermaid diagrams in unfocused state (brightness hint), and toolbar buttons (scale response).
- **Rationale**: Hover feedback is a fundamental affordance on desktop. Without it, interactive elements feel inert. Subtle scale/glow responses are consistent with the orb's living quality.
- **Acceptance Criteria**:
  - AC-009a: Hovering over an orb produces a subtle scale increase, returning to normal on hover exit.
  - AC-009b: Hovering over an unfocused Mermaid diagram produces a subtle brightness increase, signaling clickability.
  - AC-009c: Hovering over a toolbar button produces a subtle scale increase.
  - AC-009d: All hover animations use a quick-settle spring consistent with the design language.

### REQ-010: Popover Presentation Animation

- **Priority**: Could Have
- **User Type**: Daily-driver developer
- **Requirement**: When popovers appear (orb dialogs, future UI surfaces), they must enter with a custom spring-settle animation (scaling up from slightly smaller with simultaneous opacity fade-in) rather than using the system default.
- **Rationale**: Popover presentation is a visible micro-interaction. A custom entrance consistent with the mode transition overlay aesthetic reinforces the app's animation identity.
- **Acceptance Criteria**:
  - AC-010a: Popovers enter with a spring-settle animation (slight scale-up + opacity fade-in).
  - AC-010b: The popover entrance visually matches the mode transition overlay aesthetic at a smaller scale.

### REQ-011: Reduce Motion Compliance

- **Priority**: Must Have
- **User Type**: Motion-sensitive user
- **Requirement**: When the user has enabled "Reduce Motion" in macOS System Settings, all spring and easeInOut animations must be replaced with instant or very short transitions. Continuous animations (orb breathing, halo bloom) must be disabled, showing a static state instead. The experience must be complete and first-class, not a degraded fallback.
- **Rationale**: Accessibility is a core quality attribute. Motion-sensitive users must have a fully functional, pleasant experience. The charter's design philosophy demands that every element deserves care -- including the no-motion path.
- **Acceptance Criteria**:
  - AC-011a: With Reduce Motion enabled, all spring and easeInOut animations are replaced with instant transitions or very short crossfades (approximately 0.15s).
  - AC-011b: Orb breathing and halo bloom are disabled; orbs display at a static, full-opacity state.
  - AC-011c: Content load stagger is disabled; all blocks appear immediately.
  - AC-011d: Theme crossfade is preserved but shortened (approximately 0.15s) because a hard theme cut is jarring even for motion-sensitive users.
  - AC-011e: All functionality remains fully accessible -- Reduce Motion removes visual motion but does not remove any functional capability.

### REQ-012: Animation Single Source of Truth

- **Priority**: Must Have
- **User Type**: Future contributors (developer experience)
- **Requirement**: Every animation timing value used anywhere in the application must be defined in a single, central location. No animation may use inline timing values. Each entry must be documented with its visual intent, design rationale, and the primitive it derives from.
- **Rationale**: A single source of truth prevents animation drift, makes auditing possible, and enables consistent Reduce Motion overrides from one location.
- **Acceptance Criteria**:
  - AC-012a: All animation timing values are defined in one central file.
  - AC-012b: No inline animation timing values exist anywhere else in the codebase.
  - AC-012c: Each animation constant has documentation covering visual intent, design rationale, and primitive derivation.

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| Expectation | Target |
|-------------|--------|
| Idle GPU utilization (orb breathing only) | At or below 5% on M1 MacBook Air |
| Peak GPU utilization (simultaneous mode change + theme crossfade) | At or below 15% on M1 MacBook Air |
| Frame rate for all animations | Sustained 60fps with no dropped frames |
| Spring animation settling | Animations within 0.5pt of final value are considered settled and removed from render loop |

### 6.2 Security Requirements

No security-specific requirements. Animations operate entirely within the local SwiftUI rendering pipeline with no external data or network involvement.

### 6.3 Usability Requirements

| Requirement | Description |
|-------------|-------------|
| Subtlety over spectacle | Animations must feel natural and unobtrusive after repeated exposure. A daily-driver user seeing the same animation hundreds of times must never find it annoying. |
| Physical feel | Spring-based animations should feel like they have physical weight and momentum, not robotic or purely mathematical. |
| Breathing rhythm | Continuous animations (orb pulse) must be timed to human breathing rhythms (~12 cycles/min) to create a subconscious sense of calm. |
| No animation for animation's sake | Every animated element must have a clear purpose: signaling state change, providing affordance feedback, or creating a sense of continuity between states. |

### 6.4 Compliance Requirements

| Requirement | Description |
|-------------|-------------|
| macOS Reduce Motion | Full compliance with the `accessibilityReduceMotion` system preference. Tested as a first-class code path, not an afterthought. |

## 7. User Stories

### STORY-001: Consistent Motion Experience

- **As a** daily-driver developer
- **I want** every animated element in mkdn to feel like it belongs to the same visual language
- **So that** the app feels cohesive and intentionally designed rather than assembled from mismatched parts

**Acceptance Scenarios**:

- GIVEN I am using mkdn with multiple animated elements visible (orb breathing, focus border appearing, mode transition overlay)
  WHEN I observe the motion of each element
  THEN all animations share a recognizable family resemblance in their timing, curves, and character

### STORY-002: Smooth Mermaid Focus

- **As a** developer viewing a Markdown file with Mermaid diagrams
- **I want** the focus border to bloom in smoothly when I click a diagram
- **So that** the interaction feels polished and alive rather than a blunt state toggle

**Acceptance Scenarios**:

- GIVEN I am viewing a Markdown file with at least one Mermaid diagram
  WHEN I click on a Mermaid diagram to focus it
  THEN a focus border animates in with a soft bloom effect (not a hard cut)

- GIVEN a Mermaid diagram is focused
  WHEN I click elsewhere to remove focus
  THEN the focus border dissolves out smoothly

### STORY-003: Graceful Content Appearance

- **As a** user opening a Markdown file
- **I want** the rendered content to appear with a subtle staggered animation
- **So that** the file reveal feels intentional and beautiful rather than an abrupt dump of content

**Acceptance Scenarios**:

- GIVEN I open a Markdown file from the terminal via `mkdn file.md`
  WHEN the file is parsed and rendered
  THEN content blocks appear with a staggered fade-in and subtle upward drift

- GIVEN I am viewing a file that has changed on disk and I trigger a reload
  WHEN the file is re-rendered
  THEN the stagger animation replays from the first visible block

### STORY-004: Smooth Mermaid State Transitions

- **As a** developer viewing a file with Mermaid diagrams
- **I want** transitions between loading, rendered, and error states to be smooth crossfades
- **So that** I am not jarred by abrupt visual cuts while waiting for diagrams to render

**Acceptance Scenarios**:

- GIVEN a Mermaid diagram is in the loading state with a pulsing spinner
  WHEN rendering completes
  THEN the spinner fades out and the rendered diagram fades in simultaneously

- GIVEN a Mermaid diagram fails to render
  WHEN the error state appears
  THEN it crossfades in rather than appearing as a hard cut

### STORY-005: Hover Discoverability

- **As a** new user exploring mkdn for the first time
- **I want** interactive elements to respond subtly when I hover over them
- **So that** I can discover what is clickable without needing instructions

**Acceptance Scenarios**:

- GIVEN I move my mouse over an orb indicator
  WHEN the cursor enters the orb's bounds
  THEN the orb subtly scales up to signal interactivity

- GIVEN I move my mouse over an unfocused Mermaid diagram
  WHEN the cursor enters the diagram's bounds
  THEN a subtle brightness change hints that the diagram is clickable

### STORY-006: Motion-Sensitive User Experience

- **As a** motion-sensitive user with Reduce Motion enabled
- **I want** mkdn to respect my system preference by eliminating non-essential animation
- **So that** I can use the app comfortably without motion-triggered discomfort

**Acceptance Scenarios**:

- GIVEN I have enabled "Reduce Motion" in macOS System Settings
  WHEN I open mkdn
  THEN orbs are displayed at a static state (no breathing or pulsing)

- GIVEN Reduce Motion is enabled
  WHEN I switch themes
  THEN the theme change uses a very short crossfade (not a hard cut, but significantly shorter than the standard animation)

- GIVEN Reduce Motion is enabled
  WHEN I open a file
  THEN all content blocks appear immediately without stagger animation

### STORY-007: Popover Polish

- **As a** daily-driver developer
- **I want** popovers (like the orb's dialog) to enter with a subtle spring animation
- **So that** even small UI surfaces feel part of the same design language

**Acceptance Scenarios**:

- GIVEN I click on an orb to open its popover
  WHEN the popover appears
  THEN it scales up from slightly smaller with a spring-settle effect and simultaneous opacity fade-in

## 8. Business Rules

| Rule ID | Rule | Rationale |
|---------|------|-----------|
| BR-001 | All animation timing values must originate from a single, central source. No inline values. | Prevents animation drift and enables consistent Reduce Motion overrides. |
| BR-002 | Every new animation added to the app must be derivable from existing named primitives. If a new primitive is needed, it must be added to the central source with full documentation. | Maintains coherence of the animation language over time. |
| BR-003 | The orb animation system is the canonical aesthetic reference. Other animations should evoke the orb's qualities (breathing rhythm, spring physics, bloom/dissolve character) without literally replicating the orb. | Ensures a unified product identity while allowing variety. |
| BR-004 | Reduce Motion is a first-class code path, not a degradation. It must be designed, not just toggled off. | Accessibility is a design concern, not an afterthought. |
| BR-005 | Animations must never block user interaction. Spring settling, crossfades, and stagger sequences must not prevent the user from clicking, scrolling, or otherwise interacting during the animation. | A tool must never feel sluggish. Perceived responsiveness trumps animation completeness. |
| BR-006 | Continuous animations (orb breathing) are limited to a maximum of two simultaneous instances to stay within GPU budget. | Performance constraint derived from M1 MacBook Air target. |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Type | Notes |
|------------|------|-------|
| SwiftUI Animation API | Platform framework | All motion uses SwiftUI's built-in animation system. No external animation libraries. |
| `AnimationConstants.swift` | Internal file | Existing file at `mkdn/UI/Theme/AnimationConstants.swift`. Will be expanded with new primitives. Single source of truth for all timing values. |
| macOS 14.0+ (Sonoma) | Platform | Required for `Animation.spring(response:dampingFraction:)` and `@Observable`. |
| Existing orb system | Internal | `FileChangeOrbView` and `DefaultHandlerHintView` define the aesthetic baseline. |
| Existing mode transition overlay | Internal | `ModeTransitionOverlay` is already implemented with spring-in + fade-out. |
| Existing Mermaid block view | Internal | `MermaidBlockView` has the focus border and loading/error states that need animation. |

### Constraints

| Constraint | Impact |
|------------|--------|
| WKWebView boundary | SwiftUI cannot animate content inside the WKWebView used for Mermaid diagrams. Only SwiftUI layers outside/above the web view (focus border, loading overlay, error overlay) can be animated. Theme changes inside the web view are handled by JavaScript. |
| GPU budget | Continuous animations must be lightweight (simple property animations: opacity, scale, shadow radius). No complex path or mesh animations. |
| Reduce Motion | `accessibilityReduceMotion` must be respected as a first-class path. |
| Theme crossfade isolation | Theme crossfade must not interfere with in-progress orb pulses or spring animations. Requires explicit animation scoping rather than implicit broad animation modifiers. |
| No external animation libraries | All motion must be pure SwiftUI. No Lottie, Rive, Pop, or similar. |
| Subtlety requirement | All animations must withstand repeated daily exposure without becoming annoying. This constraint favors conservative, understated motion over attention-grabbing flourishes. |

## 10. Clarifications Log

| ID | Question | Resolution | Source |
|----|----------|------------|--------|
| CL-001 | Should the content load stagger animate on every scroll-into-view, or only on initial file load/reload? | Inferred: Only on initial file load and reload. Scroll-into-view animation risks feeling busy on fast scrolling and adds complexity. Conservative default. | PRD OQ-1 + conservative inference |
| CL-002 | Should the Mermaid focus border glow use the diagram's theme accent color or always Solarized violet? | Inferred: Use the Solarized theme accent color (matching the current theme) rather than always violet. This creates visual continuity with the overall theme while the orb retains its distinct color semantics. | PRD OQ-2 + conservative inference |
| CL-003 | What is the right hover feedback for Mermaid diagrams -- brightness overlay, border hint, or subtle scale? | Inferred: Brightness overlay (white at low opacity). Avoids layout shifts from scale and is the most lightweight GPU option. | PRD OQ-3 + conservative inference |
| CL-004 | Should popover exit animations match entrance (spring-settle in reverse) or use a simpler fade? | Inferred: Simpler fade for exit. Matching spring-settle in reverse could delay perceived responsiveness. A quick fade-out feels more responsive while still being polished. | PRD OQ-4 + conservative inference |
| CL-005 | No REQUIREMENTS input was provided. | Feature requirements inferred entirely from the PRD `animation-design-language.md` and project charter. | PRD + Charter |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | `animation-design-language.md` | Exact filename match with FEATURE_ID. Only one matching PRD. |
| REQUIREMENTS input | Empty -- derived from PRD | No raw requirements were provided. The PRD `animation-design-language.md` is comprehensive and was used as the sole requirements source. |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| Content load stagger trigger scope (OQ-1) | Only on initial file load and reload, not scroll-into-view | PRD OQ-1 context + conservative default (avoids complexity and visual busyness) |
| Mermaid focus border glow color (OQ-2) | Theme accent color (not always violet) | PRD OQ-2 context + conservative default (theme continuity over orb consistency) |
| Mermaid hover feedback type (OQ-3) | Brightness overlay (white at low opacity) | PRD OQ-3 context + conservative default (no layout shifts, lowest GPU cost) |
| Popover exit animation style (OQ-4) | Simple fade (not reverse spring-settle) | PRD OQ-4 context + conservative default (preserves perceived responsiveness) |
| Vague term "subtle" used throughout | Interpreted as: small enough to be subconsciously registered, not consciously noticed. Scale factors in the 1.05-1.08 range, opacity overlays at 0.03. | PRD concrete specs + charter design philosophy |
| Vague term "premium feel" | Interpreted as: consistent, physically plausible motion with no jarring transitions. Measured by daily-driver satisfaction, not by animation quantity. | Charter success criteria + design philosophy |
| Missing actor for "future contributors" stakeholder | Interpreted as: developers who may contribute to the codebase after the animation language is established | Charter context (personal project with potential future contributors) |
