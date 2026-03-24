#if os(macOS)
    import AppKit
    import SwiftUI

    /// Manages overlay views (Mermaid, images, tables) positioned within an
    /// `NSTextView`. Attachment-based overlays are positioned via their
    /// `NSTextAttachment` placeholder. Table overlays use text-range-based
    /// positioning via `TableAttributes.range` in the text storage. Includes
    /// sticky header positioning for long tables.
    @MainActor
    final class OverlayCoordinator {
        // MARK: - Types

        struct OverlayEntry {
            let view: NSView
            let attachment: NSTextAttachment?
            let block: MarkdownBlock
            var preferredWidth: CGFloat?
            var tableRangeID: String?
            var highlightOverlay: TableHighlightOverlay?
            var cellMap: TableCellMap?
            var lastAppliedVisualHeight: CGFloat?

            init(
                view: NSView,
                block: MarkdownBlock,
                attachment: NSTextAttachment? = nil,
                preferredWidth: CGFloat? = nil,
                tableRangeID: String? = nil,
                highlightOverlay: TableHighlightOverlay? = nil,
                cellMap: TableCellMap? = nil,
                lastAppliedVisualHeight: CGFloat? = nil
            ) {
                self.view = view
                self.attachment = attachment
                self.block = block
                self.preferredWidth = preferredWidth
                self.tableRangeID = tableRangeID
                self.highlightOverlay = highlightOverlay
                self.cellMap = cellMap
                self.lastAppliedVisualHeight = lastAppliedVisualHeight
            }
        }

        struct LayoutContext {
            let origin: NSPoint
            let containerWidth: CGFloat
            let textStorage: NSTextStorage
            let contentManager: NSTextContentManager
            let layoutManager: NSTextLayoutManager
            let visibleRange: NSRange?
        }

        // MARK: - Properties

        weak var textView: NSTextView?
        var entries: [Int: OverlayEntry] = [:]
        nonisolated(unsafe) var layoutObserver: NSObjectProtocol?
        var appSettings: AppSettings?
        var stickyHeaders: [Int: NSView] = [:]
        nonisolated(unsafe) var scrollObserver: NSObjectProtocol?
        let containerState = OverlayContainerState()
        private var isRepositionScheduled = false
        var attachmentIndex: [ObjectIdentifier: NSRange] = [:]
        var tableRangeIndex: [String: NSRange] = [:]
        var onLayoutInvalidation: (() -> Void)?
        var onOverlayReady: (() -> Void)?
        var reportedOverlays: Set<Int> = []
        var pendingVisualHeights: [Int: CGFloat] = [:]
        /// Highest text offset through which layout has been reconciled via
        /// `reconcileLayoutThroughViewport`. Reset to 0 when paragraph heights
        /// change, avoiding redundant full-prefix enumeration on every scroll.
        private var reconciledThroughOffset = 0

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
                entry.highlightOverlay?.isHidden = true
            }
            for (_, header) in stickyHeaders {
                header.isHidden = true
            }
        }

        /// Recalculates all overlay positions from the current layout geometry.
        ///
        /// Before reading fragment positions, forces TextKit 2 to lay out all
        /// fragments from the document start through the visible area. This
        /// prevents stale cumulative y-offset estimates (from lazy layout) from
        /// cascading into wrong positions for table-dense regions.
        func repositionOverlays() {
            guard let context = makeLayoutContext(),
                  context.containerWidth > 0
            else { return }
            let widthChanged = abs(containerState.containerWidth - context.containerWidth) > 1
            containerState.containerWidth = context.containerWidth
            if widthChanged {
                invalidateReconciliation()
                for key in entries.keys {
                    entries[key]?.lastAppliedVisualHeight = nil
                }
                stickyHeaders.values.forEach { $0.removeFromSuperview() }
                stickyHeaders.removeAll()
            }
            let finalContext = widthChanged ? (makeLayoutContext() ?? context) : context
            reconcileLayoutThroughViewport(context: finalContext)
            for (_, entry) in entries
                where shouldPositionEntry(entry, context: finalContext)
            {
                positionEntry(entry, context: finalContext)
            }
        }

        /// Forces `.ensuresLayout` enumeration through the visible range so
        /// cumulative y-offsets are correct before `boundingRect` reads them.
        ///
        /// Uses a high-water mark (`reconciledThroughOffset`) to skip content
        /// that has already been reconciled since the last layout invalidation.
        /// On a typical scroll, only the newly-revealed delta is enumerated.
        private func reconcileLayoutThroughViewport(context: LayoutContext) {
            guard let visibleRange = context.visibleRange,
                  visibleRange.length > 0
            else { return }

            let targetEnd = NSMaxRange(visibleRange)
            guard targetEnd > reconciledThroughOffset else { return }

            let docStart = context.contentManager.documentRange.location
            let startOffset = max(reconciledThroughOffset, 0)

            guard let startLoc = context.contentManager.location(
                docStart, offsetBy: startOffset
            ),
                let endLoc = context.contentManager.location(
                    docStart, offsetBy: targetEnd
                )
            else { return }

            context.layoutManager.enumerateTextLayoutFragments(
                from: startLoc,
                options: [.ensuresLayout]
            ) { fragment in
                fragment.rangeInElement.location.compare(endLoc) == .orderedAscending
            }

            reconciledThroughOffset = targetEnd
        }

        /// Resets the layout reconciliation high-water mark, forcing the next
        /// `reconcileLayoutThroughViewport` call to re-enumerate from the
        /// document start. Call after any mutation that changes paragraph
        /// heights or attachment sizes.
        func invalidateReconciliation() {
            reconciledThroughOffset = 0
        }

        private func shouldPositionEntry(
            _ entry: OverlayEntry,
            context: LayoutContext
        ) -> Bool {
            guard let tableRangeID = entry.tableRangeID else { return true }
            guard let visibleRange = context.visibleRange,
                  let tableRange = findTableTextRange(for: tableRangeID)
            else { return true }
            return NSIntersectionRange(visibleRange, tableRange).length > 0
        }

        /// Removes all hosted overlay views and stops layout observation.
        func removeAllOverlays() {
            for (_, entry) in entries {
                entry.view.removeFromSuperview()
                entry.highlightOverlay?.removeFromSuperview()
            }
            entries.removeAll()
            reportedOverlays.removeAll()
            stickyHeaders.values.forEach { $0.removeFromSuperview() }
            stickyHeaders.removeAll()
            removeObservers()
        }

        /// Updates the placeholder height, triggering layout invalidation and repositioning.
        func updateAttachmentHeight(blockIndex: Int, newHeight: CGFloat) {
            guard let entry = entries[blockIndex],
                  let attachment = entry.attachment,
                  let textView,
                  let textStorage = textView.textStorage
            else { return }

            guard abs(attachment.bounds.height - newHeight) > 1 else { return }
            invalidateAttachmentHeight(
                attachment, newHeight: newHeight, textView: textView, textStorage: textStorage
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

            let heightChanged = abs(attachment.bounds.height - newHeight) > 1
            if heightChanged {
                invalidateAttachmentHeight(
                    attachment, newHeight: newHeight, textView: textView, textStorage: textStorage
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

        // MARK: - Attachment Height

        private func invalidateAttachmentHeight(
            _ attachment: NSTextAttachment,
            newHeight: CGFloat,
            textView: NSTextView,
            textStorage: NSTextStorage
        ) {
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

            invalidateReconciliation()
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
                let knownHeight = oldAttachment.bounds.height
                if knownHeight > 1, let textStorage = textView.textStorage {
                    invalidateAttachmentHeight(
                        info.attachment,
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
            entries[info.blockIndex]?.highlightOverlay?.removeFromSuperview()
            createAttachmentOverlay(
                for: info,
                appSettings: appSettings,
                documentState: documentState,
                in: textView
            )
        }

        private func removeStaleAttachmentOverlays(keeping validIndices: Set<Int>) {
            for (index, entry) in entries where !validIndices.contains(index) {
                guard entry.tableRangeID == nil else { continue }
                entry.view.removeFromSuperview()
                entries.removeValue(forKey: index)
                stickyHeaders[index]?.removeFromSuperview()
                stickyHeaders.removeValue(forKey: index)
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
                    appSettings: appSettings
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
