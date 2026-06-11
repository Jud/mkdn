#if os(macOS)
    import Foundation

    /// Dynamic container width shared with overlay SwiftUI views so they can
    /// resize when the text view width changes (e.g., window resize).
    ///
    /// Also arbitrates the document's single selection, Chrome-style: at most
    /// one table — or the text view — owns a text selection at a time.
    @MainActor @Observable
    final class OverlayContainerState {
        var containerWidth: CGFloat = 600

        /// `blockIndex` of the table that owns the active text selection, or
        /// `nil` when the text view (or nothing) does. Tables observe this and
        /// drop their selection when another view takes it.
        var tableSelectionOwner: Int?

        /// Collapses the text view's own selection — called by a table when it
        /// starts one, so the two never coexist.
        var clearDocumentSelection: (() -> Void)?

        /// Plain text of the owning table's selection, for Cmd+C routed
        /// through the text view (the usual first responder).
        var tableSelectionPlainText: (() -> String?)?

        /// Test-harness bridge: synthetic events can't drive SwiftUI
        /// gestures, so each table registers an imperative driver
        /// (from/to in table-local top-left coords, click count → handled?)
        /// that runs the same selection path the drag gesture runs.
        var tableSelectionDrivers: [Int: (CGPoint, CGPoint, Int) -> Bool] = [:]
    }
#endif
