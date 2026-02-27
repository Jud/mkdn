import SwiftUI

/// Centralized animation timing constants for mkdn.
///
/// Every animation in the application derives from named primitives defined here.
/// Each primitive traces back to the orb aesthetic -- the canonical animation
/// reference -- and is documented with its visual intent, design rationale, and
/// derivation.
///
/// ## Primitive Groups
///
/// - **Continuous**: ``breathe``, ``haloBloom`` -- repeating, sinusoidal, orb-derived
/// - **Spring**: ``springSettle``, ``gentleSpring``, ``quickSettle`` -- physical, bouncy
/// - **Fade**: ``fadeIn``, ``fadeOut``, ``crossfade``, ``quickFade`` -- opacity transitions
/// - **Orchestration**: ``staggerDelay``, ``staggerCap`` -- multi-element sequencing
/// - **Reduce Motion**: ``reducedCrossfade``, ``reducedInstant`` -- accessibility alternatives
enum AnimationConstants {
    // MARK: - Primitive: Breathe

    // Continuous sinusoidal rhythm timed to human breathing (~12 cycles/min).
    // Derived from: orb core pulse. The foundational continuous animation.

    /// Core breathing rhythm. 2.5s half-cycle = ~5s full cycle = ~12 cycles/min.
    ///
    /// - Visual intent: A gentle, living pulse that rises and falls like a resting breath.
    /// - Design rationale: ~12 cycles/min matches human resting respiratory rate, creating
    ///   a subconscious sense of calm. Sinusoidal easeInOut avoids mechanical feel.
    /// - Derivation: Foundational continuous primitive. The orb core pulse defines this
    ///   rhythm; all other continuous animations are timed relative to it.
    static let breathe: Animation = .easeInOut(duration: 2.5)
        .repeatForever(autoreverses: true)

    /// Halo bloom: slightly slower than core breathing for dimensional offset.
    ///
    /// - Visual intent: An outer glow that expands and contracts behind the core pulse,
    ///   creating depth through phase offset.
    /// - Design rationale: 3.0s half-cycle vs 2.5s core creates a subtle phase drift
    ///   that makes the orb feel organic rather than mechanically synchronized.
    /// - Derivation: Variant of ``breathe``, slowed to create visual layering in the
    ///   orb's three-layer gradient structure.
    static let haloBloom: Animation = .easeInOut(duration: 3.0)
        .repeatForever(autoreverses: true)

    // MARK: - Primitive: Spring-Settle

    // Physical spring entrance with noticeable bounce. Used for prominent UI surfaces.
    // Derived from: orb appear. The orb "bounces into existence."

    /// Standard spring-settle for prominent entrances (overlays, focus borders).
    ///
    /// - Visual intent: A physical "bounce into existence" with noticeable but brief
    ///   overshoot.
    /// - Design rationale: Response 0.35 keeps entrance snappy; damping 0.7 allows one
    ///   visible bounce before settling, giving a sense of physical weight.
    /// - Derivation: Directly from the orb's appear animation translated to spring
    ///   physics. The orb "breathes into existence" -- this primitive captures that
    ///   entrance quality for non-orb UI surfaces.
    static let springSettle: Animation = .spring(
        response: 0.35,
        dampingFraction: 0.7
    )

    // MARK: - Primitive: Gentle-Spring

    // Softer spring with higher damping. Layout transitions that should feel physical
    // but not bouncy. Derived from: orb appear, dampened for subtlety.

    /// Gentle spring for layout transitions (view mode switch, split pane).
    ///
    /// - Visual intent: A smooth, physical transition that feels weighted but not
    ///   bouncy. Content moves into place with momentum that decelerates naturally.
    /// - Design rationale: Response 0.4 gives slightly more time for spatial
    ///   transitions; damping 0.85 nearly eliminates overshoot, appropriate for layout
    ///   changes where bounce would feel distracting.
    /// - Derivation: ``springSettle`` dampened for subtlety. The orb's appear energy,
    ///   tamed for structural transitions that should feel solid rather than playful.
    static let gentleSpring: Animation = .spring(
        response: 0.4,
        dampingFraction: 0.85
    )

    // MARK: - Primitive: Sidebar Slide

    /// Smooth easeInOut slide for sidebar drawer animation.
    ///
    /// Uses a timing curve instead of a spring to guarantee zero overshoot.
    /// Even with continuous TextKit reflow (table row heights update on every
    /// frame via ``OverlayCoordinator/repositionOverlays()``), spring overshoot
    /// causes visible jitter as text reflows back and forth during bounce-back.
    /// An easeInOut curve decelerates smoothly into the final position with no
    /// directional reversal, producing a clean slide.
    static let sidebarSlide: Animation = .easeInOut(duration: 0.35)

    // MARK: - Primitive: Quick-Settle

    // Fast, crisp spring for micro-interactions. Minimal overshoot.
    // Derived from: orb spring, compressed for hover/feedback responsiveness.

