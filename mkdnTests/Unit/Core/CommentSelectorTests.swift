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

        /// A comment entry carrying `selector`'s captured anchor.
        private func anchored(_ selector: CommentSelector) -> CommentSidecar.Entry {
            var entry = CommentSidecar.Entry(id: "c", body: "b")
            entry.setAnchor(selector)
            return entry
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
            #expect(CommentAnchorResolver.resolve(anchored(selector), in: t) == .resolved(builderRange))
        }

        @Test("A captured selector disambiguates a duplicate quote via context + hint")
        func roundTripDuplicate() throws {
            let t = tape("red apple and green apple")
            let secondApple = NSRange(location: 20, length: 5)
            let selector = try #require(CommentSelectorCapture.capture(builderRange: secondApple, in: t))
            #expect(CommentAnchorResolver.resolve(anchored(selector), in: t) == .resolved(secondApple))
        }

        @Test("A selection ending inside a collapsed-whitespace run round-trips identically")
        func roundTripTrailingCollapsedWhitespace() throws {
            // No trim on either side, so a quote that pulls in a trailing collapsed
            // space must still capture+resolve to the same builder span — the
            // write/read symmetry the design hinges on.
            let t = AnchorTape.build(from: NSAttributedString(string: "Hello   World"))
            let selection = NSRange(location: 0, length: 8) // "Hello   " (5 + 3 spaces)
            let selector = try #require(CommentSelectorCapture.capture(builderRange: selection, in: t))
            #expect(selector.quote == "hello ")
            #expect(CommentAnchorResolver.resolve(anchored(selector), in: t) == .resolved(selection))
        }

        @Test("A selection splitting a surrogate pair snaps to keep the astral char whole")
        func surrogatePairNotSplit() throws {
            let t = tape("a😀b") // UTF-16: a, D83D, DE00, b
            // Selection ends between the emoji's high and low halves; must snap out
            // to include the whole emoji rather than capturing a lone surrogate.
            let endSplit = try #require(CommentSelectorCapture.capture(builderRange: NSRange(location: 0, length: 2), in: t))
            #expect(endSplit.quote == "a😀")
            #expect(!endSplit.quote.unicodeScalars.contains("\u{FFFD}"))
            #expect(CommentAnchorResolver.resolve(anchored(endSplit), in: t) == .resolved(NSRange(location: 0, length: 3)))

            // Selection starts on the emoji's low half; must snap back to its high half.
            let startSplit = try #require(CommentSelectorCapture.capture(builderRange: NSRange(location: 2, length: 2), in: t))
            #expect(startSplit.quote == "😀b")
            #expect(CommentAnchorResolver.resolve(anchored(startSplit), in: t) == .resolved(NSRange(location: 1, length: 3)))
        }

        @Test("A captured code selector round-trips verbatim")
        func roundTripCode() throws {
            let indexed = IndexedBlock(index: 0, block: .codeBlock(language: "swift", code: "Let X = 1"))
            let built = MarkdownTextStorageBuilder.build(blocks: [indexed], theme: .solarizedDark)
            let t = AnchorTape.build(from: built.attributedString)
            let codeRange = (built.attributedString.string as NSString).range(of: "Let X = 1")
            let selector = try #require(CommentSelectorCapture.capture(builderRange: codeRange, in: t))
            #expect(selector.quote == "Let X = 1") // case preserved
            #expect(CommentAnchorResolver.resolve(anchored(selector), in: t) == .resolved(codeRange))
        }
    }
#endif
