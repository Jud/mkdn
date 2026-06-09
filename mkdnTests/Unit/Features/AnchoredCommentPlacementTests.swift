#if os(macOS)
    import Testing
    @testable import mkdnLib

    @Suite("AnchoredCommentPlacement")
    struct AnchoredCommentPlacementTests {
        @Test("Non-overlapping cards keep their anchors")
        func noCollision() {
            let tops = AnchoredCommentPlacement.tops(anchors: [0, 100, 300], heights: [40, 40, 40], gap: 8)
            #expect(tops == [0, 100, 300])
        }

        @Test("Cards sharing an anchor stack with a gap")
        func sameAnchorStacks() {
            let tops = AnchoredCommentPlacement.tops(anchors: [100, 100, 100], heights: [20, 20, 20], gap: 5)
            #expect(tops == [100, 125, 150])
        }

        @Test("An off-screen-above card keeps its negative top — no jump into view")
        func offscreenAbove() {
            let tops = AnchoredCommentPlacement.tops(anchors: [-50, 10], heights: [30, 20], gap: 5)
            #expect(tops == [-50, 10])
        }

        @Test("Collision still pushes down while both cards are above the viewport")
        func collisionAboveViewport() {
            let tops = AnchoredCommentPlacement.tops(anchors: [-50, -40], heights: [30, 20], gap: 5)
            #expect(tops == [-50, -15]) // second dropped to -50 + 30 + 5
        }

        @Test("A dense cluster cascades past the bottom; clipping absorbs the overflow")
        func bottomOverflow() {
            let tops = AnchoredCommentPlacement.tops(anchors: [500, 500, 500], heights: [40, 40, 40], gap: 8)
            #expect(tops == [500, 548, 596])
        }

        @Test("Empty input yields no tops")
        func empty() {
            #expect(AnchoredCommentPlacement.tops(anchors: [], heights: [], gap: 8).isEmpty)
        }

        // MARK: - fitBottomOverflow (document-end reachability)

        @Test("fitBottomOverflow leaves a tail that already fits untouched")
        func fitNoOverflow() {
            let tops = AnchoredCommentPlacement.tops(
                anchors: [0, 100, 200], heights: [40, 40, 40], gap: 8,
                visibleBottom: 600, fitBottomOverflow: true)
            #expect(tops == [0, 100, 200])
        }

        @Test("A dense tail at the document end is lifted up to fit the panel")
        func fitDenseTail() {
            let tops = AnchoredCommentPlacement.tops(
                anchors: [500, 500, 500], heights: [40, 40, 40], gap: 8,
                visibleBottom: 600, fitBottomOverflow: true)
            #expect(tops == [464, 512, 560]) // bottom card ends at 600
        }

        @Test("Fitting the tail leaves earlier anchored cards in place")
        func fitKeepsEarlierCards() {
            let tops = AnchoredCommentPlacement.tops(
                anchors: [100, 500, 500, 500], heights: [40, 40, 40, 40], gap: 8,
                visibleBottom: 600, fitBottomOverflow: true)
            #expect(tops == [100, 464, 512, 560]) // the 100 card is undisturbed
        }

        @Test("Fitting the tail leaves an above-viewport card above")
        func fitKeepsAboveCard() {
            let tops = AnchoredCommentPlacement.tops(
                anchors: [-100, 500, 500, 500], heights: [40, 40, 40, 40], gap: 8,
                visibleBottom: 600, fitBottomOverflow: true)
            #expect(tops == [-100, 464, 512, 560])
        }

        @Test("A card taller than the panel pins its bottom into view")
        func fitOversizedCard() {
            let tops = AnchoredCommentPlacement.tops(
                anchors: [100], heights: [700], gap: 8,
                visibleBottom: 600, fitBottomOverflow: true)
            #expect(tops == [-100]) // bottom at 600; top clips above
        }
    }
#endif
