import SwiftUI

/// Reusable 3-layer orb visual: outer halo, mid glow, and inner core.
///
/// Extracted from the identical visual implementations in ``FileChangeOrbView``
/// and ``DefaultHandlerHintView``. This component handles only the visual
/// rendering -- animation state, interaction, and popover logic remain in the
/// calling view.
///
/// The three layers create depth through independent opacity, scale, and
/// shadow modulation driven by the `isPulsing` and `isHaloExpanded` flags.
struct OrbVisual: View {
    let color: Color
    let isPulsing: Bool
    let isHaloExpanded: Bool

    var body: some View {
        ZStack {
            outerHalo
            midGlow
            innerCore
        }
        .opacity(isPulsing ? 1.0 : 0.4)
    }

    // MARK: - Layers

    private var outerHalo: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(isHaloExpanded ? 0.3 : 0.1),
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
                        color.opacity(0.8),
                        color.opacity(0.15),
                    ],
                    center: .center,
                    startRadius: 1,
                    endRadius: 10
                )
            )
            .frame(width: 22, height: 22)
            .shadow(
                color: color.opacity(isPulsing ? 0.6 : 0.2),
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
                        color,
                        color.opacity(0.3),
                    ],
                    center: UnitPoint(x: 0.4, y: 0.35),
                    startRadius: 0,
                    endRadius: 7
                )
            )
            .frame(width: 12, height: 12)
            .opacity(isPulsing ? 1.0 : 0.5)
    }
}
