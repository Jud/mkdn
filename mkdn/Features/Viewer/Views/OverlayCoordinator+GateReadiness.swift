#if os(macOS)
    import AppKit

    /// Entrance gate readiness tracking for ``OverlayCoordinator``.
    extension OverlayCoordinator {
        /// Checks whether all async attachment overlays (Mermaid diagrams and
        /// images) visible in the scroll view's viewport have reported their
        /// rendered size. Returns `true` when every such viewport overlay has
        /// called ``updateAttachmentHeight`` or ``updateAttachmentSize``, or when
        /// no async overlays fall within the visible rect.
        ///
        /// Synchronous overlays (math, thematic breaks) are excluded from the
        /// check because they report size near-instantly.
        func viewportOverlaysReady(in scrollView: NSScrollView) -> Bool {
            let visibleRect = scrollView.contentView.bounds
            guard let context = makeLayoutContext() else { return true }

            for (blockIndex, entry) in entries {
                guard entry.attachment != nil else { continue }
                guard !reportedOverlays.contains(blockIndex) else { continue }
                guard entry.block.isAsync else { continue }

                let frameToCheck = resolveEntryFrame(entry, context: context)

                // If we can't resolve the frame, the overlay hasn't been
                // positioned yet — conservatively assume it's in the viewport.
                guard let frame = frameToCheck else { return false }

                if frame.intersects(visibleRect) {
                    return false
                }
            }
            return true
        }

        /// Resolves the positioned frame for an overlay entry, using the cached
        /// view frame if available or computing it from the text layout.
        private func resolveEntryFrame(
            _ entry: OverlayEntry,
            context: LayoutContext
        ) -> CGRect? {
            let entryFrame = entry.view.frame
            if entryFrame.width > 0, entryFrame.height > 0 {
                return entryFrame
            }

            guard let attachment = entry.attachment,
                  let range = attachmentIndex[ObjectIdentifier(attachment)]
            else { return nil }

            guard let docLocation = context.contentManager.location(
                context.contentManager.documentRange.location,
                offsetBy: range.location
            )
            else { return nil }

            var fragmentFrame: CGRect?
            context.layoutManager.enumerateTextLayoutFragments(
                from: docLocation,
                options: [.ensuresLayout]
            ) { fragment in
                fragmentFrame = fragment.layoutFragmentFrame
                return false
            }

            guard let frame = fragmentFrame else { return nil }
            return CGRect(
                x: context.origin.x,
                y: frame.origin.y + context.origin.y,
                width: context.containerWidth,
                height: max(frame.height, 1)
            )
        }
    }
#endif
