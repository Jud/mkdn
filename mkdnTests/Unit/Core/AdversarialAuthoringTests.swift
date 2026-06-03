import Foundation
import Testing
@testable import mkdnLib

/// Authoring hardening: bounded id generation (B1), non-corruption of existing
/// comments (B4/I4), and add/edit/delete algebra (I6).
@Suite("Comment adversarial authoring")
struct AdversarialAuthoringTests {
    @Test("B1: a colliding fixed id generator terminates with a fresh unique id")
    func uniqueIDDoesNotHang() {
        // First comment claims id "c1".
        let once = CommentFixture.doc("alpha beta gamma", comment: "alpha", id: "c1", body: "one")
        let doc0 = CriticMarkup.preprocess(once)
        let range = doc0.rawSource.range(of: "gamma")!
        // The generator ALSO returns "c1" forever — must not hang, must pick a
        // different unique id rather than reuse or spin.
        let twice = try! #require(CriticMarkup.wrapComment(
            in: doc0.rawSource, range: range, body: "two", idGenerator: { "c1" }
        ))
        #expect(twice.id != "c1") // fell back to a fresh id rather than reuse/spin
        let parsed = CriticMarkup.preprocess(twice.source)
        #expect(parsed.comments.count == 2)
        #expect(Set(parsed.comments.map(\.id)).count == 2)
    }

    @Test("B4: authoring a new comment preserves every existing comment")
    func authoringPreservesExisting() {
        let base = "the quick brown fox jumps over"
        let existing = CommentFixture.doc(base, comment: "quick brown", id: "ex", body: "existing")
        // Place a new comment in several relationships to the existing one:
        // disjoint, nested inside it, and crossing its boundary.
        for span in ["fox jumps", "quick", "brown fox"] {
            let doc0 = CriticMarkup.preprocess(existing)
            let t = doc0.transformedSource
            let raw = try! #require(doc0.rawRange(forTransformed: t.range(of: span)!))
            let wrapped = try! #require(
                CriticMarkup.wrapComment(in: doc0.rawSource, range: raw, body: "new", idGenerator: { "nw" })
            )
            let parsed = CriticMarkup.preprocess(wrapped.source)
            let ex = try! #require(parsed.commentsByID["ex"], "existing comment lost for span \(span)")
            #expect(ex.body == "existing", "existing body changed for span \(span)")
            #expect(parsed.transformedSource[ex.transformedHighlightRange] == "quick brown",
                    "existing highlight changed for span \(span)")
            #expect(parsed.commentsByID["nw"]?.body == "new")
        }
    }

    @Test("I6: add then delete restores the prior active set and content")
    func addDeleteInverse() {
        let base = "alpha beta gamma"
        let withC = CommentFixture.doc(base, comment: "beta", id: "c1")
        let deleted = CriticMarkup.deleteComment(in: withC, id: "c1")
        let parsed = CriticMarkup.preprocess(deleted)
        #expect(parsed.comments.isEmpty)
        // Content is restored; removing the last comment's sidecar normalizes the
        // document to a single trailing newline (writeSidecar), so compare modulo
        // trailing whitespace rather than exact bytes.
        #expect(parsed.transformedSource.trimmingCharacters(in: .whitespacesAndNewlines) == base)
        // And repeating the round-trip must not accumulate trailing newlines.
        let again = CriticMarkup.deleteComment(
            in: CommentFixture.doc(deleted, comment: "gamma", id: "c2"), id: "c2"
        )
        #expect(again.filter(\.isNewline).count == deleted.filter(\.isNewline).count)
    }

    @Test("I6: comment order is independent of authoring order")
    func orderIndependence() {
        let base = "one two three"
        let ab = CommentFixture.doc(base, comments: [("one", "a", "A"), ("three", "b", "B")])
        let ba = CommentFixture.doc(base, comments: [("three", "b", "B"), ("one", "a", "A")])
        #expect(activeComments(ab) == activeComments(ba))
        #expect(activeComments(ab) == ["a": "A", "b": "B"])
    }

    @Test("I6: edit is last-writer-wins; edit/delete of an absent id is a clean no-op")
    func editDeleteAlgebra() {
        let withC = CommentFixture.doc("alpha beta", comment: "beta", id: "c1", body: "orig")
        let edited = try! #require(CriticMarkup.editComment(in: withC, id: "c1", newBody: "first"))
        let edited2 = try! #require(CriticMarkup.editComment(in: edited, id: "c1", newBody: "second"))
        #expect(activeComments(edited2)["c1"] == "second")
        #expect(CriticMarkup.editComment(in: withC, id: "absent", newBody: "x") == nil)
        #expect(CriticMarkup.deleteComment(in: withC, id: "absent") == withC)
    }
}
