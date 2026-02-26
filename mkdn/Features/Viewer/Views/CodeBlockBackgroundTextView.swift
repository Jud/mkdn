import AppKit
import SwiftUI

/// `NSTextView` subclass that draws rounded-rectangle background containers
/// behind code block text ranges identified via ``CodeBlockAttributes``.
///
/// After `super.drawBackground(in:)` fills the document background, this
/// subclass enumerates `.codeBlockRange` attributes in the text storage,
/// computes a bounding rectangle from TextKit 2 layout fragment frames for
/// each code block, and draws a filled-and-stroked rounded rectangle behind
/// the code text. The text content (including syntax highlighting) then draws
/// on top of the container in the normal text drawing pass.
///
/// The container extends to the full width of the text container (FR-1) and
/// relies on `NSParagraphStyle.headIndent` / `tailIndent` set by the text
/// storage builder to create visual padding between the box edge and the
/// code text content.
///
/// On mouse hover, a copy button overlay appears at the top-right corner of
/// the hovered code block. Clicking the button copies the raw code content
/// (without language label) to the system clipboard.
final class CodeBlockBackgroundTextView: NSTextView {
    // MARK: - Constants

    private static let cornerRadius: CGFloat = 6
    private static let borderWidth: CGFloat = 1
    private static let borderOpacity: CGFloat = 0.3
    private static let bottomPadding: CGFloat = MarkdownTextStorageBuilder.codeBlockPadding
    private static let copyButtonInset: CGFloat = 8
    private static let copyButtonSize: CGFloat = 24

    // MARK: - Types

    private struct CodeBlockInfo {
        let blockID: String
        let range: NSRange
        let colorInfo: CodeBlockColorInfo
    }

    // MARK: - Copy Button Types

    private struct CodeBlockGeometry {
        let blockID: String
        let rect: CGRect
        let range: NSRange
        let colorInfo: CodeBlockColorInfo
    }

    // MARK: - Copy Button State

    private var hoveredBlockID: String?
    private var copyButtonOverlay: NSView?
    private var cachedBlockRects: [CodeBlockGeometry] = []

    // MARK: - Find State

    weak var findState: FindState?

    // MARK: - Selection Drag Callback

    /// Called on every mouseDragged event during a text selection drag,
    /// allowing real-time table cell highlight updates.
    var selectionDragHandler: ((NSRange) -> Void)?

    // MARK: - Print Support

    /// Current indexed blocks retained for print-time attributed string rebuild.
    var printBlocks: [IndexedBlock] = []

    // MARK: - Table-Aware Copy

    override func copy(_ sender: Any?) {
        if !handleTableCopy() { super.copy(sender) }
    }

