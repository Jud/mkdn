import SwiftUI

/// Breathing orb indicator shown when the on-disk file has changed.
/// Replaces the text-based OutdatedIndicator with a subtle, calming pulse.
struct BreathingOrbView: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var isPulsing = false
    @State private var isHaloExpanded = false

    private let orbColor = AnimationConstants.orbGlowColor

    var body: some View {
        ZStack {
            outerHalo
            midGlow
            innerCore
        }
        .opacity(isPulsing ? 1.0 : 0.4)
        .onAppear {
            withAnimation(AnimationConstants.orbPulse) {
                isPulsing = true
            }
            withAnimation(AnimationConstants.orbHaloBloom) {
                isHaloExpanded = true
            }
        }
    }

    private var outerHalo: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        orbColor.opacity(isHaloExpanded ? 0.3 : 0.1),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: 20
                )
            )
            .frame(width: 40, height: 40)
            .scaleEffect(isHaloExpanded ? 1.1 : 0.85)
    }

    private var midGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        orbColor.opacity(0.8),
                        orbColor.opacity(0.15),
                    ],
                    center: .center,
                    startRadius: 1,
                    endRadius: 8
                )
            )
            .frame(width: 18, height: 18)
            .shadow(
                color: orbColor.opacity(isPulsing ? 0.6 : 0.2),
                radius: isPulsing ? 10 : 4
            )
            .scaleEffect(isPulsing ? 1.0 : 0.85)
    }

    private var innerCore: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.9),
                        orbColor,
                        orbColor.opacity(0.3),
                    ],
                    center: UnitPoint(x: 0.4, y: 0.35),
                    startRadius: 0,
                    endRadius: 5
                )
            )
            .frame(width: 8, height: 8)
            .opacity(isPulsing ? 1.0 : 0.5)
    }
}
