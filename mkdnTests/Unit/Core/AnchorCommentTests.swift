import Foundation
import Testing
@testable import mkdnLib

@Suite("Anchor-comment parser")
struct AnchorCommentParserTests {
    /// Raw source with an anchor pair around `quote` and a matching sidecar.
    private func source(_ before: String, _ quote: String, _ after: String, id: String, body: String) -> String {
        let sidecar = CommentSidecar.encode([.init(id: id, body: body, quote: quote)])
        return "\(before)\(CommentFixture.start(id))\(quote)\(CommentFixture.end(id))\(after)\n\n\(sidecar)\n"
    }

    @Test("Strips anchors and sidecar, keeping the commented text")
    func basicPair() {
        let raw = source("The ", "quick brown fox", " jumps.", id: "k7", body: "needs a citation")
        let doc = CriticMarkup.preprocess(raw)

        #expect(doc.transformedSource == "The quick brown fox jumps.")
        #expect(doc.comments.count == 1)
        let comment = doc.comments[0]
        #expect(comment.id == "k7")
        #expect(comment.body == "needs a citation")
        #expect(doc.transformedSource[comment.transformedHighlightRange] == "quick brown fox")
        #expect(doc.rawSource[comment.rawHighlightRange] == "quick brown fox")
    }

    @Test("Any rendered text is commentable — links, code, emphasis, mid-word")
    func commentsArbitraryContent() {
        for inner in ["[docs](https://x.com)", "`swift build`", "**bold** text", "uns"] {
            let raw = source("see ", inner, " now", id: "a", body: "c")
            let doc = CriticMarkup.preprocess(raw)
            #expect(doc.comments.count == 1)
            #expect(doc.transformedSource[doc.comments[0].transformedHighlightRange] == inner)
        }
    }

