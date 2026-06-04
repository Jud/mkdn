#if os(macOS)
    import AppKit
    import Foundation
    import Testing
    @testable import mkdnLib

    @MainActor
    @Suite("Comment hit-test (drawn comments)")
    struct CommentHitTestTests {
        /// A laid-out text view rendering `markdown`, with `quote` captured as a
        /// comment and resolved into the view's index — the same capture→resolve
        /// chain the live authoring path uses. Touching `layoutManager` forces the
        /// TextKit 1 stack so geometry and `characterIndex` agree in the test.
        private func textView(_ markdown: String, comment quote: String) -> CodeBlockBackgroundTextView {
            let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)
            let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: .solarizedDark)
            let tape = AnchorTape.build(from: result.attributedString)
            let builderRange = (result.attributedString.string as NSString).range(of: quote)
            let selector = CommentSelectorCapture.capture(builderRange: builderRange, in: tape)!
            var entry = CommentSidecar.Entry(id: "c1", body: "note")
            entry.setAnchor(selector)

            let view = CodeBlockBackgroundTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            view.textContainerInset = NSSize(width: 16, height: 16)
            view.textStorage?.setAttributedString(result.attributedString)
            view.resolvedComments = ResolvedComments.resolve([entry], in: tape)
            view.layoutManager?.ensureLayout(for: view.textContainer!)
            return view
        }

        private func centerPoint(of substring: String, in view: NSTextView) -> CGPoint {
            let nsRange = (view.string as NSString).range(of: substring)
            let rect = view.boundingRect(forCharacterRange: nsRange)!
            return CGPoint(x: rect.midX, y: rect.midY)
        }

        @Test("A point over a commented span resolves to the comment and its range")
        func hitOnComment() {
            let view = textView("foo bar baz", comment: "bar")
            let hits = view.commentHits(at: centerPoint(of: "bar", in: view))
            #expect(hits.map(\.entry.id) == ["c1"])
            #expect((view.string as NSString).substring(with: hits[0].range) == "bar")
        }

        @Test("Finds the comment over a commented link label")
        func hitOnCommentedLink() {
            let view = textView("see [docs](https://x.com) now", comment: "docs")
            #expect(view.commentHits(at: centerPoint(of: "docs", in: view)).map(\.entry.id) == ["c1"])
        }

        @Test("Returns no hits over text that is not commented")
        func missOnPlainText() {
            let view = textView("foo bar baz", comment: "bar")
            #expect(view.commentHits(at: centerPoint(of: "foo", in: view)).isEmpty)
            #expect(view.commentHits(at: centerPoint(of: "baz", in: view)).isEmpty)
        }

        @Test("Returns no hits for a point in the empty margin past the text")
        func missInMargin() {
            let view = textView("short here", comment: "short")
            #expect(view.commentHits(at: CGPoint(x: 590, y: 380)).isEmpty)
        }

        @Test("boundingRect of a comment range round-trips back to the comment")
        func boundingRectRoundTrip() throws {
            let view = textView("foo bar baz", comment: "bar")
            let range = (view.string as NSString).range(of: "bar")
            let rect = try #require(view.boundingRect(forCharacterRange: range))
            #expect(rect.width > 0 && rect.height > 0)
            #expect(view.commentHits(at: CGPoint(x: rect.midX, y: rect.midY)).map(\.entry.id) == ["c1"])
        }
    }
#endif
