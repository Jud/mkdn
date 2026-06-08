#if os(macOS)
    import AppKit
    import Foundation
    import SwiftUI
    import Testing
    @testable import mkdnLib

    @MainActor
    @Suite("Comment popover wiring")
    struct CommentPopoverWiringTests {
        private func makeView(_ markdown: String) -> CodeBlockBackgroundTextView {
            let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)
            let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: .solarizedDark)

            let view = CodeBlockBackgroundTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            view.textContainerInset = NSSize(width: 16, height: 16)
            view.commentTheme = .solarizedDark
            view.textStorage?.setAttributedString(result.attributedString)
            view.anchorTape = AnchorTape.build(from: result.attributedString)
            view.layoutManager?.ensureLayout(for: view.textContainer!)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                styleMask: [.borderless], backing: .buffered, defer: false
            )
            window.contentView?.addSubview(view)
            return view
        }

        @Test("Presents an overlay for a resolved comment hit")
        func presentsForKnownComment() {
            let view = makeView("foo bar baz")
            let range = (view.string as NSString).range(of: "bar")
            let entry = CommentSidecar.Entry(id: "c1", body: "note")
            view.showComments([(entry: entry, range: range)])
            #expect(view.commentOverlay is NSHostingView<CommentPopoverView>)
            view.dismissCommentOverlay() // avoid an open overlay/monitor at teardown
        }

        @Test("commentableSelection accepts a non-empty prose selection")
        func resolvesSelection() {
            let view = makeView("The quick brown fox")
            view.setSelectedRange((view.string as NSString).range(of: "quick"))
            #expect(view.commentableSelection() != nil)
        }

        @Test("commentableSelection is nil for an empty selection")
        func emptySelectionNoRange() {
            let view = makeView("The quick brown fox")
            view.setSelectedRange(NSRange(location: 2, length: 0))
            #expect(view.commentableSelection() == nil)
        }

        @Test("addCommentToSelection presents the input overlay for a valid selection")
        func presentsAddPopover() {
            let view = makeView("The quick brown fox")
            let state = DocumentState() // documentState is weak; hold it strongly
            view.documentState = state
            view.setSelectedRange((view.string as NSString).range(of: "quick"))
            withExtendedLifetime(state) {
                view.addCommentToSelection(nil)
                #expect(view.commentOverlay is NSHostingView<CommentInputView>)
                view.dismissCommentOverlay() // avoid an open overlay/monitor at teardown
            }
        }

        @Test("Does nothing when there are no comment hits")
        func ignoresNoHits() {
            let view = makeView("foo bar baz")
            view.showComments([])
            #expect(view.commentOverlay == nil)
        }
    }
#endif
