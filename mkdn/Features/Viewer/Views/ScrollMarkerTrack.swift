#if os(macOS)
    import SwiftUI

    /// A slim vertical gutter beside the preview that plots comment positions and
    /// the current viewport, read from ``PreviewMapState/documentMap``. Comment
    /// ticks stay put; a faint thumb tracks the viewport and fades out when idle,
    /// like an overlay scroller. A tap jumps the preview to the nearest comment via
    /// ``PreviewMapState/scrollTo``.
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
        /// How long the thumb lingers after the last scroll/hover before fading.
        private static let thumbLinger: Duration = .milliseconds(1200)

        /// Scroll position at drag start, nil when the drag began off the thumb
        /// (those end as a tap-to-jump).
        @State private var dragStartScrollY: CGFloat?
        /// Whether the viewport thumb is currently shown. Surfaced on scroll/hover,
        /// then hidden after ``thumbLinger`` of stillness — the comment ticks are
        /// unaffected and always visible.
        @State private var thumbVisible = false
        @State private var thumbHovering = false
        /// Bumped on every scroll or hover change to restart the fade-out timer.
        @State private var thumbActivity = 0

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
                    viewportThumb(map: map, height: height)
                }
                .contentShape(Rectangle())
                .gesture(trackGesture(map: map, height: height))
            }
            .frame(width: Self.width)
            .onChange(of: map.viewportTop) { showThumbBriefly() }
            .onHover { hovering in
                thumbHovering = hovering
                showThumbBriefly()
            }
            .task(id: thumbActivity) {
                try? await Task.sleep(for: Self.thumbLinger)
                guard !Task.isCancelled, !thumbHovering else { return }
                thumbVisible = false
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("scroll-marker-track")
            .accessibilityLabel("Document map")
        }

        /// Reveal the thumb and restart its fade-out timer.
        private func showThumbBriefly() {
            thumbVisible = true
            thumbActivity &+= 1
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
                    // Fade in on scroll/hover, out when idle; the offset still tracks
                    // live so a re-grab lands on the current position.
                    .opacity(thumbVisible || thumbHovering ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: thumbVisible)
                    .animation(.easeOut(duration: 0.3), value: thumbHovering)
                    .accessibilityLabel("Viewport")
            }
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

        /// Jump to the comment nearest the tapped y; with no comments, scrub
        /// proportionally.
        private func jump(toTrackY tapY: CGFloat, trackHeight: CGFloat, map: PreviewDocumentMap) {
            guard trackHeight > 0, map.totalHeight > 0 else { return }
            let tapFraction = tapY / trackHeight
            let markYs = map.comments.map(\.y)
            let nearest = markYs.min { lhs, rhs in
                abs(map.normalized(lhs) - tapFraction) < abs(map.normalized(rhs) - tapFraction)
            }
            state.scrollTo?(nearest ?? tapFraction * map.totalHeight)
        }
    }
#endif
