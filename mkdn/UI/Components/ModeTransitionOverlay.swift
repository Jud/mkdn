import SwiftUI

/// Ephemeral overlay that briefly displays the active mode name
/// during mode transitions, then auto-dismisses.
///
/// ## Animation Contract
///
/// - **Entrance**: Spring-settle from 0.8 scale + 0 opacity to 1.0 scale + 1.0 opacity
///   using ``AnimationConstants/springSettle``.
/// - **Hold**: Remains visible for ``AnimationConstants/overlayDisplayDuration`` (1.5s).
/// - **Exit**: Fade-out using ``AnimationConstants/quickFade`` (0.2s easeOut).
/// - **Reduce Motion**: Entrance and exit both use ``AnimationConstants/reducedCrossfade``
///   (0.15s easeInOut) for a brief but non-jarring transition.
struct ModeTransitionOverlay: View {
    let label: String
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    private var motion: MotionPreference {
        MotionPreference(reduceMotion: reduceMotion)
    }

    var body: some View {
        Text(label)
            .font(.title2.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0)
            .onAppear {
                let entranceAnimation = reduceMotion
                    ? AnimationConstants.reducedCrossfade
                    : AnimationConstants.springSettle
                withAnimation(entranceAnimation) {
                    isVisible = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: AnimationConstants.overlayDisplayDuration)
                    let exitAnimation = reduceMotion
                        ? AnimationConstants.reducedCrossfade
                        : AnimationConstants.quickFade
                    withAnimation(exitAnimation) {
                        isVisible = false
                    }
                    try? await Task.sleep(for: AnimationConstants.overlayFadeOutDuration)
                    onDismiss()
                }
            }
    }
}
