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
        /// The overlapping-comments count badge is sized as a fraction of the
        /// commented line's height, so it scales with the text size.
        static let overlapBadgeLineFraction: CGFloat = 0.85
        static let overlapBadgeMinDiameter: CGFloat = 14
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
        /// Count badges marking spans covered by 2+ overlapping comments, cached in
        /// `viewWillDraw` to avoid forcing layout during drawing. Carries the
        /// covering ids + range so clicking the badge opens those comments.
        struct OverlapBadge {
            let rect: CGRect
            let ids: [String]
            let range: NSRange
            var count: Int { ids.count }
        }

        var cachedCommentOverlapBadges: [OverlapBadge] = []
        /// A transparent subview that paints the overlap badges; a subview renders
        /// above the text (unlike `draw(_:)`, which the highlight covers).
        var commentBadgeOverlay: CommentBadgeOverlayView?

        // MARK: - Find State

        weak var findState: FindState?

        // MARK: - Comment State

        /// Comments resolved against the rendered text, drawn as a background fill
        /// (see ``drawCommentHighlights(in:)``) and queried for hit-testing.
        var resolvedComments: ResolvedComments?
        /// The rendered anchor tape, for capturing a selector when authoring a comment.
        var anchorTape: AnchorTape?
        weak var documentState: DocumentState?
        var commentTheme: AppTheme?
        /// The currently presented comment overlay (read popover or add input), a
        /// hosted subview rather than an NSPopover so the whole box pops with the
        /// app's animation and has no arrow.
        var commentOverlay: NSView?
        var commentOverlayModel: CommentOverlayModel?
        var commentDismissMonitor: Any?
        /// The comments currently shown (empty for the add-comment input or when
        /// closed), so a re-click on the same overlapping set toggles it closed
        /// (see `openCommentPopoverIfNeeded`).
        var openCommentIDs: [String] = []
        /// One-shot: skip dismissing the open overlay on the next content rebuild.
        /// Set when a comment body is edited from the popover (a sidecar-only
        /// change that leaves the layout — and the overlay's anchor — valid), so
        /// the box can pop back to its updated display state instead of closing.
        var keepCommentOverlayThroughRebuild = false
        /// The comment whose row is hovered in the box, emphasized in the document
        /// so the reader sees which span it refers to.
        var hoveredCommentID: String?
        /// Position constraints for the open overlay, updated while dragging it.
        var commentOverlayLeading: NSLayoutConstraint?
        var commentOverlayTop: NSLayoutConstraint?
        var commentOverlayDragBase: CGPoint?
        /// Clears a jump-to-comment flash after its hold; cancelled when a newer
        /// flash or hover supersedes it.
        var commentFlashTask: Task<Void, Never>?
        /// Drives the smooth scroll for a jump-to-comment; cancelled when a newer
        /// jump supersedes it (e.g. clicking a second comment mid-scroll).
        var commentScrollTimer: DispatchSourceTimer?
        /// The comment whose span is drawn with hover emphasis. Lags
        /// ``hoveredCommentID`` during the fade-out so the emphasis can animate away
        /// rather than vanish.
        var emphasisDrawID: String?
        /// 0 → 1 fade of the hover emphasis for ``emphasisDrawID``, animated by
        /// ``commentEmphasisTimer`` so the span eases into/out of the highlight.
        var emphasisProgress: CGFloat = 0
        var commentEmphasisTimer: DispatchSourceTimer?

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
                dismissCommentOverlay() // click-away in the empty/drag area closes a comment
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
        /// follows normally because `commentHits` is empty there.
        private func openCommentPopoverIfNeeded(for event: NSEvent, at point: CGPoint) {
            guard event.clickCount == 1,
                  event.modifierFlags.intersection([.shift, .command, .option, .control]).isEmpty,
                  selectedRange().length == 0
            else {
                return
            }
            let hits = commentHits(at: point)
            guard !hits.isEmpty else {
                dismissCommentOverlay() // a plain-text click closes any open comment
                return
            }
            toggleComments(hits)
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            let menu = super.menu(for: event) ?? NSMenu()
            if commentableSelection() != nil {
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
            guard let cursor = cursor(at: point) else { return } // overlay owns it
            cursor.set()
            updateCopyButtonForMouse(at: point)
        }

        override func cursorUpdate(with event: NSEvent) {
            if isObscuredAtPoint(event.locationInWindow) { return }
            let point = convert(event.locationInWindow, from: nil)
            cursor(at: point)?.set()
        }

        /// The cursor for a point, or nil when the comment overlay (our own
        /// subview) is on top and owns its cursor — the caller must not override it.
        private func cursor(at point: CGPoint) -> NSCursor? {
            if commentOverlay?.frame.contains(point) == true { return nil }
            if isOverOverlapBadge(point) { return .pointingHand }
            if isOverEmptyTextArea(point) { return .arrow }
            if isOverLink(at: point) || !commentHits(at: point).isEmpty { return .pointingHand }
            return .iBeam
        }

        private func isOverOverlapBadge(_ point: CGPoint) -> Bool {
            cachedCommentOverlapBadges.contains { $0.rect.contains(point) }
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
        /// causing visible flicker on resize. viewWillDraw fires before
        /// drawing begins; the cache refresh forces real layout itself (see
        /// refreshCachedBlockRects) since viewWillDraw alone does not guarantee
        /// TextKit 2 has laid out fragments beyond the visible viewport.
        override func viewWillDraw() {
            super.viewWillDraw()
            refreshCachedBlockRects()
            refreshCachedCommentOverlapBadges()
            syncCommentBadgeOverlay()
        }

        override func drawBackground(in rect: NSRect) {
            super.drawBackground(in: rect)
            drawCodeBlockContainers(in: rect)
            drawCommentHighlights(in: rect)
        }

        // MARK: - Print

        override func printView(_ sender: Any?) {
            guard !printBlocks.isEmpty else {
                super.printView(sender)
                return
            }

            let savedString = textStorage.map { NSAttributedString(attributedString: $0) }
            let savedBgColor = backgroundColor
            // Comment highlights are drawn from screen-resolved ranges; suppress them
            // for the print canvas (its rebuilt storage has no comments) so they
            // don't bleed onto the page.
            let savedResolvedComments = resolvedComments
            resolvedComments = nil
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
            resolvedComments = savedResolvedComments
        }
    }
#endif
