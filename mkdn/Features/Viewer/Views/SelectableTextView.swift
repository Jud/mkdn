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
        let criticDocument: CriticMarkupDocument?
        let commentSourceMap: SourceMap
        /// The built text *without* comment highlights, used to re-derive them on
        /// a comment-only change without a rebuild.
        let baseAttributedText: NSAttributedString
        /// Bumped by the preview when only comments changed; drives a live
        /// highlight repaint instead of replacing the attributed string.
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
                // Attachment height changes shift fragment y-positions below;
                // code-block geometry cached in viewWillDraw must be rebuilt.
                (coordinator.textView as? CodeBlockBackgroundTextView)?
                    .invalidateCodeBlockCache()
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

            applyTheme(to: textView, scrollView: scrollView)
            textView.findState = findState
            textView.printBlocks = blocks
            textView.criticDocument = criticDocument
            textView.commentSourceMap = commentSourceMap
            textView.documentState = documentState
            textView.commentTheme = theme

            textView.textStorage?.setAttributedString(attributedText)
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
                coordinator.invalidateHeadingPositionCache()
            }

            applyTheme(to: textView, scrollView: scrollView)
            textView.findState = findState
            textView.printBlocks = blocks
            textView.criticDocument = criticDocument
            textView.commentSourceMap = commentSourceMap
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
            let textContainer = NSTextContainer()
            textContainer.widthTracksTextView = true

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
            textView.textContainer?.widthTracksTextView = true
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

        /// Repaint comment highlights on the LIVE text storage for a comment-only
        /// change (visible text unchanged). Re-derives highlights from the
        /// un-highlighted base and syncs only `.backgroundColor` + `.mkdnCommentID`
        /// onto the storage — an attribute-only edit that recreates no attachments,
        /// so the document doesn't relayout and the viewport doesn't jump.
        private func repaintCommentHighlights(textView: CodeBlockBackgroundTextView) {
            guard let storage = textView.textStorage,
                  storage.length == baseAttributedText.length
            else { return }

            let highlighted = NSMutableAttributedString(attributedString: baseAttributedText)
            if let document = criticDocument, !document.comments.isEmpty {
                MarkdownTextStorageBuilder.applyCommentHighlights(
                    to: highlighted,
                    document: document,
                    sourceMap: commentSourceMap,
                    color: PlatformTypeConverter.color(from: theme.colors.commentHighlight)
                )
            }

            // Only touch the ranges whose comment state actually changed (old
            // highlighted ∪ new highlighted). Editing `.backgroundColor` over the
            // whole document invalidates every fragment and re-estimates attachment
            // heights — the very relayout/jump we're avoiding. Within each dirty
            // range, sync both attributes from `highlighted` (base + comments), so
            // a removed comment restores the base inline-code background underneath.
            let full = NSRange(location: 0, length: storage.length)
            var dirty: [NSRange] = []
            storage.enumerateAttribute(.mkdnCommentID, in: full, options: []) { value, range, _ in
                if value != nil { dirty.append(range) }
            }
            highlighted.enumerateAttribute(.mkdnCommentID, in: full, options: []) { value, range, _ in
                if value != nil { dirty.append(range) }
            }
            guard !dirty.isEmpty else { return }

            storage.beginEditing()
            for range in dirty {
                storage.removeAttribute(.backgroundColor, range: range)
                storage.removeAttribute(.mkdnCommentID, range: range)
                highlighted.enumerateAttribute(.backgroundColor, in: range, options: []) { value, sub, _ in
                    if let value { storage.addAttribute(.backgroundColor, value: value, range: sub) }
                }
                highlighted.enumerateAttribute(.mkdnCommentID, in: range, options: []) { value, sub, _ in
                    if let value { storage.addAttribute(.mkdnCommentID, value: value, range: sub) }
                }
            }
            storage.endEditing()

            // The add-comment flow sets this expecting applyNewContent to consume
            // it; the comment-only path skips that pass, so clear it here.
            textView.keepCommentOverlayThroughRebuild = false
            textView.needsDisplay = true
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
        }

        override func tile() {
            super.tile()
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

            if let savedOrigin = liveResizeBoundsOrigin {
                contentView.setBoundsOrigin(savedOrigin)
                reflectScrolledClipView(contentView)
                liveResizeBoundsOrigin = nil
            }
        }
    }
#endif
