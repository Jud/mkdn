import SwiftUI

/// Breathing orb indicator shown when the on-disk file has changed.
/// Replaces the text-based OutdatedIndicator with a subtle, calming pulse.
struct BreathingOrbView: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(appSettings.theme.colors.accent)
            .frame(width: 10, height: 10)
            .shadow(
                color: appSettings.theme.colors.accent.opacity(0.6),
                radius: isPulsing ? 8 : 4
            )
            .scaleEffect(isPulsing ? 1.0 : 0.85)
            .opacity(isPulsing ? 1.0 : 0.4)
            .onAppear {
                withAnimation(AnimationConstants.orbPulse) {
                    isPulsing = true
                }
            }
    }
}
