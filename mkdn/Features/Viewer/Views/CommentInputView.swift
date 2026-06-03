#if os(macOS)
    import SwiftUI

    /// The popover shown when adding a comment to a selection. Submits the typed
    /// body; an empty/whitespace body is not submittable.
    struct CommentInputView: View {
        @ObservedObject var model: CommentOverlayModel
        let theme: AppTheme
        let onSubmit: (String) -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var text = ""

        private var trimmed: String {
            text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add comment")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.foregroundSecondary)
                TextEditor(text: $text)
                    .font(.body)
                    .frame(width: 280, height: 72)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(theme.colors.border))
                HStack {
                    Spacer()
                    Button("Comment") { onSubmit(trimmed) }
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(trimmed.isEmpty)
                }
                .buttonStyle(.borderless)
            }
            .padding(12)
            .frame(width: 300)
            .commentBox(theme: theme)
            .commentOverlayTransition(model: model, reduceMotion: reduceMotion)
        }
    }
#endif
