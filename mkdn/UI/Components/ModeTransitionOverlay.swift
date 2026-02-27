import SwiftUI

/// Compact pill overlay pinned near the top of the window, inspired by
/// the Dynamic Island. Slides down on entrance, holds briefly, then
/// slides back up and fades out.
struct ModeTransitionOverlay: View {
    let label: String
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        VStack {
            Text(label)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .offset(y: isVisible ? 0 : -30)
                .opacity(isVisible ? 1.0 : 0)
                .padding(.top, 8)

            Spacer()
        }
        .onAppear {
            let entrance: Animation = reduceMotion
                ? AnimationConstants.reducedCrossfade
                : .spring(duration: 0.35, bounce: 0.15)
            withAnimation(entrance) {
                isVisible = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: AnimationConstants.overlayDisplayDuration)
                let exit: Animation = reduceMotion
                    ? AnimationConstants.reducedCrossfade
                    : .easeIn(duration: 0.2)
                withAnimation(exit) {
                    isVisible = false
                }
                try? await Task.sleep(for: AnimationConstants.overlayFadeOutDuration)
                onDismiss()
            }
        }
    }
}
