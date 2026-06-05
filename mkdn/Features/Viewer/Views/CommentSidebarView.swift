#if os(macOS)
    import SwiftUI

    /// One row in the comment sidebar, decoupled from the resolver: `active` rows
    /// (anchor located on the page) show a quote chip + body + jump; `detached`
    /// rows (anchor lost) show the struck quote-in-context + Re-place / Delete.
    struct CommentSidebarItem: Identifiable, Equatable {
        let id: String
        let body: String
        let quote: String
        let prefix: String
        let suffix: String
    }

    /// Which comments the sidebar lists.
    enum CommentFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case onPage = "On page"
        case detached = "Detached"

        var id: String { rawValue }
    }

    /// The right-docked comment panel: an "On this page" section (resolved
    /// comments) and a "Detached" section (anchors that couldn't be located),
    /// gated by a segmented filter. Pure presentation — the host maps
    /// ``ResolvedComments`` into items and supplies the jump/delete actions.
    struct CommentSidebarView: View {
        let active: [CommentSidebarItem]
        let detached: [CommentSidebarItem]
        let theme: AppTheme
        let onJump: (String) -> Void
        let onReplace: (String) -> Void
        let onDelete: (String) -> Void
        let onClose: () -> Void

        static let width: CGFloat = 300

        @State private var filter: CommentFilter = .all

        private var hasActive: Bool { filter != .detached && !active.isEmpty }
        private var hasDetached: Bool { filter != .onPage && !detached.isEmpty }
        private var isEmpty: Bool { !hasActive && !hasDetached }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                header
                CommentFilterPicker(filter: $filter, theme: theme)
                content
            }
            .padding(16)
            .frame(width: Self.width, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(theme.colors.backgroundSecondary)
            .environment(\.colorScheme, theme.colorScheme)
        }

        private var header: some View {
            HStack {
                Text("Comments")
                    .font(.headline)
                    .foregroundStyle(theme.colors.headingColor)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.colors.foregroundSecondary)
                }
                .buttonStyle(.borderless)
                .pointingHandCursor()
                .accessibilityLabel("Close comments")
            }
        }

        @ViewBuilder
        private var content: some View {
            if isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if hasActive {
                            section("On this page") {
                                ForEach(active) { item in
                                    ActiveCommentCard(item: item, theme: theme, onJump: onJump)
                                }
                            }
                        }
                        if hasDetached {
                            section("Detached (\(detached.count))") {
                                Text("These comments' anchors are no longer in the document.")
                                    .font(.caption)
                                    .foregroundStyle(theme.colors.foregroundSecondary)
                                ForEach(detached) { item in
                                    DetachedCommentCard(
                                        item: item, theme: theme,
                                        onReplace: onReplace, onDelete: onDelete
                                    )
                                }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.never)
            }
        }

        private var emptyState: some View {
            VStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 22))
                Text(filter == .all ? "No comments yet" : "Nothing here")
                    .font(.callout)
            }
            .foregroundStyle(theme.colors.foregroundSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private func section(
            _ title: String, @ViewBuilder _ rows: () -> some View
        ) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.colors.foregroundSecondary)
                rows()
            }
        }
    }

    /// Segmented filter control, themed (selected segment filled with `accent`).
    /// Hand-rolled rather than a native segmented `Picker` so every color is a
    /// ``ThemeColors`` token instead of the system accent.
    private struct CommentFilterPicker: View {
        @Binding var filter: CommentFilter
        let theme: AppTheme

        var body: some View {
            HStack(spacing: 0) {
                ForEach(CommentFilter.allCases) { option in
                    let selected = option == filter
                    Text(option.rawValue)
                        .font(.caption.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? theme.colors.background : theme.colors.foregroundSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(selected ? theme.colors.accent : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { filter = option }
                        .pointingHandCursor()
                }
            }
            .background(theme.colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.colors.border.opacity(0.5)))
        }
    }

    private let commentCardCornerRadius: CGFloat = 8

    private extension View {
        /// The flat, opaque card surface shared by both sidebar cards. The border
        /// differs per card (solid vs dashed warning), so callers add their own
        /// `.overlay`.
        func commentCardSurface(theme: AppTheme) -> some View {
            padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.colors.background)
                .clipShape(RoundedRectangle(cornerRadius: commentCardCornerRadius))
        }
    }

    /// A resolved comment: quote chip (in `commentHighlight`) + body, revealing a
    /// jump affordance on hover. The whole card jumps to the comment when clicked.
    private struct ActiveCommentCard: View {
        let item: CommentSidebarItem
        let theme: AppTheme
        let onJump: (String) -> Void

        @State private var hovering = false

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                if !item.quote.isEmpty {
                    Text(item.quote)
                        .font(.caption)
                        .foregroundStyle(theme.colors.headingColor)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.colors.commentHighlight)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text(item.body)
                    .font(.body)
                    .foregroundStyle(theme.colors.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if hovering {
                    Text("↳ Jump")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.colors.accent)
                }
            }
            .commentCardSurface(theme: theme)
            .overlay(
                RoundedRectangle(cornerRadius: commentCardCornerRadius)
                    .strokeBorder(theme.colors.border.opacity(0.4))
            )
            .contentShape(Rectangle())
            .onTapGesture { onJump(item.id) }
            .onHover { hovering = $0 }
            .pointingHandCursor()
        }
    }

    /// A detached comment: dashed `warning` treatment, the original quote shown
    /// struck-through in its saved context, then Re-place / Delete.
    private struct DetachedCommentCard: View {
        let item: CommentSidebarItem
        let theme: AppTheme
        let onReplace: (String) -> Void
        let onDelete: (String) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Detached")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.colors.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(theme.colors.warning.opacity(0.6))
                    )
                context
                Text(item.body)
                    .font(.body)
                    .foregroundStyle(theme.colors.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                actions
            }
            .commentCardSurface(theme: theme)
            .overlay(
                RoundedRectangle(cornerRadius: commentCardCornerRadius)
                    .strokeBorder(
                        theme.colors.warning.opacity(0.5),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
        }

        private var context: some View {
            var text = Text("was on ")
            if !item.prefix.isEmpty {
                text = text + Text("…\(item.prefix)")
            }
            text = text + Text(item.quote).strikethrough()
            if !item.suffix.isEmpty {
                text = text + Text("\(item.suffix)…")
            }
            return text
                .font(.caption)
                .foregroundColor(theme.colors.foregroundSecondary)
                .lineLimit(2)
        }

        private var actions: some View {
            HStack {
                Button("Re-place…") { onReplace(item.id) }
                    .foregroundStyle(theme.colors.accent)
                    .pointingHandCursor()
                Spacer()
                Button("Delete", role: .destructive) { onDelete(item.id) }
                    .foregroundStyle(theme.colors.danger)
                    .pointingHandCursor()
            }
            .font(.caption.weight(.medium))
            .buttonStyle(.borderless)
        }
    }
#endif
