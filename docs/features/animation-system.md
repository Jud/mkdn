# Feature Blueprint: Animation System

## Overview

mkdn's animation system provides a unified motion language derived from the orb's breathing aesthetic. Every animation in the application -- from orb pulses to content entrance cascades to focus border blooms -- traces back to a shared vocabulary of named motion primitives defined in a single source of truth. The system enforces full macOS Reduce Motion compliance through a centralized resolver, treating the no-motion path as a first-class experience rather than a degraded fallback.

## User Experience

Content loads with a staggered fade-in cascade: each text layout fragment appears in sequence with a subtle upward drift, creating a "reveal" rather than an abrupt dump. Code blocks and tables are grouped so they animate as single units. The stagger runs at 30ms per fragment, capped at 500ms total, so even large documents arrive within half a second.

Interactive elements respond to hover with subconscious-level feedback: orbs scale up 1.06x, toolbar buttons 1.05x, and unfocused Mermaid diagrams gain a 0.03-opacity brightness overlay. Focus borders bloom in with a spring-settle that visually echoes the orb's halo. Theme changes crossfade at 0.35s, scoped so they never interfere with concurrent orb breathing or focus animations.

With Reduce Motion enabled, continuous animations (orb breathing, halo bloom) stop -- orbs display at a static state. Spring and fade transitions collapse to near-instant (0.01s). Content stagger is disabled; all blocks appear immediately. Theme crossfade shortens to 0.15s (a hard cut is jarring even for motion-sensitive users). No functionality is lost.

## Architecture

The system has three structural components:

**AnimationConstants** (`mkdn/UI/Theme/AnimationConstants.swift`) -- a `static`-only enum that serves as the single source of truth for every timing value in the app. Organized into primitive groups: Continuous (breathe, haloBloom), Spring (springSettle, gentleSpring, quickSettle), Fade (fadeIn, fadeOut, crossfade, quickFade, quickShift), Orchestration (staggerDelay, staggerCap), and Reduce Motion alternatives (reducedCrossfade, reducedInstant). Also holds dimensional constants for hover feedback, focus borders, and orb colors.

**MotionPreference** (`mkdn/UI/Theme/MotionPreference.swift`) -- a lightweight struct that views instantiate with the SwiftUI `accessibilityReduceMotion` environment value. Exposes a `resolved(_ primitive:) -> Animation?` method that maps a named `Primitive` enum case to either the standard animation or its Reduce Motion alternative. Continuous primitives return `nil` when reduced (disabled entirely). Crossfade returns a shortened 0.15s version. Everything else returns `reducedInstant`. Also provides `allowsContinuousAnimation` and `staggerDelay` convenience properties.

**EntranceAnimator** (`mkdn/Features/Viewer/Views/EntranceAnimator.swift`) -- a `@MainActor` class that drives the per-fragment staggered entrance on document load/reload. Uses Core Animation (CALayer cover layers + CABasicAnimation) rather than SwiftUI animation, because the preview is an NSTextView rendered through TextKit 2. Each layout fragment gets a background-colored cover layer that fades to transparent with an index-based stagger delay. An additional view-level drift animation shifts the entire text view upward by 8pt over the total duration. Code block and table fragments are grouped by block ID (via custom text attributes) so they share a single full-width cover layer. A cleanup task removes all cover layers after the last animation completes.

## Implementation Decisions

**Breathing rate derivation.** The `breathe` primitive uses a 2.5s half-cycle (easeInOut, repeating with autoreversal), producing a full cycle of approximately 5 seconds, which yields roughly 12 cycles per minute. This matches the human resting respiratory rate, creating a subconscious sense of calm. The `haloBloom` primitive runs at 3.0s half-cycle, creating a phase drift against the core pulse that makes the orb feel organic rather than mechanically synchronized.

**Cover-layer approach for entrance.** Because the preview is an NSTextView (not SwiftUI), the entrance animator uses CALayer cover layers painted in the background color and faded to transparent. This avoids fighting TextKit 2's layout pipeline and works with any text content without modifying the attributed string.

**Block grouping.** Code blocks and tables span multiple layout fragments. Without grouping, individual fragments within a code block would stagger independently, breaking the visual unit. The animator detects grouping via custom `NSAttributedString` attributes (`CodeBlockAttributes.range`, `TableAttributes.range`) and creates a single full-width cover layer per block.

**Theme crossfade isolation.** Theme crossfade uses explicit `withAnimation` scoping at the call site. Because SwiftUI's `withAnimation` only captures state changes within its closure, orb breathing and focus border animations -- driven by their own separate `withAnimation` calls -- are unaffected.

**No external animation libraries.** All motion is pure SwiftUI animation API or Core Animation. No Lottie, Rive, or similar dependencies.

## Files

| File | Role |
|------|------|
| `mkdn/UI/Theme/AnimationConstants.swift` | Named motion primitives, timing values, dimensional constants |
| `mkdn/UI/Theme/MotionPreference.swift` | Reduce Motion resolver with `Primitive` enum |
| `mkdn/Features/Viewer/Views/EntranceAnimator.swift` | Per-fragment staggered entrance via CALayer covers |

## Dependencies

- **SwiftUI Animation API**: All declarative animations (spring, easeInOut, easeIn, easeOut, repeatForever).
- **Core Animation**: Used by EntranceAnimator for CALayer cover layers and CABasicAnimation on the NSTextView.
- **macOS 14.0+ (Sonoma)**: Required for `Animation.spring(response:dampingFraction:)` and `@Observable`.
- **`@Environment(\.accessibilityReduceMotion)`**: Standard SwiftUI environment value for reading the system Reduce Motion preference.
- **TextKit 2**: EntranceAnimator enumerates `NSTextLayoutFragment` objects from the text layout manager.

No external dependencies. No third-party frameworks.

## Testing

Unit tests validate constants and Reduce Motion resolution logic. Visual animation behavior (spring feel, crossfade smoothness, frame rate) is verified manually or via the mkdn-ctl visual testing harness.

**AnimationConstantsTests** (`mkdnTests/Unit/UI/AnimationConstantsTests.swift`) -- 9 tests covering: stagger delay is 30ms, stagger cap is 500ms, hover scale factors are within the subtle range (1.0-1.15), toolbar scale is subtler than orb scale, focus border width is 2pt, focus glow radius is 6pt, Mermaid hover brightness is positive and below 0.1, stagger cap accommodates at least 10 blocks.

**MotionPreferenceTests** (`mkdnTests/Unit/UI/MotionPreferenceTests.swift`) -- 7 tests covering: `allowsContinuousAnimation` returns true/false based on reduceMotion, `staggerDelay` is zero with reduceMotion and standard without, continuous primitives (breathe, haloBloom) resolve to nil with reduceMotion, non-continuous primitives resolve to non-nil with reduceMotion, all primitives resolve to non-nil without reduceMotion.

EntranceAnimator is not unit-tested directly because it requires a live NSTextView with completed TextKit 2 layout. Entrance behavior is verified through the visual testing harness: load a fixture, capture screenshots at multiple scroll positions, and inspect the result.
