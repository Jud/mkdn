import SwiftUI

/// Centralized animation timing constants for the Controls feature.
/// Single source of truth for all animation tuning.
enum AnimationConstants {
    // MARK: - Breathing Orb

    /// Pulse animation: sinusoidal, ~12 cycles/min = ~5s per full cycle = ~2.5s per half.
    static let orbPulse: Animation = .easeInOut(duration: 2.5).repeatForever(autoreverses: true)

    static let orbAppear: Animation = .easeOut(duration: 0.5)

    static let orbDissolve: Animation = .easeIn(duration: 0.4)

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
