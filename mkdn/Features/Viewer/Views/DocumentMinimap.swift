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
                .gesture(
                    DragGesture(minimumDistance: 0).onEnded { value in
                        guard height > 0, map.totalHeight > 0 else { return }
                        let fraction = min(max(value.location.y / height, 0), 1)
                        state.scrollTo?(fraction * map.totalHeight)
                    }
                )
            }
            .frame(width: Self.width)
            .overlay(alignment: .leading) {
                Rectangle().fill(colors.border).frame(width: 1)
            }
        }

        /// A document length scaled onto the track (no clamp — heights, not positions).
        private func scaled(_ length: CGFloat, map: PreviewDocumentMap, trackHeight: CGFloat) -> CGFloat {
            guard map.totalHeight > 0 else { return 0 }
            return (length / map.totalHeight) * trackHeight
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
            if let thumb = map.thumbMetrics(trackHeight: height, minHeight: Self.minThumbHeight) {
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
