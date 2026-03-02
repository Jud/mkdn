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

            return LayoutContext(
                origin: textView.textContainerOrigin,
                containerWidth: textContainerWidth(in: textView),
                textStorage: textStorage,
                contentManager: contentManager,
                layoutManager: layoutManager
            )
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
