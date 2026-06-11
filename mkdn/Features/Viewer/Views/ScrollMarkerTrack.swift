#if os(macOS)
    import SwiftUI

    /// A slim vertical gutter beside the preview that plots heading and comment
    /// positions and the current viewport, read from ``PreviewMapState/documentMap``.
    /// Heading tick length and opacity encode level; a faint thumb tracks the viewport.
    /// A tap jumps the preview to the nearest mark via ``PreviewMapState/scrollTo``.
    ///
    /// All positions arrive pre-converted to scroll space and normalized against the
    /// real document height, so the view never touches TextKit or coordinate math —
    /// it scales `documentMap` y-values by its own height.
    struct ScrollMarkerTrack: View {
        let state: PreviewMapState

        @Environment(AppSettings.self) private var appSettings

        static let width: CGFloat = 12
        private static let minThumbHeight: CGFloat = 20
        private static let thumbWidth: CGFloat = 7

        /// Scroll position at drag start, nil when the drag began off the thumb
        /// (those end as a tap-to-jump).
        @State private var dragStartScrollY: CGFloat?

        private var colors: ThemeColors { appSettings.theme.colors }

        var body: some View {
            let map = state.documentMap
            GeometryReader { geo in
                let height = geo.size.height
                ZStack(alignment: .topLeading) {
                    colors.background
                    ForEach(map.comments) { comment in
                        commentTick(comment, at: map.normalized(comment.lineCenterY) * height)
                    }
                    ForEach(map.headings) { heading in
                        headingTick(heading, at: map.normalized(heading.y) * height)
                    }
                    viewportThumb(map: map, height: height)
                }
                .contentShape(Rectangle())
                .gesture(trackGesture(map: map, height: height))
            }
            .frame(width: Self.width)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("scroll-marker-track")
            .accessibilityLabel("Document map")
        }

        /// Dragging the thumb scrubs the document like a scroller knob; a press
        /// anywhere else jumps to the nearest mark on release.
        private func trackGesture(map: PreviewDocumentMap, height: CGFloat) -> some Gesture {
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
                    guard !wasThumbDrag else { return }
                    jump(toTrackY: value.location.y, trackHeight: height, map: map)
                }
        }

        @ViewBuilder
        private func viewportThumb(map: PreviewDocumentMap, height: CGFloat) -> some View {
            // Hidden when the whole document fits the viewport, like a native scroller.
            if map.viewportHeight < map.totalHeight,
               let thumb = map.thumbMetrics(trackHeight: height, minHeight: Self.minThumbHeight)
            {
                Capsule()
                    .fill(colors.foreground.opacity(0.3))
                    .frame(width: Self.thumbWidth, height: thumb.height)
                    .offset(x: (Self.width - Self.thumbWidth) / 2, y: thumb.offset)
                    .accessibilityLabel("Viewport")
            }
        }

        private func headingTick(_ heading: HeadingMark, at y: CGFloat) -> some View {
            let length = max(9 - CGFloat(heading.level), 4)
            return Rectangle()
                .fill(colors.foreground.opacity(max(1 - CGFloat(heading.level) * 0.12, 0.4)))
                .frame(width: length, height: 1.5)
                .offset(x: Self.width - length, y: y - 0.75)
                .help(heading.title)
                .accessibilityLabel("Heading: \(heading.title)")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { state.scrollTo?(heading.y) }
        }

        private func commentTick(_ comment: CommentMark, at y: CGFloat) -> some View {
            Rectangle()
                .fill(colors.accent)
                .frame(width: 4, height: 1.5)
                .offset(x: 0, y: y - 0.75)
                .accessibilityLabel("Comment")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { state.scrollTo?(comment.y) }
        }

        /// Jump to the mark nearest the tapped y; with no marks, scrub proportionally.
        private func jump(toTrackY tapY: CGFloat, trackHeight: CGFloat, map: PreviewDocumentMap) {
            guard trackHeight > 0, map.totalHeight > 0 else { return }
            let tapFraction = tapY / trackHeight
            let markYs = map.headings.map(\.y) + map.comments.map(\.y)
            let nearest = markYs.min { lhs, rhs in
                abs(map.normalized(lhs) - tapFraction) < abs(map.normalized(rhs) - tapFraction)
            }
            state.scrollTo?(nearest ?? tapFraction * map.totalHeight)
        }
    }
#endif
