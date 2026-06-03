import Foundation
import Testing
@testable import mkdnLib

/// Sidecar codec hardening (I7) and the trailing-only stripping policy (B3/I2).
@Suite("Comment adversarial sidecar")
struct AdversarialSidecarTests {
    /// Bodies/quotes that must survive the `-->`-safe escape + JSON round-trip.
    static let hostilePayloads: [String] = [
        "ends a comment --> here", "bare -- dashes", "<!--mkdn-comments nested marker",
        "line\nbreak\tand tab", "quote \" and backslash \\ and slash /",
        "emoji 😀🎉 flags 🇺🇸", "combining e\u{0301}", "rtl \u{202E}x\u{202C}",
        "null\u{0000}byte", "html <div> & </div>", String(repeating: "x-->", count: 500),
    ]

    @Test("Sidecar round-trips arbitrary hostile bodies and quotes", arguments: hostilePayloads)
    func roundTripsHostilePayloads(payload: String) {
        let entry = CommentSidecar.Entry(id: "id1", body: payload, quote: payload, prefix: payload, suffix: payload)
        let encoded = CommentSidecar.encode([entry])

        // The encoded block's interior must never contain a premature `-->`.
        let interior = String(encoded.dropFirst(CommentSidecar.blockOpen.count).dropLast(CommentSidecar.blockClose.count))
        #expect(!interior.contains("-->"), "premature terminator for payload")

        let decoded = CommentSidecar.decode(from: "body text\n\n" + encoded)
        #expect(decoded?.entries.first?.body == payload)
        #expect(decoded?.entries.first?.quote == payload)
        #expect(decoded?.entries.first?.prefix == payload)
    }

    @Test("B3: a sidecar-looking block that isn't the trailing block is left as content")
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
        let doc = CriticMarkup.preprocess(raw)
        // The fenced literal and the trailing prose must both survive — the block
        // is inside a code fence and not trailing, so it is ordinary content.
        #expect(doc.transformedSource.contains("Real text after the fence."))
        #expect(doc.transformedSource.contains("mkdn-comments"))
    }

    @Test("B3: a genuinely trailing sidecar is still recognized and stripped")
    func trailingSidecarStillStripped() {
        let raw = CommentFixture.doc("comment me please", comment: "comment me")
        let doc = CriticMarkup.preprocess(raw)
        #expect(!doc.transformedSource.contains("mkdn-comments"))
        #expect(doc.comments.count == 1)
        // Trailing whitespace after the block must not defeat recognition.
        let padded = CriticMarkup.preprocess(raw + "\n\n  \n")
        #expect(!padded.transformedSource.contains("mkdn-comments"))
        #expect(padded.comments.count == 1)
    }

    @Test("A user's trailing HTML comment after the sidecar doesn't detach comments")
    func trailingHTMLCommentAfterSidecar() {
        // Common case: comments authored by mkdn (sidecar at EOF) plus the user's
        // own footer comment. The sidecar must still be recognized + stripped and
        // the comment stay active — not orphaned with raw JSON shown.
        let raw = CommentFixture.doc("comment this text", comment: "comment this") + "\n\n<!-- license: MIT -->\n"
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.comments.count == 1)
        #expect(!doc.transformedSource.contains("mkdn-comments"))
        #expect(doc.transformedSource.contains("<!-- license: MIT -->")) // user's note survives
    }

    @Test("A shadow marker inside a trailing HTML comment doesn't hide the real sidecar")
    func shadowMarkerInTrailingComment() {
        // A footer comment that literally mentions the marker would be the LAST
        // `<!--mkdn-comments` occurrence; decode must skip it (its JSON is junk)
        // and still find the genuine sidecar above it.
        let raw = CommentFixture.doc("comment this text", comment: "comment this")
            + "\n\n<!-- see <!--mkdn-comments for docs -->\n"
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.comments.count == 1)
        #expect(doc.comments.first?.body == "note")
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
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.transformedSource.contains("mkdn-comments")) // not stripped
        #expect(doc.comments.isEmpty)
    }

    @Test("A future schema version still decodes its comments (lenient policy)")
    func futureVersionDecodes() {
        let raw = "doc\n\n<!--mkdn-comments\n{\"v\":99,\"comments\":[{\"id\":\"a\",\"body\":\"b\"}]}\n-->"
        #expect(CommentSidecar.decode(from: raw)?.entries.first?.body == "b")
    }
}
