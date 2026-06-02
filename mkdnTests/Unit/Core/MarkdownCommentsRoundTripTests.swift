import Foundation
import Testing
@testable import mkdnLib

/// The Phase 1 feasibility gate: prove a rendered-text selection can be mapped
/// back to raw source, wrapped with CriticMarkup, and re-parsed to an identical
/// render plus a greppable comment.
@MainActor
@Suite("Markdown comments round-trip")
struct MarkdownCommentsRoundTripTests {
    private func build(_ transformed: String) -> TextStorageResult {
        let blocks = MarkdownRenderer.render(text: transformed, theme: .solarizedDark)
        return MarkdownTextStorageBuilder.build(blocks: blocks, theme: .solarizedDark)
    }

    /// Authoring: wrap a raw-source range in `{==…==}{>>comment<<}`.
    private func wrap(_ raw: String, range: Range<String.Index>, comment: String) -> String {
        String(raw[..<range.lowerBound])
            + "{==" + String(raw[range]) + "==}{>>" + comment + "<<}"
            + String(raw[range.upperBound...])
    }

    @Test("Selection maps to source, wraps, and re-parses to an identical render")
    func fullRoundTrip() {
        let raw = "The quick brown fox jumps."

        let document = CriticMarkup.preprocess(raw)
        #expect(document.transformedSource == raw) // no comments yet
        let result = build(document.transformedSource)

        // Select "quick" in the rendered text and resolve it back to source.
        let nsRange = (result.attributedString.string as NSString).range(of: "quick")
        let resolver = CommentRangeResolver(document: document, sourceMap: result.sourceMap)
        let rawRange = try! #require(resolver.rawRange(forBuilderRange: nsRange))
        #expect(raw[rawRange] == "quick")

        // Wrap + "save".
        let edited = wrap(raw, range: rawRange, comment: "is it?")
        #expect(edited.contains("{>>is it?<<}")) // an agent can grep this

        // Re-parse: the comment is recovered and the render input is unchanged.
        let reparsed = CriticMarkup.preprocess(edited)
        #expect(reparsed.comments.count == 1)
        #expect(reparsed.comments[0].body == "is it?")
        #expect(reparsed.rawSource[reparsed.comments[0].rawHighlightRange] == "quick")
        #expect(reparsed.transformedSource == raw)
    }

    @Test("Round-trip is correct across a surrogate-pair emoji")
    func roundTripAcrossEmoji() {
        // The emoji is 2 UTF-16 units; selecting "world" after it exercises the
        // UTF-16 offset arithmetic in SourceMap and the resolver.
        let raw = "hello 😀 world today"

        let document = CriticMarkup.preprocess(raw)
        let result = build(document.transformedSource)

        let nsRange = (result.attributedString.string as NSString).range(of: "world")
        let resolver = CommentRangeResolver(document: document, sourceMap: result.sourceMap)
        let rawRange = try! #require(resolver.rawRange(forBuilderRange: nsRange))
        #expect(raw[rawRange] == "world")

        let edited = wrap(raw, range: rawRange, comment: "🌍")
        let reparsed = CriticMarkup.preprocess(edited)
        #expect(reparsed.comments.count == 1)
        #expect(reparsed.rawSource[reparsed.comments[0].rawHighlightRange] == "world")
        #expect(reparsed.comments[0].body == "🌍")
        #expect(reparsed.transformedSource == raw)
    }
}
