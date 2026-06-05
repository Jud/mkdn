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

        /// A laid-out *TextKit 2* text view — does NOT touch `layoutManager` (which
        /// would switch to TextKit 1); forces layout via `textLayoutManager`. This
        /// exercises the TextKit 2 `characterIndex(at:)` branch the other tests skip.
        private func tk2TextView(
            _ attributed: NSAttributedString, comment quote: String, width: CGFloat
        ) throws -> CodeBlockBackgroundTextView {
            let tape = AnchorTape.build(from: attributed)
            let builderRange = (attributed.string as NSString).range(of: quote)
            let selector = try #require(CommentSelectorCapture.capture(builderRange: builderRange, in: tape))
            var entry = CommentSidecar.Entry(id: "c1", body: "note")
            entry.setAnchor(selector)

            let view = CodeBlockBackgroundTextView(frame: NSRect(x: 0, y: 0, width: width, height: 2000))
            view.textContainerInset = NSSize(width: 16, height: 16)
            view.textContainer?.containerSize = NSSize(width: width - 32, height: .greatestFiniteMagnitude)
            view.textStorage?.setAttributedString(attributed)
            view.resolvedComments = ResolvedComments.resolve([entry], in: tape)
            let tlm = try #require(view.textLayoutManager)
            tlm.ensureLayout(for: try #require(tlm.textContentManager).documentRange)
            return view
        }

        @Test("TextKit 2: a comment on a wrapped 2nd line hit-tests at its span center")
        func hitOnWrappedSecondLineTK2() throws {
            // A long single paragraph that must wrap; the commented phrase lands well
            // past the first line. Regression guard for the wrapped-line hit-test
            // offset fix (the old code double-counted the line-fragment start and
            // returned nil for 2nd+ line spans).
            let prose = "The quick brown fox jumps over the lazy dog and keeps running "
                + "far past the right margin so this line is forced to wrap several "
                + "times before the commented WRAPPEDPHRASE finally appears."
            let attributed = NSAttributedString(string: prose)
            let view = try tk2TextView(attributed, comment: "WRAPPEDPHRASE", width: 280)

            let string = view.string as NSString
            let quoteRect = try #require(view.boundingRect(forCharacterRange: string.range(of: "WRAPPEDPHRASE")))
            let firstWordRect = try #require(view.boundingRect(forCharacterRange: string.range(of: "quick")))
            // Non-vacuous: the phrase must be on a visual line below the first word.
            #expect(quoteRect.minY > firstWordRect.maxY)

            let hits = view.commentHits(at: CGPoint(x: quoteRect.midX, y: quoteRect.midY))
            #expect(hits.map(\.entry.id) == ["c1"])
            #expect(string.substring(with: hits[0].range) == "WRAPPEDPHRASE")
        }
    }
#endif
