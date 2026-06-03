#if os(macOS)
    import SwiftUI

    enum CommentBoxMetrics {
        /// Transparent padding around the box, leaving room for its shadow so the
        /// hosting view doesn't clip it. The overlay positioner subtracts this to
        /// align the visible box with the comment span.
        static let shadowPadding: CGFloat = 16
        /// How long to keep the host alive after a dismiss so the contract
        /// animation can play before the view is removed.
        static let exitDuration: TimeInterval = 0.25
    }

    /// Drives a comment overlay's expand/contract. AppKit flips `presented` and
    /// the hosted SwiftUI view animates the box in/out (mirroring the outline's
    /// pop-open / quick-close), so the dismiss "pops out" rather than vanishing.
    @MainActor
    final class CommentOverlayModel: ObservableObject {
        @Published var presented = false
    }

    extension View {
        /// Floating-box chrome for the comment overlays: a themed rounded
        /// background, border, and shadow, with padding so the shadow isn't
        /// clipped, and the control appearance pinned to the theme so default
        /// buttons stay legible.
        func commentBox(theme: AppTheme, colorScheme: ColorScheme) -> some View {
            background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.colors.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(theme.colors.border)
            )
            .environment(\.colorScheme, colorScheme)
            .shadow(color: .black.opacity(0.22), radius: 10, y: 3)
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
