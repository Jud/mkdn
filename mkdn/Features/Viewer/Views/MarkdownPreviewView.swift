#if os(macOS)
    import SwiftUI

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

        @State private var renderedBlocks: [IndexedBlock] = []
        @State private var cachedBlocks: [IndexedBlock] = []
        @State private var isInitialRender = true
        @State private var knownBlockIDs: Set<String> = []
        @State private var textStorageResult = TextStorageResult(
            attributedString: NSAttributedString(),
            attachments: []
        )
        @State private var isFullReload = false
        /// The CriticMarkup parse of the current content, cached so theme/scale
        /// re-renders can re-apply comment highlights without re-preprocessing.
        @State private var criticDocument: CriticMarkupDocument?
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
                criticDocument: criticDocument,
                commentSourceMap: textStorageResult.sourceMap,
                resolvedComments: resolvedComments,
                commentRevision: commentRevision,
                isLoadingGateActive: $docState.isLoadingGateActive
            )
            // Changing this identity tears down and recreates the text view's
            // representable (a fresh cold makeNSView), reusing the already-built
            // attributed content. Bumped only by the test harness to reproduce
            // cold first-paint bugs; constant in normal use.
            .id(documentState.viewRebuildGeneration)
            .background(appSettings.theme.colors.background)
            .task(id: documentState.markdownContent) {
                if isInitialRender {
                    isInitialRender = false
                } else {
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                }

                // Strip CriticMarkup before rendering so comment delimiters never
                // reach the screen; the parse is cached for highlight application.
                let document = CriticMarkup.preprocess(documentState.markdownContent)

                // A comment add/edit/delete changes the raw source but not the
                // visible (transformed) text. Repaint highlights on the live
                // storage instead of rebuilding — no setAttributedString, no
                // attachment relayout, no scroll jump. Fall back to a full rebuild
                // while Find is open: find-match highlights share `.backgroundColor`
                // with comments, live in the storage (not the cached base), and
                // carry save/restore bookkeeping the scoped repaint would corrupt;
                // the rebuild path re-applies them correctly. (`criticDocument`
                // still holds the previously rendered parse here.)
                if document.transformedSource == criticDocument?.transformedSource,
                   !findState.isVisible {
                    criticDocument = document
                    if let tape = anchorTape {
                        resolvedComments = ResolvedComments.resolve(
                            CommentDocument.parse(documentState.markdownContent).entries, in: tape
                        )
                    }
                    commentRevision += 1
                    return
                }

                criticDocument = document
                let newBlocks = MarkdownRenderer.render(
                    text: document.transformedSource,
                    theme: appSettings.theme,
                    generation: documentState.loadGeneration
                )
                cachedBlocks = newBlocks

                let anyKnown = newBlocks.contains { knownBlockIDs.contains($0.id) }
                let shouldAnimate = !anyKnown && !reduceMotion && !newBlocks.isEmpty

                renderAndBuild(newBlocks, isFullReload: shouldAnimate)
            }
            .onChange(of: appSettings.theme) {
                renderAndBuild(cachedBlocks, isFullReload: false)
            }
            .onChange(of: appSettings.scaleFactor) {
                renderAndBuild(cachedBlocks, isFullReload: false)
            }
        }

        private func renderAndBuild(_ newBlocks: [IndexedBlock], isFullReload animate: Bool) {
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
            resolvedComments = ResolvedComments.resolve(
                CommentDocument.parse(documentState.markdownContent).entries, in: tape
            )
            outlineState.updateHeadings(from: newBlocks)
        }
    }
#endif
