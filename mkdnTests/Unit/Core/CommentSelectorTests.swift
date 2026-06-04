#if os(macOS)
    import AppKit
    import Testing
    @testable import mkdnLib

    @Suite("CommentSelector")
    @MainActor
    struct CommentSelectorTests {
        private func tape(_ text: String) -> AnchorTape {
            AnchorTape.build(from: NSAttributedString(string: text))
        }

        @Test("Capture records the normalized quote, context, and offsets")
        func capturesFields() throws {
            let t = tape("the quick brown fox")
            let selector = try #require(
                CommentSelectorCapture.capture(builderRange: NSRange(location: 4, length: 11), in: t)
            )
            #expect(selector.quote == "quick brown")
            #expect(selector.prefix == "the ")
            #expect(selector.suffix == " fox")
            #expect(selector.start == 4)
            #expect(selector.end == 15)
            #expect(selector.norm == AnchorTape.normalizationVersion)
        }

        @Test("Context windows clamp to the document edges")
        func contextClampsAtEdges() throws {
            let t = tape("alpha beta")
            let selector = try #require(
                CommentSelectorCapture.capture(builderRange: NSRange(location: 0, length: 5), in: t)
            )
            #expect(selector.prefix == "")
            #expect(selector.suffix == " beta")
        }

        @Test("Capture returns nil for an empty selection")
        func emptySelectionIsNil() {
            #expect(CommentSelectorCapture.capture(builderRange: NSRange(location: 2, length: 0), in: tape("abc")) == nil)
        }

        // MARK: - Round-trip with the resolver

        @Test("A captured selector resolves back to the original span (unique quote)")
        func roundTripUnique() throws {
            let t = tape("the quick brown fox")
            let builderRange = NSRange(location: 4, length: 11)
            let selector = try #require(CommentSelectorCapture.capture(builderRange: builderRange, in: t))
            var entry = CommentSidecar.Entry(id: "c", body: "b")
            entry.setAnchor(selector)
            #expect(CommentAnchorResolver.resolve(entry, in: t) == .resolved(builderRange))
        }

        @Test("A captured selector disambiguates a duplicate quote via context + hint")
        func roundTripDuplicate() throws {
            let t = tape("red apple and green apple")
            let secondApple = NSRange(location: 20, length: 5)
            let selector = try #require(CommentSelectorCapture.capture(builderRange: secondApple, in: t))
            var entry = CommentSidecar.Entry(id: "c", body: "b")
            entry.setAnchor(selector)
            #expect(CommentAnchorResolver.resolve(entry, in: t) == .resolved(secondApple))
        }

        @Test("A captured code selector round-trips verbatim")
        func roundTripCode() throws {
            let indexed = IndexedBlock(index: 0, block: .codeBlock(language: "swift", code: "Let X = 1"))
            let built = MarkdownTextStorageBuilder.build(blocks: [indexed], theme: .solarizedDark)
            let t = AnchorTape.build(from: built.attributedString)
            let codeRange = (built.attributedString.string as NSString).range(of: "Let X = 1")
            let selector = try #require(CommentSelectorCapture.capture(builderRange: codeRange, in: t))
            #expect(selector.quote == "Let X = 1") // case preserved
            var entry = CommentSidecar.Entry(id: "c", body: "b")
            entry.setAnchor(selector)
            #expect(CommentAnchorResolver.resolve(entry, in: t) == .resolved(codeRange))
        }
    }
#endif
