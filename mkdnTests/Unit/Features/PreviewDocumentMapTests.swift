#if os(macOS)
    import AppKit
    import Testing
    @testable import mkdnLib

    @Suite("PreviewDocumentMap")
    struct PreviewDocumentMapTests {
        // Three contiguous blocks spanning [0,10) [10,30) [30,45); length 45.
        private let model = DocumentHeightModel(blocks: [
            BlockSpan(index: 0, range: NSRange(location: 0, length: 10)),
            BlockSpan(index: 1, range: NSRange(location: 10, length: 20)),
            BlockSpan(index: 2, range: NSRange(location: 30, length: 15)),
        ])
        // Block tops in text-view space; scroll-space y = top - originY (32 below).
        private let offsets = DocumentBlockOffsets(
            blocks: [
                BlockOffset(index: 0, top: 32),
                BlockOffset(index: 1, top: 132),
                BlockOffset(index: 2, top: 332),
            ],
            totalHeight: 500
        )
        private let originY: CGFloat = 32

        // MARK: - DocumentHeightModel.blockIndex(containing:)

        @Test("Location resolves to its containing block")
        func locationInsideBlocks() {
            #expect(model.blockIndex(containing: 5) == 0)
            #expect(model.blockIndex(containing: 20) == 1)
            #expect(model.blockIndex(containing: 44) == 2)
        }

        @Test("A boundary location belongs to the later block")
        func locationOnBoundary() {
            // 10 ends block 0 and starts block 1; 30 ends block 1 and starts block 2.
            #expect(model.blockIndex(containing: 10) == 1)
            #expect(model.blockIndex(containing: 30) == 2)
        }

        @Test("A location at or past the end falls to the last block")
        func locationAtEnd() {
            #expect(model.blockIndex(containing: 45) == 2)
            #expect(model.blockIndex(containing: 99) == 2)
        }

        @Test("An empty model resolves no block")
        func emptyModel() {
            let empty = DocumentHeightModel(blocks: [])
            #expect(empty.blockIndex(containing: 0) == nil)
        }

        // MARK: - build

        @Test("Headings convert block tops to scroll-space y")
        func buildHeadings() {
            let headings = [
                HeadingNode(id: 0, title: "Intro", level: 1, blockIndex: 0),
                HeadingNode(id: 2, title: "Details", level: 2, blockIndex: 2),
            ]
            let map = PreviewDocumentMap.build(
                headings: headings, comments: [], offsets: offsets, blockModel: model,
                textContainerOriginY: originY, totalHeight: 480, viewportTop: 0, viewportHeight: 100
            )
            #expect(map.headings.map(\.y) == [0, 300]) // 32-32, 332-32
            #expect(map.headings.map(\.level) == [1, 2])
            #expect(map.headings.map(\.title) == ["Intro", "Details"])
            #expect(map.estimatedTotalHeight == 500)
            #expect(map.totalHeight == 480)
        }

        @Test("A heading whose block has no offset is dropped")
        func buildHeadingMissingOffset() {
            let headings = [HeadingNode(id: 9, title: "Ghost", level: 1, blockIndex: 9)]
            let map = PreviewDocumentMap.build(
                headings: headings, comments: [], offsets: offsets, blockModel: model,
                textContainerOriginY: originY, totalHeight: 480, viewportTop: 0, viewportHeight: 100
            )
            #expect(map.headings.isEmpty)
        }

        @Test("Comments map through their containing block to scroll-space y")
        func buildComments() {
            let comments: [(id: String, range: NSRange)] = [
                (id: "a", range: NSRange(location: 5, length: 3)),   // block 0 -> y 0
                (id: "b", range: NSRange(location: 10, length: 1)),  // boundary -> block 1 -> y 100
                (id: "c", range: NSRange(location: 35, length: 2)),  // block 2 -> y 300
                (id: "d", range: NSRange(location: 45, length: 0)),  // end -> block 2 -> y 300
            ]
            let map = PreviewDocumentMap.build(
                headings: [], comments: comments, offsets: offsets, blockModel: model,
                textContainerOriginY: originY, totalHeight: 480, viewportTop: 0, viewportHeight: 100
            )
            #expect(map.comments.map(\.id) == ["a", "b", "c", "d"])
            #expect(map.comments.map(\.blockIndex) == [0, 1, 2, 2])
            #expect(map.comments.map(\.y) == [0, 100, 300, 300])
        }

        // MARK: - normalization

        @Test("normalized maps y onto [0, 1] and clamps")
        func normalized() {
            let map = PreviewDocumentMap(totalHeight: 400)
            #expect(abs(map.normalized(100) - 0.25) < 1e-9)
            #expect(map.normalized(-50) == 0)
            #expect(map.normalized(800) == 1)
            #expect(PreviewDocumentMap(totalHeight: 0).normalized(100) == 0)
        }

        @Test("normalizedViewport is a clamped (top, height) fraction")
        func normalizedViewport() {
            let inside = PreviewDocumentMap(totalHeight: 400, viewportTop: 100, viewportHeight: 200)
            #expect(abs(inside.normalizedViewport.top - 0.25) < 1e-9)
            #expect(abs(inside.normalizedViewport.height - 0.5) < 1e-9)

            // Viewport overhanging the end: height clamps so the thumb stays in the track.
            let overhang = PreviewDocumentMap(totalHeight: 400, viewportTop: 360, viewportHeight: 200)
            #expect(abs(overhang.normalizedViewport.top - 0.9) < 1e-9)
            #expect(abs(overhang.normalizedViewport.height - 0.1) < 1e-9)

            #expect(PreviewDocumentMap(totalHeight: 0).normalizedViewport.height == 0)
        }
    }
#endif
