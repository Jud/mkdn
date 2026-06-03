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
            let offset = run.sourceSpan!.start
            let runText = String(text[run.range].characters)
            #expect(sourceText(source, utf16Offset: offset, utf16Length: runText.utf16.count) == runText)
        }
        // The whole paragraph is verbatim, so the first span starts at 0.
        #expect(text.runs.first?.sourceSpan?.start == 0)
    }

    @Test("Bold inner text carries the correct source offset")
    func boldOffset() {
        let source = "foo **bar**"
        let text = paragraph(source)

        let barRun = text.runs.first { String(text[$0.range].characters) == "bar" }
        let offset = try! #require(barRun?.sourceSpan).start
        // "bar" begins after "foo **" — UTF-16 offset 6.
        #expect(offset == 6)
        #expect(sourceText(source, utf16Offset: offset, utf16Length: 3) == "bar")
    }

    @Test("A link is one atomic span covering the whole [text](url) source")
    func linkAtomicSpan() {
        let source = "see [docs](https://x.com) now"
        let text = paragraph(source)

        let docsRun = text.runs.first { String(text[$0.range].characters) == "docs" }
        let span = try! #require(docsRun?.sourceSpan)
        #expect(sourceText(source, utf16Offset: span.start, utf16Length: span.end - span.start)
            == "[docs](https://x.com)")
    }

    @Test("Inline code is an atomic span covering the backticked source")
    func inlineCodeAtomicSpan() {
        let source = "run `swift build` now"
        let text = paragraph(source)

        let codeRun = text.runs.first { String(text[$0.range].characters) == "swift build" }
        let span = try! #require(codeRun?.sourceSpan)
        #expect(sourceText(source, utf16Offset: span.start, utf16Length: span.end - span.start)
            == "`swift build`")
    }

    @Test("An escaped character is not given a 1:1 span")
    func escapedNotSpanned() {
        // "\*" renders as "*" — the rendered run is shorter than its source, so
        // it must not be tagged (selections there are rejected).
        let text = paragraph(#"a \* b"#)
        let unspanned = text.runs.filter { $0.sourceSpan == nil }
        #expect(!unspanned.isEmpty)
    }

    @Test("Text around inline math is not spanned (no stale offsets)")
    func inlineMathNeighboursNotSpanned() {
        // postProcessMathDelimiters replaces "$x$", which would otherwise leave
        // a stale offset on the trailing " b". The whole "$"-bearing run is
        // dropped, so no run may carry a (wrong) span.
        let text = paragraph("a $x$ b")
        for run in text.runs where run.sourceSpan != nil {
            let runText = String(text[run.range].characters)
            let offset = run.sourceSpan!.start
            // Any span that survives must still be exactly 1:1 with the source.
            #expect(sourceText("a $x$ b", utf16Offset: offset, utf16Length: runText.utf16.count) == runText)
        }
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
