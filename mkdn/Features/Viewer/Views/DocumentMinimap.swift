#if os(macOS)
    import SwiftUI

    /// A wider navigation panel showing the document's block structure as per-kind
    /// colored bands, with comment marks and a viewport thumb. Reads
    /// ``PreviewMapState/documentMap`` and jumps via ``PreviewMapState/scrollTo``:
    /// a tap (or drag) scrolls to the matching fraction of the document.
    struct DocumentMinimap: View {
        let state: PreviewMapState

        @Environment(AppSettings.self) private var appSettings

        static let width: CGFloat = 64
        private static let minThumbHeight: CGFloat = 24

        /// Scroll position at drag start, nil when the drag began off the thumb
        /// (those end as a tap-to-jump).
        @State private var dragStartScrollY: CGFloat?

        private var colors: ThemeColors { appSettings.theme.colors }

        var body: some View {
            let map = state.documentMap
            GeometryReader { geo in
                let height = geo.size.height
                ZStack(alignment: .topLeading) {
                    colors.backgroundSecondary
                    ForEach(map.blocks) { band in
                        bandView(
                            band,
                            top: map.normalized(band.y) * height,
                            length: scaled(band.height, map: map, trackHeight: height)
                        )
                    }
                    ForEach(map.comments) { comment in
                        commentMark(top: map.normalized(comment.y) * height)
                    }
                    viewportThumb(map: map, height: height)
                }
                .contentShape(Rectangle())
                .gesture(panelGesture(map: map, height: height))
            }
            .frame(width: Self.width)
            .overlay(alignment: .leading) {
                Rectangle().fill(colors.border).frame(width: 1)
            }
        }

        /// Dragging the thumb scrubs the document like a scroller knob; a press
        /// anywhere else jumps to the matching document fraction on release.
        private func panelGesture(map: PreviewDocumentMap, height: CGFloat) -> some Gesture {
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStartScrollY == nil,
                       let thumb = map.thumbMetrics(
                           trackHeight: height, minHeight: Self.minThumbHeight
                       ),
                       (thumb.offset...(thumb.offset + thumb.height))
                       .contains(value.startLocation.y)
                    {
                        dragStartScrollY = map.viewportTop
                    }
                    guard let startY = dragStartScrollY, height > 0 else { return }
                    state.scrubTo?(startY + value.translation.height / height * map.totalHeight)
                }
                .onEnded { value in
                    let wasThumbDrag = dragStartScrollY != nil
                    dragStartScrollY = nil
                    guard !wasThumbDrag, height > 0, map.totalHeight > 0 else { return }
                    let fraction = min(max(value.location.y / height, 0), 1)
                    state.scrollTo?(fraction * map.totalHeight)
                }
        }

        /// A document length scaled onto the track (no clamp — heights, not positions).
        /// Shares `trackExtent` with `normalized` so band heights tile against the
        /// same denominator as their tops.
        private func scaled(_ length: CGFloat, map: PreviewDocumentMap, trackHeight: CGFloat) -> CGFloat {
            guard map.trackExtent > 0 else { return 0 }
            return (length / map.trackExtent) * trackHeight
        }

        private func bandView(_ band: BlockBand, top: CGFloat, length: CGFloat) -> some View {
            let inset = inset(band.kind)
            return RoundedRectangle(cornerRadius: 1)
                .fill(fillColor(band.kind))
                .frame(width: Self.width - inset * 2, height: max(length - 1, 1))
                .offset(x: inset, y: top)
        }

        private func commentMark(top: CGFloat) -> some View {
            Circle()
                .fill(colors.accent)
                .frame(width: 4, height: 4)
                .offset(x: Self.width - 7, y: top - 2)
        }

        @ViewBuilder
        private func viewportThumb(map: PreviewDocumentMap, height: CGFloat) -> some View {
            // Hidden when the whole document fits the viewport, like a native scroller.
            if map.viewportHeight < map.totalHeight,
               let thumb = map.thumbMetrics(trackHeight: height, minHeight: Self.minThumbHeight)
            {
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors.foreground.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(colors.foreground.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: Self.width, height: thumb.height)
                    .offset(y: thumb.offset)
            }
        }

        /// Band colour by kind — headings read strong and embedded content
        /// (code/table/image/math) gets accent hues; body text recedes.
        private func fillColor(_ kind: BlockKind) -> Color {
            switch kind {
            case .heading: colors.headingColor
            case .paragraph: colors.foregroundSecondary.opacity(0.3)
            case .code: colors.codeForeground.opacity(0.6)
            case .list: colors.foregroundSecondary.opacity(0.5)
            case .blockquote: colors.blockquoteBorder
            case .table, .math: colors.accent.opacity(0.7)
            case .image: colors.linkColor.opacity(0.8)
            case .divider: colors.border
            }
        }

        /// Horizontal inset by kind, so headings sit near full width and nested
        /// blocks (quote, list) indent — mirroring the document's left margin.
        private func inset(_ kind: BlockKind) -> CGFloat {
            switch kind {
            case .heading, .divider: 6
            case .blockquote, .list: 14
            default: 9
            }
        }
    }
#endif
