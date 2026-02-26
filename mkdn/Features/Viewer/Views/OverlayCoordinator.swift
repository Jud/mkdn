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

        init(
            view: NSView,
            block: MarkdownBlock,
            attachment: NSTextAttachment? = nil,
            preferredWidth: CGFloat? = nil,
            tableRangeID: String? = nil,
            highlightOverlay: TableHighlightOverlay? = nil,
            cellMap: TableCellMap? = nil
        ) {
            self.view = view
            self.attachment = attachment
            self.block = block
            self.preferredWidth = preferredWidth
            self.tableRangeID = tableRangeID
            self.highlightOverlay = highlightOverlay
            self.cellMap = cellMap
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
    var stickyHeaders: [Int: NSView] = [:]
    nonisolated(unsafe) var scrollObserver: NSObjectProtocol?
    let containerState = OverlayContainerState()
    private var isRepositionScheduled = false
    var attachmentIndex: [ObjectIdentifier: NSRange] = [:]
    var tableRangeIndex: [String: NSRange] = [:]

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
        repositionOverlays()
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
    /// Layout is resolved per-fragment via `textLayoutFragment(for:)` and
    /// `.ensuresLayout` enumeration options rather than an upfront full-document pass.
    func repositionOverlays() {
        guard let context = makeLayoutContext() else { return }
        containerState.containerWidth = context.containerWidth
        for (_, entry) in entries {
            positionEntry(entry, context: context)
        }
    }

    /// Removes all hosted overlay views and stops layout observation.
    func removeAllOverlays() {
        for (_, entry) in entries {
            entry.view.removeFromSuperview()
            entry.highlightOverlay?.removeFromSuperview()
        }
        entries.removeAll()
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
            scheduleReposition()
        }
    }

    /// Schedules overlay repositioning for the next run-loop iteration so TextKit 2
    /// has time to process layout invalidation before we read fragment frames.
    /// Multiple calls within the same run-loop cycle are coalesced into a single pass.
    private func scheduleReposition() {
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

        if let range = attachmentRange(for: attachment) {
            textStorage.edited(.editedAttributes, range: range, changeInLength: 0)
            buildPositionIndex(from: textStorage)
        }

        if let layoutManager = textView.textLayoutManager {
            let fullRange = layoutManager.documentRange
            layoutManager.invalidateLayout(for: fullRange)
            layoutManager.ensureLayout(for: fullRange)
        }
    }

    // MARK: - Attachment Overlay Lifecycle

    private func needsOverlay(_ block: MarkdownBlock) -> Bool {
        switch block {
        case .mermaidBlock, .image, .thematicBreak, .mathBlock:
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
            // because the image is already loaded.
            let knownHeight = oldAttachment.bounds.height
            if knownHeight > 1, let textStorage = textView.textStorage {
                let containerWidth = textContainerWidth(in: textView)
                info.attachment.bounds = CGRect(
                    x: 0, y: 0, width: containerWidth, height: knownHeight
                )
                if let range = attachmentRange(for: info.attachment) {
                    textStorage.edited(.editedAttributes, range: range, changeInLength: 0)
                }
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
        default:
            return
        }

        overlayView.isHidden = true
        textView.addSubview(overlayView)
        entries[info.blockIndex] = OverlayEntry(
            view: overlayView, block: info.block, attachment: info.attachment
        )
    }

    // MARK: - Positioning

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

        guard let fragment = context.layoutManager.textLayoutFragment(
            for: docLocation
        )
        else {
            entry.view.isHidden = true
            return
        }

        let fragmentFrame = fragment.layoutFragmentFrame
        let overlayWidth = entry.preferredWidth ?? context.containerWidth

        guard fragmentFrame.height > 1 else {
            entry.view.isHidden = true
            return
        }

        entry.view.frame = CGRect(
            x: context.origin.x,
            y: fragmentFrame.origin.y + context.origin.y,
            width: overlayWidth,
            height: fragmentFrame.height
        )
        entry.view.isHidden = false
    }

    // MARK: - Helpers

    private func attachmentRange(
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

// MARK: - Attachment Overlay Factories

extension OverlayCoordinator {
    func makeMermaidOverlay(
        code: String,
        blockIndex: Int,
        appSettings: AppSettings
    ) -> NSView {
        let rootView = MermaidBlockView(code: code) { [weak self] _, aspectRatio in
            guard let self, let textView else { return }
            let width = textContainerWidth(in: textView)
            let height = width * aspectRatio
            updateAttachmentHeight(blockIndex: blockIndex, newHeight: height)
        }
        .environment(appSettings)
        .environment(containerState)
        return NSHostingView(rootView: rootView)
    }

    func makeImageOverlay(
        source: String,
        alt: String,
        blockIndex: Int,
        appSettings: AppSettings,
        documentState: DocumentState
    ) -> NSView {
        let containerWidth = textView.map { textContainerWidth(in: $0) } ?? 600
        let rootView = ImageBlockView(
            source: source,
            alt: alt,
            containerWidth: containerWidth
        ) { [weak self] renderedWidth, renderedHeight in
            guard let self else { return }
            let preferredWidth = renderedWidth < containerWidth ? renderedWidth : nil
            updateAttachmentSize(
                blockIndex: blockIndex,
                newWidth: preferredWidth,
                newHeight: renderedHeight
            )
        }
        .environment(appSettings)
        .environment(documentState)
        .environment(containerState)
        return NSHostingView(rootView: rootView)
    }

    func makeThematicBreakOverlay(
        appSettings: AppSettings
    ) -> NSView {
        let borderColor = appSettings.theme.colors.border
        let rootView = borderColor
            .frame(height: 1)
            .padding(.vertical, 8)
        return NSHostingView(rootView: rootView)
    }

    func makeMathBlockOverlay(
        code: String,
        blockIndex: Int,
        appSettings: AppSettings
    ) -> NSView {
        let rootView = MathBlockView(code: code) { [weak self] newHeight in
            self?.updateAttachmentHeight(
                blockIndex: blockIndex,
                newHeight: newHeight
            )
        }
        .environment(appSettings)
        return NSHostingView(rootView: rootView)
    }
}
