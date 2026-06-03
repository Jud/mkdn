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
        /// Called when a body edit is saved, so the host can keep the overlay open
        /// through the resulting content rebuild (the edit only changed the sidecar).
        let onEdited: () -> Void
        /// Emphasize (id) / un-emphasize (nil) the hovered comment in the document.
        let onHover: (String?) -> Void
        let onDragChanged: (CGSize) -> Void
        let onDragEnded: () -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // The header doubles as a drag handle so the box can be pulled off
                // text it covers.
                Text(comments.count > 1 ? "Comments" : "Comment")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.foregroundSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .gesture(
                        // Global space: translation stays stable as the box moves,
                        // avoiding a feedback loop (the box jittering).
                        DragGesture(coordinateSpace: .global)
                            .onChanged { onDragChanged($0.translation) }
                            .onEnded { _ in onDragEnded() }
                    )

                ForEach(comments) { comment in
                    CommentRowView(
                        comment: comment,
                        source: source,
                        theme: theme,
                        documentState: documentState,
                        onClose: onClose,
                        onEdited: onEdited,
                        onHover: onHover
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
        let onEdited: () -> Void
        let onHover: (String?) -> Void

        @State private var isEditing = false
        @State private var draft = ""
        /// The body to show after an in-place edit, so the row reflects the save
        /// without waiting for (or being torn down by) a content rebuild.
        @State private var editedBody: String?

        private var body0: String { editedBody ?? comment.body }

        private var trimmedDraft: String {
            draft.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                if isEditing {
                    editor
                } else {
                    Text(body0)
                        .font(.body)
                        .foregroundStyle(theme.colors.foreground)
                        .textSelection(.enabled)
                    if let documentState {
                        actions(documentState)
                    }
                }
            }
            .contentShape(Rectangle())
            .onHover { onHover($0 ? comment.id : nil) }
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
                    Button("Cancel") { withAnimation(AnimationConstants.outlinePop) { isEditing = false } }
                        .pointingHandCursor()
                    Spacer()
                    Button("Save", action: save)
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(trimmedDraft.isEmpty)
                        .pointingHandCursor()
                }
                .buttonStyle(.borderless)
            }
        }

        private func save() {
            // Keep the editor open (and the draft) if the edit is rejected.
            guard documentState?.editComment(id: comment.id, of: source, newBody: trimmedDraft) == true
            else {
                return
            }
            onEdited() // keep the overlay alive through the rebuild this triggers
            withAnimation(AnimationConstants.outlinePop) {
                editedBody = trimmedDraft
                isEditing = false
            }
        }

        private func actions(_ documentState: DocumentState) -> some View {
            HStack {
                Button("Edit") {
                    draft = body0
                    withAnimation(AnimationConstants.outlinePop) { isEditing = true }
                }
                .pointingHandCursor()
                Spacer()
                Button("Delete", role: .destructive) {
                    if documentState.deleteComment(id: comment.id, of: source) {
                        onClose()
                    }
                }
                .pointingHandCursor()
            }
            .buttonStyle(.borderless)
        }
    }
#endif
