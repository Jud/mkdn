import Foundation
import Testing
@testable import mkdnLib

@Suite("CommentSidecar codec")
struct CommentSidecarTests {
    @Test("Round-trips a single entry")
    func roundTripSingle() throws {
        let entry = CommentSidecar.Entry(
            id: "k7",
            body: "needs a citation",
            quote: "quick brown fox",
            prefix: "The ",
            suffix: " jumps."
        )
        let block = CommentSidecar.encode([entry])
        let decoded = try #require(CommentSidecar.decode(from: block))
        #expect(decoded.entries == [entry])
    }

    @Test("Encoded block is a well-formed mkdn-comments HTML comment")
    func wellFormedBlock() {
        let block = CommentSidecar.encode([CommentSidecar.Entry(id: "a", body: "hi")])
        #expect(block.hasPrefix("<!--mkdn-comments"))
        #expect(block.hasSuffix("-->"))
    }

    @Test("Bodies containing --> and -- survive the escape")
    func escapesCommentTerminator() throws {
        let entry = CommentSidecar.Entry(
            id: "x", body: "see --> here, and a--b range", quote: "q->q"
        )
        let block = CommentSidecar.encode([entry])
        // No "-->" may appear inside the block except the final terminator, and
        // no bare "--" anywhere in the JSON payload.
        let payload = String(block.dropFirst("<!--mkdn-comments".count).dropLast("-->".count))
        #expect(!payload.contains("-->"))
        #expect(!payload.contains("--"))
        #expect(!payload.contains(">"))

        let decoded = try #require(CommentSidecar.decode(from: block))
        #expect(decoded.entries == [entry])
    }

    @Test("Decodes a block embedded in surrounding markdown")
    func decodeEmbedded() throws {
        let entry = CommentSidecar.Entry(id: "m1", body: "note")
        let raw = "# Title\n\nSome prose.\n\n\(CommentSidecar.encode([entry]))\n"
        let decoded = try #require(CommentSidecar.decode(from: raw))
        #expect(decoded.entries == [entry])
        #expect(raw[decoded.blockRange].hasPrefix("<!--mkdn-comments"))
        #expect(raw[decoded.blockRange].hasSuffix("-->"))
    }

    @Test("Missing prefix/suffix/quote default to empty")
    func tolerantDecode() throws {
        let raw = "<!--mkdn-comments\n{\"v\":1,\"comments\":[{\"id\":\"a\",\"body\":\"b\"}]}\n-->"
        let decoded = try #require(CommentSidecar.decode(from: raw))
        #expect(decoded.entries == [CommentSidecar.Entry(id: "a", body: "b")])
    }

    @Test("Earlier prose mentioning the marker does not shadow the real trailing sidecar")
    func trailingBlockWins() throws {
        let entry = CommentSidecar.Entry(id: "real", body: "actual")
        let raw = "Docs: write `<!--mkdn-comments` to start a block. -->\n\n\(CommentSidecar.encode([entry]))"
        let decoded = try #require(CommentSidecar.decode(from: raw))
        #expect(decoded.entries == [entry])
    }

    @Test("Returns nil when there is no sidecar block")
    func noBlock() {
        #expect(CommentSidecar.decode(from: "# Just a heading\n\ntext") == nil)
    }

    @Test("Returns nil for malformed JSON")
    func malformedJSON() {
        let raw = "<!--mkdn-comments\nnot json\n-->"
        #expect(CommentSidecar.decode(from: raw) == nil)
    }

    @Test("Round-trips multiple entries")
    func roundTripMultiple() throws {
        let entries = [
            CommentSidecar.Entry(id: "a", body: "first", quote: "one"),
            CommentSidecar.Entry(id: "b", body: "second", quote: "two", prefix: "p", suffix: "s"),
        ]
        let decoded = try #require(CommentSidecar.decode(from: CommentSidecar.encode(entries)))
        #expect(decoded.entries == entries)
    }

    // MARK: - v2 position/norm fields

    @Test("Round-trips a v2 entry with position hint and norm version")
    func roundTripV2Fields() throws {
        let entry = CommentSidecar.Entry(
            id: "v2",
            body: "b",
            quote: "fox",
            prefix: "the ",
            suffix: " jumps",
            start: 12,
            end: 15,
            norm: 1
        )
        let decoded = try #require(CommentSidecar.decode(from: CommentSidecar.encode([entry])))
        #expect(decoded.entries == [entry])
        let got = try #require(decoded.entries.first)
        #expect(got.start == 12)
        #expect(got.end == 15)
        #expect(got.norm == 1)
    }

