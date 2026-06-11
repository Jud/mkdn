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

        /// Invoked when a sidebar slide or window live-resize settles, so the
        /// coordinator runs a final scroll-spy pass once its in-resize guard lifts.
        var onResizeSettled: (() -> Void)?

        // MARK: - Copy Button State

        var hoveredBlockID: String?
        var copyButtonOverlay: NSView?
        var cachedBlockRects: [CodeBlockGeometry] = []
        /// Scroll origin the viewport-scoped rect cache was computed at; a
        /// scroll invalidates it as surely as a content change.
        var cachedBlockRectsOrigin: CGPoint?
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
        /// A comment just added by paste, not yet resolved against the rendered
        /// text. The comment-only repaint that follows the sidecar write consumes
        /// it and opens the comment's box (see ``revealPendingComment()``) — the
        /// paste path has no input overlay to morph into a display box.
        var pendingRevealCommentID: String?
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

        deinit {
            // Stop the comment animation timers/task if the view is torn down
            // mid-flight, so none keep firing against a detached view.
            commentScrollTimer?.cancel()
            commentEmphasisTimer?.cancel()
            commentFlashTask?.cancel()
            if let storageEditObserver {
                NotificationCenter.default.removeObserver(storageEditObserver)
            }
        }

        // MARK: - Print Support

        /// Current indexed blocks — the print-time attributed string rebuild and
        /// the progressive open's provisional height floor both read them.
        var printBlocks: [IndexedBlock] = []

        // MARK: - Sidebar Resize

        /// The overlay coordinator hosting this view's attachments, so the
        /// sidebar-resize settle can drain heights queued after the slide's
        /// final frame before its exact layout passes run.
        weak var overlayCoordinator: OverlayCoordinator?

        /// Top-of-viewport anchor captured while the comment rail animates the
        /// preview width. Non-nil marks an in-flight sidebar resize: the scroll
        /// view re-pins this line to the same viewport y on every layout pass, so
        /// the text the reader is looking at holds still while everything rewraps.
        var sidebarResizeAnchor: SidebarResizeAnchor?

        /// True for the whole comment-rail slide (begin…end), not just the frames where
        /// `sidebarResizeAnchor` happens to be set. The anchor can be briefly nil at the
        /// slide's edges (it's captured/cleared a frame off the width animation), so it
        /// alone leaks per-frame estimate/map work; this flag spans the gesture.
        var isSidebarResizeInFlight = false

        /// Any width gesture in flight — the rail slide or a window live-resize — during
        /// which per-frame whole-string measures (height estimate, document map) must be
        /// skipped and run once on settle. The shared signal for every such guard.
        var isResizeGestureActive: Bool {
            isSidebarResizeInFlight
                || sidebarResizeAnchor != nil
                || (enclosingScrollView?.inLiveResize ?? false)
        }

        // MARK: - Progressive Open

        /// A progressive open's tail is still appending chunks: the storage holds a
        /// prefix and `documentHeightModel` covers only that prefix, so whole-string
        /// measures would read a fraction of the document as its full height. Cleared
        /// by the coordinator's finish once the tail (and the one exact pass) lands.
        var isProgressiveOpenActive = false

        /// Scale factor for the provisional floor while the tail runs (the text view
        /// has no other route to the app's zoom).
        var progressiveOpenScaleFactor: CGFloat = 1

        /// Set by the coordinator while a tail is active; actions that need the full
        /// document now (print) call it to drain the tail synchronously.
        var forceFinishProgressiveOpen: (() -> Void)?

        /// Whole-string measures suppressed: any width gesture, or a progressive
        /// open's tail. One signal for the spy/map/heading/code-block-rect guards.
        var isMetricsSuppressed: Bool {
            isResizeGestureActive || isProgressiveOpenActive
        }

        /// Floor for the document-view height from the whole-string height estimate, so
        /// the scroller reflects the full height immediately instead of TextKit 2
        /// building it up lazily as the reader scrolls. Recomputed at each settled width
        /// (load, resize end); cleared during a slide/drag so the reflow is free.
        var estimatedHeightFloor: CGFloat?

        /// Block spans for the current content, set alongside each storage swap. Lets
        /// `refreshEstimatedHeight` size the scroller from the per-block sum (fast) rather
        /// than a whole-document `boundingRect` (super-linear in length for some content).
        var documentHeightModel: DocumentHeightModel?

        /// Container width of the last height estimate, so a redundant re-measure at an
        /// unchanged width is skipped (see `refreshEstimatedHeight`). Nilled when the
        /// height changes at a fixed width (attachment resolution) to force a recompute.
        private var lastEstimatedWidth: CGFloat?

        /// Shared cache of the per-block Core Text pass at `lastEstimatedWidth`:
        /// ``refreshEstimatedHeight`` recomputes and replaces it on every re-measure, and the
        /// heading navigation and document map read it via ``currentBlockOffsets()`` — one
        /// pass per content/width. Freed wherever block tops can shift before a synchronous
        /// refresh reaches it: the resize-gesture starts (sidebar slide, window live-resize),
        /// which suppress the per-frame refresh, and attachment resolution, whose height
        /// re-estimate is debounced — so a reader in that window recomputes fresh instead of
        /// reading stale tops.
        var blockOffsets: DocumentBlockOffsets?

        private var refreshHeightWorkItem: DispatchWorkItem?

        /// How long to wait for an attachment-resolution burst to settle before
        /// re-estimating, so the whole-string measure runs once rather than per overlay.
        private static let attachmentRefreshDebounce: TimeInterval = 0.1

        // MARK: - Live Resize

        /// While set, the container reports itself simple-rectangular so TextKit lays
        /// out lazily — each width-gesture frame then costs O(viewport), not O(prefix).
        /// Gesture begin/end handlers own the flag; see ``GestureLazyTextContainer``.
        var prefersLazyGestureLayout: Bool {
            get { (textContainer as? GestureLazyTextContainer)?.prefersLazyLayout ?? false }
            set { (textContainer as? GestureLazyTextContainer)?.prefersLazyLayout = newValue }
        }

        /// AppKit's implementation derives the origin from the layout manager's usage
        /// bounds, which can force layout well beyond the viewport right after an
        /// invalidation (each frame of a width gesture re-sizes the container) — all
        /// to learn an origin that, for this top-aligned document view, is always the
        /// container inset. Return the inset directly.
        override var textContainerOrigin: NSPoint {
            NSPoint(x: textContainerInset.width, y: textContainerInset.height)
        }

        override func setFrameSize(_ newSize: NSSize) {
            var size = newSize
            if let floor = estimatedHeightFloor {
                size.height = max(size.height, floor)
            }
            let containerChanged = syncTextContainerSize(forViewWidth: newSize.width)
            super.setFrameSize(size)
            if containerChanged {
                // The cold paint installs content while the width is still 0; the first
                // real width must discard that zero-width viewport layout and lay out
                // the viewport for real, or the document stays blank until a scroll.
                realizeViewportAfterContainerResize(hardInvalidate: true)
                // Recompute the height estimate at a settled width. Skip during a slide
                // or window drag (the whole-string measure would run every frame); those
                // refresh once at their end.
                if canRefreshEstimatedHeight {
                    refreshSettledHeight()
                }
            }
            invalidateCodeBlockRects()
            needsDisplay = true
        }

        /// Size the text container to the view's current width (minus the
        /// horizontal inset; TextKit subtracts `lineFragmentPadding` internally). The
        /// container can't track the view width on its own, and `setFrameSize` is the
        /// width hook for every sidebar and window resize since the scroll view
        /// autoresizes the text view's frame. Returns whether the width changed.
        @discardableResult
        func syncTextContainerSize(forViewWidth viewWidth: CGFloat? = nil) -> Bool {
            guard let textContainer else { return false }
            let width = max(0, (viewWidth ?? bounds.width) - 2 * textContainerInset.width)
            let desired = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            guard abs(textContainer.size.width - desired.width) > 0.5
                || textContainer.size.height != desired.height
            else { return false }
            textContainer.size = desired
            // The shared offsets were measured at the old width. The gesture
            // paths nil them at their start, but a non-gesture width change
            // (minimap toggle, window zoom, tiling) only passes through here —
            // and readers reuse a live cache assuming it matches the current
            // geometry.
            blockOffsets = nil
            invalidateCodeBlockRects()
            needsDisplay = true
            return true
        }

        /// Lay out and draw the viewport at the current real container width. Content
        /// installed while the width was 0 (cold paint) otherwise keeps its zero-width
        /// viewport layout and paints blank until a scroll. Cheap (viewport only) — it
        /// deliberately does NOT lay out the whole document, so the scroll height stays
        /// lazy; full-document layout would be exact but crush load/toggle on big docs.
        func realizeViewportAfterContainerResize(hardInvalidate: Bool) {
            guard let textLayoutManager,
                  (textStorage?.length ?? 0) > 0,
                  (textContainer?.size.width ?? 0) > 0,
                  bounds.width > 0
            else { return }
            OpenTimeline.shared.time("viewportLayout") {
                if hardInvalidate {
                    textLayoutManager.invalidateLayout(for: textLayoutManager.documentRange)
                }
                textLayoutManager.textViewportLayoutController.layoutViewport()
            }
            setNeedsDisplay(enclosingScrollView?.documentVisibleRect ?? bounds)
        }

        /// The estimate must not be refreshed mid-gesture: it would re-arm the height
        /// floor that beginSidebarResize freed and resize the frame under the slide. The
        /// slide/resize end-handlers re-estimate, so a skipped mid-gesture refresh loses
        /// nothing.
        private var canRefreshEstimatedHeight: Bool {
            !isResizeGestureActive
        }

        /// Width available to text: the container width (already minus the horizontal
        /// inset) minus the line-fragment padding TextKit applies inside it; 0 when there
        /// is no container or it has collapsed. Shared by the height estimate and the
        /// per-block offsets so both measure at the same width.
        var textWidth: CGFloat {
            guard let textContainer else { return 0 }
            return textContainer.size.width - 2 * textContainer.lineFragmentPadding
        }

        /// Recompute the document-height estimate at the current container width and size
        /// the frame to it, so the scroller reflects the full height immediately instead
        /// of TextKit 2 building it up lazily as the reader scrolls. A whole-string Core
        /// Text measure — no fragment layout; call on load and at each width settle. The
        /// estimate tracks real layout (including resolved attachment heights) closely
        /// enough to size the frame in both directions, so an attachment that resolves
        /// below its placeholder shrinks the frame instead of leaving dead scroll extent.
        func refreshEstimatedHeight() {
            // Mid-tail the model covers only the installed prefix, so the "exact"
            // measure would shrink the scroller to a fraction of the document; every
            // caller (settles included) must wait for the finish, which clears the
            // flag and runs the one exact pass.
            guard !isProgressiveOpenActive else { return }
            // Bail at a collapsed/degenerate width: a zero estimate must not shrink a
            // non-empty view to nothing now that sizing is bidirectional.
            guard let textStorage, textWidth > 0 else { return }
            // Skip a redundant re-measure at a width already estimated — a settle posts the
            // final width through several layout events, each of which would otherwise redo
            // the per-block pass. A freed floor (content swap, gesture start) or the attachment
            // path (which nils `lastEstimatedWidth`) still forces a recompute, since those
            // change the height at an unchanged width.
            guard textWidth != lastEstimatedWidth || estimatedHeightFloor == nil else { return }
            lastEstimatedWidth = textWidth
            // Per-block sum when a model is present (dodges the super-linear whole-document
            // measure — the open-time freeze on large, fallback-heavy docs), else whole-doc.
            // The cached total equals the old height-only estimate — `buildOffsets` only adds
            // the per-block array, never the total.
            let estimate: CGFloat
            if documentHeightModel != nil {
                // Any non-nil model routes through the shared offsets: the builder emits one
                // block span per rendered block, so empty blocks pair only with empty text —
                // both measure to 0, matching the whole-document fallback this replaced.
                // The cached pass is reusable when present — every height-changing event
                // (width change, attachment resolution, content swap) nils it, so a live
                // cache is already at the current geometry; recomputing would repeat the
                // measure a map rebuild just ran.
                guard let offsets = currentBlockOffsets() else { return }
                estimate = offsets.totalHeight
            } else {
                estimate = DocumentHeightEstimator.estimatedHeight(
                    of: textStorage, model: nil,
                    textWidth: textWidth, verticalInset: textContainerInset.height)
            }
            applyEstimatedHeightFloor(estimate)
        }

        private func applyEstimatedHeightFloor(_ floor: CGFloat) {
            estimatedHeightFloor = floor
            if abs(frame.height - floor) > 0.5 {
                setFrameSize(NSSize(width: frame.width, height: floor))
            }
        }

        /// The settle-time height recompute: exact when the document is fully
        /// materialized, the provisional floor while a progressive open's tail is
        /// still appending. Width settles (load, resize end, slide end) call this
        /// so a settle mid-tail can't collapse the scroller to the prefix height.
        func refreshSettledHeight() {
            if isProgressiveOpenActive {
                seedProvisionalEstimatedHeightFloor()
            } else {
                refreshEstimatedHeight()
            }
        }

        /// Size the frame from the parsed-blocks floor while the tail appends —
        /// the scroller then reflects roughly the whole document from first paint.
        /// Memoized by width like the exact estimate: a settle posts its final
        /// width through several layout events, and the estimate is an
        /// O(document characters) scan.
        func seedProvisionalEstimatedHeightFloor() {
            guard isProgressiveOpenActive, textWidth > 0, !printBlocks.isEmpty else { return }
            guard textWidth != lastEstimatedWidth || estimatedHeightFloor == nil else { return }
            lastEstimatedWidth = textWidth
            let floor = ProvisionalHeightEstimator.provisionalHeight(
                of: printBlocks, textWidth: textWidth,
                scaleFactor: progressiveOpenScaleFactor,
                verticalInset: textContainerInset.height
            )
            guard floor > 0 else { return }
            applyEstimatedHeightFloor(floor)
        }

        /// Per-block offsets at the current width — the cached pass if present, else computed
        /// once and cached. A Core Text per-block measure, accurate off-viewport where TextKit
        /// returns estimated frames; nil until a model and real width exist.
        func currentBlockOffsets() -> DocumentBlockOffsets? {
            blockOffsets ?? computeBlockOffsets()
        }

        /// Measure the per-block offsets at the current width and cache them, replacing any
        /// prior generation — the sole compute site.
        private func computeBlockOffsets() -> DocumentBlockOffsets? {
            guard let textStorage, let documentHeightModel, textWidth > 0 else { return nil }
            let offsets = DocumentBlockOffsets.compute(
                of: textStorage, model: documentHeightModel,
                textWidth: textWidth, verticalInset: textContainerInset.height)
            blockOffsets = offsets
            return offsets
        }

        /// Debounced ``refreshEstimatedHeight``. Attachment overlays (image, Mermaid,
        /// math) resolve their real heights asynchronously and in bursts, each firing a
        /// layout invalidation; coalesce those into a single re-estimate once they
        /// settle rather than re-measuring the whole string on every callback.
        func scheduleRefreshEstimatedHeight() {
            refreshHeightWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, self.canRefreshEstimatedHeight else { return }
                // Attachments resolved to new heights at an unchanged width; clear the
                // width memo so the re-estimate isn't skipped as redundant.
                self.lastEstimatedWidth = nil
                self.refreshEstimatedHeight()
            }
            refreshHeightWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Self.attachmentRefreshDebounce, execute: workItem
            )
        }

        // MARK: - Text Change Invalidation

        override func didChangeText() {
            super.didChangeText()
            invalidateCodeBlockCache()
        }

        /// Programmatic storage mutations (content install, progressive tail appends)
        /// never route through `didChangeText` — observe the storage directly.
        /// Character edits are what change the block list; attribute-only edits
        /// (attachment height resolution) leave ranges and colors intact and are
        /// handled by ``invalidateCodeBlockRects()`` at their call sites.
        nonisolated(unsafe) private var storageEditObserver: NSObjectProtocol?

        func observeTextStorageEdits() {
            guard storageEditObserver == nil, let textStorage else { return }
            storageEditObserver = NotificationCenter.default.addObserver(
                forName: NSTextStorage.didProcessEditingNotification,
                object: textStorage,
                queue: nil
            ) { [weak self] note in
                guard let storage = note.object as? NSTextStorage,
                      storage.editedMask.contains(.editedCharacters)
                else { return }
                MainActor.assumeIsolated {
                    self?.invalidateCodeBlockCache()
                }
            }
        }

        /// Full invalidation: the block list (ranges, colors) and the viewport rects.
        /// Only content edits change the list — geometry changes use
        /// ``invalidateCodeBlockRects()`` so they don't force the O(document)
        /// attribute re-enumeration (which otherwise runs per frame during a width
        /// gesture and per attachment-height report).
        func invalidateCodeBlockCache() {
            isCodeBlockCacheValid = false
            areBlockRectsValid = false
        }

        /// Geometry-only invalidation: fragment frames moved (width change, attachment
        /// height resolution), but the block ranges and colors are unchanged.
        func invalidateCodeBlockRects() {
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

        /// Pasting onto a selection authors a comment: the pasteboard text becomes
        /// the body, anchored to the selected span — so a dictation tool can drop
        /// a comment without touching the input box. The selection survives (a
        /// comment add is a sidecar-only repaint, no storage swap), so pasting
        /// again adds another comment on the same span.
        override func paste(_ sender: Any?) {
            guard let selection = commentableSelection(),
                  let tape = anchorTape,
                  let selector = CommentSelectorCapture.capture(builderRange: selection, in: tape),
                  let documentState,
                  let body = pasteboardCommentBody()
            else {
                super.paste(sender)
                return
            }
            pendingRevealCommentID = documentState.addComment(selector, body: body)
        }

        /// Enable Edit > Paste (Cmd+V) when a paste would author a comment — the
        /// read-only view otherwise reports paste invalid and the key does nothing.
        override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
            if item.action == #selector(paste(_:)) {
                return commentableSelection() != nil && pasteboardCommentBody() != nil
            }
            return super.validateUserInterfaceItem(item)
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
            // The print run swaps the storage and spins a modal runloop; an active
            // tail would append into the print canvas. Drain it first so the
            // restore below puts back the complete document.
            if isProgressiveOpenActive {
                forceFinishProgressiveOpen?()
            }
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
            // The print run lays out at page width; a rebuild during the modal could have
            // cached page-width offsets. Drop them so the screen reads fresh tops.
            blockOffsets = nil
            backgroundColor = savedBgColor
            resolvedComments = savedResolvedComments
        }
    }
#endif
