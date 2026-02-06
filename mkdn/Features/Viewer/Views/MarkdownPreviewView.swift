import SwiftUI

/// Full-width Markdown preview (read-only mode).
///
/// Rendering is debounced via `.task(id:)` so that rapid typing in the
/// editor does not trigger a re-render on every keystroke. The initial
/// render on appear is performed without delay.
struct MarkdownPreviewView: View {
    @Environment(AppState.self) private var appState

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
        .background(appState.theme.colors.background)
        .task(id: appState.markdownContent) {
            if isInitialRender {
                isInitialRender = false
            } else {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
            }
            renderedBlocks = MarkdownRenderer.render(
                text: appState.markdownContent,
                theme: appState.theme
            )
        }
        .onChange(of: appState.theme) {
            renderedBlocks = MarkdownRenderer.render(
                text: appState.markdownContent,
                theme: appState.theme
            )
        }
    }
}
