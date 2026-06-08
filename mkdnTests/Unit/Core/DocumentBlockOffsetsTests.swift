#if os(macOS)
    import AppKit
    import Testing
    @testable import mkdnLib

    /// Validates `DocumentBlockOffsets` against the ground truth: real TextKit 2
    /// per-block positions. The estimated offset of each block must track the real
    /// top y that block lays out at.
    @Suite("DocumentBlockOffsets")
    struct DocumentBlockOffsetsTests {
        @MainActor private func mixedBlocks() -> [IndexedBlock] {
            let blocks: [MarkdownBlock] = [
                .heading(level: 1, text: AttributedString("Document Title")),
                .paragraph(text: AttributedString(
                    "A first paragraph long enough to wrap to a couple of lines at the "
                        + "narrow widths used in these tests.")),
                .codeBlock(language: "swift", code: "let a = 1\nlet b = 2\nlet c = a + b"),
                .paragraph(text: AttributedString(
                    "A second paragraph, also wrapping, to push the later blocks down.")),
                .thematicBreak,
                .image(source: "x.png", alt: "alt"),
                .paragraph(text: AttributedString("Closing line.")),
            ]
            return blocks.enumerated().map { IndexedBlock(index: $0.offset, block: $0.element) }
        }

        @Test("Per-block offsets track real TextKit block positions", arguments: [400.0, 700.0])
        @MainActor func offsetsTrackRealPositions(viewWidth: CGFloat) throws {
            let result = MarkdownTextStorageBuilder.build(blocks: mixedBlocks(), theme: .solarizedDark)
            let (textView, window, textWidth) =
                LayoutMeasurementHarness.layOut(result.attributedString, viewWidth: viewWidth)
            _ = window
            let offsets = DocumentBlockOffsets.compute(
                of: result.attributedString, model: result.documentHeightModel,
                textWidth: textWidth, verticalInset: 32)

            let modelBlocks = result.documentHeightModel.blocks
            let realTops = try modelBlocks.map { block in
                try #require(textView.boundingRect(forCharacterRange: block.range)?.minY)
            }
            for position in modelBlocks.indices {
                // The estimated top lands on the real TextKit block top (couple px for rounding).
                #expect(abs(offsets.blocks[position].top - realTops[position]) < 4)
                // A real y inside this block resolves to it, not the neighbour.
                let nextReal = position + 1 < realTops.count ? realTops[position + 1] : offsets.totalHeight
                #expect(offsets.blockIndex(atY: (realTops[position] + nextReal) / 2)
                    == modelBlocks[position].index)
            }
        }

        @Test("blockIndex(atY:) maps a y back to the block that contains it")
        @MainActor func yMapsToBlock() {
            let result = MarkdownTextStorageBuilder.build(blocks: mixedBlocks(), theme: .solarizedDark)
            let offsets = DocumentBlockOffsets.compute(
                of: result.attributedString, model: result.documentHeightModel,
                textWidth: 600, verticalInset: 32)
            // A y inside each block's span resolves to that block.
            let count = offsets.blocks.count
            for position in offsets.blocks.indices {
                let spanEnd = position + 1 < count ? offsets.blocks[position + 1].top : offsets.totalHeight
                #expect(offsets.blockIndex(atY: (offsets.blocks[position].top + spanEnd) / 2)
                    == offsets.blocks[position].index)
            }
            // Clamp: a y above the first block resolves to the first; past the end, the last.
            #expect(offsets.blockIndex(atY: -100) == offsets.blocks.first?.index)
            #expect(offsets.blockIndex(atY: offsets.totalHeight + 1000) == offsets.blocks.last?.index)
        }
    }
#endif