    @Test("Multiple comments are ordered by document position")
    func multipleComments() {
        let entries = [
            CommentSidecar.Entry(id: "b", body: "two"),
            CommentSidecar.Entry(id: "a", body: "one"),
        ]
        let raw = "\(CommentFixture.start("a"))A\(CommentFixture.end("a")) and "
            + "\(CommentFixture.start("b"))B\(CommentFixture.end("b"))\n\n"
            + CommentSidecar.encode(entries)
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.transformedSource == "A and B")
        #expect(doc.comments.map(\.id) == ["a", "b"])
        #expect(doc.comments.map(\.body) == ["one", "two"])
    }

    @Test("Nested (crossing) anchor pairs both resolve")
    func nestedComments() {
        let entries = [
            CommentSidecar.Entry(id: "out", body: "outer"),
            CommentSidecar.Entry(id: "in", body: "inner"),
        ]
        let raw = "\(CommentFixture.start("out"))foo \(CommentFixture.start("in"))bar"
            + "\(CommentFixture.end("in")) baz\(CommentFixture.end("out"))\n\n"
            + CommentSidecar.encode(entries)
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.transformedSource == "foo bar baz")
        let byID = doc.commentsByID
        #expect(doc.transformedSource[byID["out"]!.transformedHighlightRange] == "foo bar baz")
        #expect(doc.transformedSource[byID["in"]!.transformedHighlightRange] == "bar")
    }

    @Test("innermostComment picks the smallest-enclosing comment in an overlap")
    func innermostComment() {
        let entries = [
            CommentSidecar.Entry(id: "out", body: "outer"),
            CommentSidecar.Entry(id: "in", body: "inner"),
        ]
        let raw = "\(CommentFixture.start("out"))foo \(CommentFixture.start("in"))bar"
            + "\(CommentFixture.end("in")) baz\(CommentFixture.end("out"))\n\n"
            + CommentSidecar.encode(entries)
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.innermostComment(among: ["out", "in"])?.id == "in")
        #expect(doc.innermostComment(among: ["out"])?.id == "out")
        #expect(doc.innermostComment(among: ["nope"]) == nil)
    }

    @Test("Overlapping (truly crossing) anchor pairs both resolve")
    func overlappingComments() {
        let entries = [
            CommentSidecar.Entry(id: "x", body: "first"),
            CommentSidecar.Entry(id: "y", body: "second"),
        ]
        // x opens, y opens, x closes, y closes — a genuine overlap, not nesting.
        let raw = "\(CommentFixture.start("x"))A B \(CommentFixture.start("y"))C"
            + "\(CommentFixture.end("x")) D\(CommentFixture.end("y"))\n\n"
            + CommentSidecar.encode(entries)
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.transformedSource == "A B C D")
        #expect(doc.transformedSource[doc.commentsByID["x"]!.transformedHighlightRange] == "A B C")
        #expect(doc.transformedSource[doc.commentsByID["y"]!.transformedHighlightRange] == "C D")
    }

    @Test("Orphaned anchors are stripped but yield no comment")
    func orphanAnchorStripped() {
        let raw = "foo \(CommentFixture.start("lonely"))bar baz\n\n"
            + CommentSidecar.encode([.init(id: "lonely", body: "x")])
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.transformedSource == "foo bar baz")
        #expect(doc.comments.isEmpty)
    }

    @Test("Anchors with no sidecar entry yield no comment")
    func noSidecarEntry() {
        let raw = "foo \(CommentFixture.start("z"))bar\(CommentFixture.end("z")) baz"
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.transformedSource == "foo bar baz")
        #expect(doc.comments.isEmpty)
    }

    @Test("Duplicate ids are rejected")
    func duplicateID() {
        let raw = "\(CommentFixture.start("d"))A\(CommentFixture.end("d")) "
            + "\(CommentFixture.start("d"))B\(CommentFixture.end("d"))\n\n"
            + CommentSidecar.encode([.init(id: "d", body: "x")])
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.transformedSource == "A B")
        #expect(doc.comments.isEmpty)
    }

    @Test("rawRange maps a transformed sub-range back to raw")
    func rawRangeRoundTrip() {
        let raw = source("The ", "quick brown fox", " jumps.", id: "k7", body: "c")
        let doc = CriticMarkup.preprocess(raw)
        let t = doc.transformedSource
        let quick = t.range(of: "quick")!
        let rawRange = try! #require(doc.rawRange(forTransformed: quick))
        #expect(doc.rawSource[rawRange] == "quick")
    }

    @Test("Empty highlight (adjacent anchors) yields no comment")
    func emptyHighlight() {
        let raw = "foo \(CommentFixture.start("e"))\(CommentFixture.end("e")) bar\n\n"
            + CommentSidecar.encode([.init(id: "e", body: "x")])
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.transformedSource == "foo  bar")
        #expect(doc.comments.isEmpty)
    }

    @Test("Duplicate sidecar entries for one id yield a single comment")
    func duplicateSidecarEntry() {
        let entries = [
            CommentSidecar.Entry(id: "d", body: "one"),
            CommentSidecar.Entry(id: "d", body: "two"),
        ]
        let raw = "\(CommentFixture.start("d"))X\(CommentFixture.end("d"))\n\n" + CommentSidecar.encode(entries)
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.comments.count == 1)
        #expect(doc.comments[0].body == "one")
    }

    @Test("A mid-document sidecar is stripped without merging the paragraphs around it")
    func midDocumentSidecar() {
        let sidecar = CommentSidecar.encode([.init(id: "m", body: "x")])
        let raw = "para one\n\n\(sidecar)\n\npara two"
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.transformedSource == "para one\n\npara two")
    }

    @Test("CRLF separators around a trailing sidecar are absorbed")
    func crlfSidecarAbsorption() {
        let sidecar = CommentSidecar.encode([.init(id: "m", body: "x")])
        let doc = CriticMarkup.preprocess("para\r\n\r\n\(sidecar)")
        #expect(doc.transformedSource == "para")
    }

    @Test("A literal non-self-closing <mkdn-comment ...> in prose doesn't swallow a real anchor")
    func literalMarkerInProse() {
        let real = CommentFixture.doc("see foo here", comment: "foo", id: "c1", body: "n")
        let raw = "Docs: <mkdn-comment id=\"x\" edge=\"start\"> denotes a start.\n\n" + real
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.commentsByID["c1"]?.body == "n")
        #expect(doc.transformedSource.contains("denotes a start."))
        #expect(doc.transformedSource.contains("see foo here"))
    }

    @Test("An orphaned sidecar entry is re-anchored by its unique TextQuote")
    func reanchorByQuote() {
        let entry = CommentSidecar.Entry(
            id: "k1", body: "note", quote: "brown fox", prefix: "quick ", suffix: " jumps"
        )
        let raw = "The quick brown fox jumps over\n\n" + CommentSidecar.encode([entry])
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.comments.count == 1)
        #expect(doc.commentsByID["k1"]?.body == "note")
        #expect(doc.transformedSource[doc.commentsByID["k1"]!.transformedHighlightRange] == "brown fox")
    }

    @Test("A re-anchored comment maps back to the raw source")
    func reanchorMapsToRaw() {
        let entry = CommentSidecar.Entry(id: "k1", body: "n", quote: "fox", prefix: "brown ", suffix: " jumps")
        let raw = "The quick brown fox jumps\n\n" + CommentSidecar.encode([entry])
        let doc = CriticMarkup.preprocess(raw)
        let comment = try! #require(doc.commentsByID["k1"])
        #expect(doc.rawSource[comment.rawHighlightRange] == "fox")
    }

    @Test("Anchor attributes parse regardless of order (real id, not a substring)")
    func attributeOrderIndependent() {
        let raw = "<mkdn-comment edge=\"start\" id=\"real\"/>X<mkdn-comment edge=\"end\" id=\"real\"/>\n\n"
            + CommentSidecar.encode([.init(id: "real", body: "n")])
        let doc = CriticMarkup.preprocess(raw)
        #expect(doc.commentsByID["real"]?.body == "n")
        #expect(doc.transformedSource == "X")
    }

    @Test("A non-unique quote stays orphaned (no fuzzy matching)")
    func reanchorAmbiguous() {
        let entry = CommentSidecar.Entry(id: "k1", body: "n", quote: "cat")
        let raw = "cat and cat\n\n" + CommentSidecar.encode([entry])
        #expect(CriticMarkup.preprocess(raw).comments.isEmpty)
    }

    @Test("A quote absent from the text stays orphaned")
    func reanchorMissing() {
        let entry = CommentSidecar.Entry(id: "k1", body: "n", quote: "zebra")
        let raw = "no animals here\n\n" + CommentSidecar.encode([entry])
        #expect(CriticMarkup.preprocess(raw).comments.isEmpty)
    }

    @Test("A plain document with no anchors round-trips unchanged")
    func plainDocument() {
        let doc = CriticMarkup.preprocess("# Title\n\nJust prose.")
        #expect(doc.transformedSource == "# Title\n\nJust prose.")
        #expect(doc.comments.isEmpty)
    }
}

