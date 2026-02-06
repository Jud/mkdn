import SwiftUI

/// A plain-text Markdown editor using a native `TextEditor`.
struct MarkdownEditorView: View {
    @Binding var text: String
    @Environment(AppState.self) private var appState

    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(appState.theme.colors.foreground)
            .scrollContentBackground(.hidden)
            .background(appState.theme.colors.background)
            .padding(8)
    }
}
