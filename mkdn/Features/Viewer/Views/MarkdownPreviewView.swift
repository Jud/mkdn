#if os(macOS)
    import SwiftUI

    private extension CommentSidebarItem {
        init(_ entry: CommentSidecar.Entry) {
            self.init(
                id: entry.id, body: entry.body, quote: entry.quote,
                prefix: entry.prefix, suffix: entry.suffix
            )
        }
    }

    /// Full-width Markdown preview (read-only mode).
    ///
    /// Rendering is debounced via `.task(id:)` so that rapid typing in the
    /// editor does not trigger a re-render on every keystroke. The initial
    /// render on appear is performed without delay.
    ///
    /// Content is rendered into a single `NSAttributedString` via
    /// ``MarkdownTextStorageBuilder`` and displayed in a ``SelectableTextView``
    /// backed by TextKit 2, enabling native cross-block text selection.
    ///
    /// Content blocks appear with a staggered entrance animation on initial
    /// file load and full content reloads, driven by ``EntranceAnimator``
    /// within the ``SelectableTextView``. Incremental changes (e.g. editor
    /// typing) update blocks instantly without stagger. With Reduce Motion
    /// enabled, all blocks appear immediately.
    struct MarkdownPreviewView: View {
        @Environment(DocumentState.self) private var documentState
        @Environment(AppSettings.self) private var appSettings
        @Environment(FindState.self) private var findState
        @Environment(OutlineState.self) private var outlineState
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private var motion: MotionPreference {
            MotionPreference(reduceMotion: reduceMotion)
        }

        @State private var renderedBlocks: [IndexedBlock] = []
        @State private var cachedBlocks: [IndexedBlock] = []
        @State private var isInitialRender = true
        @State private var knownBlockIDs: Set<String> = []
        @State private var textStorageResult = TextStorageResult(
            attributedString: NSAttributedString(),
            attachments: []
        )
        @State private var isFullReload = false
        /// The last rendered body (sidecar + markers stripped), to detect a
        /// comment-only change (visible text unchanged) and skip the rebuild.
        @State private var lastRenderedBody: String?
        /// The rendered anchor tape for the current text, cached so a comment-only
        /// change re-resolves selectors without rebuilding the text.
        @State private var anchorTape: AnchorTape?
        /// Comments resolved against `anchorTape`, drawn by the text view.
        @State private var resolvedComments: ResolvedComments?
        /// Bumped on a comment-only change to drive the live highlight redraw.
        @State private var commentRevision = 0
        /// Slide progress of the comment rail, 0 (closed) → 1 (open). Drives the
        /// preview's width so the text occupies the narrowed viewport, and the
        /// toggle's fade. Animated explicitly (not via `.animation(value:)`) so the
        /// scroll anchor can be captured before the width starts changing.
        @State private var sidebarProgress: CGFloat = 0
        /// Bumped per toggle so a superseded slide's completion can't tear down the
        /// anchor while a newer slide (fast re-toggle) is still re-pinning it.
        @State private var sidebarResizeToken = 0
        /// Positions the coordinator publishes for the scroll-marker track, and the
        /// track's scroll-to bridge back into it.
        @State private var mapState = PreviewMapState()
        /// Non-nil while a progressive open's tail is appending: the published
        /// `textStorageResult` is the installed prefix, and the text view's
        /// coordinator drives this session to completion.
        @State private var progressiveSession: ProgressiveTextStorageBuild?

        var body: some View {
            @Bindable var docState = documentState
            GeometryReader { proxy in
                let railWidth = CommentSidebarView.width * sidebarProgress
                let gutterWidth = documentState.isMinimapVisible
                    ? DocumentMinimap.width : ScrollMarkerTrack.width
                HStack(spacing: 0) {
                    SelectableTextView(
                        attributedText: textStorageResult.attributedString,
                        attachments: textStorageResult.attachments,
                        blocks: renderedBlocks,
                        theme: appSettings.theme,
                        isFullReload: isFullReload,
                        reduceMotion: reduceMotion,
                        appSettings: appSettings,
                        documentState: documentState,
                        findQuery: findState.query,
                        findCurrentIndex: findState.currentMatchIndex,
                        findIsVisible: findState.isVisible,
                        findState: findState,
                        outlineState: outlineState,
                        headingOffsets: textStorageResult.headingOffsets,
                        documentHeightModel: textStorageResult.documentHeightModel,
                        resolvedComments: resolvedComments,
                        anchorTape: anchorTape,
                        commentRevision: commentRevision,
                        mapState: mapState,
                        progressiveSession: progressiveSession,
                        onProgressiveOpenFinished: { session, full in
                            // A rebuild that replaced or cleared the session
                            // already published newer content; a stale finish
                            // landing in that gap must not overwrite it.
                            guard session === progressiveSession else { return }
                            // Re-parse rather than cache the open-time entries:
                            // a comment edit made mid-tail is in the source.
                            publishFullResult(
                                full,
                                entries: CommentDocument.parse(documentState.markdownContent).entries
                            )
                            // This publish is identity-stable (no reinstall);
                            // the revision bump drives the highlight repaint
                            // for comments that went nil → resolved.
                            commentRevision += 1
                            progressiveSession = nil
                        },
                        isLoadingGateActive: $docState.isLoadingGateActive
                    )
                    // Changing this identity tears down and recreates the text view's
                    // representable (a fresh cold makeNSView), reusing the already-built
                    // attributed content. Bumped only by the test harness to reproduce
                    // cold first-paint bugs; constant in normal use.
                    .id(documentState.viewRebuildGeneration)
                    .background(appSettings.theme.colors.background)
                    // The rail is a layout sibling, not an overlay: the preview's
                    // width shrinks as the rail opens, so the text reflows into the
                    // narrowed viewport instead of being covered by it. The gutter
                    // (marker track, or the minimap when toggled) is a second,
                    // constant-width sibling on the preview's right.
                    .frame(width: max(proxy.size.width - railWidth - gutterWidth, 0))

                    if documentState.isMinimapVisible {
                        DocumentMinimap(state: mapState)
                    } else {
                        ScrollMarkerTrack(state: mapState)
                    }

                    if documentState.canShowCommentSidebar {
                        CommentSidebarView(
                            active: activeItems,
                            detached: detachedItems,
                            theme: appSettings.theme,
                            mapState: mapState,
                            onJump: { jumpToComment($0) },
                            onDelete: { documentState.deleteComment(id: $0) },
                            onClose: { documentState.toggleCommentSidebar() },
                            onHover: { MkdnCommands.findTextView()?.setHoveredComment($0) }
                        )
                        .frame(width: CommentSidebarView.width)
                        // Mounted whenever it can show so the slide has something to
                        // reveal, but it sits off the clipped edge when closed —
                        // clipping hides it visually, not from VoiceOver, so drop it
                        // from the a11y tree until it's actually opening.
                        .accessibilityHidden(sidebarProgress == 0)
                    }
                }
                // While the rail is partly open the row is wider than the viewport
                // (full preview + rail), so pin it leading and clip the overflow —
                // the rail then slides in from the right edge as the preview narrows.
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    // canShowCommentSidebar gates to preview-only: in split mode this
                    // view is the half-width right pane, so a right-docked rail would
                    // sit inside the preview. The toggle fades out as the rail opens.
                    if documentState.canShowCommentSidebar {
                        CommentSidebarToggle(count: commentCount, theme: appSettings.theme) {
                            documentState.toggleCommentSidebar()
                        }
                        .padding(.top, 12)
                        .padding(.trailing, 16)
                        .opacity(1 - sidebarProgress)
                        .allowsHitTesting(sidebarProgress == 0)
                        .accessibilityHidden(sidebarProgress > 0)
                    }
                }
            }
            .task(id: documentState.markdownContent) {
                if isInitialRender {
                    isInitialRender = false
                } else {
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                }

                OpenTimeline.shared.begin()
                // Strip the sidecar + any stray markers before rendering so they
                // never reach the screen.
                let document = OpenTimeline.shared.time("parse") {
                    CommentDocument.parse(documentState.markdownContent)
                }

                // A comment add/edit/delete changes the raw source but not the
                // visible (body) text. Re-resolve + redraw the overlay instead of
                // rebuilding — no setAttributedString, no attachment relayout, no
                // scroll jump. Fall back to a full rebuild while Find is open:
                // find-match highlights live in the storage and carry save/restore
                // bookkeeping the comment-only path doesn't run.
                // Mid-tail (anchorTape nil) the edit needs no carrying either:
                // the finish re-parses the source, which already holds it.
                if document.body == lastRenderedBody, !findState.isVisible {
                    OpenTimeline.shared.abandon()
                    if let tape = anchorTape {
                        resolvedComments = ResolvedComments.resolve(document.entries, in: tape)
                    }
                    commentRevision += 1
                    return
                }

                lastRenderedBody = document.body
                let newBlocks = OpenTimeline.shared.time("render") {
                    MarkdownRenderer.render(
                        text: document.body,
                        theme: appSettings.theme,
                        generation: documentState.loadGeneration
                    )
                }
                cachedBlocks = newBlocks

                let anyKnown = newBlocks.contains { knownBlockIDs.contains($0.id) }
                let shouldAnimate = !anyKnown && !reduceMotion && !newBlocks.isEmpty

                if Self.shouldOpenProgressively(newBlocks, body: document.body) {
                    openProgressively(
                        newBlocks, isFullReload: shouldAnimate, entries: document.entries
                    )
                } else {
                    renderAndBuild(newBlocks, isFullReload: shouldAnimate, entries: document.entries)
                }
            }
            .onChange(of: appSettings.theme) {
                renderAndBuild(cachedBlocks, isFullReload: false)
            }
            .onChange(of: appSettings.scaleFactor) {
                renderAndBuild(cachedBlocks, isFullReload: false)
            }
            .onChange(of: documentState.isCommentSidebarVisible) { _, visible in
                // Only resize when the rail can actually mount: in split mode the
                // sidebar is gated off, so animating the width here would shrink the
                // pane by 300pt with nothing to show (the harness can flip this flag
                // directly, bypassing the gated menu/toggle).
                guard documentState.canShowCommentSidebar else { return }
                // Skip a zero-delta toggle. Animating sidebarProgress to the value it
                // already holds can drop the completion, so endSidebarResize never fires
                // and the gesture flag latches — freezing the map/height for the session.
                // It also resyncs after a mode-switch round-trip left isCommentSidebarVisible
                // and sidebarProgress disagreeing.
                guard sidebarProgress != (visible ? 1 : 0) else { return }
                // Capture the viewport anchor while the layout still reflects the old
                // width, animate the width, then settle the anchor once at the end.
                // The per-frame re-pin runs from the text view's tile().
                sidebarResizeToken += 1
                let token = sidebarResizeToken
                let textView = MkdnCommands.findTextView()
                textView?.beginSidebarResize()
                withAnimation(motion.resolved(.sidebarSlide)) {
                    sidebarProgress = visible ? 1 : 0
                } completion: {
                    // Only the latest slide tears down the anchor; a stale completion
                    // from a superseded toggle leaves the live re-pin running.
                    if token == sidebarResizeToken { textView?.endSidebarResize() }
                }
            }
            .onChange(of: documentState.canShowCommentSidebar) { _, canShow in
                // A mode switch (e.g. into split) drops the rail; collapse instantly so
                // the preview reclaims full width with no dangling animation, and clear
                // any in-flight anchor so a dropped slide completion can't leave the
                // text view's resize state stuck (every later tile() would no-op).
                if !canShow {
                    sidebarProgress = 0
                    MkdnCommands.findTextView()?.endSidebarResize()
                }
            }
            .onAppear {
                sidebarProgress = documentState.canShowCommentSidebar
                    && documentState.isCommentSidebarVisible ? 1 : 0
            }
        }

        private var activeItems: [CommentSidebarItem] {
            (resolvedComments?.active ?? []).map { CommentSidebarItem($0.entry) }
        }

        private var detachedItems: [CommentSidebarItem] {
            (resolvedComments?.orphans ?? []).map { CommentSidebarItem($0) }
        }

        private var commentCount: Int {
            guard let resolved = resolvedComments else { return 0 }
            return resolved.ranges.count + resolved.orphans.count
        }

        /// Smooth-scroll to the comment's span. The sidebar stays open, and the
        /// card's hover keeps the span emphasized.
        private func jumpToComment(_ id: String) {
            guard let range = resolvedComments?.ranges[id] else { return }
            MkdnCommands.findTextView()?.scrollComment(to: range)
        }

        /// `entries` is the already-parsed sidecar for the content-change path; the
        /// theme/scale re-render paths pass nil and re-parse (content unchanged).
        private func renderAndBuild(
            _ newBlocks: [IndexedBlock], isFullReload animate: Bool,
            entries: [CommentSidecar.Entry]? = nil
        ) {
            beginRenderGeneration(newBlocks, isFullReload: animate)
            let result = OpenTimeline.shared.time("build") {
                MarkdownTextStorageBuilder.build(
                    blocks: newBlocks,
                    theme: appSettings.theme,
                    scaleFactor: appSettings.scaleFactor,
                    appSettings: appSettings
                )
            }
            let resolved = entries ?? CommentDocument.parse(documentState.markdownContent).entries
            publishFullResult(result, entries: resolved)
            outlineState.updateHeadings(from: newBlocks)
        }

        // MARK: - Progressive Open

        /// Documents below these sizes build fast enough to install whole; the
        /// constants are calibrated against the perf fixtures (a 250-block /
        /// 78KB document builds in roughly a third of a second).
        private static let progressiveBlockThreshold = 200
        private static let progressiveSourceThreshold = 200_000
        /// First-paint prefix: enough blocks to cover a couple of viewports of
        /// estimated height, capped so a pathological document still paints.
        private static let prefixHeightTarget: CGFloat = 3000
        private static let prefixDeadline: Duration = .milliseconds(250)
        /// Width assumption for the prefix-height estimate (the real width is
        /// unknown until AppKit lays out). Wider than any typical preview
        /// column: over-guessing the width under-estimates each fragment's
        /// height, so the loop builds more blocks — the error direction that
        /// over-fills the prefix rather than leaving the first paint short.
        private static let prefixMeasureWidth: CGFloat = 1200

        private static func shouldOpenProgressively(
            _ blocks: [IndexedBlock], body: String
        ) -> Bool {
            blocks.count >= progressiveBlockThreshold
                || body.utf16.count >= progressiveSourceThreshold
        }

        /// Viewport-first open: build and publish only the first viewport's
        /// blocks, then hand the session to the text view's coordinator, which
        /// appends the tail in main-actor slices and calls back with the full
        /// result (docs/features/height-estimation/viewport-first-perf-plan.md).
        private func openProgressively(
            _ newBlocks: [IndexedBlock], isFullReload animate: Bool,
            entries: [CommentSidecar.Entry]
        ) {
            beginRenderGeneration(newBlocks, isFullReload: animate)
            let session = ProgressiveTextStorageBuild(
                blocks: newBlocks,
                theme: appSettings.theme,
                scaleFactor: appSettings.scaleFactor,
                appSettings: appSettings
            )
            OpenTimeline.shared.time("buildPrefix") {
                Self.buildPrefix(session)
            }
            if session.isComplete {
                // The prefix loop swallowed the whole document (threshold-edge
                // size); publish it like an ordinary open.
                publishFullResult(session.result(), entries: entries)
            } else {
                progressiveSession = session
                textStorageResult = session.partialResult()
                // No tape or comments until the tail lands the full text, and
                // no map: the previous document's marks would stay clickable
                // for the whole tail (rebuilds are suppressed until the finish).
                anchorTape = nil
                resolvedComments = nil
                mapState.documentMap = PreviewDocumentMap()
            }
            outlineState.updateHeadings(from: newBlocks)
        }

        /// Shared per-render bookkeeping for both open paths. Clearing the
        /// session matters on the synchronous path too: a theme/scale rebuild
        /// replaces the storage whole, and a progressive session still in
        /// flight must not hand its tail to the new content.
        private func beginRenderGeneration(
            _ newBlocks: [IndexedBlock], isFullReload animate: Bool
        ) {
            renderedBlocks = newBlocks
            knownBlockIDs = Set(newBlocks.map(\.id))
            isFullReload = animate
            progressiveSession = nil
        }

        /// Build blocks until the estimated prefix height covers the target or
        /// the deadline passes. The caller reads the result off the session
        /// (`partialResult()` or `result()`), so the threshold-edge case that
        /// completes the document doesn't pay for a discarded prefix snapshot.
        private static func buildPrefix(_ session: ProgressiveTextStorageBuild) {
            let deadline = ContinuousClock.now + prefixDeadline
            var estimated: CGFloat = 0
            while !session.isComplete, estimated < prefixHeightTarget,
                  ContinuousClock.now < deadline
            {
                guard let fragment = session.buildNext(maxBlocks: 8, deadline: deadline)
                else { break }
                estimated += DocumentHeightEstimator.contentHeight(
                    of: fragment, textWidth: prefixMeasureWidth
                )
            }
        }

        /// Publish a complete build: the storage result, the anchor tape built
        /// from its text, and comments resolved against that tape. Shared by the
        /// synchronous open and the progressive finish.
        private func publishFullResult(
            _ result: TextStorageResult, entries: [CommentSidecar.Entry]
        ) {
            textStorageResult = result
            let tape = OpenTimeline.shared.time("anchorTape") {
                AnchorTape.build(from: result.attributedString)
            }
            anchorTape = tape
            resolvedComments = OpenTimeline.shared.time("resolveComments") {
                ResolvedComments.resolve(entries, in: tape)
            }
        }
    }
#endif
