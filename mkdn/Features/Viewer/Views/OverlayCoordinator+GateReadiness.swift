#if os(macOS)
    import AppKit

    /// Entrance gate readiness tracking for ``OverlayCoordinator``.
    extension OverlayCoordinator {
        /// Checks whether all Mermaid attachment overlays visible in the scroll
        /// view's viewport have reported their rendered size. Returns `true` when
        /// every viewport Mermaid overlay has called ``updateAttachmentHeight`` or
        /// ``updateAttachmentSize``, or when no Mermaid overlays fall within the
        /// visible rect.
        ///
        /// Non-Mermaid overlays (images, math, thematic breaks) are excluded from
        /// the check because they report size near-instantly and do not cause
        /// visible layout jumps.
        func viewportOverlaysReady(in scrollView: NSScrollView) -> Bool {
            let visibleRect = scrollView.contentView.bounds
            guard let context = makeLayoutContext() else { return true }

            for (blockIndex, entry) in entries {
                guard entry.attachment != nil else { continue }
                guard !reportedOverlays.contains(blockIndex) else { continue }
                guard case .mermaidBlock = entry.block else { continue }

                let frameToCheck = resolveEntryFrame(entry, context: context)
                guard let frame = frameToCheck else { continue }

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
