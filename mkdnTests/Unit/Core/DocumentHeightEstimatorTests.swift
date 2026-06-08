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
            let (textView, window, textWidth) =
                LayoutMeasurementHarness.layOut(attributed, viewWidth: viewWidth)
            _ = window
            let usage = textView.textLayoutManager?.usageBoundsForTextContainer ?? .zero
            return (ceil(usage.height) + 32 * 2, textWidth)
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

        @Test("Estimate tracks an attachment whose bounds change after build")
        @MainActor func tracksAttachmentBoundsChange() throws {
            let blocks: [MarkdownBlock] = [
                .paragraph(text: AttributedString("Before the image.")),
                .image(source: "x.png", alt: "alt"),
                .paragraph(text: AttributedString("After the image.")),
            ]
            let indexed = blocks.enumerated().map { IndexedBlock(index: $0.offset, block: $0.element) }
            let result = MarkdownTextStorageBuilder.build(blocks: indexed, theme: .solarizedDark)
            let textWidth: CGFloat = 526
            let attachment = try #require(result.attachments.first { $0.blockIndex == 1 }?.attachment)
            let placeholder = attachment.bounds.height
            let before = DocumentHeightEstimator.estimatedHeight(
                of: result.attributedString, textWidth: textWidth, verticalInset: 32)
            // Simulate the image overlay resolving to a real height above the placeholder;
            // re-measuring must grow the estimate by that delta (what the debounced
            // refresh relies on).
            attachment.bounds = CGRect(
                x: 0, y: 0, width: attachment.bounds.width, height: placeholder + 200)
            let after = DocumentHeightEstimator.estimatedHeight(
                of: result.attributedString, textWidth: textWidth, verticalInset: 32)
            #expect(after > before)
            #expect(abs((after - before) - 200) < 2)
            // And below the placeholder: resolving smaller shrinks the estimate, which is
            // what lets refreshEstimatedHeight size the frame back down.
            attachment.bounds = CGRect(x: 0, y: 0, width: attachment.bounds.width, height: 40)
            let shrunk = DocumentHeightEstimator.estimatedHeight(
                of: result.attributedString, textWidth: textWidth, verticalInset: 32)
            #expect(shrunk < before)
        }

        @Test("A non-positive text width estimates to zero")
        @MainActor func nonPositiveWidthIsZero() {
            let result = MarkdownTextStorageBuilder.build(
                blocks: [IndexedBlock(index: 0, block: .paragraph(text: AttributedString("Content.")))],
                theme: .solarizedDark)
            #expect(DocumentHeightEstimator.estimatedHeight(
                of: result.attributedString, textWidth: 0, verticalInset: 32) == 0)
            #expect(DocumentHeightEstimator.estimatedHeight(
                of: result.attributedString, textWidth: -5, verticalInset: 32) == 0)
        }
    }
#endif
