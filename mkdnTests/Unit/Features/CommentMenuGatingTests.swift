#if os(macOS)
    import AppKit
    import Testing
    @testable import mkdnLib

    /// Drives the actual gate the "Add Comment…" menu item and click path use —
    /// `commentableSelectionRange()` on a real text view with a live selection,
    /// `criticDocument`, and `commentSourceMap` — rather than the resolver alone.
    @Suite("CommentMenuGating")
    @MainActor
    struct CommentMenuGatingTests {
        private func makeTextView(_ raw: String) -> (CodeBlockBackgroundTextView, NSString) {
            let document = CriticMarkup.preprocess(raw)
            let blocks = MarkdownRenderer.render(text: document.transformedSource, theme: .solarizedDark)
            let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: .solarizedDark)

            let textContainer = NSTextContainer()
            let layoutManager = NSTextLayoutManager()
            layoutManager.textContainer = textContainer
            let contentStorage = NSTextContentStorage()
            contentStorage.addTextLayoutManager(layoutManager)

            let textView = CodeBlockBackgroundTextView(
                frame: NSRect(x: 0, y: 0, width: 600, height: 400),
                textContainer: textContainer
            )
            textView.textStorage?.setAttributedString(result.attributedString)
            textView.criticDocument = document
            textView.commentSourceMap = result.sourceMap
            return (textView, textView.string as NSString)
        }

        @Test("Selecting a quoted phrase enables commenting (the menu gate)")
        func quotedPhraseIsCommentable() {
            let raw = "the partials commute, so\n\"recipient last\" is an orchestration rule"
            let (textView, rendered) = makeTextView(raw)

            let range = rendered.range(of: "recipient last")
            #expect(range.location != NSNotFound)
            textView.setSelectedRange(range)

            // This is exactly what menu(for:) checks before adding "Add Comment…".
            #expect(textView.commentableSelectionRange() != nil)
        }

        @Test("Empty selection is not commentable")
        func emptySelectionNotCommentable() {
            let (textView, _) = makeTextView("plain prose here")
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            #expect(textView.commentableSelectionRange() == nil)
        }
    }
#endif
