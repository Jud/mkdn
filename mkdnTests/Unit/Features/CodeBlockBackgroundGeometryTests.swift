#if os(macOS)
    import AppKit
    import Testing
    @testable import mkdnLib

    /// Regression test for the first-paint code-block background bug: a code
    /// block sitting below the initial viewport was cached at TextKit 2's
    /// *estimated* (wrong) Y because `.ensuresLayout` during fragment
    /// enumeration only realizes the visible viewport. `refreshCachedBlockRects`
    /// must force real layout so a below-fold block's cached rect matches the
    /// geometry it has once fully laid out.
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

        @MainActor private func makeTextView(
            _ attributed: NSAttributedString
        ) -> (CodeBlockBackgroundTextView, NSWindow) {
            let textContainer = NSTextContainer()
            textContainer.widthTracksTextView = true
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
            window.layoutIfNeeded()
            return (textView, window)
        }

        @Test("Below-fold code block cached geometry matches fully laid-out reference")
        @MainActor func belowFoldBlockGeometryIsFinalOnFirstPaint() throws {
            let result = MarkdownTextStorageBuilder.build(blocks: belowFoldBlocks(), theme: .solarizedDark)

            // Cold: the first refresh after the window lays out, before any scroll.
            let (textView, _) = makeTextView(result.attributedString)
            textView.refreshCachedBlockRects()
            let cold = try #require(textView.cachedBlockRects.last?.rect)

            // Reference: force full real layout, then recompute.
            let layoutManager = try #require(textView.textLayoutManager)
            layoutManager.ensureLayout(for: layoutManager.documentRange)
            textView.invalidateCodeBlockCache()
            textView.refreshCachedBlockRects()
            let reference = try #require(textView.cachedBlockRects.last?.rect)

            #expect(abs(cold.minY - reference.minY) < 0.5)
            #expect(abs(cold.height - reference.height) < 0.5)
        }
    }
#endif
