#if os(macOS)
    import SwiftUI

    /// One comment to display in the popover.
    struct DisplayedComment: Identifiable, Equatable {
        let id: String
        let body: String
    }

    /// The popover shown when a reader clicks a commented span. When comments
    /// overlap at the click point, all of them are shown stacked (innermost
    /// first). Edit/Delete appear only when a `documentState` is available;
    /// mutations are keyed by comment id so they resolve against the current
    /// content (never a stale range).
    struct CommentPopoverView: View {
        @ObservedObject var model: CommentOverlayModel
        let comments: [DisplayedComment]
        /// The content the ids were resolved against; edit/delete reject if it no
        /// longer matches, so a re-keyed id can't mutate the wrong comment.
        let source: String
        let theme: AppTheme
        let documentState: DocumentState?
        let onClose: () -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(comments.count > 1 ? "Comments" : "Comment")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.foregroundSecondary)

                ForEach(comments) { comment in
                    CommentRowView(
                        comment: comment,
                        source: source,
                        theme: theme,
                        documentState: documentState,
                        onClose: onClose
                    )
                    if comment.id != comments.last?.id {
                        Rectangle()
                            .fill(theme.colors.border.opacity(0.4))
                            .frame(height: 1)
                    }
                }
            }
            .padding(12)
            .frame(width: 300, alignment: .leading)
            .commentBox(theme: theme)
            .commentOverlayTransition(model: model, reduceMotion: reduceMotion)
        }
    }

    /// A single comment within the popover: its body plus Edit/Delete, with an
    /// inline editor when editing. Each row owns its own edit state so stacked
    /// comments edit independently.
    private struct CommentRowView: View {
        let comment: DisplayedComment
        let source: String
        let theme: AppTheme
        let documentState: DocumentState?
        let onClose: () -> Void

        @State private var isEditing = false
        @State private var draft = ""

        private var trimmedDraft: String {
            draft.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var body: some View {
            if isEditing {
                editor
            } else {
                Text(comment.body)
                    .font(.body)
                    .foregroundStyle(theme.colors.foreground)
                    .textSelection(.enabled)
                if let documentState {
                    actions(documentState)
                }
            }
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
                        if documentState?.editComment(id: comment.id, of: source, newBody: trimmedDraft) == true {
                            onClose()
                        }
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(trimmedDraft.isEmpty)
                }
                .buttonStyle(.borderless)
            }
        }

        private func actions(_ documentState: DocumentState) -> some View {
            HStack {
                Button("Edit") {
                    draft = comment.body
                    isEditing = true
                }
                Spacer()
                Button("Delete", role: .destructive) {
                    if documentState.deleteComment(id: comment.id, of: source) {
                        onClose()
                    }
                }
            }
            .buttonStyle(.borderless)
        }
    }
#endif