    @Test("A v1 entry (no position/norm) omits those keys on encode")
    func v1EntryOmitsV2Keys() {
        let block = CommentSidecar.encode([CommentSidecar.Entry(id: "a", body: "b", quote: "q")])
        let payload = String(block.dropFirst("<!--mkdn-comments".count).dropLast("-->".count))
        // Absent optionals must not surface as keys (would dirty existing v1 docs).
        // Match the quoted JSON key, not the bare word, so a value containing
        // "start"/"end"/"norm" couldn't mask a regression.
        #expect(!payload.contains("\"start\""))
        #expect(!payload.contains("\"end\""))
        #expect(!payload.contains("\"norm\""))
    }

    @Test("Decoding a legacy v1 block yields nil position/norm")
    func legacyDecodeHasNilV2Fields() throws {
        let raw = "<!--mkdn-comments\n{\"v\":1,\"comments\":[{\"id\":\"a\",\"body\":\"b\",\"quote\":\"q\"}]}\n-->"
        let decoded = try #require(CommentSidecar.decode(from: raw))
        let entry = try #require(decoded.entries.first)
        #expect(entry.start == nil)
        #expect(entry.end == nil)
        #expect(entry.norm == nil)
    }

    // MARK: - Authors and reply threads

    @Test("Round-trips an entry with an author and a reply thread")
    func roundTripAuthorAndReplies() throws {
        let entry = CommentSidecar.Entry(
            id: "k7",
            body: "needs a citation",
            author: "claude",
            replies: [
                CommentSidecar.Reply(id: "r1", body: "good catch"),
                CommentSidecar.Reply(id: "r2", body: "added one", author: "claude"),
            ],
            quote: "quick brown fox"
        )
        let decoded = try #require(CommentSidecar.decode(from: CommentSidecar.encode([entry])))
        #expect(decoded.entries == [entry])
        let got = try #require(decoded.entries.first)
        #expect(got.author == "claude")
        #expect(got.replies?.map(\.body) == ["good catch", "added one"])
        #expect(got.replies?.map(\.author) == [nil, "claude"])
    }

    @Test("An authorless, threadless entry omits those keys on encode")
    func plainEntryOmitsThreadKeys() {
        let block = CommentSidecar.encode([CommentSidecar.Entry(id: "a", body: "b", quote: "q")])
        let payload = String(block.dropFirst("<!--mkdn-comments".count).dropLast("-->".count))
        #expect(!payload.contains("\"author\""))
        #expect(!payload.contains("\"replies\""))
    }

    @Test("Decoding a legacy block yields nil author/replies")
    func legacyDecodeHasNilThreadFields() throws {
        let raw = "<!--mkdn-comments\n{\"v\":1,\"comments\":[{\"id\":\"a\",\"body\":\"b\"}]}\n-->"
        let decoded = try #require(CommentSidecar.decode(from: raw))
        let entry = try #require(decoded.entries.first)
        #expect(entry.author == nil)
        #expect(entry.replies == nil)
    }

    @Test("addReply appends to the target thread and leaves other entries alone")
    func addReplyAppends() throws {
        let entries = [
            CommentSidecar.Entry(id: "a", body: "first"),
            CommentSidecar.Entry(id: "b", body: "second"),
        ]
        let raw = "prose\n\n" + CommentSidecar.encode(entries)

        let one = try #require(CommentSidecar.addReply(to: "b", body: "on it", author: "claude", in: raw))
        let two = try #require(CommentSidecar.addReply(to: "b", body: "done", author: "claude", in: one.raw))
        #expect(one.replyID != two.replyID) // reply ids count as used

        let decoded = try #require(CommentSidecar.decode(from: two.raw))
        let target = try #require(decoded.entries.first { $0.id == "b" })
        #expect(target.replies?.map(\.body) == ["on it", "done"])
        #expect(target.replies?.allSatisfy { $0.author == "claude" } == true)
        let other = try #require(decoded.entries.first { $0.id == "a" })
        #expect(other.replies == nil)
        #expect(two.raw.hasPrefix("prose\n")) // document body untouched
    }

    @Test("addReply to an unknown id returns nil and leaves the document untouched")
    func addReplyUnknownID() {
        let raw = CommentSidecar.encode([CommentSidecar.Entry(id: "a", body: "first")])
        #expect(CommentSidecar.addReply(to: "missing", body: "x", author: "claude", in: raw) == nil)
    }

    @Test("Reply bodies containing --> survive the escape")
    func replyEscapesCommentTerminator() throws {
        let entry = CommentSidecar.Entry(
            id: "a",
            body: "b",
            replies: [CommentSidecar.Reply(id: "r", body: "see --> here", author: "claude")]
        )
        let block = CommentSidecar.encode([entry])
        let payload = String(block.dropFirst("<!--mkdn-comments".count).dropLast("-->".count))
        #expect(!payload.contains("-->"))
        let decoded = try #require(CommentSidecar.decode(from: block))
        #expect(decoded.entries == [entry])
    }
}