@Suite("Anchor-comment authoring")
struct AnchorCommentAuthoringTests {
    @Test("wrapComment inserts an anchor pair and sidecar, re-parsing to the comment")
    func wrapBasic() {
        let raw = "The quick brown fox"
        let wrapped = try! #require(
            CriticMarkup.wrapComment(in: raw, range: raw.range(of: "quick")!, body: "note", idGenerator: { "c1" })
        )
        let doc = CriticMarkup.preprocess(wrapped)
        #expect(doc.transformedSource == "The quick brown fox")
        #expect(doc.comments.count == 1)
        #expect(doc.comments[0].id == "c1")
        #expect(doc.comments[0].body == "note")
        #expect(doc.transformedSource[doc.comments[0].transformedHighlightRange] == "quick")
    }

    @Test("Commenting the first word of a line is allowed (structure-safe marker)")
    func wrapLineStart() {
        let raw = "Hello world"
        let wrapped = try! #require(
            CriticMarkup.wrapComment(in: raw, range: raw.range(of: "Hello")!, body: "hi", idGenerator: { "c1" })
        )
        let doc = CriticMarkup.preprocess(wrapped)
        #expect(doc.transformedSource == "Hello world")
        #expect(doc.transformedSource[doc.comments[0].transformedHighlightRange] == "Hello")
    }

    @Test("Anchors use the semantic self-closing <mkdn-comment> custom element")
    func anchorTokenFormat() {
        let wrapped = CommentFixture.doc("Hello world", comment: "Hello", id: "c1")
        #expect(wrapped.contains("<mkdn-comment id=\"c1\" edge=\"start\"/>"))
        #expect(wrapped.contains("<mkdn-comment id=\"c1\" edge=\"end\"/>"))
    }

    @Test("AST verify rejects an insertion that changes block structure")
    func wrapRejectsStructureChange() {
        // Wrapping the leading '#' would place the anchor ahead of it, demoting
        // the heading to a paragraph in a standard renderer — must be rejected.
        let raw = "# Title"
        let hash = raw.startIndex ..< raw.index(after: raw.startIndex)
        #expect(CriticMarkup.wrapComment(in: raw, range: hash, body: "x") == nil)
    }

    @Test("wrapComment rejects an empty range")
    func wrapEmpty() {
        let raw = "hello"
        let empty = raw.startIndex ..< raw.startIndex
        #expect(CriticMarkup.wrapComment(in: raw, range: empty, body: "x") == nil)
    }

    @Test("wrapComment commenting a link keeps the link intact")
    func wrapLink() {
        let raw = "see [docs](https://example.com) now"
        let wrapped = try! #require(
            CriticMarkup.wrapComment(
                in: raw, range: raw.range(of: "[docs](https://example.com)")!, body: "c", idGenerator: { "c1" }
            )
        )
        let doc = CriticMarkup.preprocess(wrapped)
        #expect(doc.transformedSource == raw)
        #expect(doc.transformedSource[doc.comments[0].transformedHighlightRange] == "[docs](https://example.com)")
    }

    @Test("wrapComment generates a unique id, never colliding with an existing one")
    func wrapUniqueID() {
        let first = CommentFixture.doc("a and b", comment: "a", id: "c1", body: "one")
        var generated = ["c1", "c1", "zz9"].makeIterator()
        let second = try! #require(
            CriticMarkup.wrapComment(
                in: first, range: first.range(of: "b")!, body: "two",
                idGenerator: { generated.next() ?? "fallback" }
            )
        )
        let doc = CriticMarkup.preprocess(second)
        #expect(doc.comments.count == 2)
        #expect(Set(doc.comments.map(\.id)) == ["c1", "zz9"])
    }

    @Test("wrapComment rejects a selection that swallows the sidecar block")
    func wrapRejectsSidecarSelection() {
        let raw = CommentFixture.doc("a b c", comment: "b", id: "c1", body: "note")
        let whole = raw.startIndex ..< raw.endIndex // spans the sidecar block too
        #expect(CriticMarkup.wrapComment(in: raw, range: whole, body: "x") == nil)
    }

    @Test("wrapComment rejects a selection overlapping the sidecar's JSON payload")
    func wrapRejectsSidecarPayloadSelection() {
        let raw = CommentFixture.doc("a b c", comment: "b", id: "c1", body: "note")
        let block = CommentSidecar.decode(from: raw)!.blockRange
        // A range strictly inside the sidecar payload — past the marker, so a
        // substring check on the marker would miss it; range-overlap catches it.
        let inside = raw.index(block.lowerBound, offsetBy: 20) ..< raw.index(before: block.upperBound)
        #expect(CriticMarkup.wrapComment(in: raw, range: inside, body: "x") == nil)
    }

    @Test("CRLF document survives an add/delete round-trip without doubled newlines")
    func crlfRoundTrip() {
        let withComment = CommentFixture.doc("text\r\n", comment: "text", id: "c1", body: "n")
        let afterDelete = CriticMarkup.deleteComment(in: withComment, id: "c1")
        #expect(!afterDelete.hasSuffix("\n\n"))
        #expect(CriticMarkup.preprocess(afterDelete).transformedSource == "text\n")
    }

    @Test("Deleting the last comment preserves significant trailing spaces")
    func deletePreservesHardBreakSpaces() {
        let withComment = CommentFixture.doc("see this  ", comment: "this", id: "c1", body: "n")
        let afterDelete = CriticMarkup.deleteComment(in: withComment, id: "c1")
        #expect(afterDelete.contains("this  ")) // hard-break spaces survive
    }

    @Test("editComment rewrites the body; unknown id returns nil")
    func edit() {
        let raw = CommentFixture.doc("a b c", comment: "b", id: "c1", body: "old")
        let edited = try! #require(CriticMarkup.editComment(in: raw, id: "c1", newBody: "new"))
        #expect(CriticMarkup.preprocess(edited).commentsByID["c1"]?.body == "new")
        #expect(CriticMarkup.editComment(in: raw, id: "missing", newBody: "x") == nil)
    }

    @Test("editComment accepts arbitrary body text (sidecar escapes it)")
    func editArbitraryBody() {
        let raw = CommentFixture.doc("a b c", comment: "b", id: "c1", body: "old")
        let edited = try! #require(CriticMarkup.editComment(in: raw, id: "c1", newBody: "see --> and `x`"))
        #expect(CriticMarkup.preprocess(edited).commentsByID["c1"]?.body == "see --> and `x`")
    }

    @Test("deleteComment removes the anchors and sidecar entry, keeping the text")
    func delete() {
        let raw = CommentFixture.doc("a b c", comment: "b", id: "c1", body: "note")
        let deleted = CriticMarkup.deleteComment(in: raw, id: "c1")
        let doc = CriticMarkup.preprocess(deleted)
        #expect(doc.transformedSource == "a b c\n") // sidecar removed, EOF newline kept
        #expect(doc.comments.isEmpty)
        #expect(!deleted.contains("mkc"))
        #expect(!deleted.contains("mkdn-comments"))
    }

    @Test("Authoring round-trip leaves the visible markdown unchanged")
    func roundTrip() {
        let original = "# Heading\n\nSome **bold** prose and a [link](url)."
        let wrapped = CommentFixture.doc(original, comment: "bold", id: "c1", body: "why bold?")
        #expect(CriticMarkup.preprocess(wrapped).transformedSource == original)
    }

    @Test("Two comments coexist; deleting one leaves the other intact")
    func deleteOneOfTwo() {
        let raw = CommentFixture.doc("a and b", comments: [("a", "c1", "one"), ("b", "c2", "two")])
        let afterDelete = CriticMarkup.deleteComment(in: raw, id: "c1")
        let doc = CriticMarkup.preprocess(afterDelete)
        #expect(doc.comments.map(\.id) == ["c2"])
        #expect(doc.commentsByID["c2"]?.body == "two")
        #expect(doc.transformedSource == "a and b")
    }
}
