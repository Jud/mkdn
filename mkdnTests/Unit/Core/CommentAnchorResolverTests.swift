#if os(macOS)
    import AppKit
    import Testing
    @testable import mkdnLib

    @Suite("CommentAnchorResolver")
    @MainActor
    struct CommentAnchorResolverTests {
        /// Build a tape from plain text. Callers pass already-normalized
        /// (lowercase, single-spaced) text so the tape maps 1:1 and resolved
        /// `NSRange`s are easy to assert against.
        private func makeTape(_ text: String) -> AnchorTape {
            AnchorTape.build(from: NSAttributedString(string: text))
        }

        private func entry(
            quote: String,
            id: String = "c",
            prefix: String = "",
            suffix: String = "",
            start: Int? = nil,
            norm: Int? = AnchorTape.normalizationVersion
        ) -> CommentSidecar.Entry {
            CommentSidecar.Entry(
                id: id, body: "b", quote: quote, prefix: prefix, suffix: suffix, start: start, norm: norm
            )
        }

        // MARK: - Single match

        @Test("A unique quote resolves to its builder range")
        func uniqueQuote() {
            let tape = makeTape("the quick brown fox")
            let result = CommentAnchorResolver.resolve(entry(quote: "quick brown"), in: tape)
            #expect(result == .resolved(NSRange(location: 4, length: 11)))
        }

        @Test("A lone match anchors even when context no longer matches")
        func singleMatchIgnoresContext() {
            let tape = makeTape("the quick brown fox")
            let result = CommentAnchorResolver.resolve(
                entry(quote: "quick brown", prefix: "wrong ", suffix: " context"), in: tape
            )
            #expect(result == .resolved(NSRange(location: 4, length: 11)))
        }

        // MARK: - No match

        @Test("A quote not present orphans")
        func absentQuote() {
            let result = CommentAnchorResolver.resolve(entry(quote: "missing"), in: makeTape("the quick brown fox"))
            #expect(result == .orphaned)
        }

        @Test("An empty quote orphans")
        func emptyQuote() {
            let result = CommentAnchorResolver.resolve(entry(quote: ""), in: makeTape("the quick brown fox"))
            #expect(result == .orphaned)
        }

        @Test("A selector from a different normalizer version orphans")
        func normMismatchOrphans() {
            let tape = makeTape("the quick brown fox")
            let stale = entry(quote: "quick brown", norm: AnchorTape.normalizationVersion + 1)
            #expect(CommentAnchorResolver.resolve(stale, in: tape) == .orphaned)
        }

        // MARK: - Duplicate quote disambiguation

        @Test("Duplicate quote disambiguates by prefix context")
        func disambiguatesByPrefix() {
            let tape = makeTape("red apple and green apple")
            let result = CommentAnchorResolver.resolve(entry(quote: "apple", prefix: "green "), in: tape)
            #expect(result == .resolved(NSRange(location: 20, length: 5)))
        }

        @Test("Duplicate quote disambiguates by suffix context")
        func disambiguatesBySuffix() {
            let tape = makeTape("apple pie and apple tart")
            let result = CommentAnchorResolver.resolve(entry(quote: "apple", suffix: " tart"), in: tape)
            #expect(result == .resolved(NSRange(location: 14, length: 5)))
        }

        @Test("Identical context falls back to nearest position hint")
        func disambiguatesByNearestHint() {
            let tape = makeTape("apple apple apple")
            let result = CommentAnchorResolver.resolve(entry(quote: "apple", start: 7), in: tape)
            #expect(result == .resolved(NSRange(location: 6, length: 5)))
        }

        @Test("Identical context and no hint is a tie → orphan")
        func tieWithoutHintOrphans() {
            let tape = makeTape("apple apple apple")
            #expect(CommentAnchorResolver.resolve(entry(quote: "apple"), in: tape) == .orphaned)
        }

        @Test("Equidistant candidates from the hint is a tie → orphan")
        func equidistantHintOrphans() {
            let tape = makeTape("apple apple")
            let result = CommentAnchorResolver.resolve(entry(quote: "apple", start: 3), in: tape)
            #expect(result == .orphaned)
        }

        @Test("An out-of-range or corrupt position hint is ignored (tie → orphan, no crash)")
        func outOfRangeHintOrphans() {
            let tape = makeTape("apple apple apple")
            #expect(CommentAnchorResolver.resolve(entry(quote: "apple", start: -1), in: tape) == .orphaned)
            #expect(CommentAnchorResolver.resolve(entry(quote: "apple", start: .min), in: tape) == .orphaned)
            #expect(CommentAnchorResolver.resolve(entry(quote: "apple", start: 9_999), in: tape) == .orphaned)
        }

        // MARK: - Batch index

        @Test("resolveAll keys resolved entries by id and lists orphans")
        func resolveAllBuildsIndex() {
            let tape = makeTape("the quick brown fox")
            let index = CommentAnchorResolver.resolveAll(
                [entry(quote: "quick brown", id: "a"), entry(quote: "missing", id: "b")], in: tape
            )
            #expect(index.ranges == ["a": NSRange(location: 4, length: 11)])
            #expect(index.orphaned == ["b"])
        }

        @Test("Index hit-test returns covering comments innermost-first")
        func indexHitTest() {
            var index = CommentAnchorResolver.Index()
            index.ranges = [
                "outer": NSRange(location: 0, length: 20),
                "inner": NSRange(location: 5, length: 5),
                "elsewhere": NSRange(location: 40, length: 3),
            ]
            // Offset 7 is inside both outer and inner; inner (smaller) comes first.
            #expect(index.comments(containing: 7).map(\.id) == ["inner", "outer"])
            // Offset 15 is only inside outer.
            #expect(index.comments(containing: 15).map(\.id) == ["outer"])
            // Offset 25 is in no comment.
            #expect(index.comments(containing: 25).isEmpty)
            // End-exclusive: offset 20 is past outer's [0,20).
            #expect(index.comments(containing: 20).isEmpty)
        }

        // MARK: - Tape integration (normalization)

        @Test("Resolved range covers the verbatim source of a collapsed-whitespace span")
        func collapsedWhitespaceSpan() throws {
            let source = "Hello   World"
            let tape = AnchorTape.build(from: NSAttributedString(string: source))
            let result = CommentAnchorResolver.resolve(entry(quote: "hello world"), in: tape)
            let range = try #require({ if case let .resolved(matched) = result { matched } else { nil } }())
            // swiftlint:disable:next legacy_objc_type
            #expect((source as NSString).substring(with: range) == source)
        }

        @Test("Code quote resolves verbatim (case-significant)")
        func codeQuoteVerbatim() throws {
            let indexed = IndexedBlock(index: 0, block: .codeBlock(language: "swift", code: "Let X = 1"))
            let built = MarkdownTextStorageBuilder.build(blocks: [indexed], theme: .solarizedDark)
            let tape = AnchorTape.build(from: built.attributedString)
            let result = CommentAnchorResolver.resolve(entry(quote: "Let X = 1"), in: tape)
            let range = try #require({ if case let .resolved(matched) = result { matched } else { nil } }())
            #expect(built.attributedString.attributedSubstring(from: range).string.contains("Let X = 1"))
        }
    }
#endif
