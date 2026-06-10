#if os(macOS)
    import AppKit
    import SwiftUI

    /// Manages overlay views (Mermaid, images, tables, math, thematic breaks)
    /// positioned within an `NSTextView`. All overlays use attachment-based
    /// positioning via their `NSTextAttachment` placeholder in the text storage.
    @MainActor
    final class OverlayCoordinator {
        // MARK: - Types

        struct OverlayEntry {
            let view: NSView
            let attachment: NSTextAttachment?
            let block: MarkdownBlock
            var preferredWidth: CGFloat?

            init(
                view: NSView,
                block: MarkdownBlock,
                attachment: NSTextAttachment? = nil,
                preferredWidth: CGFloat? = nil
            ) {
                self.view = view
                self.attachment = attachment
                self.block = block
                self.preferredWidth = preferredWidth
            }
        }

        struct LayoutContext {
            let origin: NSPoint
            let containerWidth: CGFloat
            let textStorage: NSTextStorage
            let contentManager: NSTextContentManager
            let layoutManager: NSTextLayoutManager
        }

        // MARK: - Properties

        weak var textView: NSTextView?
        var entries: [Int: OverlayEntry] = [:]
        nonisolated(unsafe) var layoutObserver: NSObjectProtocol?
        var appSettings: AppSettings?
        weak var findState: FindState?
        nonisolated(unsafe) var scrollObserver: NSObjectProtocol?
        let containerState = OverlayContainerState()
        private var isRepositionScheduled = false
        var attachmentIndex: [ObjectIdentifier: NSRange] = [:]
        var onLayoutInvalidation: (() -> Void)?
        var onOverlayReady: (() -> Void)?
        var onFrameChange: (() -> Void)?
        var onScrollChange: (() -> Void)?
        var reportedOverlays: Set<Int> = []
        private(set) var isInLiveResize = false
        private var deferredAttachmentHeights: [Int: CGFloat] = [:]

        deinit {
            if let layoutObserver {
                NotificationCenter.default.removeObserver(layoutObserver)
            }
            if let scrollObserver {
                NotificationCenter.default.removeObserver(scrollObserver)
            }
        }

        // MARK: - Attachment-Based Overlay API

        /// Creates, updates, or removes overlay views for non-text blocks
        /// (Mermaid, images, thematic breaks) that use `NSTextAttachment`
        /// placeholders.
        func updateOverlays(
            attachments: [AttachmentInfo],
            appSettings: AppSettings,
            documentState: DocumentState,
            in textView: NSTextView
        ) {
            self.textView = textView
            self.appSettings = appSettings
            reportedOverlays.removeAll()

            if let textStorage = textView.textStorage {
                buildPositionIndex(from: textStorage)
            }

            let validIndices = Set(attachments.map(\.blockIndex))
            removeStaleAttachmentOverlays(keeping: validIndices)

            for info in attachments {
                guard needsOverlay(info.block) else { continue }
                updateOrCreateOverlay(
                    for: info,
                    appSettings: appSettings,
                    documentState: documentState,
                    in: textView
                )
            }

            observeLayoutChanges(on: textView)
            observeScrollChanges(on: textView)
            scheduleReposition()
        }

        // MARK: - Common API

        /// Hides all overlay views to prevent flash during content replacement.
        func hideAllOverlays() {
            for (_, entry) in entries {
                entry.view.isHidden = true
            }
        }

        /// Recalculates all overlay positions from the current layout geometry.
        func repositionOverlays() {
            guard let context = makeLayoutContext(),
                  context.containerWidth > 0
            else { return }
            if abs(containerState.containerWidth - context.containerWidth) > 1 {
                containerState.containerWidth = context.containerWidth
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for (_, entry) in entries {
                positionEntry(entry, context: context)
            }
            CATransaction.commit()
        }

        /// Removes all hosted overlay views and stops layout observation.
        func removeAllOverlays() {
            for (_, entry) in entries {
                entry.view.removeFromSuperview()
            }
            entries.removeAll()
            reportedOverlays.removeAll()
            removeObservers()
        }

        /// Updates the placeholder height, triggering layout invalidation and repositioning.
        func updateAttachmentHeight(blockIndex: Int, newHeight: CGFloat) {
            guard let entry = entries[blockIndex],
                  let attachment = entry.attachment,
                  let textView,
                  let textStorage = textView.textStorage
            else { return }

            guard abs(effectiveHeight(for: blockIndex, attachment: attachment) - newHeight) > 1
            else { return }
            invalidateAttachmentHeight(
                attachment,
                blockIndex: blockIndex,
                newHeight: newHeight,
                textView: textView,
                textStorage: textStorage
            )
            reportedOverlays.insert(blockIndex)
            onOverlayReady?()
            scheduleReposition()
        }

        /// Updates both the preferred width and placeholder height for an attachment overlay.
        func updateAttachmentSize(
            blockIndex: Int,
            newWidth: CGFloat?,
            newHeight: CGFloat
        ) {
            guard var entry = entries[blockIndex],
                  let attachment = entry.attachment,
                  let textView,
                  let textStorage = textView.textStorage
            else { return }

            var widthChanged = false
            if let newWidth, entry.preferredWidth != newWidth {
                entry.preferredWidth = newWidth
                entries[blockIndex] = entry
                widthChanged = true
            }

            let heightChanged =
                abs(effectiveHeight(for: blockIndex, attachment: attachment) - newHeight) > 1
            if heightChanged {
                invalidateAttachmentHeight(
                    attachment,
                    blockIndex: blockIndex,
                    newHeight: newHeight,
                    textView: textView,
                    textStorage: textStorage
                )
            }

            if widthChanged || heightChanged {
                reportedOverlays.insert(blockIndex)
                onOverlayReady?()
                scheduleReposition()
            }
        }

        /// Schedules overlay repositioning for the next run-loop iteration so TextKit 2
        /// has time to process layout invalidation before we read fragment frames.
        /// Multiple calls within the same run-loop cycle are coalesced into a single pass.
        func scheduleReposition() {
            guard !isRepositionScheduled else { return }
            isRepositionScheduled = true
            DispatchQueue.main.async { [weak self] in
                self?.isRepositionScheduled = false
                self?.repositionOverlays()
            }
        }

        /// Returns true if any of `ranges` overlaps an attachment placeholder.
        /// Body-text-only edits cannot move attachments, so callers can skip
        /// repositioning when this returns false.
        func hasAttachments(intersecting ranges: [NSRange]) -> Bool {
            guard !ranges.isEmpty, !attachmentIndex.isEmpty else { return false }
            for range in ranges {
                for attachmentRange in attachmentIndex.values
                    where NSIntersectionRange(range, attachmentRange).length > 0
                {
                    return true
                }
            }
            return false
        }

        // MARK: - Attachment Height

        func enterLiveResize() {
            isInLiveResize = true
        }

        /// Idempotent counterpart to `enterLiveResize`. Always paired with a
        /// drain so callers can't forget — the queue and the flag move
        /// together.
        func exitLiveResize() {
            guard isInLiveResize else { return }
            isInLiveResize = false
            applyDeferredAttachmentHeights()
        }

        /// Returns the height that callers should compare against when
        /// deciding whether a new height is meaningfully different. During
        /// live resize, `attachment.bounds.height` stays at the pre-resize
        /// value; the queued height represents the most recent intent.
        private func effectiveHeight(
            for blockIndex: Int,
            attachment: NSTextAttachment
        ) -> CGFloat {
            deferredAttachmentHeights[blockIndex] ?? attachment.bounds.height
        }

        /// Drains heights queued during live resize. All bounds updates and
        /// edited() calls happen inside a single beginEditing/endEditing
        /// block, with one invalidateLayout pass over the union range so a
        /// document with many overlays doesn't trigger N layout passes on
        /// mouse-up.
        private func applyDeferredAttachmentHeights() {
            guard let textView, let textStorage = textView.textStorage else {
                deferredAttachmentHeights.removeAll()
                return
            }
            guard !deferredAttachmentHeights.isEmpty else { return }
            let pending = deferredAttachmentHeights
            deferredAttachmentHeights.removeAll()

            let containerWidth = textContainerWidth(in: textView)
            var earliestLocation = Int.max

            textStorage.beginEditing()
            for (blockIndex, height) in pending {
                guard let attachment = entries[blockIndex]?.attachment else { continue }
                attachment.bounds = CGRect(
                    x: 0, y: 0, width: containerWidth, height: height
                )
                if let attachRange = attachmentRange(for: attachment) {
                    textStorage.edited(
                        .editedAttributes, range: attachRange, changeInLength: 0
                    )
                    earliestLocation = min(earliestLocation, attachRange.location)
                }
            }
            textStorage.endEditing()

            guard earliestLocation != Int.max,
                  let layoutManager = textView.textLayoutManager,
                  let contentManager = layoutManager.textContentManager,
                  let startLoc = contentManager.location(
                      contentManager.documentRange.location,
                      offsetBy: earliestLocation
                  ),
                  let tailRange = NSTextRange(
                      location: startLoc,
                      end: contentManager.documentRange.endLocation
                  )
            else { return }

            layoutManager.invalidateLayout(for: tailRange)
            layoutManager.textViewportLayoutController.layoutViewport()
            onLayoutInvalidation?()
            // Apply the new layout to overlay frames so callers (notably the
            // tile() backstop, which doesn't reposition itself) end with
            // overlays sitting on the drained fragments rather than the
            // pre-drain positions.
            repositionOverlays()
        }

        private func invalidateAttachmentHeight(
            _ attachment: NSTextAttachment,
            blockIndex: Int,
            newHeight: CGFloat,
            textView: NSTextView,
            textStorage: NSTextStorage
        ) {
            if isInLiveResize {
                deferredAttachmentHeights[blockIndex] = newHeight
                return
            }
            let containerWidth = textContainerWidth(in: textView)
            attachment.bounds = CGRect(x: 0, y: 0, width: containerWidth, height: newHeight)

            let attachRange = attachmentRange(for: attachment)
            if let attachRange {
                textStorage.beginEditing()
                textStorage.edited(.editedAttributes, range: attachRange, changeInLength: 0)
                textStorage.endEditing()
                buildPositionIndex(from: textStorage)
            }

            if let attachRange,
               let layoutManager = textView.textLayoutManager,
               let contentManager = layoutManager.textContentManager,
               let startLoc = contentManager.location(
                   contentManager.documentRange.location,
                   offsetBy: attachRange.location
               )
            {
                let tailRange = NSTextRange(
                    location: startLoc,
                    end: contentManager.documentRange.endLocation
                )
                if let tailRange {
                    layoutManager.invalidateLayout(for: tailRange)
                    layoutManager.textViewportLayoutController.layoutViewport()
                }
            }

            onLayoutInvalidation?()
        }

        // MARK: - Attachment Overlay Lifecycle

        private func needsOverlay(_ block: MarkdownBlock) -> Bool {
            switch block {
            case .mermaidBlock, .image, .thematicBreak, .mathBlock, .table:
                true
            default:
                false
            }
        }

        private func updateOrCreateOverlay(
            for info: AttachmentInfo,
            appSettings: AppSettings,
            documentState: DocumentState,
            in textView: NSTextView
        ) {
            if let existing = entries[info.blockIndex],
               let oldAttachment = existing.attachment,
               blocksMatch(existing.block, info.block)
            {
                // Carry over the known height from the old attachment to the new one.
                // Text storage rebuilds create fresh attachments with the default
                // placeholder height; the SwiftUI view won't re-fire onSizeChange
                // because the image is already loaded. Use invalidateAttachmentHeight
                // so entrance animation cover layers get rebuilt for the new layout.
                // Same instance means nothing to carry over: a progressive open's
                // finish re-registers the prefix attachments it already installed,
                // and re-invalidating each would discard the tail's layout and
                // re-trigger the height/offsets passes per attachment.
                let knownHeight = oldAttachment.bounds.height
                if oldAttachment !== info.attachment, knownHeight > 1,
                   let textStorage = textView.textStorage {
                    invalidateAttachmentHeight(
                        info.attachment,
                        blockIndex: info.blockIndex,
                        newHeight: knownHeight,
                        textView: textView,
                        textStorage: textStorage
                    )
                }

                entries[info.blockIndex] = OverlayEntry(
                    view: existing.view,
                    block: info.block,
                    attachment: info.attachment,
                    preferredWidth: existing.preferredWidth
                )
                return
            }

            entries[info.blockIndex]?.view.removeFromSuperview()
            createAttachmentOverlay(
                for: info,
                appSettings: appSettings,
                documentState: documentState,
                in: textView
            )
        }

        private func removeStaleAttachmentOverlays(keeping validIndices: Set<Int>) {
            for (index, entry) in entries where !validIndices.contains(index) {
                entry.view.removeFromSuperview()
                entries.removeValue(forKey: index)
            }
        }

        private func createAttachmentOverlay(
            for info: AttachmentInfo,
            appSettings: AppSettings,
            documentState: DocumentState,
            in textView: NSTextView
        ) {
            let overlayView: NSView

            switch info.block {
            case let .mermaidBlock(code):
                overlayView = makeMermaidOverlay(
                    code: code, blockIndex: info.blockIndex, appSettings: appSettings
                )
            case let .image(source, alt):
                overlayView = makeImageOverlay(
                    source: source,
                    alt: alt,
                    blockIndex: info.blockIndex,
                    appSettings: appSettings,
                    documentState: documentState
                )
            case .thematicBreak:
                overlayView = makeThematicBreakOverlay(appSettings: appSettings)
            case let .mathBlock(code):
                overlayView = makeMathBlockOverlay(
                    code: code, blockIndex: info.blockIndex, appSettings: appSettings
                )
            case let .table(columns, rows):
                overlayView = makeTableAttachmentOverlay(
                    columns: columns,
                    rows: rows,
                    blockIndex: info.blockIndex,
                    appSettings: appSettings,
                    findState: findState
                )
            default:
                return
            }

            overlayView.isHidden = true
            textView.addSubview(overlayView)
            entries[info.blockIndex] = OverlayEntry(
                view: overlayView, block: info.block, attachment: info.attachment
            )
        }
    }

#endif
