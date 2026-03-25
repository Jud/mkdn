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
                guard !coordinator.gate.isGateActive else { return }
                guard coordinator.animator.isAnimating else { return }
                coordinator.animator.animateVisibleFragments()
                coordinator.overlayCoordinator.applyEntranceAnimation(
                    attachmentDelays: coordinator.animator.attachmentDelays,
                    fadeInDuration: AnimationConstants.fadeInDuration
                )
            }

            coordinator.outlineState = outlineState
            coordinator.headingOffsets = headingOffsets

            applyTheme(to: textView, scrollView: scrollView)
            textView.findState = findState
            textView.printBlocks = blocks

            textView.textStorage?.setAttributedString(attributedText)
            textView.window?.invalidateCursorRects(for: textView)
            applyEntranceOrGate(
                coordinator: coordinator, textView: textView, scrollView: scrollView
            )
            coordinator.lastAppliedText = attributedText
            coordinator.startScrollSpy(on: scrollView)
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

            let isNewContent = coordinator.lastAppliedText !== attributedText
            if isNewContent {
                applyNewContent(
                    coordinator: coordinator, textView: textView, scrollView: scrollView
                )
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
        private var liveResizeBoundsOrigin: NSPoint?

        override func tile() {
            super.tile()
            guard inLiveResize,
                  let textView = documentView as? NSTextView
            else { return }
            textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
            liveResizeBoundsOrigin = contentView.bounds.origin
        }

        override func viewDidEndLiveResize() {
            super.viewDidEndLiveResize()
            guard let textView = documentView as? NSTextView else { return }
            textView.textLayoutManager?.textViewportLayoutController.layoutViewport()

            if let savedOrigin = liveResizeBoundsOrigin {
                contentView.setBoundsOrigin(savedOrigin)
                reflectScrolledClipView(contentView)
                liveResizeBoundsOrigin = nil
            }
        }
    }
#endif
