import Testing
@testable import mkdnLib

@Suite("CommentDocument")
struct CommentDocumentTests {
    @Test("Strips the sidecar block and decodes its entries")
    func stripsSidecar() {
        let entry = CommentSidecar.Entry(id: "x", body: "note", quote: "q", norm: 1)
        let raw = "Hello world.\n\n\(CommentSidecar.encode([entry]))"
        let doc = CommentDocument.parse(raw)
        #expect(doc.entries.map(\.id) == ["x"])
        #expect(doc.entries.first?.body == "note")
        #expect(doc.body.contains("Hello world."))
        #expect(!doc.body.contains("mkdn-comments"))
    }

    @Test("Strips well-formed inline markers and keeps the surrounding text")
    func stripsInlineMarkers() {
        let raw = #"a <mkdn-comment id="k" edge="start"/>commented<mkdn-comment id="k" edge="end"/> b"#
        #expect(CommentDocument.parse(raw).body == "a commented b")
    }

    @Test("Leaves an attribute-less or malformed mkdn-comment occurrence intact")
    func leavesLiteralIntact() {
        let raw = "Use <mkdn-comment > in a doc as an example."
        #expect(CommentDocument.parse(raw).body == raw)
    }

    @Test("Body is stable across adding the first comment (comment-only detection)")
    func bodyStableAcrossFirstComment() {
        let plain = "Hello world."
        let entry = CommentSidecar.Entry(id: "c", body: "note", quote: "x", norm: 1)
        let withComment = CommentSidecar.upsert(entry, into: plain)
        // The writer trims+separates; parse trims trailing newlines — so the body a
        // comment-only change compares against is unchanged by the first add.
        #expect(CommentDocument.parse(plain).body == CommentDocument.parse(withComment).body)
    }

    @Test("Returns the body unchanged when there are no comments")
    func noComments() {
        let raw = "# Title\n\nBody text."
        let doc = CommentDocument.parse(raw)
        #expect(doc.body == raw)
        #expect(doc.entries.isEmpty)
    }
}
