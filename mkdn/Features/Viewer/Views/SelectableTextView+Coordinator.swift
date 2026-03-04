#if os(macOS)
    import AppKit
    import SwiftUI

    // MARK: - Coordinator

    extension SelectableTextView {
        @MainActor
        final class Coordinator: NSObject, NSTextViewDelegate {
            weak var textView: NSTextView?
            weak var documentState: DocumentState?
            let animator = EntranceAnimator()
            let overlayCoordinator = OverlayCoordinator()
            let gate = EntranceGate()
            var lastAppliedText: NSAttributedString?

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
