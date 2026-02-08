import AppKit
import SwiftUI

/// Manages the lifecycle and positioning of non-text overlay views (Mermaid
/// diagrams, images) at `NSTextAttachment` placeholder locations within an
/// `NSTextView`.
///
/// Overlay views are `NSHostingView` instances wrapping SwiftUI views added as
/// subviews of the text view. They scroll naturally with the text content and
/// are repositioned when the text layout changes due to window resize or
/// content updates.
@MainActor
final class OverlayCoordinator {
    // MARK: - Types

    private struct OverlayEntry {
        let view: NSView
        let attachment: NSTextAttachment
        let block: MarkdownBlock
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
        removeObservers()
    }

    /// Updates the placeholder height for a specific overlay block,
    /// triggering a text layout invalidation and overlay repositioning.
    func updateAttachmentHeight(blockIndex: Int, newHeight: CGFloat) {
        guard let entry = entries[blockIndex],
              let textView,
              let textStorage = textView.textStorage
        else { return }

        let attachment = entry.attachment
        guard abs(attachment.bounds.height - newHeight) > 1 else { return }

        attachment.bounds = CGRect(
            x: 0,
            y: 0,
            width: attachment.bounds.width,
            height: newHeight
        )

        guard let range = attachmentRange(
            for: attachment, in: textStorage
        )
        else { return }

        textStorage.edited(.editedAttributes, range: range, changeInLength: 0)
        repositionOverlays()
    }

    // MARK: - Overlay Lifecycle

    private func needsOverlay(_ block: MarkdownBlock) -> Bool {
        switch block {
        case .mermaidBlock, .image:
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
                block: info.block
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
        default:
            false
        }
    }

    private func removeStaleOverlays(keeping validIndices: Set<Int>) {
        for (index, entry) in entries where !validIndices.contains(index) {
            entry.view.removeFromSuperview()
            entries.removeValue(forKey: index)
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
                appSettings: appSettings
            )
        case let .image(source, alt):
            overlayView = makeImageOverlay(
                source: source,
                alt: alt,
                appSettings: appSettings,
                documentState: documentState
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
        appSettings: AppSettings
    ) -> NSView {
        let rootView = MermaidBlockView(code: code)
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
        entry.view.frame = CGRect(
            x: fragmentFrame.origin.x + context.origin.x,
            y: fragmentFrame.origin.y + context.origin.y,
            width: context.containerWidth,
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

    // MARK: - Layout Observation

    private func observeLayoutChanges(on textView: NSTextView) {
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

    private func removeObservers() {
        if let observer = layoutObserver {
            NotificationCenter.default.removeObserver(observer)
            layoutObserver = nil
        }
    }
}
