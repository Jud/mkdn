#if os(macOS)
    import SwiftUI

    /// The overlay shown when adding a comment to a selection. It composes a new
    /// comment, then morphs in place into that comment's display row on submit
    /// (same box, animated) rather than closing — mirroring an in-place edit save.
    struct CommentInputView: View {
        @ObservedObject var model: CommentOverlayModel
        let theme: AppTheme
        let documentState: DocumentState?
        /// Adds the comment to the document, returning its new id (nil = rejected).
        let addComment: (String) -> String?
        let onClose: () -> Void
        /// Called once the comment is created, so the host can keep the overlay
        /// through the resulting rebuild and mark it as the open comment.
        let onAdded: (String) -> Void
        /// Called when the (now-created) comment is edited, same as the popover.
        let onEdited: () -> Void
        let onHover: (String?) -> Void
        let onDragChanged: (CGSize) -> Void
        let onDragEnded: () -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var draft = ""
        /// The created comment; once set, the box shows its display row instead of
        /// the compose editor.
        @State private var created: DisplayedComment?

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                CommentBoxHeader(
                    title: created == nil ? "Add comment" : "Comment",
                    theme: theme, onDragChanged: onDragChanged, onDragEnded: onDragEnded
                )
                if let created {
                    CommentRowView(
                        comment: created,
                        theme: theme,
                        documentState: documentState,
                        onClose: onClose,
                        onEdited: onEdited,
                        onHover: onHover
                    )
                } else {
                    CommentEditor(
                        draft: $draft, theme: theme,
                        cancelTitle: "Cancel", confirmTitle: "Comment",
                        onCancel: onClose, onConfirm: submit
                    )
                }
            }
            .padding(12)
            .frame(width: 300, alignment: .leading)
            .commentBox(theme: theme)
            .commentOverlayTransition(model: model, reduceMotion: reduceMotion)
        }

        private func submit() {
            let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let id = addComment(trimmed) else { return }
            onAdded(id) // keep the overlay through the rebuild + mark it open
            withAnimation(reduceMotion ? AnimationConstants.reducedInstant : AnimationConstants.outlinePop) {
                created = DisplayedComment(id: id, body: trimmed)
            }
        }
    }
#endif
