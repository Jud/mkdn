#if os(macOS)
    import AppKit
    import SwiftUI

    /// `NSViewRepresentable` wrapping a read-only, selectable `NSTextView` backed by
    /// TextKit 2 for continuous cross-block text selection in the preview pane.
    ///
    /// The text view displays an `NSAttributedString` produced by
    /// ``MarkdownTextStorageBuilder`` and supports native macOS selection behaviors:
    /// click-drag, Shift-click, Cmd+A, Cmd+C. Non-text elements (Mermaid diagrams,
    /// images) are represented by `NSTextAttachment` placeholders; overlays are
    /// positioned by the ``OverlayCoordinator``.
    ///
    /// The ``Coordinator`` owns an ``EntranceAnimator`` that enumerates layout
    /// fragments after content is set to apply staggered cover-layer animations.
    struct SelectableTextView: NSViewRepresentable {
        let attributedText: NSAttributedString
        let attachments: [AttachmentInfo]
        let blocks: [IndexedBlock]
        let theme: AppTheme
        let isFullReload: Bool
        let reduceMotion: Bool
        let appSettings: AppSettings
        let documentState: DocumentState
        let findQuery: String
        let findCurrentIndex: Int
        let findIsVisible: Bool
        let findState: FindState
        let outlineState: OutlineState
        let headingOffsets: [Int: Int]
        /// Per-block spans, for computing heading y-positions without TextKit layout.
        let documentHeightModel: DocumentHeightModel
        /// Comments resolved against the rendered text, drawn as a background fill.
        let resolvedComments: ResolvedComments?
        /// The rendered anchor tape, for capturing a selector when authoring.
        let anchorTape: AnchorTape?
        /// Bumped by the preview when only comments changed; swaps the resolved
        /// index and redraws — no storage edit, so the viewport never jumps.
        let commentRevision: Int
        @Binding var isLoadingGateActive: Bool

        // MARK: - NSViewRepresentable

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        func makeNSView(context: Context) -> NSScrollView {
            let (scrollView, textView) = Self.makeScrollableCodeBlockTextView()

            Self.configureTextView(textView)
            Self.configureScrollView(scrollView)

            let coordinator = context.coordinator
            coordinator.textView = textView
            coordinator.documentState = documentState
            coordinator.animator.textView = textView
            textView.delegate = coordinator
            coordinator.overlayCoordinator.onLayoutInvalidation = { [weak coordinator] in
                guard let coordinator else { return }
                if let textView = coordinator.textView as? CodeBlockBackgroundTextView {
                    // Attachment height changes shift fragment y-positions below: cached
                    // code-block geometry must be rebuilt, and the scroller re-estimated
                    // now that an attachment resolved its real height.
                    textView.invalidateCodeBlockCache()
                    textView.scheduleRefreshEstimatedHeight()
                }
                guard !coordinator.gate.isGateActive else { return }
                guard coordinator.animator.isAnimating else { return }
                coordinator.animator.animateVisibleFragments()
                coordinator.overlayCoordinator.applyEntranceAnimation(
                    attachmentDelays: coordinator.animator.attachmentDelays,
                    fadeInDuration: AnimationConstants.fadeInDuration
                )
            }
            (scrollView as? LiveResizeScrollView)?.overlayCoordinator =
                coordinator.overlayCoordinator

            coordinator.outlineState = outlineState
            coordinator.headingOffsets = headingOffsets
            coordinator.documentHeightModel = documentHeightModel

            applyTheme(to: textView, scrollView: scrollView)
            textView.findState = findState
            textView.printBlocks = blocks
            textView.resolvedComments = resolvedComments
            textView.anchorTape = anchorTape
            textView.documentState = documentState
            textView.commentTheme = theme

            textView.textStorage?.setAttributedString(attributedText)
            textView.realizeViewportAfterContainerResize(hardInvalidate: false)
            textView.refreshEstimatedHeight()
            textView.window?.invalidateCursorRects(for: textView)
            applyEntranceOrGate(
                coordinator: coordinator, textView: textView, scrollView: scrollView
            )
            coordinator.lastAppliedText = attributedText
            coordinator.lastCommentRevision = commentRevision
            coordinator.wireScrollSpy()
            RenderCompletionSignal.shared.signalRenderComplete()

            return scrollView
        }

        func updateNSView(_ scrollView: NSScrollView, context: Context) {
            guard let textView = scrollView.documentView as? CodeBlockBackgroundTextView else {
                return
            }

            let coordinator = context.coordinator
            if coordinator.headingOffsets != headingOffsets {
                coordinator.headingOffsets = headingOffsets
                coordinator.documentHeightModel = documentHeightModel
                coordinator.invalidateHeadingPositionCache()
            }

            applyTheme(to: textView, scrollView: scrollView)
            textView.findState = findState
            textView.printBlocks = blocks
            textView.resolvedComments = resolvedComments
            textView.anchorTape = anchorTape
            textView.documentState = documentState
            textView.commentTheme = theme

            let isNewContent = coordinator.lastAppliedText !== attributedText
            if isNewContent {
                applyNewContent(
                    coordinator: coordinator, textView: textView, scrollView: scrollView
                )
            } else if coordinator.lastCommentRevision != commentRevision {
                coordinator.lastCommentRevision = commentRevision
                repaintCommentHighlights(textView: textView)
            }

            coordinator.handleFindUpdate(
                findQuery: findQuery,
                findCurrentIndex: findCurrentIndex,
                findIsVisible: findIsVisible,
                findState: findState,
                theme: theme,
                isNewContent: isNewContent
            )

            // Consume pending scroll-to-heading target from outline navigation.
            // Skip if already scrolled to this target to prevent double-scroll.
            if let targetBlockIndex = outlineState.pendingScrollTarget,
               targetBlockIndex != coordinator.lastScrolledTarget
            {
                coordinator.lastScrolledTarget = targetBlockIndex
                coordinator.scrollToHeading(blockIndex: targetBlockIndex, in: scrollView)
                Task { @MainActor in
                    outlineState.pendingScrollTarget = nil
                }
            }
        }
    }

    // MARK: - View Configuration

    extension SelectableTextView {
        private static func makeScrollableCodeBlockTextView() -> (
            NSScrollView, CodeBlockBackgroundTextView
        ) {
            // A non-simple container makes NSTextLayoutManager lay out contiguously
            // from the top rather than lazily with estimated off-viewport heights —
            // the lazy path leaves the document-view frame height unstable (TextKit
            // keeps re-asserting a smaller estimate), which makes a scroll after a
            // width reflow snap. widthTracksTextView is unreliable for a non-simple
            // container, so the width is set explicitly via `syncTextContainerSize`.
            let textContainer = ContiguousTextContainer(
                size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            )
            textContainer.widthTracksTextView = false
            textContainer.heightTracksTextView = false

            let layoutManager = NSTextLayoutManager()
            layoutManager.textContainer = textContainer

            let contentStorage = NSTextContentStorage()
            contentStorage.addTextLayoutManager(layoutManager)

            let textView = CodeBlockBackgroundTextView(
                frame: .zero,
                textContainer: textContainer
            )
            textView.autoresizingMask = [.width]
            textView.minSize = NSSize(width: 0, height: 0)
            textView.maxSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )

            let scrollView = LiveResizeScrollView()
            scrollView.documentView = textView

            return (scrollView, textView)
        }

        private static func configureTextView(_ textView: NSTextView) {
            textView.wantsLayer = true
            textView.layerContentsRedrawPolicy = .duringViewResize
            textView.isEditable = false
            textView.isSelectable = true
            textView.drawsBackground = true
            textView.usesFontPanel = false
            textView.usesRuler = false
            textView.allowsUndo = false
            textView.isAutomaticLinkDetectionEnabled = false
            textView.textContainerInset = NSSize(width: 32, height: 32)
            textView.isRichText = true
            textView.isHorizontallyResizable = false
            textView.isVerticallyResizable = true
            // The non-simple container doesn't track the view width; size it now that
            // the inset is set, then keep it in sync from setFrameSize.
            (textView as? CodeBlockBackgroundTextView)?.syncTextContainerSize()
            textView.isAutomaticSpellingCorrectionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
        }

        private static func configureScrollView(_ scrollView: NSScrollView) {
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true
            scrollView.automaticallyAdjustsContentInsets = false
            scrollView.layerContentsRedrawPolicy = .duringViewResize
            scrollView.contentView.layerContentsRedrawPolicy = .duringViewResize
        }

        private func applyNewContent(
            coordinator: Coordinator,
            textView: CodeBlockBackgroundTextView,
            scrollView: NSScrollView
        ) {
            let textChanged = textView.textStorage?.string != attributedText.string

            coordinator.gate.reset()
            coordinator.lastScrolledTarget = nil
            isLoadingGateActive = false
            scrollView.alphaValue = 1

            if !isFullReload {
                coordinator.animator.reset()
            }

            coordinator.overlayCoordinator.hideAllOverlays()
            // Stop any in-flight footnote pulse before swapping storage; its
            // delayed fade would otherwise write stale ranges into new content.
            coordinator.cancelFootnotePulse()
            // Likewise stop an in-flight jump scroll; it targets the old layout and
            // would yank the viewport after the swap resets it.
            textView.cancelCommentScroll()
            // A content swap invalidates the captured anchor's text location; drop it
            // so an in-flight sidebar slide's tile() doesn't re-pin against the
            // replaced document (the stale NSTextLocation would enumerate out of range).
            textView.sidebarResizeAnchor = nil
            textView.estimatedHeightFloor = nil
            // Dismiss an open comment overlay; its position points into the old
            // layout and its body may no longer match the new content. A body edit
            // from the popover only changed the sidecar (layout unchanged), so it
            // asks to keep the overlay through that one rebuild.
            if textView.keepCommentOverlayThroughRebuild {
                textView.keepCommentOverlayThroughRebuild = false
                // Clear any row-hover emphasis before the storage swap; otherwise
                // the stale hovered id paints onto the rebuilt content.
                textView.setHoveredComment(nil)
            } else {
                textView.dismissCommentOverlay()
            }
            textView.textStorage?.setAttributedString(attributedText)
            textView.realizeViewportAfterContainerResize(hardInvalidate: false)
            textView.refreshEstimatedHeight()
            textView.window?.invalidateCursorRects(for: textView)

            if textChanged {
                textView.setSelectedRange(NSRange(location: 0, length: 0))
                scrollView.contentView.scroll(to: .zero)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }

            applyEntranceOrGate(
                coordinator: coordinator, textView: textView, scrollView: scrollView
            )
            coordinator.lastAppliedText = attributedText
            RenderCompletionSignal.shared.signalRenderComplete()
        }

        /// Apply a comment-only change (visible text unchanged) by swapping the
        /// resolved-comment index and redrawing the viewport. No storage edit, so no
        /// attachment re-estimation and no scroll jump — the whole point of drawing
        /// comments instead of baking them.
        private func repaintCommentHighlights(textView: CodeBlockBackgroundTextView) {
            textView.resolvedComments = resolvedComments
            // The rebuild path clears hover emphasis before swapping; this path
            // skips that, so clear it here or a hovered row stays emphasized.
            textView.setHoveredComment(nil)
            // The add-comment flow sets this expecting applyNewContent to consume
            // it; the comment-only path skips that pass, so clear it here.
            textView.keepCommentOverlayThroughRebuild = false
            textView.setNeedsDisplay(textView.enclosingScrollView?.documentVisibleRect ?? textView.bounds)
            textView.commentBadgeOverlay?.needsDisplay = true
            RenderCompletionSignal.shared.signalRenderComplete()
        }

        private func applyEntranceOrGate(
            coordinator: Coordinator,
            textView: NSTextView,
            scrollView: NSScrollView
        ) {
            let hasAsyncOverlay = attachments.contains(where: \.block.isAsync)
            let shouldGate = isFullReload && !reduceMotion && hasAsyncOverlay
            if shouldGate {
                textView.alphaValue = 0
                scrollView.alphaValue = 0
                refreshOverlays(coordinator: coordinator, in: textView)
                wireGate(coordinator: coordinator, textView: textView, scrollView: scrollView)
                if coordinator.overlayCoordinator.viewportOverlaysReady(in: scrollView) {
                    coordinator.gate.markReady()
                }
            } else {
                if isFullReload {
                    coordinator.animator.beginEntrance(reduceMotion: reduceMotion)
                }
                refreshOverlays(coordinator: coordinator, in: textView)
                coordinator.animator.animateVisibleFragments()
                if coordinator.animator.isAnimating {
                    coordinator.overlayCoordinator.applyEntranceAnimation(
                        attachmentDelays: coordinator.animator.attachmentDelays,
                        fadeInDuration: AnimationConstants.fadeInDuration
                    )
                }
            }
        }

        private func wireGate(
            coordinator: Coordinator,
            textView: NSTextView,
            scrollView: NSScrollView
        ) {
            coordinator.gate.reset()
            coordinator.gate.beginGate()
            isLoadingGateActive = true
            let loadingBinding = _isLoadingGateActive

            coordinator.overlayCoordinator.onOverlayReady = { [weak coordinator] in
                guard let coordinator else { return }
                if coordinator.overlayCoordinator.viewportOverlaysReady(in: scrollView) {
                    coordinator.gate.markReady()
                }
            }

            coordinator.gate.onReady = { [weak coordinator] in
                guard let coordinator else { return }
                loadingBinding.wrappedValue = false
                scrollView.alphaValue = 1
                textView.alphaValue = 1
                coordinator.animator.beginEntrance(reduceMotion: false)
                coordinator.animator.animateVisibleFragments()
                if coordinator.animator.isAnimating {
                    coordinator.overlayCoordinator.applyEntranceAnimation(
                        attachmentDelays: coordinator.animator.attachmentDelays,
                        fadeInDuration: AnimationConstants.fadeInDuration
                    )
                }
            }
        }

        private func refreshOverlays(coordinator: Coordinator, in textView: NSTextView) {
            coordinator.overlayCoordinator.findState = findState
            coordinator.overlayCoordinator.updateOverlays(
                attachments: attachments,
                appSettings: appSettings,
                documentState: documentState,
                in: textView
            )
        }

        private func applyTheme(
            to textView: NSTextView,
            scrollView: NSScrollView
        ) {
            let colors = theme.colors
            let bgColor = PlatformTypeConverter.color(from: colors.background)
            let accentColor = PlatformTypeConverter.color(from: colors.accent)

            textView.backgroundColor = bgColor
            scrollView.backgroundColor = bgColor
            scrollView.drawsBackground = true

            textView.selectedTextAttributes = [
                .backgroundColor: accentColor.withAlphaComponent(0.3),
            ]

            textView.insertionPointColor = accentColor

            let linkNSColor = PlatformTypeConverter.color(from: colors.linkColor)
            textView.linkTextAttributes = [
                .foregroundColor: linkNSColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .cursor: NSCursor.pointingHand,
            ]
        }
    }

    // MARK: - Contiguous Text Container

    /// Reports `isSimpleRectangularTextContainer == false` so `NSTextLayoutManager`
    /// lays out contiguously from the top instead of the default lazy, non-contiguous
    /// viewport layout with estimated off-viewport heights. The estimated path leaves
    /// the document-view frame height unstable (TextKit re-asserts a smaller estimate
    /// after a reflow), which makes a post-reflow scroll snap. The trade is synchronous
    /// full-document layout; the container width must be set explicitly (see
    /// ``CodeBlockBackgroundTextView/syncTextContainerSize(forViewWidth:)``).
    private final class ContiguousTextContainer: NSTextContainer {
        override var isSimpleRectangularTextContainer: Bool { false }
    }

    // MARK: - Live Resize Scroll View

    /// NSScrollView subclass that forces TextKit 2 to lay out text in the visible
    /// viewport during live window resize. Without this, the viewport layout
    /// controller defers text layout for newly-exposed areas until resize ends,
    /// causing blank regions while dragging.
    private final class LiveResizeScrollView: NSScrollView {
        weak var overlayCoordinator: OverlayCoordinator?
        private var liveResizeBoundsOrigin: NSPoint?

        override var preservesContentDuringLiveResize: Bool { true }

        override func viewWillStartLiveResize() {
            super.viewWillStartLiveResize()
            overlayCoordinator?.enterLiveResize()
            // The estimate is for the old width; free the height for the drag.
            (documentView as? CodeBlockBackgroundTextView)?.estimatedHeightFloor = nil
        }

        override func tile() {
            super.tile()
            // Same per-frame viewport layout as the live-resize path, but anchored to
            // a text line rather than a scroll point so the reflow doesn't drift
            // vertically.
            if let textView = documentView as? CodeBlockBackgroundTextView,
               textView.sidebarResizeAnchor != nil
            {
                textView.restoreSidebarResizeAnchor()
                overlayCoordinator?.repositionOverlays()
                return
            }
            // Backstop: viewDidEndLiveResize doesn't always fire (focus loss,
            // window close mid-drag). If the flag drifted out of sync, drain
            // here so deferred heights don't pile up forever.
            if !inLiveResize {
                overlayCoordinator?.exitLiveResize()
            }
            guard inLiveResize,
                  let textView = documentView as? NSTextView
            else { return }
            textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
            // Reposition overlays in the same frame as the text repaints,
            // not on the next runloop turn via the frame-change observer.
            overlayCoordinator?.repositionOverlays()
            liveResizeBoundsOrigin = contentView.bounds.origin
        }

        override func viewDidEndLiveResize() {
            super.viewDidEndLiveResize()
            // exitLiveResize drains any queued heights and runs a final
            // layoutViewport + repositionOverlays so overlays sit on the
            // settled fragments before the scroll-origin restore below.
            overlayCoordinator?.exitLiveResize()
            // Re-estimate the height at the settled width so the scroller is right.
            (documentView as? CodeBlockBackgroundTextView)?.refreshEstimatedHeight()

            if let savedOrigin = liveResizeBoundsOrigin {
                contentView.setBoundsOrigin(savedOrigin)
                reflectScrolledClipView(contentView)
                liveResizeBoundsOrigin = nil
            }
        }
    }
#endif
