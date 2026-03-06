#if os(macOS)
    import AppKit

    // MARK: - Overlay Positioning

    extension OverlayCoordinator {
        func makeLayoutContext() -> LayoutContext? {
            guard let textView,
                  let layoutManager = textView.textLayoutManager,
                  let textStorage = textView.textStorage,
                  let contentManager = layoutManager.textContentManager
            else { return nil }

            let visibleRange = computeVisibleRange(
                textView: textView,
                layoutManager: layoutManager,
                contentManager: contentManager,
                textStorage: textStorage
            )

            return LayoutContext(
                origin: textView.textContainerOrigin,
                containerWidth: textContainerWidth(in: textView),
                textStorage: textStorage,
                contentManager: contentManager,
                layoutManager: layoutManager,
                visibleRange: visibleRange
            )
        }

        /// Computes the text range visible in the scroll view, expanded by a
        /// margin so tables just outside the viewport are also positioned.
        ///
        /// Uses the viewport layout controller's already-known viewport range as
        /// a starting point rather than enumerating from the document start,
        /// then walks backward/forward to cover the margin.
        private func computeVisibleRange(
            textView: NSTextView,
            layoutManager: NSTextLayoutManager,
            contentManager: NSTextContentManager,
            textStorage: NSTextStorage
        ) -> NSRange? {
            guard let scrollView = textView.enclosingScrollView else { return nil }
            let visibleRect = scrollView.contentView.bounds
            let margin: CGFloat = 300
            let expandedRect = visibleRect.insetBy(dx: 0, dy: -margin)
            let docRange = contentManager.documentRange

            // Start from the viewport range (cheap) instead of the document start.
            let vpRange = layoutManager.textViewportLayoutController.viewportRange
            let enumerateFrom = vpRange?.location ?? docRange.location

            // Walk backward from the viewport start to find the expanded range start.
            var startOffset: Int?
            layoutManager.enumerateTextLayoutFragments(
                from: enumerateFrom,
                options: [.reverse]
            ) { fragment in
                let frame = fragment.layoutFragmentFrame
                if frame.maxY < expandedRect.minY {
                    startOffset = contentManager.offset(
                        from: docRange.location,
                        to: fragment.rangeInElement.endLocation
                    )
                    return false
                }
                startOffset = contentManager.offset(
                    from: docRange.location,
                    to: fragment.rangeInElement.location
                )
                return true
            }

            // Walk forward from the viewport start to find the expanded range end.
            var endOffset: Int?
            layoutManager.enumerateTextLayoutFragments(
                from: enumerateFrom,
                options: [.ensuresLayout, .ensuresExtraLineFragment]
            ) { fragment in
                let frame = fragment.layoutFragmentFrame
                if frame.minY > expandedRect.maxY {
                    endOffset = contentManager.offset(
                        from: docRange.location,
                        to: fragment.rangeInElement.location
                    )
                    return false
                }
                endOffset = contentManager.offset(
                    from: docRange.location,
                    to: fragment.rangeInElement.endLocation
                )
                return true
            }

            let start = startOffset ?? 0
            let end = endOffset ?? textStorage.length
            return NSRange(location: start, length: max(0, end - start))
        }

        func positionEntry(
            _ entry: OverlayEntry,
            context: LayoutContext
        ) {
            if entry.tableRangeID != nil {
                positionTextRangeEntry(entry, context: context)
            } else if entry.attachment != nil {
                positionAttachmentEntry(entry, context: context)
            } else {
                entry.view.isHidden = true
            }
        }

        private func positionAttachmentEntry(
            _ entry: OverlayEntry,
            context: LayoutContext
        ) {
            guard let attachment = entry.attachment,
                  let range = attachmentRange(for: attachment)
            else {
                entry.view.isHidden = true
                return
            }

            guard let docLocation = context.contentManager.location(
                context.contentManager.documentRange.location,
                offsetBy: range.location
            )
            else {
                entry.view.isHidden = true
                return
            }

            var fragmentFrame: CGRect?
            context.layoutManager.enumerateTextLayoutFragments(
                from: docLocation,
                options: [.ensuresLayout]
            ) { fragment in
                fragmentFrame = fragment.layoutFragmentFrame
                return false
            }

            guard let frame = fragmentFrame, frame.height > 1 else {
                entry.view.isHidden = true
                return
            }

            let overlayWidth = entry.preferredWidth ?? context.containerWidth
            entry.view.frame = CGRect(
                x: context.origin.x,
                y: frame.origin.y + context.origin.y,
                width: overlayWidth,
                height: frame.height
            )
            entry.view.isHidden = false
        }

        // MARK: - Layout Helpers

        func attachmentRange(
            for attachment: NSTextAttachment
        ) -> NSRange? {
            attachmentIndex[ObjectIdentifier(attachment)]
        }

        func textContainerWidth(in textView: NSTextView) -> CGFloat {
            if let container = textView.textContainer {
                return container.size.width
            }
            let inset = textView.textContainerInset
            return textView.bounds.width - inset.width * 2
        }
    }
#endif
