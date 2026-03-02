#if os(macOS)
    import SwiftUI

    /// Reusable 3-layer orb visual: outer halo, mid glow, and inner core.
    ///
    /// This component handles only the visual rendering -- animation state,
    /// interaction, and popover logic remain in the calling view (``TheOrbView``).
    ///
    /// The three layers create depth through independent opacity, scale, and
    /// shadow modulation driven by the `isPulsing` and `isHaloExpanded` flags.
    struct OrbVisual: View {
        let color: Color
        let isPulsing: Bool
        let isHaloExpanded: Bool

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        /// Static highlight position (original value, used when animation is off).
        private static let staticHighlight = UnitPoint(x: 0.4, y: 0.35)

        var body: some View {
            ZStack {
                outerHalo
                midGlow
                innerCore
            }
            .contentShape(Circle())
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

        @ViewBuilder
        private var innerCore: some View {
            if reduceMotion {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                color,
                                color.opacity(0.3),
                            ],
                            center: Self.staticHighlight,
                            startRadius: 0,
                            endRadius: 7
                        )
                    )
                    .frame(width: 12, height: 12)
                    .opacity(isPulsing ? 1.0 : 0.5)
            } else {
                TimelineView(.animation) { timeline in
                    let highlight = isPulsing
                        ? Self.highlightPosition(at: timeline.date)
                        : Self.staticHighlight
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    color,
                                    color.opacity(0.3),
                                ],
                                center: highlight,
                                startRadius: 0,
                                endRadius: 7
                            )
                        )
                        .frame(width: 12, height: 12)
                        .opacity(isPulsing ? 1.0 : 0.5)
                }
            }
        }

        // MARK: - Highlight Orbit

        /// Computes the highlight UnitPoint along a tilted elliptical orbit.
        ///
        /// The ellipse is wider than tall (horizontal rotation axis viewed from
        /// slightly above), tilted 23.5° to match Earth's axial tilt.
        private static func highlightPosition(at date: Date) -> UnitPoint {
            let period = AnimationConstants.orbRotationPeriod
            let elapsed = date.timeIntervalSinceReferenceDate
            let angle = (elapsed.truncatingRemainder(dividingBy: period) / period) * 2.0 * .pi

            // Orbit center and radii
            let centerX = 0.5
            let centerY = 0.38
            let radiusX = 0.12
            let radiusY = 0.05

            // Earth-like axial tilt (23.5°)
            let tilt = 23.5 * .pi / 180.0

            // Parametric ellipse point before tilt
            let ex = radiusX * cos(angle)
            let ey = radiusY * sin(angle)

            // Rotate by tilt angle
            let cosT = cos(tilt)
            let sinT = sin(tilt)
            let rx = ex * cosT - ey * sinT
            let ry = ex * sinT + ey * cosT

            return UnitPoint(x: centerX + rx, y: centerY + ry)
        }
    }
#endif
