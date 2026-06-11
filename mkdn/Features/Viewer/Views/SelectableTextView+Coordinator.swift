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
            /// Published heading/comment/viewport positions for the scroll-marker track.
            weak var mapState: PreviewMapState?
            private var mapRebuildScheduled = false

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

            /// The theme's accent, resolved from the text view — not the system
            /// `controlAccentColor`, so transient marks (footnote pulse, heading
            /// dot) match every other accent use in the document.
            private var themeAccent: NSColor {
                guard let theme = (textView as? CodeBlockBackgroundTextView)?.commentTheme else {
                    return .controlAccentColor
                }
                return PlatformTypeConverter.color(from: theme.colors.accent)
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

                let pulseAccent = themeAccent
                let highlightColor = pulseAccent.withAlphaComponent(0.2)
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
                            let fade = pulseAccent.withAlphaComponent(alpha)
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
            }

            func wireScrollSpy() {
                // Piggyback on OverlayCoordinator's frame/scroll observers
                // rather than registering duplicates on the same notifications.
                overlayCoordinator.onScrollChange = { [weak self] in
                    self?.handleScrollForSpy()
                    self?.publishMapViewport()
                }
                overlayCoordinator.onFrameChange = { [weak self] in
                    guard let self else { return }
                    headingPositionsCacheValid = false
                    // Skip the per-frame heading + map rebuilds while a width gesture is in
                    // flight (rail slide, window live-resize) or a progressive open's tail
                    // is appending: each frame's whole-string measure would bog the gesture,
                    // and mid-tail the measures would read prefix-only state. The heading
                    // cache stays invalidated above, and onResizeSettled / the tail finish
                    // run both once at the end. (publishMapViewport and the scroll-spy
                    // self-guard the same way.)
                    guard !isMetricsSuppressed else { return }
                    scheduleScrollSpyRefresh()
                    scheduleDocumentMapRebuild()
                }
                // A settle whose final layout posts no frame/scroll change would otherwise
                // leave the spy/map unscheduled past the in-gesture guard. Re-invalidate
                // first: a settle that posted no frame change never nilled the cache.
                (textView as? CodeBlockBackgroundTextView)?.onResizeSettled = { [weak self] in
                    self?.runSettleRefresh()
                }
            }

            /// The refresh every measure-suppression end runs — gesture settles
            /// (slide end, live-resize end) and the progressive tail's finish:
            /// re-derive heading positions, spy, and map, and replay a heading
            /// jump that was refused while measures were suppressed.
            private func runSettleRefresh() {
                invalidateHeadingPositionCache()
                scheduleScrollSpyRefresh()
                scheduleDocumentMapRebuild()
                // The settle's exact re-pin moves the scroll origin with the
                // gesture flags still set, so the scroll observer skipped it;
                // refresh the viewport-scoped overlay frames at the final origin.
                overlayCoordinator.scheduleReposition()
                if let target = deferredHeadingTarget,
                   let scrollView = textView?.enclosingScrollView
                {
                    deferredHeadingTarget = nil
                    _ = scrollToHeading(blockIndex: target, in: scrollView)
                }
            }

            /// Whole-string measures (heading positions, document map, height estimate)
            /// must be skipped and run once at the end: a width gesture is in flight
            /// (comment-rail slide, window live-resize), or a progressive open's tail
            /// is still appending. One signal for every such guard.
            private var isMetricsSuppressed: Bool {
                (textView as? CodeBlockBackgroundTextView)?.isMetricsSuppressed ?? false
            }

            private var scrollSpyRefreshScheduled = false

            /// Coalesced scroll-spy pass for after a resize settles (handleScrollForSpy
            /// early-returns while the gesture is live).
            private func scheduleScrollSpyRefresh() {
                guard !scrollSpyRefreshScheduled else { return }
                scrollSpyRefreshScheduled = true
                DispatchQueue.main.async { [weak self] in
                    self?.scrollSpyRefreshScheduled = false
                    self?.handleScrollForSpy()
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

                // While the comment rail animates the width, or the window is being
                // live-resized, the active heading can't change (the anchored line is
                // held, or the gesture is in flight); mid-tail the cache would cover
                // only the prefix. Skip the per-frame work — each frame's bounds shift
                // would otherwise rebuild the whole O(blocks^2) heading-position cache
                // for no change in the breadcrumb; it settles on the next real scroll.
                guard !isMetricsSuppressed else { return }

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
                guard let outlineState, blockOffsets() != nil else {
                    cachedHeadingPositions = []
                    headingPositionsCacheValid = false
                    return
                }
                var positions: [(blockIndex: Int, y: CGFloat)] = []
                for heading in outlineState.flatHeadings {
                    guard let y = navigationY(forBlockIndex: heading.blockIndex) else { continue }
                    positions.append((blockIndex: heading.blockIndex, y: y))
                }
                // Sort by y ascending for binary search.
                positions.sort { $0.y < $1.y }
                cachedHeadingPositions = positions
                headingPositionsCacheValid = true
            }

            /// Heading top in the container coordinate space navigation scrolls in:
            /// DocumentBlockOffsets reports text-view space, so drop the container origin.
            private func navigationY(forBlockIndex blockIndex: Int) -> CGFloat? {
                guard let viewY = blockOffsets()?.offset(forBlockIndex: blockIndex),
                      let originY = textView?.textContainerOrigin.y
                else { return nil }
                return viewY - originY
            }

            /// The text view's shared per-block offsets (see
            /// `CodeBlockBackgroundTextView.blockOffsets`).
            private func blockOffsets() -> DocumentBlockOffsets? {
                (textView as? CodeBlockBackgroundTextView)?.currentBlockOffsets()
            }

            // MARK: - Progressive Open Tail

            private var progressiveTailTask: Task<Void, Never>?
            private var activeTailSession: ProgressiveTextStorageBuild?
            private var onProgressiveOpenFinished: (
                (ProgressiveTextStorageBuild, TextStorageResult) -> Void
            )?
            /// A heading jump refused while measures were suppressed (width
            /// gesture or open tail), replayed by the next settle/finish once
            /// the offsets are trustworthy again.
            private var deferredHeadingTarget: Int?
            /// Time each tail slice may spend building before yielding the
            /// main actor. The per-slice fixed costs (storage edit processing,
            /// sleep wake) are large enough that thinner slices mostly buy
            /// overhead, not responsiveness.
            private static let tailSliceBudget: Duration = .milliseconds(16)

            /// Drive the rest of a progressive open: append the session's
            /// remaining blocks to the live storage in time-budgeted main-actor
            /// slices, then finish (one exact pass, overlays, publish).
            func beginProgressiveTail(
                session: ProgressiveTextStorageBuild,
                onFinished: ((ProgressiveTextStorageBuild, TextStorageResult) -> Void)?
            ) {
                guard activeTailSession !== session else { return }
                cancelProgressiveTail()
                guard let textView = textView as? CodeBlockBackgroundTextView,
                      let storage = textView.textStorage
                else { return }
                activeTailSession = session
                onProgressiveOpenFinished = onFinished
                textView.forceFinishProgressiveOpen = { [weak self] in
                    self?.forceFinishProgressiveTail()
                }
                // A recreated view installs the prefix snapshot from SwiftUI
                // state, which can trail what the session has built; append the
                // missing slice so the storage and the session's cursor agree.
                if storage.length < session.builtUTF16Length {
                    storage.append(session.builtSlice(from: storage.length))
                }
                // A cancel can land between the last append and the finish (a
                // recreated view's dismantle during the inter-slice sleep);
                // the session arrives complete but unpublished. Finish on the
                // next runloop turn: this path runs from the representable's
                // make/update pass, and finishing inline would publish @State
                // mid-view-update.
                guard !session.isComplete else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self, activeTailSession === session else { return }
                        finishProgressiveOpen(session: session)
                    }
                    return
                }
                progressiveTailTask = Task { @MainActor [weak self] in
                    while !Task.isCancelled, let fragment = session.buildNext(
                        deadline: ContinuousClock.now + Self.tailSliceBudget
                    ) {
                        storage.beginEditing()
                        storage.append(fragment)
                        storage.endEditing()
                        // Sleep (not yield) so the runloop turns and a frame
                        // can paint between slices.
                        try? await Task.sleep(for: .milliseconds(1))
                    }
                    guard !Task.isCancelled else { return }
                    self?.finishProgressiveOpen(session: session)
                }
            }

            /// Stop an in-flight tail without finishing — the storage is about
            /// to be replaced (new content, theme rebuild) or the view is
            /// being torn down.
            func cancelProgressiveTail() {
                progressiveTailTask?.cancel()
                progressiveTailTask = nil
                activeTailSession = nil
                onProgressiveOpenFinished = nil
                deferredHeadingTarget = nil
                (textView as? CodeBlockBackgroundTextView)?.forceFinishProgressiveOpen = nil
            }

            /// Drain the tail synchronously — for actions that need the full
            /// document now (print). The SwiftUI publish is deferred to the
            /// default run-loop mode: the caller is about to spin a modal
            /// loop (the print panel), and a publish landing inside it would
            /// re-apply screen state to the print canvas.
            private func forceFinishProgressiveTail() {
                guard let session = activeTailSession else { return }
                if let storage = textView?.textStorage,
                   let fragment = session.buildNext()
                {
                    storage.beginEditing()
                    storage.append(fragment)
                    storage.endEditing()
                }
                finishProgressiveOpen(session: session, deferPublish: true)
            }

            /// The storage holds the whole document: clear the suppression,
            /// run the one exact height pass, set up the tail's overlays, and
            /// hand the full result back to SwiftUI. `lastAppliedText` is
            /// pre-set to the full string so the publish doesn't read as new
            /// content and re-install the document.
            private func finishProgressiveOpen(
                session: ProgressiveTextStorageBuild, deferPublish: Bool = false
            ) {
                let finished = onProgressiveOpenFinished
                let deferredTarget = deferredHeadingTarget
                cancelProgressiveTail()
                // Survive the teardown: the settle refresh below replays it now
                // that the target is materialized and the offsets are exact.
                deferredHeadingTarget = deferredTarget
                guard let textView = textView as? CodeBlockBackgroundTextView else { return }
                let full = session.result()
                textView.isProgressiveOpenActive = false
                textView.isSelectable = true
                textView.documentHeightModel = full.documentHeightModel
                documentHeightModel = full.documentHeightModel
                headingOffsets = full.headingOffsets
                textView.estimatedHeightFloor = nil
                textView.blockOffsets = nil
                // Mid-gesture the width is transient and the gesture freed the
                // floor on purpose; its settle runs the exact pass (via
                // refreshSettledHeight, now that the flag is clear) at the
                // final width instead.
                if !textView.isResizeGestureActive {
                    textView.refreshEstimatedHeight()
                }
                // updateOverlays starts a fresh readiness cycle, but the
                // entrance gate may still be waiting on prefix overlays whose
                // reports must survive (the same-instance carryover skip means
                // they never re-report); restore them and re-check readiness.
                let reportedBeforeFinish = overlayCoordinator.reportedOverlays
                if let appSettings = overlayCoordinator.appSettings, let documentState {
                    overlayCoordinator.updateOverlays(
                        attachments: full.attachments,
                        appSettings: appSettings,
                        documentState: documentState,
                        in: textView
                    )
                }
                overlayCoordinator.reportedOverlays.formUnion(reportedBeforeFinish)
                if gate.isGateActive, let scrollView = textView.enclosingScrollView,
                   overlayCoordinator.viewportOverlaysReady(in: scrollView)
                {
                    gate.markReady()
                }
                // Find searched a partial document while the tail ran; re-run
                // over the full storage. Calling the highlight pass directly
                // (not handleFindUpdate with isNewContent) keeps the saved
                // pre-highlight backgrounds intact: it restores them before
                // re-saving, so dismissing find can't bake old tints in.
                if let findState = textView.findState, findState.isVisible,
                   let theme = textView.commentTheme
                {
                    // Don't scroll to the current match: the finish is a
                    // background event, and yanking the viewport seconds after
                    // the user opened Find reads as a spontaneous jump.
                    applyFindHighlights(
                        findState: findState, textView: textView,
                        theme: theme, performSearch: true,
                        scrollToCurrentMatch: false
                    )
                }
                lastAppliedText = full.attributedString
                let completePublish = { [weak self] in
                    guard let self else { return }
                    // The exact pass may land exactly on the provisional
                    // floor's height, posting no frame change — run the settle
                    // refresh directly rather than waiting on a frame-change
                    // observation.
                    runSettleRefresh()
                    OpenTimeline.shared.mark("tailComplete")
                    finished?(session, full)
                }
                if deferPublish {
                    // Default mode only: skipped while a modal loop (print
                    // panel) runs, delivered once it ends — the settle refresh
                    // rides along so its scheduled spy/map rebuilds can't read
                    // the print canvas mid-modal. The unsafe capture is
                    // main-thread-confined: the block runs on the main run
                    // loop, back on the main actor.
                    nonisolated(unsafe) let publish = completePublish
                    RunLoop.main.perform(inModes: [.default]) {
                        MainActor.assumeIsolated(publish)
                    }
                } else {
                    completePublish()
                }
            }

            // MARK: - Document Map Publishing

            /// Coalesced full rebuild of the document map. Scheduled (not run inline) so
            /// a trigger from `updateNSView` doesn't mutate observable state mid-view-
            /// update, and a burst of invalidations collapses to one rebuild.
            func scheduleDocumentMapRebuild() {
                guard !mapRebuildScheduled else { return }
                mapRebuildScheduled = true
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    mapRebuildScheduled = false
                    // A rebuild scheduled just before a gesture began would otherwise fire
                    // mid-slide (or mid-tail); the settle or tail finish reschedules it.
                    guard !isMetricsSuppressed else { return }
                    guard let map = OpenTimeline.shared.time("documentMap", { buildDocumentMap() })
                    else { return }
                    mapState?.documentMap = map
                }
            }

            /// Viewport-only republish: the marks are width/content-keyed and don't move
            /// on scroll, so reuse the published map and update just the viewport rect.
            /// Skipped mid-resize/slide (the viewport is held) — the same guard as the
            /// scroll-spy; the settle path triggers a full rebuild.
            func publishMapViewport() {
                guard !isMetricsSuppressed,
                      let mapState,
                      let textView = textView as? CodeBlockBackgroundTextView,
                      let scrollView = textView.enclosingScrollView
                else { return }
                let bounds = scrollView.contentView.bounds
                var map = mapState.documentMap
                guard map.viewportTop != bounds.origin.y || map.viewportHeight != bounds.height
                else { return }
                map.viewportTop = bounds.origin.y
                map.viewportHeight = bounds.height
                mapState.documentMap = map
            }

            private func buildDocumentMap() -> PreviewDocumentMap? {
                guard let textView = textView as? CodeBlockBackgroundTextView,
                      let outlineState,
                      let model = documentHeightModel,
                      let offsets = blockOffsets(),
                      let textStorage = textView.textStorage
                else { return nil }
                let originY = textView.textContainerOrigin.y
                // Measure each comment's y at intra-block precision (the line it sits on,
                // not just its block top), then to scroll space — so a card anchors beside
                // its own line and two comments in one paragraph don't stack on the top.
                let comments: [(id: String, range: NSRange, y: CGFloat, lineHeight: CGFloat)] =
                    (textView.resolvedComments?.active ?? []).compactMap { comment in
                        guard let y = offsets.characterY(
                            at: comment.range.location, in: textStorage,
                            model: model, textWidth: textView.textWidth)
                        else { return nil }
                        // One character measures as a single line of its own style —
                        // the line height a track tick centers on.
                        let lineHeight = comment.range.location < textStorage.length
                            ? DocumentHeightEstimator.contentHeight(
                                of: textStorage.attributedSubstring(
                                    from: NSRange(location: comment.range.location, length: 1)),
                                textWidth: textView.textWidth)
                            : 0
                        return (
                            id: comment.id, range: comment.range,
                            y: y - originY, lineHeight: lineHeight
                        )
                    }
                let bounds = textView.enclosingScrollView?.contentView.bounds ?? .zero
                return PreviewDocumentMap.build(
                    headings: outlineState.flatHeadings,
                    comments: comments,
                    offsets: offsets,
                    blockModel: model,
                    textContainerOriginY: originY,
                    totalHeight: textView.frame.height,
                    viewportTop: bounds.origin.y,
                    viewportHeight: bounds.height
                )
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
            /// Returns `false` without scrolling when `blockIndex` isn't a heading or
            /// the block offsets aren't ready yet (e.g. width not laid out), so the
            /// caller doesn't record a no-op as the last scrolled target.
            func scrollToHeading(blockIndex: Int, in scrollView: NSScrollView) -> Bool {
                // Mid-gesture the width is still animating, so the offsets a lazy
                // navigationY would compute and cache sit at a transient width — and a window
                // drag that ends without viewDidEndLiveResize wouldn't refresh them. Mid-tail
                // the target heading may not even be materialized yet. Remember the target
                // and let the settle/finish replay it — a silent drop reads as a dead click.
                guard !isMetricsSuppressed else {
                    deferredHeadingTarget = blockIndex
                    return false
                }
                guard let charOffset = headingOffsets[blockIndex],
                      let headingY = navigationY(forBlockIndex: blockIndex)
                else { return false }

                showHeadingDot(forCharacterOffset: charOffset)
                scrollTo(scrollY: headingY, in: scrollView)
                return true
            }

            /// Smooth-scroll the clip view so document scroll-space `scrollY` sits at
            /// the viewport top. Factored from ``scrollToHeading`` so any mark — a track
            /// tick, not just a heading — can target an arbitrary y. Suppresses scroll-
            /// spy for the duration so the programmatic move doesn't fight the breadcrumb.
            func scrollTo(scrollY: CGFloat, in scrollView: NSScrollView) {
                isProgrammaticScroll = true
                let clipView = scrollView.contentView
                let destination = NSPoint(x: 0, y: scrollY)
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
                dot.layer?.backgroundColor = themeAccent.cgColor
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
                performSearch: Bool,
                scrollToCurrentMatch: Bool = true
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
                    let alpha: CGFloat = (index == findState.currentMatchIndex)
                        ? DesignTokens.Tint.active
                        : DesignTokens.Tint.subtle
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

                if scrollToCurrentMatch,
                   let currentRange =
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
