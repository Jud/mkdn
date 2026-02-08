import SwiftUI

/// Applies a subtle scale-up effect on mouse hover using ``AnimationConstants/quickSettle``.
///
/// Designed for interactive elements that should "acknowledge" the cursor with
/// minimal motion -- orbs, buttons, and other tappable surfaces. The scale change
/// is subconscious: large enough to feel alive, small enough to not distract.
///
/// With Reduce Motion enabled, the scale change is applied instantly (no spring
/// animation) so the element still provides hover feedback without motion.
struct HoverFeedbackModifier: ViewModifier {
    let scaleFactor: CGFloat
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? scaleFactor : 1.0)
            .animation(
                reduceMotion ? nil : AnimationConstants.quickSettle,
                value: isHovering
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

/// Applies a subtle brightness overlay on mouse hover using ``AnimationConstants/quickSettle``.
///
/// Designed for content areas (Mermaid diagrams) where scale feedback would cause
/// layout shifts. A nearly-imperceptible white overlay signals interactivity
/// without moving or resizing the element.
///
/// With Reduce Motion enabled, the brightness change is applied instantly (no
/// spring animation).
struct BrightnessHoverModifier: ViewModifier {
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                Color.white
                    .opacity(isHovering ? AnimationConstants.mermaidHoverBrightness : 0)
                    .allowsHitTesting(false)
            )
            .animation(
                reduceMotion ? nil : AnimationConstants.quickSettle,
                value: isHovering
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

extension View {
    /// Adds a subtle scale-up hover effect using ``AnimationConstants/quickSettle``.
    ///
    /// - Parameter factor: Scale multiplier on hover. Defaults to
    ///   ``AnimationConstants/hoverScaleFactor`` (1.06).
    func hoverScale(
        _ factor: CGFloat = AnimationConstants.hoverScaleFactor
    ) -> some View {
        modifier(HoverFeedbackModifier(scaleFactor: factor))
    }

    /// Adds a subtle brightness overlay on hover using ``AnimationConstants/quickSettle``.
    ///
    /// The overlay uses ``AnimationConstants/mermaidHoverBrightness`` (0.03) white
    /// opacity -- just enough to register subconsciously as a "this is interactive" hint.
    func hoverBrightness() -> some View {
        modifier(BrightnessHoverModifier())
    }
}
