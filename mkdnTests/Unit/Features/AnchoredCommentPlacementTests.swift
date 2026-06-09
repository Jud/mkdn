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
    }
#endif
