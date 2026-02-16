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
        coordinator.animator.textView = textView

        applyTheme(to: textView, scrollView: scrollView)
        textView.findState = findState
        textView.printBlocks = blocks

        if isFullReload {
            coordinator.animator.beginEntrance(reduceMotion: reduceMotion)
        }

        textView.textStorage?.setAttributedString(attributedText)
        textView.window?.invalidateCursorRects(for: textView)
        coordinator.animator.animateVisibleFragments()

        coordinator.overlayCoordinator.updateOverlays(
            attachments: attachments,
            appSettings: appSettings,
            documentState: documentState,
            in: textView
        )
        coordinator.lastAppliedText = attributedText
        RenderCompletionSignal.shared.signalRenderComplete()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CodeBlockBackgroundTextView else {
            return
        }

        let coordinator = context.coordinator

        applyTheme(to: textView, scrollView: scrollView)
        textView.findState = findState
        textView.printBlocks = blocks

        let isNewContent = coordinator.lastAppliedText !== attributedText
        if isNewContent {
            if isFullReload {
                coordinator.animator.beginEntrance(reduceMotion: reduceMotion)
            } else {
                coordinator.animator.reset()
            }

            textView.textStorage?.setAttributedString(attributedText)
            textView.window?.invalidateCursorRects(for: textView)
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            coordinator.animator.animateVisibleFragments()

            coordinator.overlayCoordinator.updateOverlays(
                attachments: attachments,
                appSettings: appSettings,
                documentState: documentState,
                in: textView
            )
            coordinator.lastAppliedText = attributedText
            RenderCompletionSignal.shared.signalRenderComplete()
        }

        coordinator.handleFindUpdate(
            findQuery: findQuery,
            findCurrentIndex: findCurrentIndex,
            findIsVisible: findIsVisible,
            findState: findState,
            theme: theme,
            isNewContent: isNewContent
        )
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
        scrollView.layerContentsRedrawPolicy = .duringViewResize
        scrollView.contentView.layerContentsRedrawPolicy = .duringViewResize
    }

    private func applyTheme(
        to textView: NSTextView,
        scrollView: NSScrollView
    ) {
        let colors = theme.colors
        let bgColor = PlatformTypeConverter.nsColor(from: colors.background)
        let accentColor = PlatformTypeConverter.nsColor(from: colors.accent)
        let fgColor = PlatformTypeConverter.nsColor(from: colors.foreground)

        textView.backgroundColor = bgColor
        scrollView.backgroundColor = bgColor
        scrollView.drawsBackground = true

        textView.selectedTextAttributes = [
            .backgroundColor: accentColor.withAlphaComponent(0.3),
            .foregroundColor: fgColor,
        ]

        textView.insertionPointColor = accentColor

        let linkNSColor = PlatformTypeConverter.nsColor(from: colors.linkColor)
        textView.linkTextAttributes = [
            .foregroundColor: linkNSColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand,
        ]
    }
}

// MARK: - Coordinator

extension SelectableTextView {
    @MainActor
    final class Coordinator: NSObject {
        weak var textView: NSTextView?
        let animator = EntranceAnimator()
        let overlayCoordinator = OverlayCoordinator()
        var lastAppliedText: NSAttributedString?

        // MARK: - Find State Tracking

        var lastFindQuery = ""
        var lastFindIndex = 0
        var lastFindVisible = false
        var lastHighlightedRanges: [NSRange] = []
        var lastFindTheme: AppTheme?

        // MARK: - Find Highlight Integration

        func handleFindUpdate(
            findQuery: String,
            findCurrentIndex: Int,
            findIsVisible: Bool,
            findState: FindState,
            theme: AppTheme,
            isNewContent: Bool
        ) {
            guard let textView else { return }

            if findIsVisible {
                let queryChanged = findQuery != lastFindQuery
                let indexChanged = findCurrentIndex != lastFindIndex
                let themeChanged = theme != lastFindTheme
                let becameVisible = !lastFindVisible

                if queryChanged || isNewContent || becameVisible {
                    applyFindHighlights(
                        findState: findState,
                        textView: textView,
                        theme: theme,
                        performSearch: true
                    )
                } else if indexChanged || themeChanged {
                    applyFindHighlights(
                        findState: findState,
                        textView: textView,
                        theme: theme,
                        performSearch: false
                    )
                }
            } else if lastFindVisible {
                clearFindHighlights(textView: textView)
                textView.window?.makeFirstResponder(textView)
            }

            lastFindQuery = findQuery
            lastFindIndex = findCurrentIndex
            lastFindVisible = findIsVisible
            lastFindTheme = theme
        }

        private func applyFindHighlights(
            findState: FindState,
            textView: NSTextView,
            theme: AppTheme,
            performSearch: Bool
        ) {
            guard let layoutManager = textView.textLayoutManager,
                  let contentManager = layoutManager.textContentManager
            else { return }

            clearRenderingAttributes(
                layoutManager: layoutManager,
                contentManager: contentManager
            )

            if performSearch {
                let text = textView.textStorage?.string ?? ""
                findState.performSearch(in: text)
            }

            guard !findState.matchRanges.isEmpty else {
                lastHighlightedRanges = []
                return
            }

            let accentNSColor = PlatformTypeConverter.nsColor(
                from: theme.colors.accent
            )

            for (index, range) in findState.matchRanges.enumerated() {
                let alpha: CGFloat =
                    (index == findState.currentMatchIndex) ? 0.4 : 0.15
                if let textRange = Self.textRange(
                    from: range,
                    contentManager: contentManager
                ) {
                    layoutManager.setRenderingAttributes(
                        [.backgroundColor: accentNSColor.withAlphaComponent(alpha)],
                        for: textRange
                    )
                }
            }

            lastHighlightedRanges = findState.matchRanges

            if let currentRange =
                findState.matchRanges[safe: findState.currentMatchIndex]
            {
                textView.scrollRangeToVisible(currentRange)
            }
        }

        private func clearFindHighlights(textView: NSTextView) {
            guard let layoutManager = textView.textLayoutManager,
                  let contentManager = layoutManager.textContentManager
            else { return }

            clearRenderingAttributes(
                layoutManager: layoutManager,
                contentManager: contentManager
            )
            lastHighlightedRanges = []
        }

        private func clearRenderingAttributes(
            layoutManager: NSTextLayoutManager,
            contentManager: NSTextContentManager
        ) {
            for range in lastHighlightedRanges {
                if let textRange = Self.textRange(
                    from: range,
                    contentManager: contentManager
                ) {
                    layoutManager.setRenderingAttributes([:], for: textRange)
                }
            }
        }

        private static func textRange(
            from nsRange: NSRange,
            contentManager: NSTextContentManager
        ) -> NSTextRange? {
            guard let start = contentManager.location(
                contentManager.documentRange.location,
                offsetBy: nsRange.location
            ),
                let end = contentManager.location(
                    start,
                    offsetBy: nsRange.length
                )
            else { return nil }
            return NSTextRange(location: start, end: end)
        }
    }
}

// MARK: - Safe Collection Subscript

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
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
