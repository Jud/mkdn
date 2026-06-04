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
    }
#endif
