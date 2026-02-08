import SwiftUI

/// A plain-text Markdown editor using a native `TextEditor`.
///
/// Displays a subtle theme-accent border when focused and suppresses
/// the default system focus ring for a polished appearance.
struct MarkdownEditorView: View {
    @Binding var text: String
    @Environment(AppSettings.self) private var appSettings
    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(appSettings.theme.colors.foreground)
            .scrollContentBackground(.hidden)
            .background(appSettings.theme.colors.background)
            .focused($isFocused)
            .focusEffectDisabled()
            .padding(8)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        appSettings.theme.colors.accent.opacity(isFocused ? 0.3 : 0),
                        lineWidth: 1.5
                    )
            )
            .animation(AnimationConstants.quickShift, value: isFocused)
    }
}
