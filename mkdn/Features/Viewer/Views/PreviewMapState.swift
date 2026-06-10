#if os(macOS)
    import Foundation

    /// Shared bridge between the preview's text-view coordinator and the sibling
    /// scroll-marker track. The coordinator publishes ``documentMap`` (heading,
    /// comment, and viewport positions in scroll space); the track renders from it
    /// and calls ``scrollTo`` to jump the preview when a mark is clicked.
    @MainActor @Observable
    final class PreviewMapState {
        var documentMap = PreviewDocumentMap()
        /// Set by the coordinator; called by the track with a scroll-space y. Not
        /// observed — the track invokes it on tap, it never drives a redraw.
        @ObservationIgnored var scrollTo: ((CGFloat) -> Void)?
        /// Immediate (unanimated) variant for dragging the viewport thumb: the
        /// animated `scrollTo` would lag and fight a live drag.
        @ObservationIgnored var scrubTo: ((CGFloat) -> Void)?
    }
#endif
