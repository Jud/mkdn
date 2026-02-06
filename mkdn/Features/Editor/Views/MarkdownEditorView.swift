import SwiftUI

/// A plain-text Markdown editor using a native `TextEditor`.
///
/// Displays a subtle theme-accent border when focused and suppresses
/// the default system focus ring for a polished appearance.
struct MarkdownEditorView: View {
    @Binding var text: String
    @Environment(AppState.self) private var appState
    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(appState.theme.colors.foreground)
            .scrollContentBackground(.hidden)
            .background(appState.theme.colors.background)
            .focused($isFocused)
            .focusEffectDisabled()
            .padding(8)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        appState.theme.colors.accent.opacity(isFocused ? 0.3 : 0),
                        lineWidth: 1.5
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
