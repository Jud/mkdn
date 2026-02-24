import SwiftUI

/// Centralized Reduce Motion resolver for the animation design language.
///
/// Views instantiate this with the environment's `accessibilityReduceMotion`
/// value and use it to resolve named animation primitives to their standard
/// or reduced alternatives. This keeps Reduce Motion logic in one place
/// rather than scattered across views.
///
/// Usage:
/// ```swift
/// @Environment(\.accessibilityReduceMotion) private var reduceMotion
///
/// private var motion: MotionPreference {
///     MotionPreference(reduceMotion: reduceMotion)
/// }
///
/// // Then:
/// withAnimation(motion.resolved(.springSettle)) { ... }
/// ```
struct MotionPreference {
    let reduceMotion: Bool

    /// Named animation primitives that can be resolved to their Reduce Motion
    /// alternatives via ``resolved(_:)``.
    enum Primitive {
        // Continuous
        case breathe
        case haloBloom

        // Spring
        case springSettle
        case gentleSpring
        case quickSettle

        // Fade
        case fadeIn
        case fadeOut
        case crossfade
        case quickFade
        case quickShift
    }

    /// Resolve a named primitive to its standard or Reduce Motion animation.
    ///
    /// - Returns: The full animation when Reduce Motion is off. When Reduce
    ///   Motion is on, continuous primitives return `nil` (disabled), spring
    ///   and fade primitives return ``AnimationConstants/reducedInstant``, and
    ///   crossfade returns ``AnimationConstants/reducedCrossfade`` (shortened
    ///   but preserved because a hard cut is jarring even for motion-sensitive
    ///   users).
    func resolved(_ primitive: Primitive) -> Animation? {
        guard reduceMotion else {
            return standardAnimation(for: primitive)
        }
        return reducedAnimation(for: primitive)
    }

    /// Whether continuous animations (orb breathing, halo bloom) should run.
    var allowsContinuousAnimation: Bool {
        !reduceMotion
    }

    /// Stagger delay per block (0 when Reduce Motion is on).
    var staggerDelay: Double {
        reduceMotion ? 0 : AnimationConstants.staggerDelay
    }

    // MARK: - Private

    private func standardAnimation(for primitive: Primitive) -> Animation {
        switch primitive {
        case .breathe: AnimationConstants.breathe
        case .haloBloom: AnimationConstants.haloBloom
        case .springSettle: AnimationConstants.springSettle
        case .gentleSpring: AnimationConstants.gentleSpring
        case .quickSettle: AnimationConstants.quickSettle
        case .fadeIn: AnimationConstants.fadeIn
        case .fadeOut: AnimationConstants.fadeOut
        case .crossfade: AnimationConstants.crossfade
        case .quickFade: AnimationConstants.quickFade
        case .quickShift: AnimationConstants.quickShift
        }
    }

    private func reducedAnimation(for primitive: Primitive) -> Animation? {
        switch primitive {
        case .breathe, .haloBloom:
            nil
        case .crossfade:
            AnimationConstants.reducedCrossfade
        case .springSettle, .gentleSpring, .quickSettle,
             .fadeIn, .fadeOut, .quickFade, .quickShift:
            AnimationConstants.reducedInstant
        }
    }
}
