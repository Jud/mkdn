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
        /// The built attributed string *before* comment highlights, so a
        /// comment-only change can re-derive highlights without a rebuild.
        @State private var baseAttributedString = NSAttributedString()
        /// The transformed (visible) source of the last full build. When a content
        /// change leaves it identical — a comment add/edit/delete — we repaint
        /// highlights on the live storage instead of rebuilding (avoids the
        /// attachment-relayout scroll jump).
        @State private var lastTransformedSource: String?
        /// Bumped on a comment-only change to drive the live highlight repaint.
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
                baseAttributedText: baseAttributedString,
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
                // attachment relayout, no scroll jump.
                if document.transformedSource == lastTransformedSource {
                    criticDocument = document
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
            baseAttributedString = result.attributedString
            lastTransformedSource = criticDocument?.transformedSource
            textStorageResult = applyingCommentHighlights(to: result)
            outlineState.updateHeadings(from: newBlocks)
        }

        private func applyingCommentHighlights(to result: TextStorageResult) -> TextStorageResult {
            guard let document = criticDocument, !document.comments.isEmpty else { return result }
            let mutable = NSMutableAttributedString(attributedString: result.attributedString)
            MarkdownTextStorageBuilder.applyCommentHighlights(
                to: mutable,
                document: document,
                sourceMap: result.sourceMap,
                color: PlatformTypeConverter.color(from: appSettings.theme.colors.commentHighlight)
            )
            return TextStorageResult(
                attributedString: mutable,
                attachments: result.attachments,
                headingOffsets: result.headingOffsets,
                sourceMap: result.sourceMap
            )
        }
    }
#endif
