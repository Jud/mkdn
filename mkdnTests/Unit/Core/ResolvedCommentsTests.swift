#if os(macOS)
    import AppKit
    import Testing
    @testable import mkdnLib

    @Suite("ResolvedComments")
    @MainActor
    struct ResolvedCommentsTests {
        private func tape(_ text: String) -> AnchorTape {
            AnchorTape.build(from: NSAttributedString(string: text))
        }

        private func entry(_ id: String, quote: String, body: String = "b") -> CommentSidecar.Entry {
            CommentSidecar.Entry(id: id, body: body, quote: quote, norm: AnchorTape.normalizationVersion)
        }

        @Test("resolve maps resolved ranges and collects orphan entries")
        func resolvesAndOrphans() {
            let resolved = ResolvedComments.resolve(
                [entry("a", quote: "quick brown"), entry("b", quote: "missing")],
                in: tape("the quick brown fox")
            )
            #expect(resolved.ranges == ["a": NSRange(location: 4, length: 11)])
            #expect(resolved.orphans.map(\.id) == ["b"])
        }

        @Test("comments(containing:) joins entries innermost-first")
        func hitTestWithBodies() {
            let resolved = ResolvedComments.resolve(
                [entry("outer", quote: "quick brown", body: "outer body"),
                 entry("inner", quote: "quick", body: "inner body")],
                in: tape("the quick brown fox")
            )
            let hits = resolved.comments(containing: 5) // inside both spans
            #expect(hits.map(\.entry.id) == ["inner", "outer"])
            #expect(hits.first?.entry.body == "inner body")
        }

        @Test("comments(containing:) is empty off any comment")
        func hitTestMiss() {
            let resolved = ResolvedComments.resolve([entry("a", quote: "quick")], in: tape("the quick brown fox"))
            #expect(resolved.comments(containing: 17).isEmpty) // in "fox", no comment
        }

        @Test("active lists resolved comments in document order with entries and ranges")
        func activeInDocumentOrder() {
            let resolved = ResolvedComments.resolve(
                [entry("b", quote: "fox", body: "second"),
                 entry("a", quote: "quick", body: "first"),
                 entry("c", quote: "missing")],
                in: tape("the quick brown fox")
            )
            let active = resolved.active
            #expect(active.map(\.id) == ["a", "b"]) // "quick"@4 before "fox"@16; "c" orphaned
            #expect(active.map(\.entry.body) == ["first", "second"])
            #expect(active.map(\.range) == [NSRange(location: 4, length: 5), NSRange(location: 16, length: 3)])
        }

        @Test("active breaks location ties by id for stable ordering")
        func activeTieBreak() {
            // Two distinct comments resolving to the same location (identical quote)
            // must order deterministically by id.
            let resolved = ResolvedComments.resolve(
                [entry("z", quote: "quick"), entry("a", quote: "quick")],
                in: tape("the quick brown fox")
            )
            #expect(resolved.active.map(\.id) == ["a", "z"])
        }

        @Test("Duplicate ids keep the first entry; resolved and orphaned stay disjoint")
        func duplicateIDs() {
            // Both entries share id "dup": first resolves, second would orphan.
            let resolved = ResolvedComments.resolve(
                [entry("dup", quote: "quick", body: "first"),
                 entry("dup", quote: "missing", body: "second")],
                in: tape("the quick brown fox")
            )
            #expect(resolved.ranges == ["dup": NSRange(location: 4, length: 5)])
            #expect(resolved.orphans.isEmpty)
            #expect(resolved.comments(containing: 5).first?.entry.body == "first")
        }
    }
#endif
