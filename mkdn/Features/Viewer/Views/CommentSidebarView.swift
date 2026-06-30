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

        /// Stacked-mode scroll position + the native wheel monitor that drives it.
        /// Anchored mode follows the document instead, so this stays at zero there.
        @State private var scroll = RailScrollModel()
        @State private var railHovered = false
        /// Rail height + the detached cards' natural height: together they let the
        /// detached footer grow to fit a long comment while capping it at a
        /// fraction of the rail so the active cards stay visible (see detachedFooter).
        @State private var railHeight: CGFloat = 0
        /// `.infinity` until measured, so the footer shows at `detachedFooterCap`
        /// before its content height is known (`min(.infinity, cap) == cap`).
        @State private var detachedContentHeight: CGFloat = .infinity

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
        /// Vertical gap between stacked cards — matches `AnchoredCommentsLayout`.
        private static let cardGap: CGFloat = 8
        /// Breathing room below the last stacked card.
        private static let stackBottomInset: CGFloat = 16

        var body: some View {
            let map = mapState.documentMap
            // Stacked: every card shares one anchor below the header, so the
            // downward-only collision pass lays them out one after another in
            // document order. Shifting that shared anchor by the scroll offset
            // slides the whole stack — the rail's own scrolling, independent of
            // the document.
            let stackedAnchor = Self.stackTop - scroll.offset
            let cardTops: [String: CGFloat] = layout == .stacked
                ? Dictionary(uniqueKeysWithValues: active.map { ($0.id, stackedAnchor) })
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
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: RailHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(RailHeightKey.self) { railHeight = $0 }
            .environment(\.colorScheme, theme.colorScheme)
            // Capture wheel events only while hovering an overflowing stacked rail.
            .onHover { hovering in
                railHovered = hovering
                syncWheelMonitor()
            }
            .onChange(of: layout) { _, newLayout in
                if newLayout == .stacked { scroll.offset = 0 }
                syncWheelMonitor()
            }
            .onDisappear { scroll.stopMonitoring() }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("comment-sidebar")
            .accessibilityLabel("Comments")
        }

        /// Active cards anchored beside their text, clipped to the panel. No implicit
        /// animation: the per-frame reposition from the live `viewportTop` is the
        /// scroll-follow, so animating it would lag the text.
        private func anchoredActiveCards(tops: [String: CGFloat], atDocumentEnd: Bool) -> some View {
            AnchoredCommentsLayout(gap: Self.cardGap, atDocumentEnd: atDocumentEnd) {
                ForEach(active) { item in
                    ActiveCommentCard(
                        item: item,
                        theme: theme,
                        onJump: onJump,
                        onReply: onReply,
                        onHover: onHover
                    )
                    // Each card reports its laid-out height so the stacked content
                    // height (and thus the max scroll) is known.
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: CardHeightsKey.self,
                                value: [item.id: proxy.size.height]
                            )
                        }
                    )
                    .commentCardAnchor(tops[item.id] ?? Self.stackTop)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: CardsAreaHeightKey.self, value: proxy.size.height)
                }
            )
            .overlay(alignment: .topTrailing) { stackScrollIndicator }
            .onPreferenceChange(CardHeightsKey.self) { heights in
                let total = active.reduce(Self.stackTop) { $0 + (heights[$1.id] ?? 0) }
                    + Self.cardGap * CGFloat(max(0, active.count - 1))
                    + Self.stackBottomInset
                scroll.contentHeight = total
                scroll.clamp()
                syncWheelMonitor()
            }
            .onPreferenceChange(CardsAreaHeightKey.self) { height in
                scroll.viewportHeight = height
                scroll.clamp()
                syncWheelMonitor()
            }
        }

        /// Starts the wheel monitor only while the cursor is over a stacked rail
        /// that actually overflows; tears it down otherwise so anchored mode and
        /// non-overflowing stacks leave document scrolling untouched.
        private func syncWheelMonitor() {
            if railHovered, layout == .stacked, scroll.maxOffset > 0 {
                scroll.startMonitoring()
            } else {
                scroll.stopMonitoring()
            }
        }

        /// A slim scroll thumb on the rail's trailing edge, sized to the visible
        /// fraction and faded in while the rail is hovered. Non-interactive — the
        /// wheel monitor owns the scrolling.
        @ViewBuilder private var stackScrollIndicator: some View {
            if layout == .stacked, scroll.maxOffset > 0, scroll.contentHeight > 0 {
                let track = max(0, scroll.viewportHeight - Self.stackTop - Self.stackBottomInset)
                let thumb = max(28, track * (scroll.viewportHeight / scroll.contentHeight))
                let travel = max(0, track - thumb)
                let y = Self.stackTop + travel * (scroll.offset / scroll.maxOffset)
                Capsule()
                    .fill(theme.colors.foregroundSecondary.opacity(railHovered ? 0.35 : 0))
                    .frame(width: 3, height: thumb)
                    .padding(.trailing, 4)
                    .offset(y: y)
                    .animation(.easeOut(duration: 0.2), value: railHovered)
                    .animation(.easeOut(duration: 0.1), value: scroll.offset)
                    .allowsHitTesting(false)
            }
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

        /// Upper bound on the detached footer's height: a fraction of the rail so
        /// the active cards keep their share. Larger when there are no active cards
        /// (nothing above to protect). Falls back to a fixed floor until the rail
        /// height is measured.
        private var detachedFooterCap: CGFloat {
            max(160, railHeight * (active.isEmpty ? 0.82 : 0.58))
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
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: DetachedHeightKey.self, value: proxy.size.height
                            )
                        }
                    )
                }
                .scrollIndicators(.never)
                // Grow to fit the detached cards so a long comment reads in full;
                // only when the content would exceed the cap does the footer scroll.
                .frame(height: min(detachedContentHeight, detachedFooterCap))
                .onPreferenceChange(DetachedHeightKey.self) { detachedContentHeight = $0 }
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
    /// A freshly-arrived reply (e.g. an agent's answer landing via auto-reload)
    /// pops into the thread — scale-up from the top with the bouncy
    /// ``AnimationConstants/outlinePop`` spring — rather than blinking in. The pop
    /// is driven by the enclosing ``CommentReplyThread``'s `.animation(value:)`;
    /// this row only declares how it enters. Reduce Motion downgrades to a fade.
    private struct CommentReplyRow: View {
        let reply: CommentSidecar.Reply
        let theme: AppTheme

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private var entrance: AnyTransition {
            reduceMotion
                ? .opacity
                : .scale(scale: 0.85, anchor: .top).combined(with: .opacity)
        }

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
            .transition(entrance)
        }
    }

    /// A comment's reply thread: the rows plus the entrance animation that pops a
    /// newly-arrived reply in. Owning the `.animation(value: replies)` here — not
    /// on each host card — scopes the spring to the thread and removes the
    /// per-card duplication. Scoped to `replies` so it fires only when one lands,
    /// not on hover, scroll-follow, or first mount. Reduce Motion → quick fade.
    private struct CommentReplyThread: View {
        let replies: [CommentSidecar.Reply]
        let theme: AppTheme

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(replies) { reply in
                    CommentReplyRow(reply: reply, theme: theme)
                }
            }
            .animation(
                reduceMotion ? AnimationConstants.reducedCrossfade : AnimationConstants.outlinePop,
                value: replies
            )
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
                CommentReplyThread(replies: item.replies, theme: theme)
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
                // Non-hit-testing: a filled shape sits over the whole card,
                // so without this it would swallow the Reply button's clicks
                // (they'd fall through to the card's jump gesture instead).
                RoundedRectangle(cornerRadius: commentCardCornerRadius)
                    .fill(theme.colors.accent.opacity(hovering ? 0.06 : 0))
                    .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: commentCardCornerRadius)
                    .strokeBorder(
                        hovering
                            ? theme.colors.accent.opacity(DesignTokens.Stroke.engaged)
                            : theme.colors.border.opacity(DesignTokens.Stroke.resting)
                    )
                    .allowsHitTesting(false)
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
                CommentReplyThread(replies: item.replies, theme: theme)
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

    /// Drives the stacked rail's scroll: a clamped content offset plus a native
    /// `scrollWheel` monitor. Stacked cards share one anchor, so shifting it by
    /// `offset` slides the whole stack. The monitor is installed only while the
    /// cursor is over an overflowing stacked rail and consumes wheel events there
    /// — so momentum carries for free (macOS keeps emitting decaying wheel deltas
    /// after the fingers lift) without an `NSScrollView` that would break the
    /// anchored↔stacked spring or intercept the cards' own clicks and hovers.
    @MainActor @Observable
    final class RailScrollModel {
        var offset: CGFloat = 0
        var contentHeight: CGFloat = 0
        var viewportHeight: CGFloat = 0

        @ObservationIgnored private var monitor: Any?

        var maxOffset: CGFloat { max(0, contentHeight - viewportHeight) }

        func clamp() { offset = min(max(0, offset), maxOffset) }

        func startMonitoring() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                // Wheel events are delivered on the main thread/run loop.
                MainActor.assumeIsolated {
                    self?.applyWheel(event.scrollingDeltaY, precise: event.hasPreciseScrollingDeltas)
                }
                return nil
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        /// Precise (trackpad) deltas are in points; line-based (mouse wheel) deltas
        /// are coarse, so scale them up. Natural-scroll direction is already baked
        /// into `scrollingDeltaY`.
        private func applyWheel(_ deltaY: CGFloat, precise: Bool) {
            let step = precise ? deltaY : deltaY * 16
            offset = min(max(0, offset - step), maxOffset)
        }
    }

    /// Per-card laid-out heights, merged across the cards, so the rail can size
    /// its stacked content and clamp the scroll.
    private struct CardHeightsKey: PreferenceKey {
        static let defaultValue: [String: CGFloat] = [:]
        static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
            value.merge(nextValue()) { _, new in new }
        }
    }

    /// Shared conformance for the rail's height measurements: the tallest reported
    /// height wins. The keys stay distinct types so their separate readers don't
    /// conflate overlapping subtree measurements (the rail is an ancestor of both
    /// the cards area and the detached footer).
    private protocol MaxHeightPreferenceKey: PreferenceKey where Value == CGFloat {}
    extension MaxHeightPreferenceKey {
        static var defaultValue: CGFloat { 0 }
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    /// The cards' available area (rail minus the detached footer), the stacked
    /// scroll viewport.
    private struct CardsAreaHeightKey: MaxHeightPreferenceKey {}

    /// The whole rail's height — bounds the detached footer to a fraction of it.
    private struct RailHeightKey: MaxHeightPreferenceKey {}

    /// The detached cards' natural (unclamped) height, so the footer can size to
    /// fit them up to the cap instead of trapping a long comment in a fixed box.
    private struct DetachedHeightKey: MaxHeightPreferenceKey {}
#endif
