#if os(macOS)
    import AppKit
    import SwiftUI

    extension View {
        /// Show the pointing-hand cursor while hovering. Uses `onContinuousHover`
        /// (re-setting on every move) rather than `onHover` + a one-shot
        /// `NSCursor.set()`: over the comment sidebar (a separate hosting view on
        /// top of the text view) a one-shot set is reset to the arrow on the next
        /// mouse move, so the pointer flickers back. Re-setting per move makes it
        /// stick.
        func pointingHandCursor() -> some View {
            onContinuousHover { phase in
                switch phase {
                case .active: NSCursor.pointingHand.set()
                case .ended: NSCursor.arrow.set()
                }
            }
        }
    }

    enum CommentBoxMetrics {
        /// Transparent padding around the box, leaving room for its shadow so the
        /// hosting view doesn't clip it. The overlay positioner subtracts this to
        /// align the visible box with the comment span. Must exceed the box
        /// shadow's reach (radius + y offset, see `commentBox`).
        static let shadowPadding: CGFloat = 16
        /// Duration of the box's fade in/out, driven on the AppKit host's
        /// `alphaValue` (a SwiftUI `.opacity` mis-composites the material backing).
        /// Matched to the scale-out so the host (removed on the fade's completion)
        /// outlives the SwiftUI close animation rather than truncating it.
        static let fadeDuration: TimeInterval = AnimationConstants.outlineCloseDuration
    }

    extension AppTheme {
        /// The control appearance to pin the comment overlays to (the theme, not
        /// the system) so default buttons stay legible on the themed box.
        var colorScheme: ColorScheme { self == .solarizedDark ? .dark : .light }
    }

    /// Drives a comment overlay's expand/contract. AppKit flips `presented` and
    /// the hosted SwiftUI view animates the box in/out (mirroring the outline's
    /// pop-open / quick-close), so the dismiss "pops out" rather than vanishing.
    @MainActor
    final class CommentOverlayModel: ObservableObject {
        @Published var presented = false
    }

    extension View {
        /// Floating-box chrome for the comment overlays: the same frosted,
        /// elevated surface as the outline navigator (ultra-thin material under a
        /// translucent theme tint) so the box reads as floating above — not
        /// matching — the window background. Padding leaves room for the shadow;
        /// the control appearance is pinned to the theme so default buttons stay
        /// legible. Shadow reach (radius + y) must stay within
        /// `CommentBoxMetrics.shadowPadding`.
        func commentBox(theme: AppTheme) -> some View {
            let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            return background(.ultraThinMaterial, in: shape)
                .background(theme.colors.background.opacity(0.6), in: shape)
                .overlay(shape.strokeBorder(theme.colors.border.opacity(0.4), lineWidth: 0.5))
                .environment(\.colorScheme, theme.colorScheme)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                .padding(CommentBoxMetrics.shadowPadding)
        }

        /// The full frame + chrome + pop transition for a comment overlay box,
        /// shared by the compose, display, and edit boxes so they stay visually
        /// identical (the morph between them depends on it).
        func commentOverlayChrome(model: CommentOverlayModel, theme: AppTheme) -> some View {
            modifier(CommentOverlayChrome(model: model, theme: theme))
        }

        /// Pop the box open/closed in step with `model.presented`, matching the
        /// outline navigator's expand (`outlinePop`) / contract (`outlineClose`)
        /// feel. Only the scale lives here; the fade is the AppKit host's
        /// `alphaValue` (animating SwiftUI `.opacity` over the material flashes a
        /// black backing).
        func commentOverlayTransition(model: CommentOverlayModel, reduceMotion: Bool) -> some View {
            scaleEffect(model.presented ? 1 : 0.9, anchor: .top)
                .animation(
                    reduceMotion
                        ? AnimationConstants.reducedInstant
                        : (model.presented ? AnimationConstants.outlinePop : AnimationConstants.outlineClose),
                    value: model.presented
                )
                .onAppear { model.presented = true }
        }
    }

    /// Backs `commentOverlayChrome`; reads Reduce Motion from the environment so
    /// callers don't have to thread it through.
    private struct CommentOverlayChrome: ViewModifier {
        let model: CommentOverlayModel
        let theme: AppTheme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        func body(content: Content) -> some View {
            content
                .padding(12)
                .frame(width: 300, alignment: .leading)
                .commentBox(theme: theme)
                .commentOverlayTransition(model: model, reduceMotion: reduceMotion)
        }
    }
#endif
