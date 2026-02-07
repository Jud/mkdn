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
}
