import Foundation
import Testing
@testable import mkdnLib

@MainActor
@Suite("DocumentState comments")
struct DocumentStateCommentTests {
    @Test("addComment wraps the selection and updates content")
    func addComment() {
        let state = DocumentState()
        state.markdownContent = "The quick brown fox"
        let source = state.markdownContent
        let range = source.range(of: "quick")!
        let newID = state.addComment(in: range, of: source, body: "note")

        let doc = CriticMarkup.preprocess(state.markdownContent)
        #expect(doc.comments.count == 1)
        #expect(newID == doc.comments[0].id)
        #expect(doc.comments[0].body == "note")
        #expect(doc.transformedSource[doc.comments[0].transformedHighlightRange] == "quick")
        #expect(doc.transformedSource == "The quick brown fox")
    }

    @Test("addComment rejects an empty selection and leaves content unchanged")
    func addRejects() {
        let state = DocumentState()
        state.markdownContent = "a b"
        let source = state.markdownContent
        let empty = source.startIndex ..< source.startIndex
        #expect(state.addComment(in: empty, of: source, body: "x") == nil)
        #expect(state.markdownContent == "a b")
    }

    @Test("addComment rejects a range from stale content (content changed)")
    func addRejectsStaleSource() {
        let state = DocumentState()
        let staleSource = "The quick brown fox"
        let range = staleSource.range(of: "quick")!
        state.markdownContent = "Totally different content now"
        #expect(state.addComment(in: range, of: staleSource, body: "note") == nil)
        #expect(state.markdownContent == "Totally different content now")
    }

    @Test("editComment by id rewrites the body; unknown id is a no-op")
    func editById() {
        let state = DocumentState()
        state.markdownContent = CommentFixture.doc("a b c", comment: "b", id: "c1", body: "old")
        let source = state.markdownContent
        #expect(state.editComment(id: "c1", of: source, newBody: "new"))
        #expect(CriticMarkup.preprocess(state.markdownContent).commentsByID["c1"]?.body == "new")
        #expect(!state.editComment(id: "missing", of: state.markdownContent, newBody: "x"))
    }

    @Test("deleteComment by id removes the markup, keeping the text")
    func deleteById() {
        let state = DocumentState()
        state.markdownContent = CommentFixture.doc("a b c", comment: "b", id: "c1", body: "note")
        #expect(state.deleteComment(id: "c1", of: state.markdownContent))
        let doc = CriticMarkup.preprocess(state.markdownContent)
        #expect(doc.comments.isEmpty)
        #expect(doc.transformedSource == "a b c\n") // sidecar removed, EOF newline kept
    }

    @Test("edit/delete reject when the source no longer matches current content")
    func editDeleteRejectStaleSource() {
        let state = DocumentState()
        let stale = CommentFixture.doc("a b c", comment: "b", id: "c1", body: "old")
        state.markdownContent = "different content"
        #expect(!state.editComment(id: "c1", of: stale, newBody: "new"))
        #expect(!state.deleteComment(id: "c1", of: stale))
        #expect(state.markdownContent == "different content")
    }
}
