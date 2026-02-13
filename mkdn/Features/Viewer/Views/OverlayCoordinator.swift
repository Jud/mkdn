import AppKit
import SwiftUI

/// Manages overlay views (Mermaid, images, tables) at `NSTextAttachment` locations
/// within an `NSTextView`. Includes sticky header positioning for long tables.
@MainActor
final class OverlayCoordinator {
    // MARK: - Types

    private struct OverlayEntry {
        let view: NSView
        let attachment: NSTextAttachment
        let block: MarkdownBlock
        var preferredWidth: CGFloat?
    }

    private struct LayoutContext {
        let origin: NSPoint
        let containerWidth: CGFloat
        let textStorage: NSTextStorage
        let contentManager: NSTextContentManager
        let layoutManager: NSTextLayoutManager
    }

    // MARK: - Properties

    private weak var textView: NSTextView?
    private var entries: [Int: OverlayEntry] = [:]
    private var layoutObserver: NSObjectProtocol?
    private var appSettings: AppSettings?
    private var stickyHeaders: [Int: NSView] = [:]
    private var scrollObserver: NSObjectProtocol?
    private var tableColumnWidths: [Int: [CGFloat]] = [:]

    // MARK: - Public API

    /// Creates, updates, or removes overlay views for non-text blocks.
    ///
    /// Existing overlays whose content has not changed are reused to avoid
    /// recreating expensive subviews such as `WKWebView` instances.
    func updateOverlays(
        attachments: [AttachmentInfo],
        appSettings: AppSettings,
        documentState: DocumentState,
        in textView: NSTextView
    ) {
        self.textView = textView
        self.appSettings = appSettings

        let validIndices = Set(attachments.map(\.blockIndex))
        removeStaleOverlays(keeping: validIndices)

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

    /// Recalculates all overlay positions from the current layout geometry.
    func repositionOverlays() {
        guard let context = makeLayoutContext() else { return }
        for (_, entry) in entries {
            positionEntry(entry, context: context)
        }
    }

    /// Removes all hosted overlay views and stops layout observation.
    func removeAllOverlays() {
        for (_, entry) in entries {
            entry.view.removeFromSuperview()
        }
        entries.removeAll()
        stickyHeaders.values.forEach { $0.removeFromSuperview() }
        stickyHeaders.removeAll()
        tableColumnWidths.removeAll()
        removeObservers()
    }

    /// Updates the placeholder height, triggering layout invalidation and repositioning.
    func updateAttachmentHeight(blockIndex: Int, newHeight: CGFloat) {
        guard let entry = entries[blockIndex],
              let textView,
              let textStorage = textView.textStorage
        else { return }

        guard abs(entry.attachment.bounds.height - newHeight) > 1 else { return }
        invalidateAttachmentHeight(entry.attachment, newHeight: newHeight, textView: textView, textStorage: textStorage)
        repositionOverlays()
    }

    /// Updates both the preferred width and placeholder height for a table overlay,
    /// triggering layout invalidation and repositioning as needed.
    func updateAttachmentSize(
        blockIndex: Int,
        newWidth: CGFloat?,
        newHeight: CGFloat
    ) {
        guard var entry = entries[blockIndex],
              let textView,
              let textStorage = textView.textStorage
        else { return }

        var widthChanged = false
        if let newWidth, entry.preferredWidth != newWidth {
            entry.preferredWidth = newWidth
            entries[blockIndex] = entry
            widthChanged = true
        }

        let heightChanged = abs(entry.attachment.bounds.height - newHeight) > 1
        if heightChanged {
            invalidateAttachmentHeight(
                entry.attachment,
                newHeight: newHeight,
                textView: textView,
                textStorage: textStorage
            )
        }

        if widthChanged || heightChanged {
            repositionOverlays()
        }
    }

    private func invalidateAttachmentHeight(
        _ attachment: NSTextAttachment,
        newHeight: CGFloat,
        textView: NSTextView,
        textStorage: NSTextStorage
    ) {
        let containerWidth = textContainerWidth(in: textView)
        attachment.bounds = CGRect(x: 0, y: 0, width: containerWidth, height: newHeight)

        if let range = attachmentRange(for: attachment, in: textStorage) {
            textStorage.edited(.editedAttributes, range: range, changeInLength: 0)
        }

        if let layoutManager = textView.textLayoutManager {
            let fullRange = layoutManager.documentRange
            layoutManager.invalidateLayout(for: fullRange)
            layoutManager.ensureLayout(for: fullRange)
        }
    }

    // MARK: - Overlay Lifecycle

    private func needsOverlay(_ block: MarkdownBlock) -> Bool {
        switch block {
        case .mermaidBlock, .image, .thematicBreak, .table:
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
           blocksMatch(existing.block, info.block)
        {
            entries[info.blockIndex] = OverlayEntry(
                view: existing.view,
                attachment: info.attachment,
                block: info.block,
                preferredWidth: existing.preferredWidth
            )
            return
        }

        entries[info.blockIndex]?.view.removeFromSuperview()
        createOverlay(
            for: info,
            appSettings: appSettings,
            documentState: documentState,
            in: textView
        )
    }

    private func blocksMatch(_ lhs: MarkdownBlock, _ rhs: MarkdownBlock) -> Bool {
        switch (lhs, rhs) {
        case let (.mermaidBlock(code1), .mermaidBlock(code2)):
            code1 == code2
        case let (.image(src1, _), .image(src2, _)):
            src1 == src2
        case (.thematicBreak, .thematicBreak):
            true
        case let (.table(cols1, rows1), .table(cols2, rows2)):
            cols1.map { String($0.header.characters) } == cols2.map { String($0.header.characters) }
                && rows1.count == rows2.count
        default:
            false
        }
    }

    private func removeStaleOverlays(keeping validIndices: Set<Int>) {
        for (index, entry) in entries where !validIndices.contains(index) {
            entry.view.removeFromSuperview()
            entries.removeValue(forKey: index)
            stickyHeaders[index]?.removeFromSuperview()
            stickyHeaders.removeValue(forKey: index)
            tableColumnWidths.removeValue(forKey: index)
        }
    }

    private func createOverlay(
        for info: AttachmentInfo,
        appSettings: AppSettings,
        documentState: DocumentState,
        in textView: NSTextView
    ) {
        let overlayView: NSView

        switch info.block {
        case let .mermaidBlock(code):
            overlayView = makeMermaidOverlay(
                code: code,
                blockIndex: info.blockIndex,
                appSettings: appSettings
            )
        case let .image(source, alt):
            overlayView = makeImageOverlay(
                source: source,
                alt: alt,
                appSettings: appSettings,
                documentState: documentState
            )
        case .thematicBreak:
            overlayView = makeThematicBreakOverlay(appSettings: appSettings)
        case let .table(columns, rows):
            overlayView = makeTableOverlay(
                columns: columns,
                rows: rows,
                blockIndex: info.blockIndex,
                appSettings: appSettings
            )
        default:
            return
        }

        textView.addSubview(overlayView)
        entries[info.blockIndex] = OverlayEntry(
            view: overlayView,
            attachment: info.attachment,
            block: info.block
        )
    }

    // MARK: - Overlay Factories

    private func makeMermaidOverlay(
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
        return NSHostingView(rootView: rootView)
    }

    private func makeImageOverlay(
        source: String,
        alt: String,
        appSettings: AppSettings,
        documentState: DocumentState
    ) -> NSView {
        let rootView = ImageBlockView(source: source, alt: alt)
            .environment(appSettings)
            .environment(documentState)
        return NSHostingView(rootView: rootView)
    }

    private func makeThematicBreakOverlay(
        appSettings: AppSettings
    ) -> NSView {
        let borderColor = appSettings.theme.colors.border
        let rootView = borderColor
            .frame(height: 1)
            .padding(.vertical, 8)
        return NSHostingView(rootView: rootView)
    }

    private func makeTableOverlay(
        columns: [TableColumn],
        rows: [[AttributedString]],
        blockIndex: Int,
        appSettings: AppSettings
    ) -> NSView {
        let containerWidth = textView.map { textContainerWidth(in: $0) } ?? 600
        let scaleFactor = appSettings.scaleFactor
        let sizing = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: containerWidth,
            font: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor)
        )
        tableColumnWidths[blockIndex] = sizing.columnWidths
        let rootView = TableBlockView(
            columns: columns,
            rows: rows,
            containerWidth: containerWidth
        ) { [weak self] width, height in
            guard let self else { return }
            updateAttachmentSize(
                blockIndex: blockIndex,
                newWidth: width,
                newHeight: height
            )
        }
        .environment(appSettings)
        return NSHostingView(rootView: rootView)
    }

