import SwiftUI

/// Ephemeral overlay that briefly displays the active mode name
/// during mode transitions, then auto-dismisses.
struct ModeTransitionOverlay: View {
    let label: String
    let onDismiss: () -> Void

    @State private var isVisible = false

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
                withAnimation(AnimationConstants.overlaySpringIn) {
                    isVisible = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: AnimationConstants.overlayDisplayDuration)
                    withAnimation(AnimationConstants.overlayFadeOut) {
                        isVisible = false
                    }
                    try? await Task.sleep(for: AnimationConstants.overlayFadeOutDuration)
                    onDismiss()
                }
            }
    }
}
