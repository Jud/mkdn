import SwiftUI

/// Represents the possible states of the unified orb indicator.
///
/// Cases are ordered by display priority (lowest to highest) so that
/// ``Comparable`` synthesis via raw case ordering means `.max()` on a
/// collection of active states returns the highest-priority state.
///
/// Priority: ``fileChanged`` > ``defaultHandler`` > ``idle``.
enum OrbState: Comparable {
    case idle
    case defaultHandler
    case fileChanged

    /// Whether the orb should be visible in this state.
    var isVisible: Bool {
        self != .idle
    }

    /// The color associated with this state.
    var color: Color {
        switch self {
        case .idle: AnimationConstants.orbDefaultHandlerColor
        case .defaultHandler: AnimationConstants.orbDefaultHandlerColor
        case .fileChanged: AnimationConstants.orbFileChangedColor
        }
    }
}