    // MARK: - Positioning

    private func makeLayoutContext() -> LayoutContext? {
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

    private func positionEntry(
        _ entry: OverlayEntry,
        context: LayoutContext
    ) {
        guard let range = attachmentRange(
            for: entry.attachment, in: context.textStorage
        )
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
        entry.view.frame = CGRect(
            x: context.origin.x,
            y: fragmentFrame.origin.y + context.origin.y,
            width: overlayWidth,
            height: fragmentFrame.height
        )
        entry.view.isHidden = false
    }

    private func attachmentRange(
        for attachment: NSTextAttachment,
        in textStorage: NSTextStorage
    ) -> NSRange? {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        var foundRange: NSRange?
        textStorage.enumerateAttribute(
            .attachment, in: fullRange, options: []
        ) { value, range, stop in
            if let found = value as? NSTextAttachment, found === attachment {
                foundRange = range
                stop.pointee = true
            }
        }
        return foundRange
    }

    private func textContainerWidth(in textView: NSTextView) -> CGFloat {
        if let container = textView.textContainer {
            return container.size.width
        }
        let inset = textView.textContainerInset
        return textView.bounds.width - inset.width * 2
    }
}

// MARK: - Observation & Sticky Headers

extension OverlayCoordinator {
    func observeLayoutChanges(on textView: NSTextView) {
        guard layoutObserver == nil else { return }
        textView.postsFrameChangedNotifications = true
        layoutObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repositionOverlays()
            }
        }
    }

    func observeScrollChanges(on textView: NSTextView) {
        guard scrollObserver == nil,
              let clipView = textView.enclosingScrollView?.contentView
        else { return }
        clipView.postsBoundsChangedNotifications = true
        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleScrollBoundsChange()
            }
        }
    }

    private func handleScrollBoundsChange() {
        guard let textView,
              let scrollView = textView.enclosingScrollView
        else { return }
        let visibleRect = scrollView.contentView.bounds
        let headerHeight = stickyHeaderHeight()
        for (blockIndex, entry) in entries {
            guard case let .table(columns, _) = entry.block,
                  let columnWidths = tableColumnWidths[blockIndex]
            else { continue }
            let tableFrame = entry.view.frame
            let headerBottom = tableFrame.origin.y + headerHeight
            let tableBottom = tableFrame.origin.y + tableFrame.height
            if visibleRect.origin.y > headerBottom,
               visibleRect.origin.y < tableBottom - headerHeight
            {
                if stickyHeaders[blockIndex] == nil, let appSettings {
                    let header = TableHeaderView(columns: columns, columnWidths: columnWidths)
                    let hosting = NSHostingView(rootView: header.environment(appSettings))
                    textView.addSubview(hosting)
                    stickyHeaders[blockIndex] = hosting
                }
                stickyHeaders[blockIndex]?.frame = CGRect(
                    x: tableFrame.origin.x,
                    y: visibleRect.origin.y + textView.textContainerOrigin.y,
                    width: tableFrame.width,
                    height: headerHeight
                )
                stickyHeaders[blockIndex]?.isHidden = false
            } else {
                stickyHeaders[blockIndex]?.isHidden = true
            }
        }
    }

    private func stickyHeaderHeight() -> CGFloat {
        let baseFont = PlatformTypeConverter.bodyFont(scaleFactor: appSettings?.scaleFactor ?? 1.0)
        let font = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        return ceil(font.ascender - font.descender + font.leading)
            + 2 * TableColumnSizer.verticalCellPadding + TableColumnSizer.headerDividerHeight
    }

    func removeObservers() {
        if let observer = layoutObserver {
            NotificationCenter.default.removeObserver(observer)
            layoutObserver = nil
        }
        if let observer = scrollObserver {
            NotificationCenter.default.removeObserver(observer)
            scrollObserver = nil
        }
    }
}
