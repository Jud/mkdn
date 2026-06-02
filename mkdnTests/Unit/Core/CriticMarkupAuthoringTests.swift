import Foundation
import Testing
@testable import mkdnLib

@Suite("CriticMarkup authoring")
struct CriticMarkupAuthoringTests {
    private func range(of substring: String, in source: String) -> Range<String.Index> {
        source.range(of: substring)!
    }

    // MARK: - wrapComment

    @Test("Wraps a span and re-parses to the comment, restoring the render")
    func wrapRoundTrips() {
        let raw = "The quick brown fox"
        let edited = try! #require(
            CriticMarkup.wrapComment(in: raw, range: range(of: "quick", in: raw), body: "note")
        )
        #expect(edited == "The {==quick==}{>>note<<} brown fox")

        let doc = CriticMarkup.preprocess(edited)
        #expect(doc.comments.count == 1)
        #expect(doc.comments[0].body == "note")
        #expect(doc.rawSource[doc.comments[0].rawHighlightRange] == "quick")
        #expect(doc.transformedSource == raw)
    }

    @Test("Rejects an empty span")
    func wrapRejectsEmpty() {
        let raw = "abc"
        let empty = raw.startIndex ..< raw.startIndex
        #expect(CriticMarkup.wrapComment(in: raw, range: empty, body: "x") == nil)
    }

    @Test("Rejects a span containing the highlight terminator")
    func wrapRejectsTerminatorInSpan() {
        let raw = "a ==} b"
        #expect(CriticMarkup.wrapComment(in: raw, range: range(of: "==}", in: raw), body: "x") == nil)
    }

    @Test("Rejects when a dangling open delimiter in the prefix would capture the wrap")
    func wrapRejectsPrefixCapture() {
        // The unmatched "{==" before the span would swallow the inserted "==}".
        let raw = "foo {== bar"
        #expect(CriticMarkup.wrapComment(in: raw, range: range(of: "bar", in: raw), body: "note") == nil)
    }

    @Test("Wraps correctly when the document already has a well-formed comment")
    func wrapAlongsideExistingComment() {
        let raw = "{==a==}{>>1<<} and second"
        let edited = try! #require(
            CriticMarkup.wrapComment(in: raw, range: range(of: "second", in: raw), body: "2")
        )
        let doc = CriticMarkup.preprocess(edited)
        #expect(doc.comments.map(\.body) == ["1", "2"])
        #expect(doc.transformedSource == "a and second")
    }

    @Test("Rejects a body containing the comment terminator")
    func wrapRejectsTerminatorInBody() {
        let raw = "hello world"
        #expect(
            CriticMarkup.wrapComment(in: raw, range: range(of: "world", in: raw), body: "see <<} here") == nil
        )
    }

    // MARK: - editComment / deleteComment

    @Test("Edits a comment body in place")
    func editsBody() {
        let raw = "a {==b==}{>>old<<} c"
        let comment = CriticMarkup.preprocess(raw).comments[0]
        let edited = try! #require(CriticMarkup.editComment(in: raw, comment: comment, newBody: "new"))
        #expect(edited == "a {==b==}{>>new<<} c")
        #expect(CriticMarkup.preprocess(edited).comments[0].body == "new")
    }

    @Test("Edit rejects a body containing the comment terminator")
    func editRejectsTerminator() {
        let raw = "a {==b==}{>>old<<} c"
        let comment = CriticMarkup.preprocess(raw).comments[0]
        #expect(CriticMarkup.editComment(in: raw, comment: comment, newBody: "x <<} y") == nil)
    }

    @Test("Deletes a comment, leaving the highlighted text")
    func deletesLeavingText() {
        let raw = "a {==b c==}{>>note<<} d"
        let comment = CriticMarkup.preprocess(raw).comments[0]
        let edited = CriticMarkup.deleteComment(in: raw, comment: comment)
        #expect(edited == "a b c d")
        #expect(CriticMarkup.preprocess(edited).comments.isEmpty)
    }
}
