#if os(macOS)
    import AppKit
    import Testing
    @testable import mkdnLib

    /// Drives the actual gate the "Add Comment…" menu item and click path use —
    /// `commentableSelection()` on a real text view with a live selection and the
    /// rendered anchor tape — rather than the resolver alone.
    @Suite("CommentMenuGating")
    @MainActor
    struct CommentMenuGatingTests {
        // swiftlint:disable:next legacy_objc_type
        private func makeTextView(_ markdown: String) -> (CodeBlockBackgroundTextView, NSString) {
            let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)
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
            textView.anchorTape = AnchorTape.build(from: result.attributedString)
            return (textView, textView.string as NSString) // swiftlint:disable:this legacy_objc_type
        }

        @Test("Selecting a phrase enables commenting (the menu gate)")
        func phraseIsCommentable() {
            let (textView, rendered) = makeTextView(
                "the partials commute, so recipient last is an orchestration rule"
            )
            let range = rendered.range(of: "recipient last")
            #expect(range.location != NSNotFound)
            textView.setSelectedRange(range)

            // This is exactly what menu(for:) checks before adding "Add Comment…".
            #expect(textView.commentableSelection() != nil)
        }

        @Test("Empty selection is not commentable")
        func emptySelectionNotCommentable() {
            let (textView, _) = makeTextView("plain prose here")
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            #expect(textView.commentableSelection() == nil)
        }
    }
#endif
