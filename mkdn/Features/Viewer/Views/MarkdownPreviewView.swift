import SwiftUI

/// Full-width Markdown preview (read-only mode).
///
/// Rendering is debounced via `.task(id:)` so that rapid typing in the
/// editor does not trigger a re-render on every keystroke. The initial
/// render on appear is performed without delay.
struct MarkdownPreviewView: View {
    @Environment(DocumentState.self) private var documentState
    @Environment(AppSettings.self) private var appSettings

    @State private var renderedBlocks: [MarkdownBlock] = []
    @State private var isInitialRender = true

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(renderedBlocks) { block in
                    MarkdownBlockView(block: block)
                }
            }
            .padding(24)
        }
        .background(appSettings.theme.colors.background)
        .task(id: documentState.markdownContent) {
            debugLog(
                "[PREVIEW] .task fired, content length=\(documentState.markdownContent.count), isInitial=\(isInitialRender)"
            )
            if isInitialRender {
                isInitialRender = false
            } else {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else {
                    debugLog("[PREVIEW] task cancelled during debounce")
                    return
                }
            }
            renderedBlocks = MarkdownRenderer.render(
                text: documentState.markdownContent,
                theme: appSettings.theme
            )
            debugLog("[PREVIEW] rendered \(renderedBlocks.count) blocks: \(renderedBlocks.map { type(of: $0) })")
            let mermaidCount = renderedBlocks.filter { block in
                if case .mermaidBlock = block { return true }
                return false
            }.count
            debugLog("[PREVIEW] mermaid blocks: \(mermaidCount)")
        }
        .onChange(of: appSettings.theme) {
            renderedBlocks = MarkdownRenderer.render(
                text: documentState.markdownContent,
                theme: appSettings.theme
            )
        }
    }
}
