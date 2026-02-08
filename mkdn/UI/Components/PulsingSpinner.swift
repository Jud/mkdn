import SwiftUI

/// A pulsing spinner that breathes at the orb's rhythm.
///
/// Used as the Mermaid diagram loading indicator, visually connecting
/// the wait state to the orb breathing aesthetic. When Reduce Motion
/// is enabled, displays at a static full-opacity state.
struct PulsingSpinner: View {
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(AnimationConstants.orbGlowColor.opacity(0.6))
            .frame(width: 12, height: 12)
            .scaleEffect(isPulsing ? 1.0 : 0.6)
            .opacity(isPulsing ? 1.0 : 0.4)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(AnimationConstants.breathe) {
                    isPulsing = true
                }
            }
    }
}
