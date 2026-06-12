#if os(macOS)
    import SwiftUI

    /// One row in the comment sidebar, decoupled from the resolver: `active` rows
    /// (anchor located on the page) show a quote chip + body; `detached` rows
    /// (anchor lost) show the struck quote-in-context + Delete.
    struct CommentSidebarItem: Identifiable, Equatable {
        let id: String
        let body: String
        /// Who wrote the comment; nil is the document owner, shown unlabeled.
        let author: String?
        /// The comment's thread, in conversation order.
        let replies: [CommentSidecar.Reply]
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
        /// Append a reply (id, body) to a comment's thread.
        let onReply: (String, String) -> Void
        /// Emphasize (id) / un-emphasize (nil) a comment's span in the document
        /// while its card is hovered.
        let onHover: (String?) -> Void
        /// How active cards are laid out; the host owns (and persists) the choice.
        /// Animated by the host via `Binding.animation`, so the mode switch is the
        /// one card reposition that springs (scroll-follow stays un-animated).
        @Binding var layout: CommentRailLayout

        static let width: CGFloat = 300
        /// The preview's `textContainerInset.height`, added back so a card lands
        /// beside the live text rather than the inset-subtracted scroll-space mark.
        private static let previewTopInset: CGFloat = 32
        /// The floating sidebar toggle's diameter; the header row matches it so
        /// the title and layout tabs center on the toggle's midline.
        private static let headerRowHeight: CGFloat = 34
        /// Where the stacked list starts: clear of the opaque header bar
        /// (12pt top padding + the 34pt header row + 12pt bottom padding).
        private static let stackTop: CGFloat = 64

        var body: some View {
            let map = mapState.documentMap
            // Stacked: every card shares one anchor below the header, so the
            // downward-only collision pass lays them out one after another in
            // document order, ignoring the scroll position.
            let cardTops = layout == .stacked
                ? [:]
                : Dictionary(
                    map.comments.map { ($0.id, $0.y - map.viewportTop + Self.previewTopInset) }
                ) { first, _ in first }
            // At the scroll end a card tail can't be pulled up by scrolling; let the
            // layout fit the overflow then. A short/unscrollable document reads as "end".
            let atDocumentEnd = layout == .anchored
                && map.totalHeight > 0
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
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("comment-sidebar")
            .accessibilityLabel("Comments")
        }

        /// Active cards anchored beside their text, clipped to the panel. No implicit
        /// animation: the per-frame reposition from the live `viewportTop` is the
        /// scroll-follow, so animating it would lag the text.
        private func anchoredActiveCards(tops: [String: CGFloat], atDocumentEnd: Bool) -> some View {
            AnchoredCommentsLayout(gap: 8, atDocumentEnd: atDocumentEnd) {
                ForEach(active) { item in
                    ActiveCommentCard(
                        item: item,
                        theme: theme,
                        onJump: onJump,
                        onReply: onReply,
                        onHover: onHover
                    )
                    .commentCardAnchor(tops[item.id] ?? Self.stackTop)
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
                    .frame(height: Self.headerRowHeight)
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
                if !active.isEmpty {
                    CommentLayoutPicker(layout: $layout, theme: theme)
                        // Clear of the floating sidebar toggle pinned over the
                        // header's right edge (its hit area, not just the glyph).
                        .padding(.trailing, 60)
                }
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

    /// The header's layout switch: two segments behind a hairline, the selected
    /// one carried by a sliding accent thumb. Hand-built from real buttons (not a
    /// system segmented `Picker`) so each segment is pressable through the
    /// accessibility tree — the system control's segments expose no AX actions
    /// via SwiftUI's bridge, which would leave the harness (and any assistive
    /// client's press action) unable to drive it.
    private struct CommentLayoutPicker: View {
        @Binding var layout: CommentRailLayout
        let theme: AppTheme

        @Namespace private var thumb

        var body: some View {
            HStack(spacing: 2) {
                ForEach(CommentRailLayout.allCases, id: \.self) { mode in
                    segment(mode)
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.block)
                    .fill(theme.colors.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.block)
                    .strokeBorder(theme.colors.border.opacity(DesignTokens.Stroke.resting))
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("comment-layout-picker")
            .accessibilityLabel("Card layout")
        }

        private func segment(_ mode: CommentRailLayout) -> some View {
            let selected = layout == mode
            return Button {
                layout = mode
            } label: {
                Text(mode.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(
                        selected ? theme.colors.headingColor : theme.colors.foregroundSecondary
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.inline)
                                .fill(theme.colors.accent.opacity(DesignTokens.Tint.resting))
                                .matchedGeometryEffect(id: "thumb", in: thumb)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .accessibilityIdentifier("comment-layout-\(mode.rawValue)")
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    private let commentCardCornerRadius: CGFloat = DesignTokens.Radius.block

    private extension View {
        /// The flat, opaque card surface shared by both sidebar cards. The border
        /// differs per card (solid vs dashed warning), so callers add their own
        /// `.overlay`.
        func commentCardSurface(theme: AppTheme) -> some View {
            padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.colors.background)
                .clipShape(RoundedRectangle(cornerRadius: commentCardCornerRadius))
        }
    }

    /// A small author line over a comment or reply body. Only named (agent)
    /// authors are labeled on top-level comments; replies always show one so a
    /// thread's turns stay attributable ("You" when the author field is absent).
    private struct CommentAuthorLabel: View {
        let name: String
        let theme: AppTheme

        var body: some View {
            Text(name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.colors.foregroundSecondary)
        }
    }

    /// One reply in a card's thread: author line + body behind a thin thread rail.
    private struct CommentReplyRow: View {
        let reply: CommentSidecar.Reply
        let theme: AppTheme

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                CommentAuthorLabel(name: reply.author ?? "You", theme: theme)
                Text(reply.body)
                    .font(.body)
                    .foregroundStyle(theme.colors.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 8)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(theme.colors.border.opacity(DesignTokens.Stroke.engaged))
                    .frame(width: 2)
            }
        }
    }

    /// A resolved comment: quote chip (in `commentHighlight`) + body, then its
    /// reply thread and a Reply affordance. The whole card is a button (pointer
    /// cursor + accent lift on hover) that scrolls to the comment.
    private struct ActiveCommentCard: View {
        let item: CommentSidebarItem
        let theme: AppTheme
        let onJump: (String) -> Void
        /// Append a reply (id, body) to the comment's thread.
        let onReply: (String, String) -> Void
        /// Emphasize (id) / un-emphasize (nil) the comment's span in the document.
        let onHover: (String?) -> Void

        @State private var hovering = false
        @State private var isReplying = false
        @State private var draft = ""

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
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.inline))
                }
                if let author = item.author {
                    CommentAuthorLabel(name: author, theme: theme)
                }
                Text(item.body)
                    .font(.body)
                    .foregroundStyle(theme.colors.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(item.replies) { reply in
                    CommentReplyRow(reply: reply, theme: theme)
                }
                if isReplying {
                    CommentEditor(
                        draft: $draft,
                        theme: theme,
                        confirmTitle: "Reply",
                        onCancel: { withAnimation(AnimationConstants.outlinePop) { isReplying = false } },
                        onConfirm: { body in
                            onReply(item.id, body)
                            withAnimation(AnimationConstants.outlinePop) {
                                isReplying = false
                                draft = ""
                            }
                        }
                    )
                } else {
                    Button("Reply") {
                        withAnimation(AnimationConstants.outlinePop) { isReplying = true }
                    }
                    .font(.caption.weight(.medium))
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("comment-reply-button")
                    .pointingHandCursor()
                }
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
                            ? theme.colors.accent.opacity(DesignTokens.Stroke.engaged)
                            : theme.colors.border.opacity(DesignTokens.Stroke.resting)
                    )
            )
            .contentShape(Rectangle())
            // While the reply editor is open, clicks belong to it (focusing,
            // selecting text) — jumping the document out from under a draft
            // would read as the card discarding the reply.
            .onTapGesture { if !isReplying { onJump(item.id) } }
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
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("comment-card")
            .accessibilityLabel(item.quote.isEmpty ? "Comment" : "Comment on \(item.quote)")
            .accessibilityValue(item.body)
            .accessibilityAction(named: "Jump to Comment") { onJump(item.id) }
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
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.inline)
                            .strokeBorder(theme.colors.warning.opacity(DesignTokens.Stroke.engaged))
                    )
                context
                if let author = item.author {
                    CommentAuthorLabel(name: author, theme: theme)
                }
                Text(item.body)
                    .font(.body)
                    .foregroundStyle(theme.colors.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(item.replies) { reply in
                    CommentReplyRow(reply: reply, theme: theme)
                }
                actions
            }
            .commentCardSurface(theme: theme)
            .overlay(
                RoundedRectangle(cornerRadius: commentCardCornerRadius)
                    .strokeBorder(
                        theme.colors.warning.opacity(DesignTokens.Stroke.resting),
                        style: StrokeStyle(lineWidth: DesignTokens.Stroke.width, dash: [4, 3])
                    )
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("detached-comment-card")
            .accessibilityLabel("Detached comment, was on \(item.quote)")
            .accessibilityValue(item.body)
        }

        private var context: some View {
            let prefix = item.prefix.isEmpty ? Text("") : Text("…\(item.prefix)")
            let suffix = item.suffix.isEmpty ? Text("") : Text("\(item.suffix)…")

            return (Text("was on ") + prefix + Text(item.quote).strikethrough() + suffix)
                .font(.caption)
                .foregroundColor(theme.colors.foregroundSecondary)
                .lineLimit(2)
        }

        private var actions: some View {
            HStack {
                Spacer()
                Button("Delete", role: .destructive) { onDelete(item.id) }
                    .foregroundStyle(theme.colors.danger)
                    .accessibilityIdentifier("comment-delete-button")
                    .pointingHandCursor()
            }
            .font(.caption.weight(.medium))
            .buttonStyle(.borderless)
        }
    }
#endif
