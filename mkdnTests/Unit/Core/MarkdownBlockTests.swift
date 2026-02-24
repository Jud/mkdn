import Foundation
import Testing
@testable import mkdnLib

@Suite("MarkdownBlock")
struct MarkdownBlockTests {
    // MARK: - ListItem ID Stability

    @Test("ListItem ID is stable across instances with same content")
    func listItemIdStability() {
        let blocks1 = [MarkdownBlock.paragraph(text: AttributedString("hello"))]
        let blocks2 = [MarkdownBlock.paragraph(text: AttributedString("hello"))]
        let item1 = ListItem(blocks: blocks1)
        let item2 = ListItem(blocks: blocks2)

        #expect(item1.id == item2.id)
    }

    @Test("ListItem ID differs for different content")
    func listItemIdDiffers() {
        let item1 = ListItem(blocks: [.paragraph(text: AttributedString("hello"))])
        let item2 = ListItem(blocks: [.paragraph(text: AttributedString("world"))])

        #expect(item1.id != item2.id)
    }

    // MARK: - IndexedBlock ID Uniqueness

    @Test("IndexedBlock produces unique IDs for thematic breaks at different indices")
    func indexedBlockThematicBreakUniqueness() {
        let block1 = IndexedBlock(index: 0, block: .thematicBreak)
        let block2 = IndexedBlock(index: 1, block: .thematicBreak)
        let block3 = IndexedBlock(index: 2, block: .thematicBreak)
        #expect(block1.id != block2.id)
        #expect(block2.id != block3.id)
        #expect(block1.id != block3.id)
    }

    @Test("IndexedBlock produces unique IDs for identical paragraphs at different indices")
    func indexedBlockParagraphUniqueness() {
        let text = AttributedString("same content")
        let block1 = IndexedBlock(index: 0, block: .paragraph(text: text))
        let block2 = IndexedBlock(index: 3, block: .paragraph(text: text))
        #expect(block1.id != block2.id)
    }

    @Test("IndexedBlock ID is deterministic for same content and index")
    func indexedBlockDeterminism() {
        let block1 = IndexedBlock(index: 5, block: .thematicBreak)
        let block2 = IndexedBlock(index: 5, block: .thematicBreak)
        #expect(block1.id == block2.id)
    }
}
