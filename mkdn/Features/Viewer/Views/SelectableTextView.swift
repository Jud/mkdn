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
    let tableOverlays: [TableOverlayInfo]
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
        coordinator.documentState = documentState
        coordinator.animator.textView = textView
        textView.delegate = coordinator

        applyTheme(to: textView, scrollView: scrollView)
        textView.findState = findState
        textView.printBlocks = blocks

        if isFullReload {
            coordinator.animator.beginEntrance(reduceMotion: reduceMotion)
        }

        textView.textStorage?.setAttributedString(attributedText)
        textView.window?.invalidateCursorRects(for: textView)
        coordinator.animator.animateVisibleFragments()

        refreshOverlays(coordinator: coordinator, in: textView)
        coordinator.lastAppliedText = attributedText
        RenderCompletionSignal.shared.signalRenderComplete()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CodeBlockBackgroundTextView else {
            return
        }

        let coordinator = context.coordinator

        if let lastTheme = coordinator.lastAppliedTheme, lastTheme != theme {
            let transition = CATransition()
            transition.type = .fade
            transition.duration = reduceMotion ? 0.15 : 0.35
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            scrollView.layer?.add(transition, forKey: "themeTransition")
        }
        coordinator.lastAppliedTheme = theme

        applyTheme(to: textView, scrollView: scrollView)
        textView.findState = findState
        textView.printBlocks = blocks

        let isNewContent = coordinator.lastAppliedText !== attributedText
        if isNewContent {
            let textChanged = textView.textStorage?.string != attributedText.string

            if isFullReload {
                coordinator.animator.beginEntrance(reduceMotion: reduceMotion)
            } else {
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

            coordinator.animator.animateVisibleFragments()

            refreshOverlays(coordinator: coordinator, in: textView)
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

    private func refreshOverlays(coordinator: Coordinator, in textView: NSTextView) {
        coordinator.overlayCoordinator.updateOverlays(
            attachments: attachments,
            appSettings: appSettings,
            documentState: documentState,
            in: textView
        )
        coordinator.overlayCoordinator.updateTableOverlays(
            tableOverlays: tableOverlays,
            appSettings: appSettings,
            in: textView
        )
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
    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
        weak var documentState: DocumentState?
        let animator = EntranceAnimator()
        let overlayCoordinator = OverlayCoordinator()
        var lastAppliedText: NSAttributedString?
        var lastAppliedTheme: AppTheme?

        // MARK: - Link Navigation

        func textView(
            _: NSTextView,
            clickedOnLink link: Any,
            at _: Int
        ) -> Bool {
            let url: URL
            if let linkURL = link as? URL {
                url = linkURL
            } else if let linkString = link as? String,
                      let parsed = URL(string: linkString)
            {
                url = parsed
            } else {
                return false
            }

            if url.scheme == nil, url.path.isEmpty {
                return true
            }

            let destination = LinkNavigationHandler.classify(
                url: url,
                relativeTo: documentState?.currentFileURL
            )

            let isCmdClick = NSApp.currentEvent?.modifierFlags.contains(.command) == true

            switch destination {
            case let .localMarkdown(resolvedURL):
                if isCmdClick {
                    FileOpenCoordinator.shared.pendingURLs.append(resolvedURL)
                } else {
                    try? documentState?.loadFile(at: resolvedURL)
                }
            case let .external(externalURL):
                NSWorkspace.shared.open(externalURL)
            case let .otherLocalFile(fileURL):
                NSWorkspace.shared.open(fileURL)
            }

            return true
        }

        // MARK: - Selection Change

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let selectedRange = textView.selectedRanges.first
            else { return }

            overlayCoordinator.updateTableSelections(
                selectedRange: selectedRange.rangeValue
            )
        }

        // MARK: - Find State Tracking

        var lastFindQuery = ""
        var lastFindIndex = 0
        var lastFindVisible = false
        var lastHighlightedRanges: [NSRange] = []
        var savedBackgrounds: [(range: NSRange, color: NSColor?)] = []
        var lastFindTheme: AppTheme?
        private var highlightFadeTask: Task<Void, Never>?

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

            if isNewContent {
                savedBackgrounds = []
            }

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
                overlayCoordinator.updateTableFindHighlights(
                    matchRanges: findState.matchRanges,
                    currentIndex: findState.currentMatchIndex
                )
            } else if lastFindVisible {
                clearFindHighlights(textView: textView)
                DispatchQueue.main.async {
                    textView.window?.makeFirstResponder(textView)
                }
            }

            lastFindQuery = findQuery
            lastFindIndex = findCurrentIndex
            lastFindVisible = findIsVisible
            lastFindTheme = theme
        }

        // MARK: - Text Storage Highlight Strategy

        //
        // Uses direct NSTextStorage attribute modifications instead of
        // NSTextLayoutManager.setRenderingAttributes. Rendering attributes
        // don't trigger re-rendering of cached TextKit 2 layout fragments,
        // but text storage edits do.

        private func applyFindHighlights(
            findState: FindState,
            textView: NSTextView,
            theme: AppTheme,
            performSearch: Bool
        ) {
            highlightFadeTask?.cancel()
            highlightFadeTask = nil

            guard let textStorage = textView.textStorage else { return }

            if performSearch {
                findState.performSearch(in: textStorage.string)
            }

            guard !findState.matchRanges.isEmpty else {
                restoreBackgrounds(in: textStorage)
                lastHighlightedRanges = []
                ensureLayoutAndRepositionOverlays(textView: textView)
                return
            }

            let highlightNSColor = PlatformTypeConverter.nsColor(
                from: theme.colors.findHighlight
            )

            textStorage.beginEditing()

            for saved in savedBackgrounds {
                guard saved.range.location + saved.range.length <= textStorage.length
                else { continue }
                if let color = saved.color {
                    textStorage.addAttribute(
                        .backgroundColor, value: color, range: saved.range
                    )
                } else {
                    textStorage.removeAttribute(
                        .backgroundColor, range: saved.range
                    )
                }
            }
            savedBackgrounds = []

            // Save original backgrounds for the new match ranges
            // (safe to read mid-edit since old highlights are already restored)
            saveBackgrounds(for: findState.matchRanges, in: textStorage)

            for (index, range) in findState.matchRanges.enumerated() {
                let alpha: CGFloat =
                    (index == findState.currentMatchIndex) ? 0.4 : 0.15
                textStorage.addAttribute(
                    .backgroundColor,
                    value: highlightNSColor.withAlphaComponent(alpha),
                    range: range
                )
            }

            textStorage.endEditing()

            lastHighlightedRanges = findState.matchRanges
            ensureLayoutAndRepositionOverlays(textView: textView)

            if let currentRange =
                findState.matchRanges[safe: findState.currentMatchIndex]
            {
                textView.scrollRangeToVisible(currentRange)
            }
        }

        private func clearFindHighlights(textView: NSTextView) {
            overlayCoordinator.updateTableFindHighlights(
                matchRanges: [],
                currentIndex: 0
            )

            guard let textStorage = textView.textStorage,
                  !lastHighlightedRanges.isEmpty
            else { return }

            highlightFadeTask?.cancel()
            let rangeColors = collectHighlightColors(from: textStorage)
            lastHighlightedRanges = []

            guard !rangeColors.isEmpty,
                  !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            else {
                restoreBackgrounds(in: textStorage)
                ensureLayoutAndRepositionOverlays(textView: textView)
                return
            }

            let fadeSteps = 4
            let stepNanos: UInt64 = 40_000_000 // 40ms per step = 160ms total

            highlightFadeTask = Task { @MainActor [weak self] in
                for step in 1 ... fadeSteps {
                    try? await Task.sleep(nanoseconds: stepNanos)
                    guard !Task.isCancelled else { return }
                    guard textStorage.length > 0 else { break }

                    let progress = CGFloat(step) / CGFloat(fadeSteps)
                    textStorage.beginEditing()
                    for (range, color) in rangeColors {
                        guard range.location + range.length <= textStorage.length
                        else { continue }
                        let fadedAlpha = color.alphaComponent * (1.0 - progress)
                        textStorage.addAttribute(
                            .backgroundColor,
                            value: color.withAlphaComponent(fadedAlpha),
                            range: range
                        )
                    }
                    textStorage.endEditing()
                    self?.ensureLayoutAndRepositionOverlays(textView: textView)
                }

                guard !Task.isCancelled, let self else { return }
                restoreBackgrounds(in: textStorage)
                ensureLayoutAndRepositionOverlays(textView: textView)
            }
        }

        private func collectHighlightColors(
            from textStorage: NSTextStorage
        ) -> [(range: NSRange, color: NSColor)] {
            var results: [(range: NSRange, color: NSColor)] = []
            for range in lastHighlightedRanges {
                guard range.location + range.length <= textStorage.length,
                      let color = textStorage.attribute(
                          .backgroundColor,
                          at: range.location,
                          effectiveRange: nil
                      ) as? NSColor
                else { continue }
                results.append((range: range, color: color))
            }
            return results
        }

        private func ensureLayoutAndRepositionOverlays(textView: NSTextView) {
            if let layoutManager = textView.textLayoutManager {
                layoutManager.ensureLayout(for: layoutManager.documentRange)
            }
            overlayCoordinator.repositionOverlays()
        }

        // MARK: - Theme Crossfade

        private func saveBackgrounds(
            for ranges: [NSRange],
            in textStorage: NSTextStorage
        ) {
            savedBackgrounds = []
            for matchRange in ranges {
                textStorage.enumerateAttribute(
                    .backgroundColor,
                    in: matchRange,
                    options: []
                ) { value, subRange, _ in
                    savedBackgrounds.append(
                        (range: subRange, color: value as? NSColor)
                    )
                }
            }
        }

        private func restoreBackgrounds(in textStorage: NSTextStorage) {
            guard !savedBackgrounds.isEmpty else { return }
            let length = textStorage.length
            textStorage.beginEditing()
            for saved in savedBackgrounds {
                guard saved.range.location + saved.range.length <= length
                else { continue }
                if let color = saved.color {
                    textStorage.addAttribute(
                        .backgroundColor,
                        value: color,
                        range: saved.range
                    )
                } else {
                    textStorage.removeAttribute(
                        .backgroundColor,
                        range: saved.range
                    )
                }
            }
            textStorage.endEditing()
            savedBackgrounds = []
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
