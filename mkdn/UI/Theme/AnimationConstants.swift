import SwiftUI

/// Centralized animation timing constants for the Controls feature.
enum AnimationConstants {
    // MARK: - Orb Visual

    /// Theme-neutral orb glow color -- Solarized violet (#6c71c4), calm and mystical.
    static let orbGlowColor = Color(red: 0.424, green: 0.443, blue: 0.769)

    // MARK: - Breathing Orb

    /// Pulse animation: sinusoidal, ~12 cycles/min = ~5s per full cycle = ~2.5s per half.
    static let orbPulse: Animation = .easeInOut(duration: 2.5).repeatForever(autoreverses: true)

    /// Halo bloom animation: slightly slower than core pulse for dimensional offset.
    static let orbHaloBloom: Animation = .easeInOut(duration: 3.0)
        .repeatForever(autoreverses: true)

    static let orbAppear: Animation = .easeOut(duration: 0.5)

    static let orbDissolve: Animation = .easeIn(duration: 0.4)

    // MARK: - File Change Orb

    /// Solarized cyan (#2aa198) for the file-change orb -- distinct from the violet default-handler orb.
    static let fileChangeOrbColor = Color(red: 0.165, green: 0.631, blue: 0.596)

    /// Pulse animation for the file-change orb; same cadence as the breathing orb.
    static let fileChangeOrbPulse: Animation = .easeInOut(duration: 2.5)
        .repeatForever(autoreverses: true)

    // MARK: - Default Handler Orb

    /// Pulse animation for the default-handler orb; same cadence as the breathing orb.
    static let defaultHandlerOrbPulse: Animation = .easeInOut(duration: 2.5)
        .repeatForever(autoreverses: true)

    // MARK: - Mode Transition Overlay

    static let overlaySpringIn: Animation = .spring(response: 0.35, dampingFraction: 0.7)

    static let overlayFadeOut: Animation = .easeOut(duration: 0.3)

    /// How long the overlay remains visible before auto-dismiss.
    static let overlayDisplayDuration: Duration = .milliseconds(1_500)

    /// Duration of the fade-out animation (for scheduling cleanup after fade completes).
    static let overlayFadeOutDuration: Duration = .milliseconds(300)

    // MARK: - View Mode Transition

    static let viewModeTransition: Animation = .spring(response: 0.4, dampingFraction: 0.85)

    // MARK: - Theme Crossfade

    static let themeCrossfade: Animation = .easeInOut(duration: 0.35)
}
