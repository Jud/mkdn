#if os(macOS)
    import SwiftUI

    enum CommentBoxMetrics {
        /// Transparent padding around the box, leaving room for its shadow so the
        /// hosting view doesn't clip it. The overlay positioner subtracts this to
        /// align the visible box with the comment span. Must exceed the box
        /// shadow's reach (radius + y offset, see `commentBox`).
        static let shadowPadding: CGFloat = 16
        /// How long to keep the host alive after a dismiss so the contract
        /// animation can finish before the view is removed. Derived from the
        /// contract animation's duration so retuning one can't truncate the other.
        static let exitDuration: TimeInterval = AnimationConstants.outlineCloseDuration + 0.05
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

        /// Pop the box open and closed in step with `model.presented`, matching
        /// the outline navigator's expand (`outlinePop`) / contract
        /// (`outlineClose`) feel.
        func commentOverlayTransition(model: CommentOverlayModel, reduceMotion: Bool) -> some View {
            scaleEffect(model.presented ? 1 : 0.9, anchor: .top)
                .opacity(model.presented ? 1 : 0)
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
