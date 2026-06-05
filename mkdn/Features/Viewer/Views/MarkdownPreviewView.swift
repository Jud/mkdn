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

        var body: some View {
            @Bindable var docState = documentState
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
                resolvedComments: resolvedComments,
                anchorTape: anchorTape,
                commentRevision: commentRevision,
                isLoadingGateActive: $docState.isLoadingGateActive
            )
            // Changing this identity tears down and recreates the text view's
            // representable (a fresh cold makeNSView), reusing the already-built
            // attributed content. Bumped only by the test harness to reproduce
            // cold first-paint bugs; constant in normal use.
            .id(documentState.viewRebuildGeneration)
            .background(appSettings.theme.colors.background)
            .overlay(alignment: .topTrailing) {
                // canShowCommentSidebar gates to preview-only: in split mode this
                // view is the half-width right pane, so a right-docked rail would
                // sit inside the preview.
                if documentState.canShowCommentSidebar, !documentState.isCommentSidebarVisible {
                    CommentSidebarToggle(count: commentCount, theme: appSettings.theme) {
                        documentState.toggleCommentSidebar()
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .trailing) {
                if documentState.canShowCommentSidebar, documentState.isCommentSidebarVisible {
                    CommentSidebarView(
                        active: activeItems,
                        detached: detachedItems,
                        theme: appSettings.theme,
                        onJump: { jumpToComment($0) },
                        onReplace: { _ in },
                        onDelete: { documentState.deleteComment(id: $0) },
                        onClose: { documentState.toggleCommentSidebar() }
                    )
                    // Slides in over the content (the overlay never displaces or
                    // resizes the text beneath it, so nothing reflows or jumps).
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(motion.resolved(.sidebarSlide), value: documentState.isCommentSidebarVisible)
            .task(id: documentState.markdownContent) {
                if isInitialRender {
                    isInitialRender = false
                } else {
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                }

                // Strip the sidecar + any stray markers before rendering so they
                // never reach the screen.
                let document = CommentDocument.parse(documentState.markdownContent)

                // A comment add/edit/delete changes the raw source but not the
                // visible (body) text. Re-resolve + redraw the overlay instead of
                // rebuilding — no setAttributedString, no attachment relayout, no
                // scroll jump. Fall back to a full rebuild while Find is open:
                // find-match highlights live in the storage and carry save/restore
                // bookkeeping the comment-only path doesn't run.
                if document.body == lastRenderedBody, !findState.isVisible {
                    if let tape = anchorTape {
                        resolvedComments = ResolvedComments.resolve(document.entries, in: tape)
                    }
                    commentRevision += 1
                    return
                }

                lastRenderedBody = document.body
                let newBlocks = MarkdownRenderer.render(
                    text: document.body,
                    theme: appSettings.theme,
                    generation: documentState.loadGeneration
                )
                cachedBlocks = newBlocks

                let anyKnown = newBlocks.contains { knownBlockIDs.contains($0.id) }
                let shouldAnimate = !anyKnown && !reduceMotion && !newBlocks.isEmpty

                renderAndBuild(newBlocks, isFullReload: shouldAnimate, entries: document.entries)
            }
            .onChange(of: appSettings.theme) {
                renderAndBuild(cachedBlocks, isFullReload: false)
            }
            .onChange(of: appSettings.scaleFactor) {
                renderAndBuild(cachedBlocks, isFullReload: false)
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

        /// Scroll to the comment's span and flash it, then close the sidebar so the
        /// flashed text isn't left behind the panel.
        private func jumpToComment(_ id: String) {
            // Only close the sidebar if we actually performed the jump — otherwise
            // the user would lose the sidebar with nothing scrolled into view.
            guard let range = resolvedComments?.ranges[id],
                  let textView = MkdnCommands.findTextView()
            else { return }
            textView.revealComment(id: id, range: range)
            documentState.toggleCommentSidebar()
        }

        /// `entries` is the already-parsed sidecar for the content-change path; the
        /// theme/scale re-render paths pass nil and re-parse (content unchanged).
        private func renderAndBuild(
            _ newBlocks: [IndexedBlock], isFullReload animate: Bool,
            entries: [CommentSidecar.Entry]? = nil
        ) {
            renderedBlocks = newBlocks
            knownBlockIDs = Set(newBlocks.map(\.id))
            isFullReload = animate
            let result = MarkdownTextStorageBuilder.build(
                blocks: newBlocks,
                theme: appSettings.theme,
                scaleFactor: appSettings.scaleFactor,
                appSettings: appSettings
            )
            textStorageResult = result
            let tape = AnchorTape.build(from: result.attributedString)
            anchorTape = tape
            let resolved = entries ?? CommentDocument.parse(documentState.markdownContent).entries
            resolvedComments = ResolvedComments.resolve(resolved, in: tape)
            outlineState.updateHeadings(from: newBlocks)
        }
    }
#endif
