#if os(macOS)
    import AppKit
    import Foundation
    import Testing
    @testable import mkdnLib

    @MainActor
    @Suite("NSTextView comment hit-test")
    struct CommentHitTestTests {
        /// A laid-out text view holding the highlighted render of `raw`.
        /// Touching `layoutManager` forces the TextKit 1 stack, so geometry and
        /// `commentInfo` agree on the same layout in the test.
        private func textView(_ raw: String) -> NSTextView {
            let document = CriticMarkup.preprocess(raw)
            let blocks = MarkdownRenderer.render(text: document.transformedSource, theme: .solarizedDark)
            let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: .solarizedDark)
            let mutable = NSMutableAttributedString(attributedString: result.attributedString)
            MarkdownTextStorageBuilder.applyCommentHighlights(
                to: mutable, document: document, sourceMap: result.sourceMap, color: .yellow
            )

            let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            view.textContainerInset = .zero
            view.textContainer?.lineFragmentPadding = 0
            view.textStorage?.setAttributedString(mutable)
            view.layoutManager?.ensureLayout(for: view.textContainer!)
            return view
        }

        private func centerPoint(of substring: String, in view: NSTextView) -> CGPoint {
            let nsRange = (view.string as NSString).range(of: substring)
            let glyphRange = view.layoutManager!.glyphRange(forCharacterRange: nsRange, actualCharacterRange: nil)
            let rect = view.layoutManager!.boundingRect(forGlyphRange: glyphRange, in: view.textContainer!)
            return CGPoint(x: rect.midX, y: rect.midY)
        }

        @Test("Returns the comment id and full range over a highlighted span")
        func hitOnComment() {
            let view = textView("foo {==bar==}{>>note<<} baz")
            let info = view.commentInfo(at: centerPoint(of: "bar", in: view))
            #expect(info?.id == "c1")
            if let info {
                #expect((view.string as NSString).substring(with: info.range) == "bar")
            }
        }

        @Test("Returns nil over text that is not commented")
        func missOnPlainText() {
            let view = textView("foo {==bar==}{>>note<<} baz")
            #expect(view.commentInfo(at: centerPoint(of: "foo", in: view)) == nil)
            #expect(view.commentInfo(at: centerPoint(of: "baz", in: view)) == nil)
        }

        @Test("Returns nil for a point in the empty margin past the text")
        func missInMargin() {
            let view = textView("short")
            #expect(view.commentInfo(at: CGPoint(x: 590, y: 380)) == nil)
        }
    }
#endif
