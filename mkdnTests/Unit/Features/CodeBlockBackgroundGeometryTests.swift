#if os(macOS)
    import AppKit
    import Testing
    @testable import mkdnLib

    /// The code-block rect cache is viewport-scoped: blocks outside the
    /// viewport carry no cached rect (computing one would force the document
    /// tail to lay out on every draw), and a block scrolled into view must get
    /// final geometry — matching a full real layout — because the contiguous
    /// container has everything through the viewport laid out by then. Guards
    /// both the original first-paint bug (a below-fold block cached at
    /// TextKit 2's *estimated* Y) and the per-draw O(document) layout the
    /// all-blocks cache used to force.
    @Suite("CodeBlockBackgroundGeometry")
    struct CodeBlockBackgroundGeometryTests {
        /// Tall lead-in content followed by a code block, so the block lands far
        /// below the test window's viewport and starts out estimated.
        @MainActor private func belowFoldBlocks() -> [IndexedBlock] {
            var blocks: [MarkdownBlock] = (0 ..< 60).map { i in
                .paragraph(text: AttributedString("Filler paragraph number \(i) with enough text to occupy a line."))
            }
            blocks.append(.codeBlock(
                language: "swift",
                code: "let answer = 42\nprint(answer)\nlet doubled = answer * 2"
            ))
            return blocks.enumerated().map { IndexedBlock(index: $0.offset, block: $0.element) }
        }

        /// Mirrors the production container: non-simple, so TextKit 2 lays out
        /// contiguously from the top — the property the viewport-scoped rect
        /// cache relies on for final frames at and above the viewport.
        private final class ContiguousContainer: NSTextContainer {
            override var isSimpleRectangularTextContainer: Bool { false }
        }

        @MainActor private func makeTextView(
            _ attributed: NSAttributedString
        ) -> (CodeBlockBackgroundTextView, NSScrollView, NSWindow) {
            let textContainer = ContiguousContainer(
                size: NSSize(width: 536, height: CGFloat.greatestFiniteMagnitude)
            )
            textContainer.widthTracksTextView = false
            textContainer.heightTracksTextView = false
            let layoutManager = NSTextLayoutManager()
            layoutManager.textContainer = textContainer
            let contentStorage = NSTextContentStorage()
            contentStorage.addTextLayoutManager(layoutManager)

            let textView = CodeBlockBackgroundTextView(
                frame: NSRect(x: 0, y: 0, width: 600, height: 400),
                textContainer: textContainer
            )
            textView.isVerticallyResizable = true
            textView.textContainerInset = NSSize(width: 32, height: 32)

            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            scrollView.documentView = textView
            let window = NSWindow(
                contentRect: scrollView.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = scrollView
            textView.textStorage?.setAttributedString(attributed)
            // Production sizes the frame from the height floor so the document
            // is scrollable before the tail of it has laid out; mirror that.
            textView.estimatedHeightFloor = 4000
            textView.setFrameSize(NSSize(width: 600, height: 4000))
            window.layoutIfNeeded()
            return (textView, scrollView, window)
        }

        @Test("Below-fold code block is uncached cold, final once scrolled into view")
        @MainActor func belowFoldBlockGeometryFinalOnceVisible() throws {
            let result = MarkdownTextStorageBuilder.build(blocks: belowFoldBlocks(), theme: .solarizedDark)

            // Cold: the first refresh after the window lays out, before any
            // scroll. The only code block sits far below the fold, so the
            // viewport-scoped cache holds nothing for it.
            let (textView, scrollView, _) = makeTextView(result.attributedString)
            let layoutManager = try #require(textView.textLayoutManager)
            layoutManager.textViewportLayoutController.layoutViewport()
            textView.refreshCachedBlockRects()
            #expect(textView.cachedBlockRects.isEmpty)

            // Scroll to the bottom the way a user does — stepwise, the viewport
            // pass laying out newly exposed content as the lazy document view
            // grows — until the scroll stops moving.
            let clipView = scrollView.contentView
            for _ in 0 ..< 100 {
                let before = clipView.bounds.origin.y
                clipView.setBoundsOrigin(NSPoint(x: 0, y: before + 400))
                scrollView.reflectScrolledClipView(clipView)
                layoutManager.textViewportLayoutController.layoutViewport()
                if clipView.bounds.origin.y == before { break }
            }
            textView.refreshCachedBlockRects()
            let visible = try #require(textView.cachedBlockRects.last?.rect)

            // Reference: force full real layout, then recompute at the same scroll.
            layoutManager.ensureLayout(for: layoutManager.documentRange)
            textView.invalidateCodeBlockCache()
            textView.refreshCachedBlockRects()
            let reference = try #require(textView.cachedBlockRects.last?.rect)

            #expect(abs(visible.minY - reference.minY) < 0.5)
            #expect(abs(visible.height - reference.height) < 0.5)
        }
    }
#endif
