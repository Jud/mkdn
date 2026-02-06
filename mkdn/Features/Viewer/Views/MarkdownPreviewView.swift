import SwiftUI

/// Full-width Markdown preview (read-only mode).
struct MarkdownPreviewView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let blocks = MarkdownRenderer.render(
            text: appState.markdownContent,
            theme: appState.theme
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(blocks) { block in
                    MarkdownBlockView(block: block)
                }
            }
            .padding(24)
        }
        .background(appState.theme.colors.background)
    }
}
