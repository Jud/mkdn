#if os(macOS)
    import SwiftUI

    /// The content shown in the popover when a reader clicks a commented span.
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
                    // Wrap long bodies and grow vertically instead of truncating
                    // (a fixed width is needed because the popover sizes to fit).
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 300, alignment: .leading)
            .background(theme.colors.background)
        }
    }
#endif
