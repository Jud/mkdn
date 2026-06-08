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
            var lastCommentRevision = 0
            var headingOffsets: [Int: Int] = [:]
            var lastScrolledTarget: Int?
            private var headingDotView: NSView?
            private var headingDotFadeTask: Task<Void, Never>?
            /// Cached heading y-positions for scroll-spy. Maps blockIndex to y-coordinate.
            /// Invalidated when content changes or view resizes.
            private var cachedHeadingPositions: [(blockIndex: Int, y: CGFloat)] = []
            private var headingPositionsCacheValid = false
            var documentHeightModel: DocumentHeightModel?
            /// Per-block offsets, computed lazily from the height model at the current
            /// width and reused for heading navigation. Invalidated on content/width
            /// change (same as the heading cache). O(blocks^2) but one-shot.
            private var documentBlockOffsets: DocumentBlockOffsets?

            // MARK: - Link Navigation

            func textView(
                _ textView: NSTextView,
                clickedOnLink link: Any,
                at charIndex: Int
            ) -> Bool {
                // A commented link opens its comment (in openCommentPopoverIfNeeded,
                // after super.mouseDown) rather than navigating — suppress the
                // navigation here so the two don't both fire on one click.
                if let codeView = textView as? CodeBlockBackgroundTextView,
                   codeView.resolvedComments?.comments(containing: charIndex).isEmpty == false {
                    return true
                }

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

                // Footnote navigation: mkdn-footnote:def-N or mkdn-footnote:ref-N
                if url.scheme == "mkdn-footnote" {
                    handleFootnoteLink(url)
                    return true
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

            // MARK: - Footnote Navigation

            private func handleFootnoteLink(_ url: URL) {
                guard let textView,
                      let scrollView = textView.enclosingScrollView,
                      let storage = textView.textStorage
                else { return }

                let target = url.absoluteString
                    .replacingOccurrences(of: "mkdn-footnote:", with: "")

                // Find the target link in the attributed string.
                // "def-N" → find the back-link "ref-N" at the definition (scroll down)
                // "ref-N" → find the forward-link "def-N" at the reference (scroll up)
                let searchURL: String
                if target.hasPrefix("def-") {
                    let index = String(target.dropFirst(4))
                    searchURL = "mkdn-footnote:ref-\(index)"
                } else {
                    let index = String(target.dropFirst(4))
                    searchURL = "mkdn-footnote:def-\(index)"
                }

                // Scan the attributed string for the matching link
                var targetOffset: Int?
                var targetRange = NSRange(location: 0, length: 0)
                storage.enumerateAttribute(.link, in: NSRange(
                    location: 0,
                    length: storage.length
                )) { value, range, stop in
                    if let linkURL = value as? URL, linkURL.absoluteString == searchURL {
                        targetOffset = range.location
                        targetRange = range
                        stop.pointee = true
                    }
                }

                guard let offset = targetOffset,
                      let targetY = yPosition(forCharacterOffset: offset)
                else { return }

                isProgrammaticScroll = true
                pulseHighlight(atCharacterOffset: offset, linkRange: targetRange)

                let clipView = scrollView.contentView
                let destination = NSPoint(x: 0, y: targetY)
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = AnimationConstants.scrollToHeadingDuration
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    clipView.animator().setBoundsOrigin(destination)
                } completionHandler: { [weak self, weak scrollView, weak clipView] in
                    guard let scrollView, let clipView else { return }
                    Task { @MainActor in
                        self?.isProgrammaticScroll = false
                        scrollView.reflectScrolledClipView(clipView)
                        self?.handleScrollForSpy()
                    }
                }
            }

            private var footnotePulseTask: Task<Void, Never>?
            private var footnotePulseRange: NSRange?
            /// Background colors (e.g. comment highlights) the pulse temporarily
            /// paints over, restored when the pulse fades so they aren't erased.
            private var footnotePulseSavedBackgrounds: [(range: NSRange, color: NSColor)] = []

            /// Cancel an in-flight footnote pulse and forget its saved state.
            /// Called before the text storage is replaced so the delayed fade
            /// can't write stale ranges into freshly rebuilt content.
            func cancelFootnotePulse() {
                footnotePulseTask?.cancel()
                footnotePulseTask = nil
                footnotePulseRange = nil
                footnotePulseSavedBackgrounds = []
            }

            private func clearFootnotePulse(_ storage: NSTextStorage, range: NSRange) {
                let length = storage.length
                if NSMaxRange(range) <= length {
                    storage.removeAttribute(.backgroundColor, range: range)
                }
                for saved in footnotePulseSavedBackgrounds where NSMaxRange(saved.range) <= length {
                    storage.addAttribute(.backgroundColor, value: saved.color, range: saved.range)
                }
                footnotePulseSavedBackgrounds = []
            }

            /// Briefly highlight the text at a footnote target using a background attribute.
            private func pulseHighlight(atCharacterOffset offset: Int, linkRange: NSRange) {
                guard let textView,
                      let storage = textView.textStorage,
                      linkRange.location + linkRange.length <= storage.length
                else { return }

                // Cancel previous highlight and clear it immediately
                footnotePulseTask?.cancel()
                if let prev = footnotePulseRange {
                    clearFootnotePulse(storage, range: prev)
                }

                let paraRange = (storage.string as NSString)
                    .paragraphRange(for: linkRange)

                // Skip past the list marker prefix (e.g. "\t1.\t")
                let nsString = storage.string as NSString
                var contentStart = paraRange.location
                let paraEnd = paraRange.location + paraRange.length
                while contentStart < paraEnd {
                    let ch = nsString.character(at: contentStart)
                    if ch == 0x09 || ch == 0x20 || (ch >= 0x30 && ch <= 0x39) || ch == 0x2E {
                        contentStart += 1
                    } else {
                        break
                    }
                }
                let contentRange = NSRange(location: contentStart, length: paraEnd - contentStart)
                footnotePulseRange = contentRange

                // Remember any existing backgrounds (comment highlights) so the
                // pulse fade restores rather than erases them.
                footnotePulseSavedBackgrounds = []
                storage.enumerateAttribute(.backgroundColor, in: contentRange, options: []) { value, range, _ in
                    if let color = value as? NSColor {
                        footnotePulseSavedBackgrounds.append((range, color))
                    }
                }

                let highlightColor = NSColor.controlAccentColor.withAlphaComponent(0.2)
                storage.addAttribute(.backgroundColor, value: highlightColor, range: contentRange)

                footnotePulseTask = Task { @MainActor [weak self, weak textView] in
                    try? await Task.sleep(for: .milliseconds(800))
                    for alpha in [0.12, 0.06, 0.0] as [CGFloat] {
                        guard !Task.isCancelled else { return }
                        try? await Task.sleep(for: .milliseconds(100))
                        guard let storage = textView?.textStorage else { return }
                        guard NSMaxRange(contentRange) <= storage.length else { return }
                        if alpha == 0 {
                            self?.clearFootnotePulse(storage, range: contentRange)
                        } else {
                            let fade = NSColor.controlAccentColor.withAlphaComponent(alpha)
                            storage.addAttribute(.backgroundColor, value: fade, range: contentRange)
                        }
                    }
                    self?.footnotePulseRange = nil
                }
            }

            // MARK: - Scroll-Spy

            func invalidateHeadingPositionCache() {
                headingPositionsCacheValid = false
                cachedHeadingPositions = []
                documentBlockOffsets = nil
            }

            func wireScrollSpy() {
                // Piggyback on OverlayCoordinator's frame/scroll observers
                // rather than registering duplicates on the same notifications.
                overlayCoordinator.onScrollChange = { [weak self] in
                    self?.handleScrollForSpy()
                }
                overlayCoordinator.onFrameChange = { [weak self] in
                    self?.headingPositionsCacheValid = false
                    self?.documentBlockOffsets = nil
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

                // While the comment rail animates the width, the anchored line is
                // held at a fixed viewport position, so the active heading can't
                // change. Skip the per-frame work — each frame's bounds shift would
                // otherwise rebuild the whole heading-position cache (it's
                // invalidated every frame by the width change) for no change in the
                // breadcrumb; it settles on the next real scroll.
                guard (textView as? CodeBlockBackgroundTextView)?.sidebarResizeAnchor == nil
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
                guard let outlineState, let textView, let offsets = blockOffsets() else {
                    cachedHeadingPositions = []
                    headingPositionsCacheValid = false
                    return
                }

                // DocumentBlockOffsets reports text-view-space tops; navigation works in
                // the container space the previous fragment-frame path used, so drop the
                // container origin.
                let originY = textView.textContainerOrigin.y
                var positions: [(blockIndex: Int, y: CGFloat)] = []
                for heading in outlineState.flatHeadings {
                    guard let y = offsets.offset(forBlockIndex: heading.blockIndex) else { continue }
                    positions.append((blockIndex: heading.blockIndex, y: y - originY))
                }
                // Sort by y ascending for binary search.
                positions.sort { $0.y < $1.y }
                cachedHeadingPositions = positions
                headingPositionsCacheValid = true
            }

            /// Per-block offsets at the current container width, computed once and cached.
            /// Replaces TextKit fragment realization for heading positions with a Core
            /// Text measure — accurate even off-viewport, where `.ensuresLayout` returns
            /// estimated frames.
            private func blockOffsets() -> DocumentBlockOffsets? {
                if let documentBlockOffsets { return documentBlockOffsets }
                guard let textView = textView as? CodeBlockBackgroundTextView,
                      let model = documentHeightModel,
                      let textStorage = textView.textStorage,
                      let textContainer = textView.textContainer,
                      textContainer.size.width > 0
                else { return nil }
                let textWidth = textContainer.size.width - 2 * textContainer.lineFragmentPadding
                let offsets = DocumentBlockOffsets.compute(
                    of: textStorage, model: model,
                    textWidth: textWidth, verticalInset: textView.textContainerInset.height)
                documentBlockOffsets = offsets
                return offsets
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
                guard let textView,
                      let viewY = blockOffsets()?.offset(forBlockIndex: blockIndex)
                else { return }
                // text-view space -> container space (see rebuildHeadingPositionCache).
                let headingY = viewY - textView.textContainerOrigin.y

                isProgrammaticScroll = true
                if let charOffset = headingOffsets[blockIndex] {
                    showHeadingDot(forCharacterOffset: charOffset)
                }
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
                        self?.handleScrollForSpy()
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
                    let clearedRanges = lastHighlightedRanges
                    restoreBackgrounds(in: textStorage)
                    lastHighlightedRanges = []
                    if overlayCoordinator.hasAttachments(intersecting: clearedRanges) {
                        overlayCoordinator.scheduleReposition()
                    }
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

                let priorRanges = lastHighlightedRanges
                lastHighlightedRanges = findState.matchRanges
                if overlayCoordinator.hasAttachments(intersecting: priorRanges)
                    || overlayCoordinator.hasAttachments(intersecting: findState.matchRanges)
                {
                    overlayCoordinator.scheduleReposition()
                }

                if let currentRange =
                    findState.matchRanges[safe: findState.currentMatchIndex]
                {
                    textView.scrollRangeToVisible(currentRange)
                }
            }

            private func clearFindHighlights(textView: NSTextView) {
                guard let textStorage = textView.textStorage,
                      !lastHighlightedRanges.isEmpty
                else { return }

                highlightFadeTask?.cancel()
                let rangeColors = collectHighlightColors(from: textStorage)
                lastHighlightedRanges = []

                guard !rangeColors.isEmpty,
                      !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                else {
                    let clearedRanges = rangeColors.map(\.range)
                    restoreBackgrounds(in: textStorage)
                    if overlayCoordinator.hasAttachments(intersecting: clearedRanges) {
                        overlayCoordinator.scheduleReposition()
                    }
                    return
                }

                let fadeSteps = 4
                let stepNanos: UInt64 = 40_000_000 // 40ms per step = 160ms total

                let fadedRanges = rangeColors.map(\.range)
                highlightFadeTask = Task { @MainActor [weak self] in
                    let touchesAttachments = self?.overlayCoordinator
                        .hasAttachments(intersecting: fadedRanges) ?? false
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
                        if touchesAttachments {
                            self?.overlayCoordinator.scheduleReposition()
                        }
                    }

                    guard !Task.isCancelled, let self else { return }
                    restoreBackgrounds(in: textStorage)
                    if touchesAttachments {
                        overlayCoordinator.scheduleReposition()
                    }
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

            /// Tear down any in-flight find highlight or dismissal fade before a
            /// comment-only repaint. The fade restores `.backgroundColor` from state
            /// captured *before* the comment change, which would otherwise fight the
            /// repaint — losing an added comment's tint or resurrecting a deleted
            /// one where a find match overlapped it.
            func cancelFindHighlightFade(in textStorage: NSTextStorage) {
                highlightFadeTask?.cancel()
                highlightFadeTask = nil
                restoreBackgrounds(in: textStorage)
                lastHighlightedRanges = []
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
