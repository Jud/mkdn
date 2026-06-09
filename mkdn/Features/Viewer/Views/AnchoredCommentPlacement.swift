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
        ///
        /// `visibleBottom`/`fitBottomOverflow`: at the document's scroll end, cards can
        /// no longer be pulled into view by scrolling, so a dense tail that cascades past
        /// the panel bottom would be unreachable. When `fitBottomOverflow` is on and the
        /// last card overflows `visibleBottom`, a reverse pass lifts just the overflowing
        /// suffix up to fit — stopping the moment an earlier card no longer collides, so
        /// the anchored cards above keep their place. Off mid-document, where the tail is
        /// meant to be below the panel and reachable by scrolling.
        static func tops(
            anchors: [CGFloat],
            heights: [CGFloat],
            gap: CGFloat,
            visibleBottom: CGFloat? = nil,
            fitBottomOverflow: Bool = false
        ) -> [CGFloat] {
            var tops: [CGFloat] = []
            tops.reserveCapacity(anchors.count)
            var cursor = -CGFloat.greatestFiniteMagnitude
            for index in anchors.indices {
                let top = max(anchors[index], cursor)
                tops.append(top)
                let height = index < heights.count ? heights[index] : 0
                cursor = top + height + gap
            }

            guard fitBottomOverflow, let visibleBottom, let last = tops.indices.last
            else { return tops }
            let lastHeight = last < heights.count ? heights[last] : 0
            guard tops[last] + lastHeight > visibleBottom else { return tops }
            var fitCursor = visibleBottom
            for index in tops.indices.reversed() {
                let height = index < heights.count ? heights[index] : 0
                let maxTop = fitCursor - height
                guard tops[index] > maxTop else { break }
                tops[index] = maxTop
                fitCursor = maxTop - gap
            }
            return tops
        }
    }
#endif
