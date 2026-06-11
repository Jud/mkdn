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

        @Test("Comments carry their precomputed y and resolve their containing block")
        func buildComments() {
            // y is the coordinator's intra-block measure (tested in DocumentBlockOffsets);
            // build pairs each comment with its block and passes the y straight through.
            let comments: [(id: String, range: NSRange, y: CGFloat)] = [
                (id: "a", range: NSRange(location: 5, length: 3), y: 12),   // block 0
                (id: "b", range: NSRange(location: 10, length: 1), y: 108), // boundary -> block 1
                (id: "c", range: NSRange(location: 35, length: 2), y: 305), // block 2
                (id: "d", range: NSRange(location: 45, length: 0), y: 410), // end -> block 2
            ]
            let map = PreviewDocumentMap.build(
                headings: [], comments: comments, offsets: offsets, blockModel: model,
                textContainerOriginY: originY, totalHeight: 480, viewportTop: 0, viewportHeight: 100
            )
            #expect(map.comments.map(\.id) == ["a", "b", "c", "d"])
            #expect(map.comments.map(\.blockIndex) == [0, 1, 2, 2])
            #expect(map.comments.map(\.y) == [12, 108, 305, 410]) // passed through, not block tops
        }

        // MARK: - block bands

        @Test("Block bands tile the document by kind; the last fills to totalHeight")
        func buildBlockBands() {
            let kinded = DocumentHeightModel(blocks: [
                BlockSpan(index: 0, range: NSRange(location: 0, length: 10), kind: .heading(level: 1)),
                BlockSpan(index: 1, range: NSRange(location: 10, length: 20), kind: .code),
                BlockSpan(index: 2, range: NSRange(location: 30, length: 15), kind: .table),
            ])
            let map = PreviewDocumentMap.build(
                headings: [], comments: [], offsets: offsets, blockModel: kinded,
                textContainerOriginY: originY, totalHeight: 480, viewportTop: 0, viewportHeight: 100
            )
            #expect(map.blocks.map(\.id) == [0, 1, 2])
            #expect(map.blocks.map(\.kind) == [.heading(level: 1), .code, .table])
            #expect(map.blocks.map(\.y) == [0, 100, 300]) // tops in scroll space
            #expect(map.blocks.map(\.height) == [100, 200, 180]) // last fills 480-300
        }

        @Test("MarkdownBlock.blockKind folds the renderer cases into minimap kinds")
        func blockKindMapping() {
            #expect(MarkdownBlock.heading(level: 2, text: AttributedString("H")).blockKind == .heading(level: 2))
            #expect(MarkdownBlock.paragraph(text: AttributedString("p")).blockKind == .paragraph)
            #expect(MarkdownBlock.codeBlock(language: nil, code: "x").blockKind == .code)
            #expect(MarkdownBlock.htmlBlock(content: "<b>").blockKind == .code)
            #expect(MarkdownBlock.image(source: "a", alt: "").blockKind == .image)
            #expect(MarkdownBlock.mermaidBlock(code: "g").blockKind == .image)
            #expect(MarkdownBlock.orderedList(items: []).blockKind == .list)
            #expect(MarkdownBlock.blockquote(blocks: []).blockKind == .blockquote)
            #expect(MarkdownBlock.table(columns: [], rows: []).blockKind == .table)
            #expect(MarkdownBlock.mathBlock(code: "x").blockKind == .math)
            #expect(MarkdownBlock.thematicBreak.blockKind == .divider)
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

        @Test("normalized plots a short document's marks at their on-screen position")
        func normalizedShortDocument() {
            // Content (190) fits the viewport (900): the track is 1:1 with the
            // screen, so a mark must land at its rendered line — text y plus the
            // top inset — not stretched by the small content height.
            let map = PreviewDocumentMap(
                totalHeight: 190, viewportTop: 0, viewportHeight: 900, textInsetTop: 32
            )
            #expect(abs(map.normalized(60) - (60 + 32) / 900) < 1e-9)
        }

        @Test("normalized includes the top inset for scrolling documents")
        func normalizedTallDocumentInset() {
            let map = PreviewDocumentMap(
                totalHeight: 4000, viewportTop: 0, viewportHeight: 900, textInsetTop: 32
            )
            #expect(abs(map.normalized(1000) - (1000 + 32) / 4000) < 1e-9)
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

        @Test("thumbMetrics floors the height and clamps the offset into the track")
        func thumbMetrics() {
            let map = PreviewDocumentMap(totalHeight: 400, viewportTop: 100, viewportHeight: 200)
            let metrics = map.thumbMetrics(trackHeight: 100, minHeight: 20)
            #expect(metrics?.height == 50) // 0.5 * 100
            #expect(metrics?.offset == 25) // 0.25 * 100

            // A tiny viewport floors to minHeight; the offset clamps so the thumb's
            // bottom stays at the track end (90 would overhang past 100-20).
            let tiny = PreviewDocumentMap(totalHeight: 1000, viewportTop: 900, viewportHeight: 10)
            let clamped = tiny.thumbMetrics(trackHeight: 100, minHeight: 20)
            #expect(clamped?.height == 20)
            #expect(clamped?.offset == 80)

            // No viewport to show -> nil.
            #expect(PreviewDocumentMap(totalHeight: 0).thumbMetrics(trackHeight: 100, minHeight: 20) == nil)
        }
    }
#endif