    // MARK: - Live Resize

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }

    // MARK: - Escape to Dismiss Find

    override func cancelOperation(_ sender: Any?) {
        if let findState, findState.isVisible {
            findState.dismiss()
            return
        }
        super.cancelOperation(sender)
    }

    // MARK: - Cursor Rects

    override func resetCursorRects() {
        super.resetCursorRects()
        addLinkCursorRects()
    }

    private func addLinkCursorRects() {
        guard let textStorage,
              let layoutManager = textLayoutManager,
              let contentManager = layoutManager.textContentManager
        else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        let origin = textContainerOrigin

        textStorage.enumerateAttribute(
            .link,
            in: fullRange,
            options: []
        ) { value, range, _ in
            guard value != nil else { return }

            let frames = fragmentFrames(
                for: range,
                layoutManager: layoutManager,
                contentManager: contentManager
            )
            for frame in frames {
                let cursorRect = CGRect(
                    x: frame.minX + origin.x,
                    y: frame.minY + origin.y,
                    width: frame.width,
                    height: frame.height
                )
                addCursorRect(cursorRect, cursor: .pointingHand)
            }
        }
    }

    // MARK: - Mouse Tracking

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner === self {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseDown(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        if isPointOverEmptySpace(viewPoint) {
            window?.performDrag(with: event)
            return
        }
        super.mouseDown(with: event)
    }

    // MARK: - Real-Time Selection Updates

    override func setSelectedRanges(
        _ ranges: [NSValue],
        affinity: NSSelectionAffinity,
        stillSelecting: Bool
    ) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        if let range = ranges.first {
            selectionDragHandler?(range.rangeValue)
        }
    }

    /// Returns `true` when the point is not over any text layout fragment,
    /// i.e. it's in the textContainerInset margins or below the last line.
    private func isPointOverEmptySpace(_ viewPoint: CGPoint) -> Bool {
        guard let textLayoutManager else { return true }

        let containerPoint = CGPoint(
            x: viewPoint.x - textContainerInset.width,
            y: viewPoint.y - textContainerInset.height
        )

        guard let fragment = textLayoutManager.textLayoutFragment(for: containerPoint) else {
            return true
        }
        return !fragment.layoutFragmentFrame.contains(containerPoint)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let point = convert(event.locationInWindow, from: nil)
        updateCopyButtonForMouse(at: point)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hideCopyButton()
    }

    private func updateCopyButtonForMouse(at point: CGPoint) {
        refreshCachedBlockRects()
        for entry in cachedBlockRects where entry.rect.contains(point) {
            if hoveredBlockID != entry.blockID {
                showCopyButton(for: entry)
            }
            return
        }
        hideCopyButton()
    }

    private func showCopyButton(for entry: CodeBlockGeometry) {
        hoveredBlockID = entry.blockID

        let buttonX = entry.rect.maxX - Self.copyButtonSize - Self.copyButtonInset
        let buttonY = entry.rect.minY + Self.copyButtonInset
        let buttonFrame = CGRect(
            x: buttonX,
            y: buttonY,
            width: Self.copyButtonSize,
            height: Self.copyButtonSize
        )

        if let existing = copyButtonOverlay {
            existing.frame = buttonFrame
            if let hostingView = existing as? NSHostingView<CodeBlockCopyButton> {
                hostingView.rootView = makeCopyButtonView(
                    colorInfo: entry.colorInfo,
                    range: entry.range
                )
            }
        } else {
            let hostingView = NSHostingView(
                rootView: makeCopyButtonView(
                    colorInfo: entry.colorInfo,
                    range: entry.range
                )
            )
            hostingView.frame = buttonFrame
            addSubview(hostingView)
            copyButtonOverlay = hostingView
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.copyButtonOverlay?.animator().alphaValue = 1.0
        }
    }

    private func hideCopyButton() {
        guard hoveredBlockID != nil else { return }
        hoveredBlockID = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.copyButtonOverlay?.animator().alphaValue = 0.0
        }
    }

    private func makeCopyButtonView(
        colorInfo: CodeBlockColorInfo,
        range: NSRange
    ) -> CodeBlockCopyButton {
        CodeBlockCopyButton(codeBlockColors: colorInfo) { [weak self] in
            self?.copyCodeBlock(at: range)
        }
    }

    private func copyCodeBlock(at range: NSRange) {
        guard let textStorage,
              range.location + range.length <= textStorage.length,
              let rawCode = textStorage.attribute(
                  CodeBlockAttributes.rawCode,
                  at: range.location,
                  effectiveRange: nil
              ) as? String
        else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(rawCode, forType: .string)
    }

    // MARK: - Block Rect Cache

    private func refreshCachedBlockRects() {
        guard let textStorage,
              let layoutManager = textLayoutManager,
              let contentManager = layoutManager.textContentManager
        else {
            cachedBlockRects = []
            return
        }

        let blocks = collectCodeBlocks(from: textStorage)
        guard !blocks.isEmpty else {
            cachedBlockRects = []
            return
        }

        let origin = textContainerOrigin
        let containerWidth = textContainer?.size.width ?? bounds.width
        let borderInset = Self.borderWidth / 2

        cachedBlockRects = blocks.compactMap { block in
            let frames = fragmentFrames(
                for: block.range,
                layoutManager: layoutManager,
                contentManager: contentManager
            )
            guard !frames.isEmpty else { return nil }

            let bounding = frames.reduce(frames[0]) { $0.union($1) }
            let drawRect = CGRect(
                x: origin.x + borderInset,
                y: bounding.minY + origin.y,
                width: containerWidth - 2 * borderInset,
                height: bounding.height + Self.bottomPadding
            )
            return CodeBlockGeometry(
                blockID: block.blockID,
                rect: drawRect,
                range: block.range,
                colorInfo: block.colorInfo
            )
        }
    }

    // MARK: - Drawing

    /// Required for print rendering and table selection highlight suppression.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        eraseTableSelectionHighlights(in: dirtyRect)
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        drawCodeBlockContainers(in: rect)
        drawTableContainers(in: rect)
    }

    // MARK: - Print

    override func printView(_ sender: Any?) {
        guard !printBlocks.isEmpty else {
            super.printView(sender)
            return
        }

        let savedString = textStorage.map { NSAttributedString(attributedString: $0) }
        let savedBgColor = backgroundColor
        let result = MarkdownTextStorageBuilder.build(
            blocks: printBlocks,
            colors: PrintPalette.colors,
            syntaxColors: PrintPalette.syntaxColors,
            isPrint: true
        )
        textStorage?.setAttributedString(result.attributedString)
        backgroundColor = PlatformTypeConverter.nsColor(from: PrintPalette.colors.background)

        // swiftlint:disable:next force_cast
        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        let printOp = NSPrintOperation(view: self, printInfo: printInfo)
        printOp.showsPrintPanel = true
        printOp.showsProgressPanel = true
        printOp.run()

        if let saved = savedString {
            textStorage?.setAttributedString(saved)
        }
        backgroundColor = savedBgColor
    }

    private func drawCodeBlockContainers(in dirtyRect: NSRect) {
        guard let textStorage,
              let layoutManager = textLayoutManager,
              let contentManager = layoutManager.textContentManager
        else { return }

        let blocks = collectCodeBlocks(from: textStorage)
        guard !blocks.isEmpty else { return }

        let origin = textContainerOrigin
        let containerWidth = textContainer?.size.width ?? bounds.width
        let borderInset = Self.borderWidth / 2

        for block in blocks {
            let frames = fragmentFrames(
                for: block.range,
                layoutManager: layoutManager,
                contentManager: contentManager
            )
            guard !frames.isEmpty else { continue }

            let bounding = frames.reduce(frames[0]) { $0.union($1) }
            let drawRect = CGRect(
                x: origin.x + borderInset,
                y: bounding.minY + origin.y,
                width: containerWidth - 2 * borderInset,
                height: bounding.height + Self.bottomPadding
            )
            guard drawRect.intersects(dirtyRect) else { continue }

            drawRoundedContainer(
                in: drawRect,
                colorInfo: block.colorInfo
            )
        }
    }

    private func drawRoundedContainer(
        in rect: NSRect,
        colorInfo: CodeBlockColorInfo
    ) {
        let path = NSBezierPath(
            roundedRect: rect,
            xRadius: Self.cornerRadius,
            yRadius: Self.cornerRadius
        )

        colorInfo.background.setFill()
        path.fill()

        colorInfo.border
            .withAlphaComponent(Self.borderOpacity).setStroke()
        path.lineWidth = Self.borderWidth
        path.stroke()
    }

    // MARK: - Block Collection

    private func collectCodeBlocks(
        from textStorage: NSTextStorage
    ) -> [CodeBlockInfo] {
        var grouped: [String: (range: NSRange, colorInfo: CodeBlockColorInfo)] = [:]
        let fullRange = NSRange(location: 0, length: textStorage.length)

        textStorage.enumerateAttribute(
            CodeBlockAttributes.range,
            in: fullRange,
            options: []
        ) { value, range, _ in
            guard let blockID = value as? String else { return }
            if var existing = grouped[blockID] {
                existing.range = NSUnionRange(existing.range, range)
                grouped[blockID] = existing
            } else if let colorInfo = textStorage.attribute(
                CodeBlockAttributes.colors,
                at: range.location,
                effectiveRange: nil
            ) as? CodeBlockColorInfo {
                grouped[blockID] = (range: range, colorInfo: colorInfo)
            }
        }

        return grouped.map { blockID, entry in
            CodeBlockInfo(blockID: blockID, range: entry.range, colorInfo: entry.colorInfo)
        }
    }

    // MARK: - Layout Fragment Geometry

    private func fragmentFrames(
        for nsRange: NSRange,
        layoutManager: NSTextLayoutManager,
        contentManager: NSTextContentManager
    ) -> [CGRect] {
        guard let textRange = textRange(
            from: nsRange,
            contentManager: contentManager
        )
        else { return [] }

        var frames: [CGRect] = []
        let endLocation = textRange.endLocation

        layoutManager.enumerateTextLayoutFragments(
            from: textRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            let fragmentStart = fragment.rangeInElement.location
            if fragmentStart.compare(endLocation) != .orderedAscending {
                return false
            }
            frames.append(fragment.layoutFragmentFrame)
            return true
        }

        return frames
    }

    private func textRange(
        from nsRange: NSRange,
        contentManager: NSTextContentManager
    ) -> NSTextRange? {
        guard nsRange.length > 0 else { return nil }

        guard let startLocation = contentManager.location(
            contentManager.documentRange.location,
            offsetBy: nsRange.location
        )
        else { return nil }

        guard let endLocation = contentManager.location(
            startLocation,
            offsetBy: nsRange.length
        )
        else { return nil }

        return NSTextRange(location: startLocation, end: endLocation)
    }
}
