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
        #expect(state.addComment(in: range, of: source, body: "note"))
        #expect(state.markdownContent == "The {==quick==}{>>note<<} brown fox")
    }

    @Test("addComment rejects an uncommentable span and leaves content unchanged")
    func addRejects() {
        let state = DocumentState()
        state.markdownContent = "a ==} b"
        let source = state.markdownContent
        let range = source.range(of: "==}")!
        #expect(!state.addComment(in: range, of: source, body: "x"))
        #expect(state.markdownContent == "a ==} b")
    }

    @Test("addComment rejects a range from stale content (content changed)")
    func addRejectsStaleSource() {
        let state = DocumentState()
        let staleSource = "The quick brown fox"
        let range = staleSource.range(of: "quick")!
        state.markdownContent = "Totally different content now"
        #expect(!state.addComment(in: range, of: staleSource, body: "note"))
        #expect(state.markdownContent == "Totally different content now")
    }

    @Test("editComment by id rewrites the body; unknown id is a no-op")
    func editById() {
        let state = DocumentState()
        state.markdownContent = "a {==b==}{>>old<<} c"
        let source = state.markdownContent
        #expect(state.editComment(id: "c1", of: source, newBody: "new"))
        #expect(state.markdownContent == "a {==b==}{>>new<<} c")
        #expect(!state.editComment(id: "missing", of: state.markdownContent, newBody: "x"))
    }

    @Test("deleteComment by id removes the markup, keeping the text")
    func deleteById() {
        let state = DocumentState()
        state.markdownContent = "a {==b==}{>>note<<} c"
        #expect(state.deleteComment(id: "c1", of: state.markdownContent))
        #expect(state.markdownContent == "a b c")
    }

    @Test("edit/delete reject when the source no longer matches current content")
    func editDeleteRejectStaleSource() {
        let state = DocumentState()
        let stale = "a {==b==}{>>old<<} c"
        state.markdownContent = "different content"
        #expect(!state.editComment(id: "c1", of: stale, newBody: "new"))
        #expect(!state.deleteComment(id: "c1", of: stale))
        #expect(state.markdownContent == "different content")
    }
}
