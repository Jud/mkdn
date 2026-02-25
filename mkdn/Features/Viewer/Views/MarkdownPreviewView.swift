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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var renderedBlocks: [IndexedBlock] = []
    @State private var isInitialRender = true
    @State private var knownBlockIDs: Set<String> = []
    @State private var textStorageResult = TextStorageResult(
        attributedString: NSAttributedString(),
        attachments: []
    )
    @State private var isFullReload = false

    var body: some View {
        SelectableTextView(
            attributedText: textStorageResult.attributedString,
            attachments: textStorageResult.attachments,
            tableOverlays: textStorageResult.tableOverlays,
            blocks: renderedBlocks,
            theme: appSettings.theme,
            isFullReload: isFullReload,
            reduceMotion: reduceMotion,
            appSettings: appSettings,
            documentState: documentState,
            findQuery: findState.query,
            findCurrentIndex: findState.currentMatchIndex,
            findIsVisible: findState.isVisible,
            findState: findState
        )
        .background(appSettings.theme.colors.background)
        .task(id: documentState.markdownContent) {
            if isInitialRender {
                isInitialRender = false
            } else {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
            }

            let newBlocks = MarkdownRenderer.render(
                text: documentState.markdownContent,
                theme: appSettings.theme
            )

            let anyKnown = newBlocks.contains { knownBlockIDs.contains($0.id) }
            let shouldAnimate = !anyKnown && !reduceMotion && !newBlocks.isEmpty

            renderedBlocks = newBlocks
            knownBlockIDs = Set(newBlocks.map(\.id))
            isFullReload = shouldAnimate
            textStorageResult = MarkdownTextStorageBuilder.build(
                blocks: newBlocks,
                theme: appSettings.theme,
                scaleFactor: appSettings.scaleFactor
            )
        }
        .onChange(of: appSettings.theme) {
            let newBlocks = MarkdownRenderer.render(
                text: documentState.markdownContent,
                theme: appSettings.theme
            )
            renderedBlocks = newBlocks
            knownBlockIDs = Set(newBlocks.map(\.id))
            isFullReload = false
            textStorageResult = MarkdownTextStorageBuilder.build(
                blocks: newBlocks,
                theme: appSettings.theme,
                scaleFactor: appSettings.scaleFactor
            )
        }
        .onChange(of: appSettings.scaleFactor) {
            let newBlocks = MarkdownRenderer.render(
                text: documentState.markdownContent,
                theme: appSettings.theme
            )
            renderedBlocks = newBlocks
            knownBlockIDs = Set(newBlocks.map(\.id))
            isFullReload = false
            textStorageResult = MarkdownTextStorageBuilder.build(
                blocks: newBlocks,
                theme: appSettings.theme,
                scaleFactor: appSettings.scaleFactor
            )
        }
    }
}
