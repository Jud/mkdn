#if os(macOS)
    import AppKit
    import SwiftUI

    extension View {
        /// Show the pointing-hand cursor while hovering — the comment overlay owns
        /// its cursor (the text view defers over it), so its buttons opt in here.
        func pointingHandCursor() -> some View {
            onHover { $0 ? NSCursor.pointingHand.set() : NSCursor.arrow.set() }
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
        static let fadeDuration: TimeInterval = 0.18
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
#endif
