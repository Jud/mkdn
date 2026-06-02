import Foundation
import Testing
@testable import mkdnLib

@Suite("MarkdownVisitor - source spans")
struct MarkdownVisitorSourceSpanTests {
    /// The source text a span points at, reconstructed from its UTF-16 offset.
    private func sourceText(_ source: String, utf16Offset: Int, utf16Length: Int) -> String {
        let start = source.utf16.index(source.utf16.startIndex, offsetBy: utf16Offset)
        let end = source.utf16.index(start, offsetBy: utf16Length)
        return String(source[start.samePosition(in: source)! ..< end.samePosition(in: source)!])
    }

    private func paragraph(_ source: String) -> AttributedString {
        let blocks = MarkdownRenderer.render(text: source, theme: .solarizedDark)
        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("expected a paragraph, got \(blocks.first.debugDescription)")
            return AttributedString()
        }
        return text
    }

    @Test("Plain text gets a 1:1 span at offset 0")
    func plainText() {
        let source = "hello world"
        let text = paragraph(source)

        let spanned = text.runs.filter { $0.sourceSpan != nil }
        #expect(!spanned.isEmpty)
        for run in spanned {
            let offset = run.sourceSpan!
            let runText = String(text[run.range].characters)
            #expect(sourceText(source, utf16Offset: offset, utf16Length: runText.utf16.count) == runText)
        }
        // The whole paragraph is verbatim, so the first span starts at 0.
        #expect(text.runs.first?.sourceSpan == 0)
    }

    @Test("Bold inner text carries the correct source offset")
    func boldOffset() {
        let source = "foo **bar**"
        let text = paragraph(source)

        let barRun = text.runs.first { String(text[$0.range].characters) == "bar" }
        let offset = try! #require(barRun?.sourceSpan)
        // "bar" begins after "foo **" — UTF-16 offset 6.
        #expect(offset == 6)
        #expect(sourceText(source, utf16Offset: offset, utf16Length: 3) == "bar")
    }

    @Test("An escaped character is not given a 1:1 span")
    func escapedNotSpanned() {
        // "\*" renders as "*" — the rendered run is shorter than its source, so
        // it must not be tagged (selections there are rejected).
        let text = paragraph(#"a \* b"#)
        let unspanned = text.runs.filter { $0.sourceSpan == nil }
        #expect(!unspanned.isEmpty)
    }

    @Test("No source means no spans (rendering unchanged)")
    func noSourceNoSpans() {
        let document = MarkdownRenderer.parse("hello world")
        let blocks = MarkdownRenderer.render(document: document, theme: .solarizedDark)
        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("expected a paragraph")
            return
        }
        #expect(text.runs.allSatisfy { $0.sourceSpan == nil })
    }
}
