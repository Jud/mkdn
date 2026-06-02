import Foundation
import Testing
@testable import mkdnLib

@MainActor
@Suite("CommentRangeResolver")
struct CommentRangeResolverTests {
    /// Run the full comment pipeline on raw markdown and return the pieces a
    /// selection resolver needs.
    private func pipeline(_ raw: String) -> (CriticMarkupDocument, TextStorageResult) {
        let document = CriticMarkup.preprocess(raw)
        let blocks = MarkdownRenderer.render(text: document.transformedSource, theme: .solarizedDark)
        let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: .solarizedDark)
        return (document, result)
    }

    private func builderRange(of substring: String, in result: TextStorageResult) -> NSRange {
        (result.attributedString.string as NSString).range(of: substring)
    }

    @Test("Maps a word selection back to the matching raw range")
    func mapsWordSelection() {
        let raw = "The quick brown fox."
        let (document, result) = pipeline(raw)
        let resolver = CommentRangeResolver(document: document, sourceMap: result.sourceMap)

        let nsRange = builderRange(of: "quick", in: result)
        let rawRange = try! #require(resolver.rawRange(forBuilderRange: nsRange))
        #expect(raw[rawRange] == "quick")
    }

    @Test("Maps a selection inside bold text back to source")
    func mapsBoldSelection() {
        let raw = "see **important** notice"
        let (document, result) = pipeline(raw)
        let resolver = CommentRangeResolver(document: document, sourceMap: result.sourceMap)

        let nsRange = builderRange(of: "important", in: result)
        let rawRange = try! #require(resolver.rawRange(forBuilderRange: nsRange))
        #expect(raw[rawRange] == "important")
    }

    @Test("Rejects a selection spanning two paragraphs")
    func rejectsCrossParagraph() {
        let raw = "first para\n\nsecond para"
        let (document, result) = pipeline(raw)
        let resolver = CommentRangeResolver(document: document, sourceMap: result.sourceMap)

        // From "para" in the first block through "second" in the next crosses a
        // terminator newline (synthetic, unmapped) → not resolvable.
        let string = result.attributedString.string as NSString
        let start = string.range(of: "para").location
        let endRange = string.range(of: "second")
        let nsRange = NSRange(location: start, length: endRange.location + endRange.length - start)
        #expect(resolver.rawRange(forBuilderRange: nsRange) == nil)
    }

    @Test("Rejects an empty selection")
    func rejectsEmpty() {
        let raw = "hello world"
        let (document, result) = pipeline(raw)
        let resolver = CommentRangeResolver(document: document, sourceMap: result.sourceMap)
        #expect(resolver.rawRange(forBuilderRange: NSRange(location: 2, length: 0)) == nil)
    }

    @Test("commentsByID exposes parsed comments keyed by id")
    func commentsByID() {
        let document = CriticMarkup.preprocess("{==a==}{>>one<<} and {==b==}{>>two<<}")
        #expect(document.commentsByID["c1"]?.body == "one")
        #expect(document.commentsByID["c2"]?.body == "two")
        #expect(document.commentsByID.count == 2)
    }
}
