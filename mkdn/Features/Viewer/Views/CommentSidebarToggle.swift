#if os(macOS)
    import SwiftUI

    /// The floating affordance that opens the comment sidebar, shown top-right of
    /// the content (the window is chrome-less, so there's no toolbar to host it).
    /// With no comments it's a bare circle; once there are comments it carries a
    /// count. The hotkey (⌘⇧C) is intentionally not surfaced here.
    struct CommentSidebarToggle: View {
        let count: Int
        let theme: AppTheme
        let action: () -> Void

        private static let diameter: CGFloat = 34

        var body: some View {
            Button(action: action) {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 13, weight: .medium))
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption.weight(.semibold))
                    }
                }
                .foregroundStyle(theme.colors.foregroundSecondary)
                .padding(.horizontal, count > 0 ? 11 : 0)
                .frame(
                    width: count > 0 ? nil : Self.diameter,
                    height: Self.diameter
                )
                .background(theme.colors.backgroundSecondary)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(theme.colors.border.opacity(0.4)))
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .accessibilityLabel(count > 0 ? "Comments (\(count))" : "Comments")
        }
    }
#endif
