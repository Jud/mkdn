#if os(macOS)
    import SwiftUI

    /// One comment to display in the popover.
    struct DisplayedComment: Identifiable, Equatable {
        let id: String
        let body: String
    }

    /// The box's title row, which doubles as a drag handle so the overlay can be
    /// pulled off the text it covers.
    struct CommentBoxHeader: View {
        let title: String
        let theme: AppTheme
        let onDragChanged: (CGSize) -> Void
        let onDragEnded: () -> Void

        var body: some View {
            Text(title)
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
        }
    }

    /// The shared body editor — a text field with a cancel and a confirm action —
    /// used both to compose a new comment and to edit an existing one.
    struct CommentEditor: View {
        @Binding var draft: String
        let theme: AppTheme
        let confirmTitle: String
        let onCancel: () -> Void
        /// Receives the trimmed body, so callers never re-trim (the disable gate
        /// and the submitted value can't diverge).
        let onConfirm: (String) -> Void

        private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $draft)
                    .font(.body)
                    .frame(height: 72)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(theme.colors.border))
                HStack {
                    Button("Cancel", action: onCancel)
                        .pointingHandCursor()
                    Spacer()
                    Button(confirmTitle) { onConfirm(trimmed) }
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(trimmed.isEmpty)
                        .pointingHandCursor()
                }
                .buttonStyle(.borderless)
            }
        }
    }

    /// The popover shown when a reader clicks a commented span. When comments
    /// overlap at the click point, all of them are shown stacked (innermost
    /// first). Edit/Delete appear only when a `documentState` is available;
    /// mutations are keyed by comment id so they resolve against the current
    /// content (never a stale range).
    struct CommentPopoverView: View {
        @ObservedObject var model: CommentOverlayModel
        let comments: [DisplayedComment]
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

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                CommentBoxHeader(
                    title: comments.count > 1 ? "Comments" : "Comment",
                    theme: theme, onDragChanged: onDragChanged, onDragEnded: onDragEnded
                )

                ForEach(comments) { comment in
                    CommentRowView(
                        comment: comment,
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
            .commentOverlayChrome(model: model, theme: theme)
        }
    }

    /// A single comment within a box: its body plus Edit/Delete, with an inline
    /// editor when editing. Each row owns its own edit state so stacked comments
    /// edit independently.
    struct CommentRowView: View {
        let comment: DisplayedComment
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

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                if isEditing {
                    CommentEditor(
                        draft: $draft, theme: theme, confirmTitle: "Save",
                        onCancel: { withAnimation(AnimationConstants.outlinePop) { isEditing = false } },
                        onConfirm: save
                    )
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

        private func save(_ trimmed: String) {
            // Operate on the live document: the overlay only survives its own
            // edits (any other rebuild dismisses it), so its rows always reflect
            // the current content. Keep the editor open (and the draft) if the
            // edit is rejected.
            guard let documentState,
                  documentState.editComment(id: comment.id, of: documentState.markdownContent, newBody: trimmed)
            else {
                return
            }
            onEdited() // keep the overlay alive through the rebuild this triggers
            withAnimation(AnimationConstants.outlinePop) {
                editedBody = trimmed
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
                    if documentState.deleteComment(id: comment.id, of: documentState.markdownContent) {
                        onClose()
                    }
                }
                .pointingHandCursor()
            }
            .buttonStyle(.borderless)
        }
    }
#endif
