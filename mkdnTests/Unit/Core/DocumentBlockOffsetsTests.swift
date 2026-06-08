#if os(macOS)
    import AppKit
    import Testing
    @testable import mkdnLib

    /// Validates `DocumentBlockOffsets` against the ground truth: real TextKit 2
    /// per-block positions. The estimated offset of each block must track the real
    /// top y that block lays out at.
    @Suite("DocumentBlockOffsets")
    struct DocumentBlockOffsetsTests {
        @MainActor private func mixedBlocks() -> [IndexedBlock] {
            let blocks: [MarkdownBlock] = [
                .heading(level: 1, text: AttributedString("Document Title")),
                .paragraph(text: AttributedString(
                    "A first paragraph long enough to wrap to a couple of lines at the "
                        + "narrow widths used in these tests.")),
                .codeBlock(language: "swift", code: "let a = 1\nlet b = 2\nlet c = a + b"),
                .paragraph(text: AttributedString(
                    "A second paragraph, also wrapping, to push the later blocks down.")),
                .thematicBreak,
                .image(source: "x.png", alt: "alt"),
                .paragraph(text: AttributedString("Closing line.")),
            ]
            return blocks.enumerated().map { IndexedBlock(index: $0.offset, block: $0.element) }
        }

        @MainActor private func layOut(_ attributed: NSAttributedString, viewWidth: CGFloat)
            -> (textView: CodeBlockBackgroundTextView, window: NSWindow, textWidth: CGFloat) {
            let textContainer = NSTextContainer()
            textContainer.size = NSSize(width: viewWidth - 64, height: .greatestFiniteMagnitude)
            let layoutManager = NSTextLayoutManager()
            layoutManager.textContainer = textContainer
            let contentStorage = NSTextContentStorage()
            contentStorage.addTextLayoutManager(layoutManager)
            let textView = CodeBlockBackgroundTextView(
                frame: NSRect(x: 0, y: 0, width: viewWidth, height: 400), textContainer: textContainer)
            textView.isVerticallyResizable = true
            textView.textContainerInset = NSSize(width: 32, height: 32)
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: 400))
            scrollView.documentView = textView
            let window = NSWindow(
                contentRect: scrollView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = scrollView
            textView.textStorage?.setAttributedString(attributed)
            window.layoutIfNeeded()
            layoutManager.ensureLayout(for: layoutManager.documentRange)
            let textWidth = textContainer.size.width - 2 * textContainer.lineFragmentPadding
            return (textView, window, textWidth)
        }

        @Test("Per-block offsets track real TextKit block positions", arguments: [400.0, 700.0])
        @MainActor func offsetsTrackRealPositions(viewWidth: CGFloat) throws {
            let result = MarkdownTextStorageBuilder.build(blocks: mixedBlocks(), theme: .solarizedDark)
            let (textView, window, textWidth) = layOut(result.attributedString, viewWidth: viewWidth)
            _ = window
            let offsets = DocumentBlockOffsets.compute(
                of: result.attributedString, model: result.documentHeightModel,
                textWidth: textWidth, verticalInset: 32)

            for (position, block) in result.documentHeightModel.blocks.enumerated() {
                let real = try #require(textView.boundingRect(forCharacterRange: block.range)?.minY)
                // Each offset is one cumulative-prefix measure, so it carries a single
                // trailing-newline seam (~one line) — a uniform shift, never accumulating
                // drift. One line of tolerance catches real drift at depth.
                #expect(abs(offsets.offsets[position] - real) < 20)
            }
        }

        @Test("blockIndex(atY:) maps a y back to the block that contains it")
        @MainActor func yMapsToBlock() {
            let result = MarkdownTextStorageBuilder.build(blocks: mixedBlocks(), theme: .solarizedDark)
            let offsets = DocumentBlockOffsets.compute(
                of: result.attributedString, model: result.documentHeightModel,
                textWidth: 600, verticalInset: 32)
            // A y just inside each block's span resolves to that block.
            for position in result.documentHeightModel.blocks.indices {
                let mid = (offsets.offsets[position] + offsets.offsets[position + 1]) / 2
                #expect(offsets.blockIndex(atY: mid) == result.documentHeightModel.blocks[position].index)
            }
            // Clamp: a y above the first block resolves to the first; past the end, the last.
            let blocks = result.documentHeightModel.blocks
            #expect(offsets.blockIndex(atY: -100) == blocks.first?.index)
            #expect(offsets.blockIndex(atY: offsets.totalHeight + 1000) == blocks.last?.index)
        }
    }
#endif
