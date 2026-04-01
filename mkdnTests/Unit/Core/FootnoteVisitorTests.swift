import Testing
@testable import mkdnLib

@Suite("Footnote Visitor")
struct FootnoteVisitorTests {
    @Test("Footnote references get correct indices")
    func footnoteIndices() {
        let md = """
        Text with footnote[^1] and another[^note].

        [^1]: First footnote.
        [^note]: Second footnote.
        """
        let blocks = MarkdownRenderer.render(text: md, theme: .solarizedDark)
        // The first block should be a paragraph containing the references
        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected paragraph")
            return
        }
        let str = String(text.characters)
        print("Rendered text: \(str)")
        // Should contain [1] and [2], not [0]
        #expect(str.contains("[1]"))
        #expect(str.contains("[2]"))
        #expect(!str.contains("[0]"))
    }
}
