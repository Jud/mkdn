#if os(macOS)
    import AppKit
    import Testing
    @testable import mkdnLib

    /// Validates `DocumentHeightEstimator` against the ground truth: a real
    /// TextKit 2 full layout. The estimate must size the scroller close to the
    /// real laid-out height (biased slightly high) across widths, without
    /// laying the document out.
    @Suite("DocumentHeightEstimator")
    struct DocumentHeightEstimatorTests {
        /// A mixed document: heading (spacing-before), wrapping prose, a
        /// thematic break (attachment), a code block (mono + padding).
        @MainActor private func mixedBlocks() -> [IndexedBlock] {
            let blocks: [MarkdownBlock] = [
                .heading(level: 1, text: AttributedString("The Document Title Goes Here")),
                .paragraph(text: AttributedString(
                    "This is a reasonably long paragraph of prose that should wrap to "
                        + "several lines at narrow container widths and fewer lines as the "
                        + "container grows wider, exercising the wrapping estimate.")),
                .paragraph(text: AttributedString(
                    "A second paragraph, also long enough to wrap, so that inter-block "
                        + "paragraph spacing is exercised between two flowed blocks here.")),
                .thematicBreak,
                .codeBlock(
                    language: "swift",
                    code: "let answer = 42\nprint(answer)\nlet doubled = answer * 2\nreturn doubled"),
                .image(source: "diagram.png", alt: "A diagram"),
                .mathBlock(code: "E = mc^2"),
                .paragraph(text: AttributedString("A short closing line.")),
            ]
            return blocks.enumerated().map { IndexedBlock(index: $0.offset, block: $0.element) }
        }

        /// Lay the attributed string out for real at `viewWidth` and return the
        /// full view height plus the text width TextKit actually used.
        @MainActor private func realLayout(
            _ attributed: NSAttributedString, viewWidth: CGFloat
        ) -> (real: CGFloat, textWidth: CGFloat) {
            let textContainer = NSTextContainer()
            textContainer.size = NSSize(width: viewWidth - 64, height: .greatestFiniteMagnitude)
            let layoutManager = NSTextLayoutManager()
            layoutManager.textContainer = textContainer
            let contentStorage = NSTextContentStorage()
            contentStorage.addTextLayoutManager(layoutManager)

            let textView = CodeBlockBackgroundTextView(
                frame: NSRect(x: 0, y: 0, width: viewWidth, height: 400),
                textContainer: textContainer
            )
            textView.isVerticallyResizable = true
            textView.textContainerInset = NSSize(width: 32, height: 32)

            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: 400))
            scrollView.documentView = textView
            let window = NSWindow(
                contentRect: scrollView.frame, styleMask: [.borderless],
                backing: .buffered, defer: false
            )
            window.contentView = scrollView
            textView.textStorage?.setAttributedString(attributed)
            window.layoutIfNeeded()

            layoutManager.ensureLayout(for: layoutManager.documentRange)
            let real = ceil(layoutManager.usageBoundsForTextContainer.height) + 32 * 2
            let textWidth = textContainer.size.width - 2 * textContainer.lineFragmentPadding
            return (real, textWidth)
        }

        @Test("Estimate tracks real TextKit layout across widths", arguments: [360.0, 600.0, 900.0])
        @MainActor func estimateTracksRealLayout(viewWidth: CGFloat) {
            let result = MarkdownTextStorageBuilder.build(blocks: mixedBlocks(), theme: .solarizedDark)
            let (real, textWidth) = realLayout(result.attributedString, viewWidth: viewWidth)
            let estimate = DocumentHeightEstimator.estimatedHeight(
                of: result.attributedString,
                textWidth: textWidth,
                verticalInset: 32
            )
            // The whole-string measure matches real TextKit 2 layout to the
            // pixel; allow 1pt for rounding either way. Under-estimating would
            // make the scroller fall short, so a hair over is the safe side.
            #expect(estimate >= real - 1)
            #expect(estimate <= real + 1)
        }

        @Test("Estimate matches real layout for a document ending in an attachment",
              arguments: [360.0, 800.0])
        @MainActor func endsInAttachment(viewWidth: CGFloat) {
            let blocks: [MarkdownBlock] = [
                .paragraph(text: AttributedString("Lead-in prose before a trailing attachment.")),
                .image(source: "diagram.png", alt: "A diagram"),
            ]
            let indexed = blocks.enumerated().map { IndexedBlock(index: $0.offset, block: $0.element) }
            let result = MarkdownTextStorageBuilder.build(blocks: indexed, theme: .solarizedDark)
            let (real, textWidth) = realLayout(result.attributedString, viewWidth: viewWidth)
            let estimate = DocumentHeightEstimator.estimatedHeight(
                of: result.attributedString, textWidth: textWidth, verticalInset: 32)
            #expect(estimate >= real - 1)
            #expect(estimate <= real + 1)
        }

        @Test("Estimate matches real layout for a long unbroken code line",
              arguments: [360.0, 800.0])
        @MainActor func longUnbrokenCodeLine(viewWidth: CGFloat) {
            let token = String(repeating: "abcdefghij", count: 20) // 200 chars, no break points
            let blocks: [MarkdownBlock] = [
                .paragraph(text: AttributedString("Intro.")),
                .codeBlock(language: "swift", code: "let value = \"\(token)\""),
            ]
            let indexed = blocks.enumerated().map { IndexedBlock(index: $0.offset, block: $0.element) }
            let result = MarkdownTextStorageBuilder.build(blocks: indexed, theme: .solarizedDark)
            let (real, textWidth) = realLayout(result.attributedString, viewWidth: viewWidth)
            let estimate = DocumentHeightEstimator.estimatedHeight(
                of: result.attributedString, textWidth: textWidth, verticalInset: 32)
            // A long unbroken token (URL, minified code) is the one case where Core
            // Text's char-wrap diverges from TextKit 2: boundingRect rounds up by about
            // one extra mono line. That's the safe direction — the scroller is a hair
            // long, never short — so assert never-under with a bounded over-estimate.
            #expect(estimate >= real)
            #expect(estimate <= real + 30)
        }
    }
#endif
