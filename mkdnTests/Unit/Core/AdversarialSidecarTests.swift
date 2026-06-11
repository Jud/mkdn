import Foundation
import Testing
@testable import mkdnLib

/// Sidecar codec hardening and the trailing-only stripping policy, over the
/// surviving `CommentSidecar` + `CommentDocument` parse path (the sidecar is
/// untrusted, user-editable input).
@Suite("Comment adversarial sidecar")
struct AdversarialSidecarTests {
    /// Bodies/quotes that must survive the `-->`-safe escape + JSON round-trip.
    static let hostilePayloads: [String] = [
        "ends a comment --> here", "bare -- dashes", "<!--mkdn-comments nested marker",
        "line\nbreak\tand tab", "quote \" and backslash \\ and slash /",
        "emoji 😀🎉 flags 🇺🇸", "combining e\u{0301}", "rtl \u{202E}x\u{202C}",
        "null\u{0000}byte", "html <div> & </div>", String(repeating: "x-->", count: 500),
    ]

    /// A document with a trailing v2 sidecar holding one comment.
    private func docWithSidecar(_ text: String, commentBody: String = "note") -> String {
        text + "\n\n" + CommentSidecar.encode([CommentSidecar.Entry(id: "c1", body: commentBody)])
    }

    @Test("Sidecar round-trips arbitrary hostile bodies and quotes", arguments: hostilePayloads)
    func roundTripsHostilePayloads(payload: String) {
        let entry = CommentSidecar.Entry(id: "id1", body: payload, quote: payload, prefix: payload, suffix: payload)
        let encoded = CommentSidecar.encode([entry])

        // The encoded block's interior must never contain a premature `-->`.
        let interior = String(
            encoded.dropFirst(CommentSidecar.blockOpen.count).dropLast(CommentSidecar.blockClose.count)
        )
        #expect(!interior.contains("-->"), "premature terminator for payload")

        let decoded = CommentSidecar.decode(from: "body text\n\n" + encoded)
        #expect(decoded?.entries.first?.body == payload)
        #expect(decoded?.entries.first?.quote == payload)
        #expect(decoded?.entries.first?.prefix == payload)
    }

    @Test("A sidecar-looking block that isn't the trailing block is left as content")
    func nonTrailingSidecarNotStripped() {
        let raw = """
        # Doc

        ```
        <!--mkdn-comments
        {"v":1,"comments":[]}
        -->
        ```

        Real text after the fence.
        """
        let parsed = CommentDocument.parse(raw)
        // The fenced literal and trailing prose both survive — the block is inside
        // a code fence and not trailing, so it is ordinary content.
        #expect(parsed.body.contains("Real text after the fence."))
        #expect(parsed.body.contains("mkdn-comments"))
        #expect(parsed.entries.isEmpty)
    }

    @Test("A genuinely trailing sidecar is recognized and stripped")
    func trailingSidecarStillStripped() {
        let raw = docWithSidecar("comment me please")
        let parsed = CommentDocument.parse(raw)
        #expect(!parsed.body.contains("mkdn-comments"))
        #expect(parsed.entries.count == 1)
        // Trailing whitespace after the block must not defeat recognition.
        let padded = CommentDocument.parse(raw + "\n\n  \n")
        #expect(!padded.body.contains("mkdn-comments"))
        #expect(padded.entries.count == 1)
    }

    @Test("A user's trailing HTML comment after the sidecar doesn't detach comments")
    func trailingHTMLCommentAfterSidecar() {
        let raw = docWithSidecar("comment this text") + "\n\n<!-- license: MIT -->\n"
        let parsed = CommentDocument.parse(raw)
        #expect(parsed.entries.count == 1)
        #expect(!parsed.body.contains("mkdn-comments"))
        #expect(parsed.body.contains("<!-- license: MIT -->")) // user's note survives
    }

    @Test("A shadow marker inside a trailing HTML comment doesn't hide the real sidecar")
    func shadowMarkerInTrailingComment() {
        let raw = docWithSidecar("comment this text", commentBody: "note")
            + "\n\n<!-- see <!--mkdn-comments for docs -->\n"
        let parsed = CommentDocument.parse(raw)
        #expect(parsed.entries.count == 1)
        #expect(parsed.entries.first?.body == "note")
    }

    @Test("Only the trailing block is decoded when several marker blocks exist")
    func lastBlockWins() {
        let raw = "earlier <!--mkdn-comments not really --> mention\n\n"
            + CommentSidecar.encode([.init(id: "a", body: "real")])
        let decoded = CommentSidecar.decode(from: raw)
        #expect(decoded?.entries.map(\.id) == ["a"])
    }

    @Test("Malformed trailing sidecar decodes to nil and is left intact")
    func malformedSidecarPreserved() {
        let raw = "doc body\n\n<!--mkdn-comments\n{this is not json\n-->"
        #expect(CommentSidecar.decode(from: raw) == nil)
        let parsed = CommentDocument.parse(raw)
        #expect(parsed.body.contains("mkdn-comments")) // not stripped
        #expect(parsed.entries.isEmpty)
    }

    @Test("A future schema version still decodes its comments (lenient policy)")
    func futureVersionDecodes() {
        let raw = "doc\n\n<!--mkdn-comments\n{\"v\":99,\"comments\":[{\"id\":\"a\",\"body\":\"b\"}]}\n-->"
        #expect(CommentSidecar.decode(from: raw)?.entries.first?.body == "b")
    }
}
