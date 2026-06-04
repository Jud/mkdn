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
        private func tape(_ text: String) -> AnchorTape {
            AnchorTape.build(from: NSAttributedString(string: text))
        }

        private func entry(
            quote: String, prefix: String = "", suffix: String = "", start: Int? = nil
        ) -> CommentSidecar.Entry {
            CommentSidecar.Entry(id: "c", body: "b", quote: quote, prefix: prefix, suffix: suffix, start: start)
        }

        // MARK: - Single match

        @Test("A unique quote resolves to its builder range")
        func uniqueQuote() {
            let t = tape("the quick brown fox")
            let result = CommentAnchorResolver.resolve(entry(quote: "quick brown"), in: t)
            #expect(result == .resolved(NSRange(location: 4, length: 11)))
        }

        @Test("A lone match anchors even when context no longer matches")
        func singleMatchIgnoresContext() {
            let t = tape("the quick brown fox")
            let result = CommentAnchorResolver.resolve(
                entry(quote: "quick brown", prefix: "wrong ", suffix: " context"), in: t
            )
            #expect(result == .resolved(NSRange(location: 4, length: 11)))
        }

        // MARK: - No match

        @Test("A quote not present orphans")
        func absentQuote() {
            let result = CommentAnchorResolver.resolve(entry(quote: "missing"), in: tape("the quick brown fox"))
            #expect(result == .orphaned)
        }

        @Test("An empty quote orphans")
        func emptyQuote() {
            let result = CommentAnchorResolver.resolve(entry(quote: ""), in: tape("the quick brown fox"))
            #expect(result == .orphaned)
        }

        // MARK: - Duplicate quote disambiguation

        @Test("Duplicate quote disambiguates by prefix context")
        func disambiguatesByPrefix() {
            let t = tape("red apple and green apple")
            let result = CommentAnchorResolver.resolve(entry(quote: "apple", prefix: "green "), in: t)
            #expect(result == .resolved(NSRange(location: 20, length: 5)))
        }

        @Test("Duplicate quote disambiguates by suffix context")
        func disambiguatesBySuffix() {
            let t = tape("apple pie and apple tart")
            let result = CommentAnchorResolver.resolve(entry(quote: "apple", suffix: " tart"), in: t)
            #expect(result == .resolved(NSRange(location: 14, length: 5)))
        }

        @Test("Identical context falls back to nearest position hint")
        func disambiguatesByNearestHint() {
            let t = tape("apple apple apple")
            let result = CommentAnchorResolver.resolve(entry(quote: "apple", start: 7), in: t)
            #expect(result == .resolved(NSRange(location: 6, length: 5)))
        }

        @Test("Identical context and no hint is a tie → orphan")
        func tieWithoutHintOrphans() {
            let t = tape("apple apple apple")
            #expect(CommentAnchorResolver.resolve(entry(quote: "apple"), in: t) == .orphaned)
        }

        @Test("Equidistant candidates from the hint is a tie → orphan")
        func equidistantHintOrphans() {
            let t = tape("apple apple")
            let result = CommentAnchorResolver.resolve(entry(quote: "apple", start: 3), in: t)
            #expect(result == .orphaned)
        }

        // MARK: - Tape integration (normalization)

        @Test("Resolved range covers the verbatim source of a collapsed-whitespace span")
        func collapsedWhitespaceSpan() throws {
            let source = "Hello   World"
            let t = AnchorTape.build(from: NSAttributedString(string: source))
            let result = CommentAnchorResolver.resolve(entry(quote: "hello world"), in: t)
            let range = try #require({ if case let .resolved(r) = result { r } else { nil } }())
            #expect((source as NSString).substring(with: range) == source)
        }

        @Test("Code quote resolves verbatim (case-significant)")
        func codeQuoteVerbatim() throws {
            let indexed = IndexedBlock(index: 0, block: .codeBlock(language: "swift", code: "Let X = 1"))
            let built = MarkdownTextStorageBuilder.build(blocks: [indexed], theme: .solarizedDark)
            let t = AnchorTape.build(from: built.attributedString)
            let result = CommentAnchorResolver.resolve(entry(quote: "Let X = 1"), in: t)
            let range = try #require({ if case let .resolved(r) = result { r } else { nil } }())
            #expect(built.attributedString.attributedSubstring(from: range).string.contains("Let X = 1"))
        }
    }
#endif
