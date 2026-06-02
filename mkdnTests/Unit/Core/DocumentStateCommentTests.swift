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
        #expect(state.editComment(id: "c1", newBody: "new"))
        #expect(state.markdownContent == "a {==b==}{>>new<<} c")
        #expect(!state.editComment(id: "missing", newBody: "x"))
    }

    @Test("deleteComment by id removes the markup, keeping the text")
    func deleteById() {
        let state = DocumentState()
        state.markdownContent = "a {==b==}{>>note<<} c"
        #expect(state.deleteComment(id: "c1"))
        #expect(state.markdownContent == "a b c")
    }
}
