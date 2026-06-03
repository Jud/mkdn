#if os(macOS)
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
        var areBlockRectsValid = false

        // MARK: - Copy Button State

        var hoveredBlockID: String?
        var copyButtonOverlay: NSView?
        var cachedBlockRects: [CodeBlockGeometry] = []

        // MARK: - Find State

        weak var findState: FindState?

        // MARK: - Comment State

        var criticDocument: CriticMarkupDocument?
        var commentSourceMap: SourceMap?
        weak var documentState: DocumentState?
        var commentTheme: AppTheme?
        var commentPopover: NSPopover?

        // MARK: - Print Support

        /// Current indexed blocks retained for print-time attributed string rebuild.
        var printBlocks: [IndexedBlock] = []

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

        func invalidateCodeBlockCache() {
            isCodeBlockCacheValid = false
            areBlockRectsValid = false
        }

        // MARK: - Escape to Dismiss Find

        override func cancelOperation(_ sender: Any?) {
            if let findState, findState.isVisible {
                findState.dismiss()
                return
            }
            super.cancelOperation(sender)
        }

        // MARK: - Mouse Tracking

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            installFullBoundsTrackingArea()
        }

        override func mouseDown(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            if isOverEmptyTextArea(point) {
                handleEmptyAreaMouseDown(with: event)
                return
            }
            super.mouseDown(with: event)

            if let mouseLocation = window?.mouseLocationOutsideOfEventStream {
                let finalPoint = convert(mouseLocation, from: nil)
                if isOverEmptyTextArea(finalPoint) {
                    NSCursor.arrow.set()
                }
            }

            openCommentPopoverIfNeeded(for: event, at: point)
        }

        /// NSTextView completes selection tracking inside `mouseDown` and consumes
        /// the matching mouse-up, so the trigger runs here — after `super` has
        /// finished the gesture and `selectedRange()` is settled — not in a
        /// `mouseUp` override (which never fires for normal text clicks). Opens a
        /// comment only on a plain single click that placed a caret (no selection,
        /// no modifiers), preserving selection, double-click and modifier-click. A
        /// click on a commented link opens the comment (its navigation is
        /// suppressed in the clickedOnLink delegate); an uncommented link still
        /// follows normally because `commentInfo` is nil there.
        private func openCommentPopoverIfNeeded(for event: NSEvent, at point: CGPoint) {
            guard event.clickCount == 1,
                  event.modifierFlags.intersection([.shift, .command, .option, .control]).isEmpty,
                  selectedRange().length == 0
            else {
                return
            }
            guard let info = commentInfo(at: point) else { return }
            showCommentPopover(id: innermostCommentID(among: info.ids), at: point)
        }

        /// The innermost (smallest-enclosing) comment among `ids` — the one a
        /// reader most likely meant when clicking inside overlapping highlights.
        /// Falls back to the first id when the document is unavailable.
        private func innermostCommentID(among ids: [String]) -> String {
            criticDocument?.innermostComment(among: ids)?.id ?? ids[0]
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            let menu = super.menu(for: event) ?? NSMenu()
            if commentableSelectionRange() != nil {
                let item = NSMenuItem(
                    title: "Add Comment…",
                    action: #selector(addCommentToSelection(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                menu.insertItem(item, at: 0)
                menu.insertItem(.separator(), at: 1)
            }
            return menu
        }

        override func mouseMoved(with event: NSEvent) {
            // Don't override cursor when another view (e.g. outline HUD) is on top.
            if isObscuredAtPoint(event.locationInWindow) { return }

            let point = convert(event.locationInWindow, from: nil)
            if isOverEmptyTextArea(point) {
                NSCursor.arrow.set()
            } else if isOverLink(at: point) || commentInfo(at: point) != nil {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.iBeam.set()
            }
            updateCopyButtonForMouse(at: point)
        }

        override func cursorUpdate(with event: NSEvent) {
            if isObscuredAtPoint(event.locationInWindow) { return }

            let point = convert(event.locationInWindow, from: nil)
            if isOverEmptyTextArea(point) {
                NSCursor.arrow.set()
            } else if isOverLink(at: point) || commentInfo(at: point) != nil {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.iBeam.set()
            }
        }

        /// Returns true if another view is on top of this text view at the given window point.
        private func isObscuredAtPoint(_ windowPoint: NSPoint) -> Bool {
            guard let hitView = window?.contentView?.hitTest(windowPoint) else { return false }
            return hitView !== self && !hitView.isDescendant(of: self)
        }

        override func mouseExited(with event: NSEvent) {
            super.mouseExited(with: event)
            hideCopyButton()
        }

        // MARK: - Drawing

        /// Pre-draw cache refresh: enumerating layout fragments inside
        /// drawBackground forces TextKit 2 layout during the draw pass,
        /// causing visible flicker on resize. viewWillDraw fires after
        /// layout has settled but before drawing begins.
        override func viewWillDraw() {
            super.viewWillDraw()
            refreshCachedBlockRects()
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

            let savedString = textStorage.map { NSAttributedString(attributedString: $0) }
            let savedBgColor = backgroundColor
            let result = MarkdownTextStorageBuilder.build(
                blocks: printBlocks,
                colors: PrintPalette.colors,
                syntaxColors: PrintPalette.syntaxColors,
                isPrint: true
            )
            textStorage?.setAttributedString(result.attributedString)
            backgroundColor = PlatformTypeConverter.color(from: PrintPalette.colors.background)

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
#endif