    /// Quick spring for hover feedback and micro-interactions.
    ///
    /// - Visual intent: A snappy response that registers as "alive" without drawing
    ///   attention. The element responds immediately and settles almost instantly.
    /// - Design rationale: Response 0.25 provides near-instant feedback; damping 0.8
    ///   minimizes overshoot so the interaction feels responsive, not wobbly.
    /// - Derivation: ``springSettle`` compressed in time and dampened for hover/feedback
    ///   contexts. Captures the orb's spring quality at micro-interaction scale.
    static let quickSettle: Animation = .spring(
        response: 0.25,
        dampingFraction: 0.8
    )

    // MARK: - Primitive: Fade-In

    // Smooth appearance. Ease-out curve (decelerates into rest).
    // Derived from: orb appear timing.

    /// Standard fade-in for element appearance.
    ///
    /// - Visual intent: A smooth emergence from invisible to fully visible,
    ///   decelerating into rest so the element "arrives" gently.
    /// - Design rationale: 0.5s duration balances visibility (not too fast to miss)
    ///   with responsiveness (not so slow it feels sluggish). Ease-out curve
    ///   decelerates into the final state, matching the orb's gentle arrival.
    /// - Derivation: From the orb's appear timing. The orb fades in over 0.5s with
    ///   ease-out; this primitive generalizes that entrance for any element.
    static let fadeIn: Animation = .easeOut(duration: 0.5)

    // MARK: - Primitive: Fade-Out

    // Smooth disappearance. Ease-in curve (accelerates away).
    // Derived from: orb dissolve timing.

    /// Standard fade-out for element removal.
    ///
    /// - Visual intent: A smooth departure that accelerates away, giving a sense of
    ///   the element receding or dissolving rather than being abruptly cut.
    /// - Design rationale: 0.4s is slightly faster than fade-in (0.5s) because users
    ///   are less patient with exits than entrances. Ease-in curve accelerates away
    ///   from the current state, matching the orb's dissolve behavior.
    /// - Derivation: From the orb's dissolve timing. The orb's exit is a receding
    ///   fade; this primitive generalizes that departure for any element.
    static let fadeOut: Animation = .easeIn(duration: 0.4)

    // MARK: - Primitive: Crossfade

    // Symmetric blend between two states. Ease-in-out for balanced feel.
    // Derived from: theme transition aesthetic.

    /// Crossfade for state transitions (theme change, loading to rendered).
    ///
    /// - Visual intent: A balanced blend between two states where neither entrance
    ///   nor exit dominates. Both states are equally weighted during the transition.
    /// - Design rationale: 0.35s is long enough to perceive as a transition (not a
    ///   glitch) but short enough to feel responsive. EaseInOut provides symmetry
    ///   between outgoing and incoming states.
    /// - Derivation: From the theme transition aesthetic. The crossfade bridges visual
    ///   states without the directional quality of fade-in/out, appropriate for
    ///   identity-changing transitions (color, content) rather than presence changes.
    static let crossfade: Animation = .easeInOut(duration: 0.35)

    // MARK: - Primitive: Quick-Fade

    // Fast fade for popover exit, transient feedback.
    // Derived from: crossfade, shortened for responsiveness.

    /// Quick fade for responsive exits (popover dismiss, hover exit).
    ///
    /// - Visual intent: A fast, clean exit that feels immediate without being a hard
    ///   cut. The element is "already going" when the user notices the transition.
    /// - Design rationale: 0.2s is at the threshold of conscious perception -- fast
    ///   enough to feel instant, slow enough to avoid visual pop. Ease-out decelerates
    ///   into gone.
    /// - Derivation: ``crossfade`` shortened for responsiveness. Where crossfade
    ///   bridges two equal states, quick-fade prioritizes the destination over the
    ///   transition.
    static let quickFade: Animation = .easeOut(duration: 0.2)

    // MARK: - Primitive: Quick-Shift

    // Symmetric fast transition. Ease-in-out curve (balanced appear/disappear).
    // Derived from: crossfade, shortened for micro-transitions that need symmetry.

    /// Quick symmetric transition for focus borders and state toggles.
    ///
    /// - Visual intent: A balanced, fast transition where appear and disappear
    ///   are equally weighted. The easeInOut curve gives a symmetric feel
    ///   appropriate for toggling states like focus borders.
    /// - Design rationale: 0.2s matches ``quickFade`` in duration but uses
    ///   easeInOut instead of easeOut, providing symmetry between on and off
    ///   states. Focus borders appear and disappear with equal emphasis.
    /// - Derivation: ``crossfade`` shortened to micro-transition speed. Where
    ///   ``quickFade`` prioritizes the exit, quickShift treats both directions
    ///   equally.
    static let quickShift: Animation = .easeInOut(duration: 0.2)

    // MARK: - Orchestration: Stagger

    /// Per-block stagger delay for content load entrance animation.
    ///
    /// - Visual intent: Successive content blocks appear in a fluid cascade, each
    ///   slightly after the previous, creating a "reveal" rather than an abrupt dump.
    /// - Design rationale: 30ms is fast enough that individual delays are not
    ///   consciously perceived, but the cumulative stagger creates a visible wave.
    /// - Derivation: Timed to complement ``fadeIn`` -- each block begins its 0.5s
    ///   fade-in 30ms after the previous, creating a smooth overlapping cascade.
    static let staggerDelay = 0.03

