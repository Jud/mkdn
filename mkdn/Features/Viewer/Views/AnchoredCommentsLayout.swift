#if os(macOS)
    import SwiftUI

    /// A card's desired top in the sidebar. Carried as a layout value so the layout
    /// reads each subview's own anchor rather than a parallel array that could fall
    /// out of step with the cards.
    private struct CommentCardAnchor: LayoutValueKey {
        static let defaultValue: CGFloat = 0
    }

    extension View {
        func commentCardAnchor(_ top: CGFloat) -> some View {
            layoutValue(key: CommentCardAnchor.self, value: top)
        }
    }

    /// Places comment cards at their anchors with downward-only collision
    /// (``AnchoredCommentPlacement``), filling the container so an off-screen card
    /// clips out rather than reflowing the rest. The cards follow the document
    /// because the host recomputes each anchor from the live `viewportTop`.
    ///
    /// `atDocumentEnd` lets a dense tail that overflows the panel bottom fit back into
    /// view (see ``AnchoredCommentPlacement``); the host sets it when the document is
    /// scrolled to its end, where the tail can't otherwise be reached.
    struct AnchoredCommentsLayout: Layout {
        var gap: CGFloat = 8
        var atDocumentEnd: Bool = false

        func sizeThatFits(proposal: ProposedViewSize, subviews _: Subviews, cache _: inout ()) -> CGSize {
            proposal.replacingUnspecifiedDimensions()
        }

        func placeSubviews(
            in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()
        ) {
            let cardProposal = ProposedViewSize(width: bounds.width, height: nil)
            let anchors = subviews.map { $0[CommentCardAnchor.self] }
            let heights = subviews.map { $0.sizeThatFits(cardProposal).height }
            let tops = AnchoredCommentPlacement.tops(
                anchors: anchors,
                heights: heights,
                gap: gap,
                visibleBottom: bounds.height,
                fitBottomOverflow: atDocumentEnd
            )
            for (index, subview) in subviews.enumerated() {
                subview.place(
                    at: CGPoint(x: bounds.minX, y: bounds.minY + tops[index]),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: bounds.width, height: heights[index])
                )
            }
        }
    }
#endif
