import SwiftUI

/// Side-by-side editor and preview split view.
struct SplitEditorView: View {
    @Environment(DocumentState.self) private var documentState
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        ResizableSplitView {
            editorPane
        } right: {
            MarkdownPreviewView()
        }
        .focusEffectDisabled()
    }

    private var editorPane: some View {
        @Bindable var state = documentState

        return MarkdownEditorView(text: $state.markdownContent)
            .background(appSettings.theme.colors.background)
    }
}
