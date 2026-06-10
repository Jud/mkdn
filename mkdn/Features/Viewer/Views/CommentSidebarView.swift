#if os(macOS)
    import SwiftUI

    /// One row in the comment sidebar, decoupled from the resolver: `active` rows
    /// (anchor located on the page) show a quote chip + body; `detached` rows
    /// (anchor lost) show the struck quote-in-context + Delete.
    struct CommentSidebarItem: Identifiable, Equatable {
        let id: String
        let body: String
        let quote: String
        let prefix: String
        let suffix: String
    }

    /// The right-docked comment panel. Active cards float anchored beside the text
    /// they annotate (``AnchoredCommentsLayout``) and follow it on scroll; a floating
    /// header sits over the top, and detached comments (anchors that couldn't be
    /// located) collect in a footer. Pure presentation — the host maps
    /// ``ResolvedComments`` into items and supplies the jump/delete actions and the
    /// ``PreviewMapState`` the anchors come from.
    struct CommentSidebarView: View {
        let active: [CommentSidebarItem]
        let detached: [CommentSidebarItem]
        let theme: AppTheme
        /// Published positions: each active comment's scroll-space `y` plus the live
        /// `viewportTop`, so cards anchor beside the text and follow it on scroll.
        let mapState: PreviewMapState
        let onJump: (String) -> Void
        let onDelete: (String) -> Void
        /// Emphasize (id) / un-emphasize (nil) a comment's span in the document
        /// while its card is hovered.
        let onHover: (String?) -> Void

        static let width: CGFloat = 300
        /// The preview's `textContainerInset.height`, added back so a card lands
        /// beside the live text rather than the inset-subtracted scroll-space mark.
        private static let previewTopInset: CGFloat = 32

        var body: some View {
            let map = mapState.documentMap
            let cardTops = Dictionary(
                map.comments.map { ($0.id, $0.y - map.viewportTop + Self.previewTopInset) },
                uniquingKeysWith: { first, _ in first }
            )
            // At the scroll end a card tail can't be pulled up by scrolling; let the
            // layout fit the overflow then. A short/unscrollable document reads as "end".
            let atDocumentEnd = map.totalHeight > 0
                && map.viewportTop + map.viewportHeight >= map.totalHeight - 1
            ZStack(alignment: .top) {
                // Cards fill the space above the footer (not under it): the footer is
                // opaque, so an overlapping ZStack sibling would occlude bottom cards.
                VStack(spacing: 0) {
                    if active.isEmpty, detached.isEmpty {
                        emptyState
                    } else {
                        anchoredActiveCards(tops: cardTops, atDocumentEnd: atDocumentEnd)
                    }
                    if !detached.isEmpty {
                        detachedFooter
                    }
                }
                headerBar
            }
            .frame(width: Self.width)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(theme.colors.backgroundSecondary)
            .environment(\.colorScheme, theme.colorScheme)
        }

        /// Active cards anchored beside their text, clipped to the panel. No implicit
        /// animation: the per-frame reposition from the live `viewportTop` is the
        /// scroll-follow, so animating it would lag the text.
        private func anchoredActiveCards(tops: [String: CGFloat], atDocumentEnd: Bool) -> some View {
            AnchoredCommentsLayout(gap: 8, atDocumentEnd: atDocumentEnd) {
                ForEach(active) { item in
                    ActiveCommentCard(item: item, theme: theme, onJump: onJump, onHover: onHover)
                        .commentCardAnchor(tops[item.id] ?? 0)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
        }

        /// Opaque header pinned to the top; active cards scroll under it.
        private var headerBar: some View {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(theme.colors.backgroundSecondary)
                Spacer(minLength: 0)
            }
        }

        /// No close affordance here: the floating toggle stays pinned over the
        /// header's right edge and closes the rail from the same spot it opened.
        private var header: some View {
            HStack {
                Text("Comments")
                    .font(.headline)
                    .foregroundStyle(theme.colors.headingColor)
                Spacer()
            }
        }

        private var detachedFooter: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("DETACHED (\(detached.count))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.colors.foregroundSecondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(detached) { item in
                            DetachedCommentCard(item: item, theme: theme, onDelete: onDelete)
                        }
                    }
                }
                .scrollIndicators(.never)
                .frame(maxHeight: 180)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors.backgroundSecondary)
        }

        private var emptyState: some View {
            VStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 22))
                Text("No comments yet")
                    .font(.callout)
            }
            .foregroundStyle(theme.colors.foregroundSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    /// A resolved comment: quote chip (in `commentHighlight`) + body. The whole
    /// card is a button (pointer cursor + accent lift on hover) that scrolls to
    /// the comment.
    private struct ActiveCommentCard: View {
        let item: CommentSidebarItem
        let theme: AppTheme
        let onJump: (String) -> Void
        /// Emphasize (id) / un-emphasize (nil) the comment's span in the document.
        let onHover: (String?) -> Void

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
            }
            .commentCardSurface(theme: theme)
            .overlay {
                // Faint accent wash on hover — signals the card is clickable
                // without changing its size (no reflow of the cards below).
                RoundedRectangle(cornerRadius: commentCardCornerRadius)
                    .fill(theme.colors.accent.opacity(hovering ? 0.06 : 0))
            }
            .overlay(
                RoundedRectangle(cornerRadius: commentCardCornerRadius)
                    .strokeBorder(
                        hovering
                            ? theme.colors.accent.opacity(0.55)
                            : theme.colors.border.opacity(0.4)
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture { onJump(item.id) }
            .onHover { inside in
                hovering = inside
                onHover(inside ? item.id : nil)
            }
            // Clear the document emphasis if this card is removed while hovered
            // (delete, sidebar close) — onHover(false) doesn't fire on removal, so
            // the accent pill would otherwise stay painted.
            .onDisappear { if hovering { onHover(nil) } }
            .pointingHandCursor()
            .animation(.easeInOut(duration: 0.15), value: hovering)
        }
    }

    /// A detached comment: dashed `warning` treatment, the original quote shown
    /// struck-through in its saved context, then Delete.
    private struct DetachedCommentCard: View {
        let item: CommentSidebarItem
        let theme: AppTheme
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
