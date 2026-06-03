import Foundation
import Testing
@testable import mkdnLib

@MainActor
@Suite("Comment highlight rendering")
struct CommentHighlightTests {
    private func highlighted(_ raw: String) -> NSAttributedString {
        let document = CriticMarkup.preprocess(raw)
        let blocks = MarkdownRenderer.render(text: document.transformedSource, theme: .solarizedDark)
        let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: .solarizedDark)
        let mutable = NSMutableAttributedString(attributedString: result.attributedString)
        MarkdownTextStorageBuilder.applyCommentHighlights(
            to: mutable,
            document: document,
            sourceMap: result.sourceMap,
            color: .yellow
        )
        return mutable
    }

    private func commentID(_ string: NSAttributedString, at substring: String) -> String? {
        commentIDs(string, at: substring)?.first
    }

    private func commentIDs(_ string: NSAttributedString, at substring: String) -> [String]? {
        let range = (string.string as NSString).range(of: substring)
        guard range.location != NSNotFound else { return nil }
        return string.attribute(.mkdnCommentID, at: range.location, effectiveRange: nil) as? [String]
    }

    private func hasBackground(_ string: NSAttributedString, at substring: String) -> Bool {
        let range = (string.string as NSString).range(of: substring)
        guard range.location != NSNotFound else { return false }
        return string.attribute(.backgroundColor, at: range.location, effectiveRange: nil) != nil
    }

    @Test("Highlights the commented span and tags it with the comment id")
    func highlightsCommentedSpan() {
        let string = highlighted(CommentFixture.doc("foo bar baz", comment: "bar"))
        #expect(string.string == "foo bar baz\n") // anchors hidden
        #expect(commentID(string, at: "bar") == "c1")
        #expect(hasBackground(string, at: "bar"))
    }

    @Test("Leaves text outside the comment unhighlighted")
    func leavesSurroundingTextAlone() {
        let string = highlighted(CommentFixture.doc("foo bar baz", comment: "bar"))
        #expect(!hasBackground(string, at: "foo"))
        #expect(!hasBackground(string, at: "baz"))
    }

    @Test("Highlights a span containing styled text across runs")
    func highlightsStyledSpan() {
        let string = highlighted(CommentFixture.doc("x **b** y z", comment: "**b** y"))
        #expect(commentID(string, at: "b") == "c1")
        #expect(commentID(string, at: "y") == "c1")
        #expect(!hasBackground(string, at: "z"))
    }

    @Test("Highlights a commented link across its whole rendered label")
    func highlightsLink() {
        let raw = CommentFixture.doc("see [docs](https://x.com) now", comment: "[docs](https://x.com)")
        let string = highlighted(raw)
        #expect(commentID(string, at: "docs") == "c1")
        #expect(hasBackground(string, at: "docs"))
        #expect(!hasBackground(string, at: "see"))
    }

    @Test("Highlights a commented inline-code span")
    func highlightsInlineCode() {
        let raw = CommentFixture.doc("run `swift build` now", comment: "`swift build`")
        let string = highlighted(raw)
        #expect(commentID(string, at: "swift build") == "c1")
        #expect(hasBackground(string, at: "swift build"))
        #expect(!hasBackground(string, at: "run"))
    }

    @Test("Overlapping comments accumulate both ids in the overlap region")
    func overlappingCommentIDs() {
        let entries = [
            CommentSidecar.Entry(id: "x", body: "first"),
            CommentSidecar.Entry(id: "y", body: "second"),
        ]
        // x covers "A B C", y covers "C D" — they overlap on "C".
        let raw = "\(CommentFixture.start("x"))A B \(CommentFixture.start("y"))C"
            + "\(CommentFixture.end("x")) D\(CommentFixture.end("y"))\n\n"
            + CommentSidecar.encode(entries)
        let string = highlighted(raw)
        #expect(Set(commentIDs(string, at: "A") ?? []) == ["x"])
        #expect(Set(commentIDs(string, at: "C") ?? []) == ["x", "y"])
        #expect(Set(commentIDs(string, at: "D") ?? []) == ["y"])
    }

    @Test("No comments means no highlight attributes")
    func noComments() {
        let string = highlighted("plain text only")
        #expect(string.attribute(.mkdnCommentID, at: 0, effectiveRange: nil) == nil)
    }
}
