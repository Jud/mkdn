#if os(macOS)
    import SwiftUI

    /// A slim vertical gutter beside the preview that plots heading and comment
    /// positions and the current viewport, read from ``PreviewMapState/documentMap``.
    /// Heading ticks sit flush right (length and opacity by level); comment ticks sit
    /// flush left in the accent color; a faint thumb tracks the viewport. A tap jumps
    /// the preview to the nearest mark via ``PreviewMapState/scrollTo``.
    ///
    /// All positions arrive pre-converted to scroll space and normalized against the
    /// real document height, so the view never touches TextKit or coordinate math —
    /// it scales `documentMap` y-values by its own height.
    struct ScrollMarkerTrack: View {
        let state: PreviewMapState

        @Environment(AppSettings.self) private var appSettings

        static let width: CGFloat = 12
        private static let minThumbHeight: CGFloat = 20

        private var colors: ThemeColors { appSettings.theme.colors }

        var body: some View {
            let map = state.documentMap
            GeometryReader { geo in
                let height = geo.size.height
                ZStack(alignment: .topLeading) {
                    colors.background
                    viewportThumb(map: map, height: height)
                    ForEach(map.comments) { comment in
                        commentTick(at: map.normalized(comment.y) * height)
                    }
                    ForEach(map.headings) { heading in
                        headingTick(heading, at: map.normalized(heading.y) * height)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onEnded { value in
                        jump(toTrackY: value.location.y, trackHeight: height, map: map)
                    }
                )
            }
            .frame(width: Self.width)
        }

        @ViewBuilder
        private func viewportThumb(map: PreviewDocumentMap, height: CGFloat) -> some View {
            let viewport = map.normalizedViewport
            if viewport.height > 0 {
                // Floor the height so a tiny viewport stays visible, then clamp the
                // offset so that floor can't push the thumb past the track's bottom.
                let thumbHeight = max(viewport.height * height, Self.minThumbHeight)
                RoundedRectangle(cornerRadius: 3)
                    .fill(colors.foreground.opacity(0.12))
                    .frame(width: Self.width, height: thumbHeight)
                    .offset(y: max(min(viewport.top * height, height - thumbHeight), 0))
            }
        }

        private func headingTick(_ heading: HeadingMark, at y: CGFloat) -> some View {
            let length = max(9 - CGFloat(heading.level), 4)
            return Rectangle()
                .fill(colors.foreground.opacity(max(1 - CGFloat(heading.level) * 0.12, 0.4)))
                .frame(width: length, height: 1.5)
                .offset(x: Self.width - length, y: y - 0.75)
                .help(heading.title)
        }

        private func commentTick(at y: CGFloat) -> some View {
            Rectangle()
                .fill(colors.accent)
                .frame(width: 4, height: 1.5)
                .offset(x: 0, y: y - 0.75)
        }

        /// Jump to the mark nearest the tapped y; with no marks, scrub proportionally.
        private func jump(toTrackY tapY: CGFloat, trackHeight: CGFloat, map: PreviewDocumentMap) {
            guard trackHeight > 0, map.totalHeight > 0 else { return }
            let tapFraction = tapY / trackHeight
            let markYs = map.headings.map(\.y) + map.comments.map(\.y)
            let nearest = markYs.min {
                abs(map.normalized($0) - tapFraction) < abs(map.normalized($1) - tapFraction)
            }
            state.scrollTo?(nearest ?? tapFraction * map.totalHeight)
        }
    }
#endif
