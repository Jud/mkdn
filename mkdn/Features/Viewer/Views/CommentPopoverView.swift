#if os(macOS)
    import SwiftUI

    /// The content shown in the popover when a reader clicks a commented span.
    /// Edit/Delete appear only when a `documentState` is available to persist
    /// them; mutations are keyed by comment id so they resolve against the
    /// current content (never a stale range).
    struct CommentPopoverView: View {
        let commentID: String
        let commentBody: String
        /// The content the id was resolved against; edit/delete reject if it no
        /// longer matches, so a re-keyed id can't mutate the wrong comment.
        let source: String
        let theme: AppTheme
        let documentState: DocumentState?
        let onClose: () -> Void

        @State private var isEditing = false
        @State private var draft = ""

        private var trimmedDraft: String {
            draft.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// Match the control appearance to the theme, not the system: otherwise a
        /// light theme under a dark-mode system renders button labels in light
        /// (dark-mode) text on the light popover — invisible.
        private var colorScheme: ColorScheme {
            theme == .solarizedDark ? .dark : .light
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Comment")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.foregroundSecondary)

                if isEditing {
                    editor
                } else {
                    Text(commentBody)
                        .font(.body)
                        .foregroundStyle(theme.colors.foreground)
                        .textSelection(.enabled)
                    if let documentState {
                        actions(documentState)
                    }
                }
            }
            .padding(12)
            .frame(width: 300, alignment: .leading)
            .background(theme.colors.background)
            .environment(\.colorScheme, colorScheme)
        }

        private var editor: some View {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $draft)
                    .font(.body)
                    .frame(height: 72)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(theme.colors.border))
                HStack {
                    Button("Cancel") { isEditing = false }
                    Spacer()
                    Button("Save") {
                        // Keep the editor open (and the draft) if the edit is rejected.
                        if documentState?.editComment(id: commentID, of: source, newBody: trimmedDraft) == true {
                            onClose()
                        }
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(trimmedDraft.isEmpty)
                }
            }
        }

        private func actions(_ documentState: DocumentState) -> some View {
            HStack {
                Button("Edit") {
                    draft = commentBody
                    isEditing = true
                }
                Spacer()
                Button("Delete", role: .destructive) {
                    if documentState.deleteComment(id: commentID, of: source) {
                        onClose()
                    }
                }
            }
        }
    }
#endif
