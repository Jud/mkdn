#if os(macOS)
    import Foundation

    /// Resolves comment-card tops from their desired anchors with downward-only
    /// collision. Pure (no SwiftUI), so the layout math is unit-testable apart from
    /// the ``Layout``.
    ///
    /// Each card sits at its anchor (`commentY − viewportTop`, so it tracks the text
    /// it annotates), unless that would overlap the card above — then it drops to just
    /// below it. The first card keeps its anchor even when negative: a comment scrolled
    /// above the viewport keeps a negative top and clips out, rather than snapping into
    /// view and shoving the rest down.
    enum AnchoredCommentPlacement {
        /// `anchors` and `heights` are parallel, in document (top-down) order.
        static func tops(anchors: [CGFloat], heights: [CGFloat], gap: CGFloat) -> [CGFloat] {
            var tops: [CGFloat] = []
            tops.reserveCapacity(anchors.count)
            var cursor = -CGFloat.greatestFiniteMagnitude
            for index in anchors.indices {
                let top = max(anchors[index], cursor)
                tops.append(top)
                let height = index < heights.count ? heights[index] : 0
                cursor = top + height + gap
            }
            return tops
        }
    }
#endif
