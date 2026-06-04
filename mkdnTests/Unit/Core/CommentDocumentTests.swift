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

    @Test("Returns the body unchanged when there are no comments")
    func noComments() {
        let raw = "# Title\n\nBody text."
        let doc = CommentDocument.parse(raw)
        #expect(doc.body == raw)
        #expect(doc.entries.isEmpty)
    }
}
