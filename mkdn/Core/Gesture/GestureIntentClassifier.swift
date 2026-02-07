import AppKit

/// Classifies scroll-wheel events as diagram pans or document-scroll pass-throughs.
///
/// A lightweight, synchronous, pure struct that examines extracted scroll event
/// fields and tracks gesture-sequence state to produce a verdict per event.
/// No allocations, no async, no side effects beyond internal state mutation.
///
/// Decision rules (mapped from business rules):
/// - BR-01: Gesture started outside the diagram stays pass-through for its duration.
/// - BR-02: Fresh gesture over the diagram (`.began`) produces `.panDiagram`.
/// - BR-03: Momentum-phase events always produce `.passThrough`.
/// - BR-05: Content that fits in the frame always produces `.passThrough`.
struct GestureIntentClassifier {
    enum Verdict {
        case panDiagram
        case passThrough
    }

    enum GestureState {
        case idle
        case panning
        case passingThrough
    }

    private(set) var gestureState: GestureState = .idle

    /// Classify a scroll event and return the appropriate verdict.
    ///
    /// Accepts extracted event fields rather than a raw `NSEvent` so callers
    /// can test the classifier with synthetic inputs (design decision D4).
    ///
    /// - Parameters:
    ///   - phase: The gesture phase from `NSEvent.phase`.
    ///   - momentumPhase: The momentum phase from `NSEvent.momentumPhase`.
    ///   - contentFitsInFrame: Whether the diagram content fits within its visible frame
    ///     at the current zoom scale. When `true`, there is nothing to pan and all
    ///     events pass through.
    /// - Returns: `.panDiagram` if the event should pan the diagram,
    ///   `.passThrough` if it should be forwarded to the parent scroll view.
    mutating func classify(
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase,
        contentFitsInFrame: Bool
    ) -> Verdict {
        // BR-03: Momentum events always pass through to document scroll.
        if !momentumPhase.isEmpty {
            return .passThrough
        }

        // Phase end/cancel: reset tracking state for the next gesture sequence.
        if phase.contains(.ended) || phase.contains(.cancelled) {
            gestureState = .idle
            return .passThrough
        }

        // Phase began: determine intent for this gesture sequence.
        if phase.contains(.began) {
            if contentFitsInFrame {
                // BR-05: Nothing to pan; pass through for the whole sequence.
                gestureState = .passingThrough
                return .passThrough
            }
            // BR-02: Fresh gesture over the diagram; pan for the whole sequence.
            gestureState = .panning
            return .panDiagram
        }

        // Phase changed: sticky verdict follows whatever was decided at .began.
        if phase.contains(.changed) {
            switch gestureState {
            case .panning:
                return .panDiagram
            case .passingThrough:
                return .passThrough
            case .idle:
                // BR-01: .changed without a prior .began means the gesture
                // originated outside this view. Lock to pass-through.
                gestureState = .passingThrough
                return .passThrough
            }
        }

        // Fallback for unexpected phase combinations (e.g., .mayBegin).
        return .passThrough
    }
}
