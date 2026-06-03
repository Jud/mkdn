#if os(macOS)
    import SwiftUI

    /// The popover shown when adding a comment to a selection. Submits the typed
    /// body; an empty/whitespace body is not submittable.
    struct CommentInputView: View {
        let theme: AppTheme
        let onSubmit: (String) -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var text = ""
        @State private var appeared = false

        private var trimmed: String {
            text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// Match control appearance to the theme, not the system (see
        /// `CommentPopoverView.colorScheme`).
        private var colorScheme: ColorScheme {
            theme == .solarizedDark ? .dark : .light
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
            }
            .padding(12)
            .frame(width: 300)
            .background(theme.colors.background)
            .environment(\.colorScheme, colorScheme)
            .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(reduceMotion ? AnimationConstants.reducedCrossfade : AnimationConstants.springSettle) {
                    appeared = true
                }
            }
        }
    }
#endif
