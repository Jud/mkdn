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

    static let cornerRadius: CGFloat = 6
    static let borderWidth: CGFloat = 1
    static let borderOpacity: CGFloat = 0.3
    static let bottomPadding: CGFloat = MarkdownTextStorageBuilder.codeBlockPadding
    static let copyButtonInset: CGFloat = 8
    static let copyButtonSize: CGFloat = 24
    static let titleBarDragHeight: CGFloat = 28

    // MARK: - Types

    struct CodeBlockInfo {
        let blockID: String
        let range: NSRange
        let colorInfo: CodeBlockColorInfo
    }

    // MARK: - Copy Button Types

    struct CodeBlockGeometry {
        let blockID: String
        let rect: CGRect
        let range: NSRange
        let colorInfo: CodeBlockColorInfo
    }

    // MARK: - Code Block Cache

    var cachedCodeBlocks: [CodeBlockInfo] = []
    var isCodeBlockCacheValid = false

    // MARK: - Copy Button State

    var hoveredBlockID: String?
    var copyButtonOverlay: NSView?
    var cachedBlockRects: [CodeBlockGeometry] = []

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
        invalidateCodeBlockCache()
        needsDisplay = true
    }

    // MARK: - Text Change Invalidation

    override func didChangeText() {
        super.didChangeText()
        invalidateCodeBlockCache()
    }

    private func invalidateCodeBlockCache() {
        isCodeBlockCacheValid = false
    }

    // MARK: - Escape to Dismiss Find

    override func cancelOperation(_ sender: Any?) {
        if let findState, findState.isVisible {
            findState.dismiss()
            return
        }
        super.cancelOperation(sender)
    }

    // MARK: - Title Bar Zone

    func titleBarRect() -> CGRect {
        let visible = visibleRect
        return CGRect(
            x: visible.origin.x,
            y: visible.origin.y,
            width: visible.width,
            height: Self.titleBarDragHeight
        )
    }

    // MARK: - Cursor Rects

    override func resetCursorRects() {
        super.resetCursorRects()
        addLinkCursorRects()
        addCursorRect(titleBarRect(), cursor: .arrow)
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
        if titleBarRect().contains(viewPoint) {
            window?.performDrag(with: event)
            return
        }
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
        if titleBarRect().contains(point) {
            NSCursor.arrow.set()
        }
        updateCopyButtonForMouse(at: point)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hideCopyButton()
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
}
