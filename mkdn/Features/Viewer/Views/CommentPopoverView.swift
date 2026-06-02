#if os(macOS)
    import SwiftUI

    /// The content shown in the popover when a reader clicks a commented span.
    /// v1 shows the comment body only; edit/delete arrive with authoring.
    struct CommentPopoverView: View {
        let commentBody: String
        let theme: AppTheme

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text("Comment")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.foregroundSecondary)
                Text(commentBody)
                    .font(.body)
                    .foregroundStyle(theme.colors.foreground)
                    .textSelection(.enabled)
            }
            .padding(12)
            .frame(maxWidth: 320, alignment: .leading)
            .background(theme.colors.background)
        }
    }
#endif
