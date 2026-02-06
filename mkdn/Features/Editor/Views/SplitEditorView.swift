import SwiftUI

/// Side-by-side editor and preview split view.
struct SplitEditorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ResizableSplitView {
            editorPane
        } right: {
            MarkdownPreviewView()
        }
        .focusEffectDisabled()
    }

    private var editorPane: some View {
        @Bindable var state = appState

        return MarkdownEditorView(text: $state.markdownContent)
            .background(appState.theme.colors.background)
    }
}
