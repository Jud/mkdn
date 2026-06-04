import Foundation
import Testing
@testable import mkdnLib

@MainActor
@Suite("DocumentState comments")
struct DocumentStateCommentTests {
    private func selector(quote: String) -> CommentSelector {
        CommentSelector(
            quote: quote, prefix: "", suffix: "", start: 0, end: quote.utf16.count,
            norm: AnchorTape.normalizationVersion
        )
    }

    @Test("addComment stores a sidecar entry (no inline markers) and returns its id")
    func addComment() {
        let state = DocumentState()
        state.markdownContent = "The quick brown fox"
        let id = state.addComment(selector(quote: "quick"), body: "note")

        let entries = CommentSidecar.decode(from: state.markdownContent)?.entries ?? []
        #expect(entries.count == 1)
        #expect(entries[0].id == id)
        #expect(entries[0].body == "note")
        #expect(entries[0].quote == "quick")
        #expect(state.markdownContent.hasPrefix("The quick brown fox")) // body untouched
        #expect(!state.markdownContent.contains("edge=")) // no inline anchor markers
    }

    @Test("editComment by id rewrites the body; unknown id is a no-op")
    func editById() {
        let state = DocumentState()
        state.markdownContent = "a b c"
        let id = state.addComment(selector(quote: "b"), body: "old")
        #expect(state.editComment(id: id, newBody: "new"))
        let entry = CommentSidecar.decode(from: state.markdownContent)?.entries.first { $0.id == id }
        #expect(entry?.body == "new")
        #expect(!state.editComment(id: "missing", newBody: "x"))
    }

    @Test("deleteComment by id removes the sidecar entry")
    func deleteById() {
        let state = DocumentState()
        state.markdownContent = "a b c"
        let id = state.addComment(selector(quote: "b"), body: "note")
        #expect(state.deleteComment(id: id))
        #expect(CommentSidecar.decode(from: state.markdownContent) == nil) // last entry → block removed
        #expect(!state.deleteComment(id: id)) // already gone → no-op
    }

    @Test("deleteComment removes an orphaned entry whose quote no longer resolves")
    func deleteOrphan() {
        let state = DocumentState()
        state.markdownContent = "a b c"
        let id = state.addComment(selector(quote: "text that is not present"), body: "orphan")
        #expect(CommentSidecar.decode(from: state.markdownContent)?.entries.count == 1)
        #expect(state.deleteComment(id: id))
        #expect(CommentSidecar.decode(from: state.markdownContent) == nil)
    }
}
