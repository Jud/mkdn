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
final class CodeBlockBackgroundTextView: NSTextView {
    // MARK: - Constants

    private static let cornerRadius: CGFloat = 6
    private static let borderWidth: CGFloat = 1
    private static let borderOpacity: CGFloat = 0.3
    private static let bottomPadding: CGFloat = MarkdownTextStorageBuilder.codeBlockPadding

    // MARK: - Types

    private struct CodeBlockInfo {
        let range: NSRange
        let colorInfo: CodeBlockColorInfo
    }

    // MARK: - Print Support

    /// Current indexed blocks retained for print-time attributed string rebuild.
    var printBlocks: [IndexedBlock] = []

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

    // MARK: - Drawing

    // Required for offscreen (print) rendering: TextKit 2 only dispatches to
    // drawBackground(in:) from draw(_:), not from display(), for non-windowed views.
    // swiftlint:disable:next unneeded_override
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        drawCodeBlockContainers(in: rect)
    }

    // MARK: - Print

    override func printView(_ sender: Any?) {
        guard !printBlocks.isEmpty else {
            super.printView(sender)
            return
        }

        let result = MarkdownTextStorageBuilder.build(
            blocks: printBlocks,
            colors: PrintPalette.colors,
            syntaxColors: PrintPalette.syntaxColors
        )

        let cloneView = Self.makePrintTextView(
            attributedString: result.attributedString,
            size: bounds.size
        )

        // swiftlint:disable:next force_cast
        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        let printOp = NSPrintOperation(view: cloneView, printInfo: printInfo)
        printOp.showsPrintPanel = true
        printOp.showsProgressPanel = true
        printOp.run()
    }

    private static func makePrintTextView(
        attributedString: NSAttributedString,
        size: NSSize
    ) -> CodeBlockBackgroundTextView {
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true

        let layoutManager = NSTextLayoutManager()
        layoutManager.textContainer = textContainer

        let contentStorage = NSTextContentStorage()
        contentStorage.addTextLayoutManager(layoutManager)

        let textView = CodeBlockBackgroundTextView(
            frame: NSRect(origin: .zero, size: size),
            textContainer: textContainer
        )
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = true
        textView.backgroundColor = PlatformTypeConverter.nsColor(
            from: PrintPalette.colors.background
        )
        textView.textContainerInset = NSSize(width: 32, height: 32)
        textView.textStorage?.setAttributedString(attributedString)

        if let tlm = textView.textLayoutManager,
           let tcm = tlm.textContentManager
        {
            tlm.ensureLayout(for: tcm.documentRange)
        }

        textView.sizeToFit()
        return textView
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

        return grouped.values.map { entry in
            CodeBlockInfo(range: entry.range, colorInfo: entry.colorInfo)
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
