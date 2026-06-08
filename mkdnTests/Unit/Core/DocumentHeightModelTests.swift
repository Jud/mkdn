import Testing
#if os(macOS)
    import AppKit
#endif
@testable import mkdnLib

@Suite("DocumentHeightModel")
struct DocumentHeightModelTests {
    @MainActor
    private func build(_ blocks: [MarkdownBlock]) -> TextStorageResult {
        let indexed = blocks.enumerated().map {
            IndexedBlock(index: $0.offset, block: $0.element)
        }
        return MarkdownTextStorageBuilder.build(blocks: indexed, theme: .solarizedDark)
    }

    @Test("One descriptor per top-level block, in document order")
    @MainActor
    func oneDescriptorPerBlock() {
        let result = build([
            .paragraph(text: AttributedString("First paragraph.")),
            .thematicBreak,
            .image(source: "x.png", alt: "alt"),
            .paragraph(text: AttributedString("Last paragraph.")),
        ])
        let model = result.documentHeightModel
        #expect(model.blocks.count == 4)
        #expect(model.blocks.map(\.blockIndex) == [0, 1, 2, 3])
    }

    @Test("Descriptor ranges tile the whole string with no gaps or overlaps")
    @MainActor
    func rangesTileTheString() {
        let result = build([
            .heading(level: 1, text: AttributedString("Title")),
            .paragraph(text: AttributedString("Body text that is long enough to exist.")),
            .thematicBreak,
        ])
        let ranges = result.documentHeightModel.blocks.map(\.attributedRange)
        var cursor = 0
        for range in ranges {
            #expect(range.location == cursor)
            cursor = range.location + range.length
        }
        #expect(cursor == result.attributedString.length)
    }

    @Test("Attachment blocks carry their attachment; flowed blocks don't")
    @MainActor
    func attachmentBlocksCarryAttachment() {
        let result = build([
            .paragraph(text: AttributedString("Flowed.")),
            .thematicBreak,
            .image(source: "x.png", alt: "alt"),
        ])
        let blocks = result.documentHeightModel.blocks
        #expect(blocks[0].attachment == nil)
        #expect(blocks[1].attachment != nil)
        #expect(blocks[2].attachment != nil)
        // Each descriptor's attachment is the very one recorded in `attachments`.
        for info in result.attachments {
            let descriptor = blocks.first { $0.blockIndex == info.blockIndex }
            #expect(descriptor?.attachment === info.attachment)
        }
    }
}