    /// Maximum total stagger duration to cap entrance length on large documents.
    ///
    /// - Visual intent: Even with hundreds of blocks, the entrance sequence completes
    ///   within half a second. The document "arrives" promptly regardless of size.
    /// - Design rationale: 500ms cap means documents up to ~16 blocks get full
    ///   stagger; beyond that, remaining blocks share the tail of the window.
    static let staggerCap = 0.5

    // MARK: - Orb Colors

    /// Solarized violet (#6c71c4) -- default handler prompt.
    /// Calm and mystical, chosen for its association with focus and intuition.
    static let orbDefaultHandlerColor = Color(red: 0.424, green: 0.443, blue: 0.769)

    /// Solarized orange (#cb4b16) -- file changed on disk.
    /// A warm alert color signaling that attention is needed.
    static let orbFileChangedColor = Color(red: 0.796, green: 0.294, blue: 0.086)

    // MARK: - Overlay Timing

    /// How long the mode transition overlay remains visible before auto-dismiss.
    static let overlayDisplayDuration: Duration = .milliseconds(1_500)

    /// Duration of the overlay fade-out (for scheduling cleanup after fade completes).
    static let overlayFadeOutDuration: Duration = .milliseconds(300)

    // MARK: - Hover Feedback

    /// Orb hover scale factor. Subtle enough to register subconsciously.
    ///
    /// - Visual intent: The orb "notices" the cursor -- a tiny, living response.
    /// - Design rationale: 1.06 is within the 1.05--1.08 range where scale changes
    ///   are felt rather than seen. Larger values risk feeling like a button press.
    /// - Derivation: Orb's living quality extended to cursor interaction. The orb
    ///   breathes; on hover, it also responds.
    static let hoverScaleFactor: CGFloat = 1.06

    /// Toolbar button hover scale factor.
    ///
    /// - Visual intent: Toolbar items acknowledge the cursor with minimal motion.
    /// - Design rationale: 1.05 is slightly subtler than the orb (1.06) because
    ///   toolbar buttons are utilitarian, not expressive.
    /// - Derivation: ``hoverScaleFactor`` reduced for less expressive UI elements.
    static let toolbarHoverScale: CGFloat = 1.05

    /// Mermaid diagram hover brightness overlay opacity.
    ///
    /// - Visual intent: An unfocused diagram brightens almost imperceptibly on hover,
    ///   hinting at interactivity without adding visual noise.
    /// - Design rationale: 0.03 opacity white overlay produces a brightness increase
    ///   that is subconsciously registered. Higher values look like a highlight; lower
    ///   values are invisible on most displays.
    /// - Derivation: Orb's glow aesthetic applied as a flat brightness layer,
    ///   appropriate for rectangular content areas.
    static let mermaidHoverBrightness = 0.03

    // MARK: - Focus Border

    /// Focus border stroke width at full visibility.
    ///
    /// - Visual intent: A clear but not heavy border that frames the focused diagram.
    /// - Design rationale: 2pt is the minimum width that reads clearly on Retina
    ///   displays while remaining elegant. Thicker borders feel heavy; thinner ones
    ///   disappear.
    /// - Derivation: Sized to complement ``focusGlowRadius`` -- the stroke provides
    ///   structure while the glow provides atmosphere.
    static let focusBorderWidth: CGFloat = 2.0

    /// Focus border outer glow radius.
    ///
    /// - Visual intent: A soft halo behind the border that evokes the orb's glow,
    ///   visually connecting the focus state to the breathing orb aesthetic.
    /// - Design rationale: 6pt produces a visible but soft glow. The glow animates in
    ///   alongside the border via ``springSettle``.
    /// - Derivation: From the orb's halo bloom -- the focus glow is the orb's radiant
    ///   quality applied to a rectangular frame.
    static let focusGlowRadius: CGFloat = 6.0

    // MARK: - Reduce Motion Alternatives

    /// Short crossfade for Reduce Motion contexts.
    ///
    /// - Visual intent: Preserves continuity between states (no jarring hard cut)
    ///   while minimizing motion. The transition is felt as a brief blend.
    /// - Design rationale: 0.15s is fast enough that motion-sensitive users will not
    ///   experience discomfort, but slow enough to avoid the harsh feel of an instant
    ///   cut. Used for theme crossfade and state transitions with Reduce Motion.
    /// - Derivation: ``crossfade`` shortened to accessibility threshold. Preserves the
    ///   design intent (smooth state change) while respecting the user's preference.
    static let reducedCrossfade: Animation = .easeInOut(duration: 0.15)

    /// Near-instant transition for Reduce Motion contexts where even a short crossfade
    /// is unnecessary.
    ///
    /// - Visual intent: Effectively instant, but technically animated to avoid SwiftUI
    ///   layout discontinuities that can occur with truly nil animations.
    /// - Design rationale: 0.01s is imperceptible. Using an explicit animation rather
    ///   than nil prevents potential layout jumpiness in some SwiftUI configurations.
    static let reducedInstant: Animation = .linear(duration: 0.01)
}
