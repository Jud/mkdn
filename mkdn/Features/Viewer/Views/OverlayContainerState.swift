import Foundation

/// Dynamic container width shared with overlay SwiftUI views so they can
/// resize when the text view width changes (e.g., window resize).
@MainActor @Observable
final class OverlayContainerState {
    var containerWidth: CGFloat = 600
}
