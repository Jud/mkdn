#if os(macOS)
    import AppKit
    import SwiftUI

    // MARK: - Coordinator

    extension SelectableTextView {
        @MainActor
        // swiftlint:disable:next type_body_length
        final class Coordinator: NSObject, NSTextViewDelegate {
            weak var textView: NSTextView?
            weak var documentState: DocumentState?
            weak var outlineState: OutlineState?
            let animator = EntranceAnimator()
            let overlayCoordinator = OverlayCoordinator()
            let gate = EntranceGate()
            var lastAppliedText: NSAttributedString?
            var headingOffsets: [Int: Int] = [:]
            var lastScrolledTarget: Int?
            private var headingDotView: NSView?
            private var headingDotFadeTask: Task<Void, Never>?
            nonisolated(unsafe) var scrollObserver: NSObjectProtocol?
            nonisolated(unsafe) var frameObserver: NSObjectProtocol?

            /// Cached heading y-positions for scroll-spy. Maps blockIndex to y-coordinate.
            /// Invalidated when content changes or view resizes.
            private var cachedHeadingPositions: [(blockIndex: Int, y: CGFloat)] = []
            private var headingPositionsCacheValid = false

            deinit {
                if let scrollObserver {
                    NotificationCenter.default.removeObserver(scrollObserver)
                }
                if let frameObserver {
                    NotificationCenter.default.removeObserver(frameObserver)
                }
            }

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
                        FileOpenService.shared.pendingURLs.append(resolvedURL)
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

            // MARK: - Scroll-Spy

            func invalidateHeadingPositionCache() {
                headingPositionsCacheValid = false
                cachedHeadingPositions = []
            }

            func startScrollSpy(on scrollView: NSScrollView) {
                // Remove any existing observers to avoid duplicates.
                if let existing = scrollObserver {
                    NotificationCenter.default.removeObserver(existing)
                    scrollObserver = nil
                }
                if let existing = frameObserver {
                    NotificationCenter.default.removeObserver(existing)
                    frameObserver = nil
                }

                let clipView = scrollView.contentView
                clipView.postsBoundsChangedNotifications = true
                scrollObserver = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: clipView,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.handleScrollForSpy()
                    }
                }

                // Also observe frame changes for cache invalidation.
                textView?.postsFrameChangedNotifications = true
                frameObserver = NotificationCenter.default.addObserver(
                    forName: NSView.frameDidChangeNotification,
                    object: textView,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.headingPositionsCacheValid = false
                    }
                }
            }

            /// Suppresses scroll-spy during programmatic scroll-to-heading.
            var isProgrammaticScroll = false

            func handleScrollForSpy() {
                guard !isProgrammaticScroll else { return }
                guard let textView,
                      let scrollView = textView.enclosingScrollView,
                      let outlineState
                else { return }

                let viewportTop = scrollView.contentView.bounds.origin.y

                // At the very top of the document, hide the breadcrumb.
                guard viewportTop > 1.0 else {
                    outlineState.updateScrollPosition(currentBlockIndex: -1)
                    return
                }

                let flatHeadings = outlineState.flatHeadings
                guard !flatHeadings.isEmpty else { return }

                // Lazily rebuild cache if invalid.
                if !headingPositionsCacheValid {
                    rebuildHeadingPositionCache()
                }

                guard !cachedHeadingPositions.isEmpty else {
                    let firstBlockIndex = flatHeadings.first?.blockIndex ?? 0
                    outlineState.updateScrollPosition(currentBlockIndex: firstBlockIndex - 1)
                    return
                }

                // Binary search for the last heading at or above viewportTop.
                var low = 0
                var high = cachedHeadingPositions.count - 1
                var bestIndex = -1
                while low <= high {
                    let mid = (low + high) / 2
                    if cachedHeadingPositions[mid].y <= viewportTop {
                        bestIndex = mid
                        low = mid + 1
                    } else {
                        high = mid - 1
                    }
                }

                if bestIndex >= 0 {
                    outlineState.updateScrollPosition(
                        currentBlockIndex: cachedHeadingPositions[bestIndex].blockIndex
                    )
                } else {
                    let firstBlockIndex = flatHeadings.first?.blockIndex ?? 0
                    outlineState.updateScrollPosition(currentBlockIndex: firstBlockIndex - 1)
                }
            }

            private func rebuildHeadingPositionCache() {
                guard let outlineState else {
                    cachedHeadingPositions = []
                    headingPositionsCacheValid = false
                    return
                }

                var positions: [(blockIndex: Int, y: CGFloat)] = []
                for heading in outlineState.flatHeadings {
                    guard let charOffset = headingOffsets[heading.blockIndex],
                          let y = yPosition(forCharacterOffset: charOffset)
                    else { continue }
                    positions.append((blockIndex: heading.blockIndex, y: y))
                }
                // Sort by y ascending for binary search.
                positions.sort { $0.y < $1.y }
                cachedHeadingPositions = positions
                headingPositionsCacheValid = true
            }

            /// Map a character offset in the text storage to a y-coordinate
            /// using the text layout manager.
            private func yPosition(forCharacterOffset offset: Int) -> CGFloat? {
                guard let textView,
                      let textContentStorage = textView.textContentStorage,
                      let textLayoutManager = textView.textLayoutManager
                else { return nil }

                let stringLength = textView.textStorage?.length ?? 0
                guard offset < stringLength else { return nil }

                let nsLocation = textContentStorage.location(
                    textContentStorage.documentRange.location,
                    offsetBy: offset
                )
                guard let nsLocation else { return nil }

                let position = NSTextRange(location: nsLocation)

                var resultY: CGFloat?
                textLayoutManager.enumerateTextLayoutFragments(
                    from: position.location,
                    options: [.ensuresLayout]
                ) { fragment in
                    resultY = fragment.layoutFragmentFrame.origin.y
                    return false // Stop after first fragment.
                }
                return resultY
            }

            /// Smooth-scroll the view to position a heading at the viewport top.
            func scrollToHeading(blockIndex: Int, in scrollView: NSScrollView) {
                guard let charOffset = headingOffsets[blockIndex],
                      let headingY = yPosition(forCharacterOffset: charOffset)
                else { return }

                isProgrammaticScroll = true
                showHeadingDot(forCharacterOffset: charOffset)
                let clipView = scrollView.contentView
                let destination = NSPoint(x: 0, y: headingY)
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = AnimationConstants.scrollToHeadingDuration
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    clipView.animator().setBoundsOrigin(destination)
                } completionHandler: { [weak self, weak scrollView, weak clipView] in
                    guard let scrollView, let clipView else { return }
                    Task { @MainActor in
                        self?.isProgrammaticScroll = false
                        scrollView.reflectScrolledClipView(clipView)
                    }
                }
            }

            /// Show a temporary accent dot in the left margin at the navigated heading.
            // swiftlint:disable:next function_body_length
            private func showHeadingDot(forCharacterOffset offset: Int) {
                guard let textView,
                      let textContentStorage = textView.textContentStorage,
                      let textLayoutManager = textView.textLayoutManager
                else { return }

                // Remove existing dot
                headingDotView?.removeFromSuperview()
                headingDotFadeTask?.cancel()

                // Get the layout fragment frame (same method as OverlayCoordinator)
                let stringLength = textView.textStorage?.length ?? 0
                guard offset < stringLength else { return }
                guard let nsLocation = textContentStorage.location(
                    textContentStorage.documentRange.location,
                    offsetBy: offset
                )
                else { return }

                var fragmentFrame: CGRect?
                textLayoutManager.enumerateTextLayoutFragments(
                    from: nsLocation,
                    options: [.ensuresLayout]
                ) { fragment in
                    fragmentFrame = fragment.layoutFragmentFrame
                    return false
                }
                guard let frame = fragmentFrame else { return }

                let dotSize: CGFloat = 6
                let origin = textView.textContainerOrigin
                // Position: left margin, vertically centered in the heading's fragment
                let dot = NSView(frame: NSRect(
                    x: origin.x - dotSize - 6,
                    y: frame.origin.y + origin.y + frame.height * 0.6 - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                ))
                dot.wantsLayer = true
                dot.layer?.cornerRadius = dotSize / 2
                dot.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
                dot.alphaValue = 0

                textView.addSubview(dot)
                headingDotView = dot

                // Fade in
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    dot.animator().alphaValue = 1.0
                }

                // Fade out after 2 seconds
                headingDotFadeTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.5
                        dot.animator().alphaValue = 0
                    } completionHandler: { [weak dot] in
                        Task { @MainActor in
                            dot?.removeFromSuperview()
                        }
                    }
                }
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
                    overlayCoordinator.scheduleReposition()
                    return
                }

                let highlightNSColor = PlatformTypeConverter.color(
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
                overlayCoordinator.scheduleReposition()

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
                    overlayCoordinator.scheduleReposition()
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
                        self?.overlayCoordinator.scheduleReposition()
                    }

                    guard !Task.isCancelled, let self else { return }
                    restoreBackgrounds(in: textStorage)
                    overlayCoordinator.scheduleReposition()
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
#endif
