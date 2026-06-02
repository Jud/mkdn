#if os(macOS)
    import AppKit
    import Foundation
    import SwiftUI
    import Testing
    @testable import mkdnLib

    @MainActor
    @Suite("Comment popover wiring")
    struct CommentPopoverWiringTests {
        private func makeView(_ raw: String) -> (CodeBlockBackgroundTextView, CriticMarkupDocument) {
            let document = CriticMarkup.preprocess(raw)
            let blocks = MarkdownRenderer.render(text: document.transformedSource, theme: .solarizedDark)
            let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: .solarizedDark)
            let mutable = NSMutableAttributedString(attributedString: result.attributedString)
            MarkdownTextStorageBuilder.applyCommentHighlights(
                to: mutable, document: document, sourceMap: result.sourceMap, color: .yellow
            )

            let view = CodeBlockBackgroundTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            view.textContainerInset = NSSize(width: 16, height: 16)
            view.commentsByID = document.commentsByID
            view.commentTheme = .solarizedDark
            view.textStorage?.setAttributedString(mutable)
            view.layoutManager?.ensureLayout(for: view.textContainer!)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                styleMask: [.borderless], backing: .buffered, defer: false
            )
            window.contentView?.addSubview(view)
            return (view, document)
        }

        @Test("Presents a popover for a known comment id")
        func presentsForKnownComment() {
            let (view, _) = makeView("foo {==bar==}{>>note<<} baz")
            let range = (view.string as NSString).range(of: "bar")
            view.showCommentPopover(id: "c1", range: range)
            #expect(view.commentPopover != nil)
            #expect(view.commentPopover?.contentViewController is NSHostingController<CommentPopoverView>)
        }

        @Test("Does nothing for an unknown comment id")
        func ignoresUnknownComment() {
            let (view, _) = makeView("foo {==bar==}{>>note<<} baz")
            let range = (view.string as NSString).range(of: "bar")
            view.showCommentPopover(id: "does-not-exist", range: range)
            #expect(view.commentPopover == nil)
        }
    }
#endif
