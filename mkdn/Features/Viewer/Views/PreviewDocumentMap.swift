#if os(macOS)
    import AppKit

    /// A heading's position on the preview's vertical extent, in scroll coordinates.
    struct HeadingMark: Identifiable, Equatable {
        let id: Int
        let blockIndex: Int
        let title: String
        let level: Int
        let y: CGFloat
    }

    /// A comment's position on the preview's vertical extent, in scroll coordinates.
    /// `y` is the top of the comment's containing block (block granularity — exact
    /// off-viewport, unlike `boundingRect`, which returns estimated frames there).
    struct CommentMark: Identifiable, Equatable {
        let id: String
        let range: NSRange
        let blockIndex: Int
        let y: CGFloat
    }

    /// A block's vertical extent on the preview, in scroll coordinates, for the
    /// minimap's per-kind bands. `height` spans the gap to the next block's top;
    /// the last block fills to the document bottom.
    struct BlockBand: Identifiable, Equatable {
        let id: Int // source block index
        let kind: BlockKind
        let y: CGFloat
        let height: CGFloat
    }

    /// Heading, comment, block-band, and viewport positions within the preview's
    /// vertical extent, all in scroll (clip-view) coordinates. The text-view
    /// coordinator builds it from ``DocumentBlockOffsets`` once per content/width/
    /// scroll change; the scroll-marker track and minimap consume it, so those views
    /// never touch TextKit or the coordinate conversions.
    struct PreviewDocumentMap: Equatable {
        /// The text view's real frame height — the denominator for normalizing a `y`
        /// onto a track, so marks track the actual scroller rather than the estimate.
        var totalHeight: CGFloat = 0
        var viewportTop: CGFloat = 0
        var viewportHeight: CGFloat = 0
        var headings: [HeadingMark] = []
        var comments: [CommentMark] = []
        var blocks: [BlockBand] = []
    }

    extension PreviewDocumentMap {
        /// Build the map from positions alone — no live `NSTextView`. `y` converts
        /// each block top from text-view space to scroll space by subtracting
        /// `textContainerOriginY`, the basis heading navigation uses.
        static func build(
            headings: [HeadingNode],
            comments: [(id: String, range: NSRange)],
            offsets: DocumentBlockOffsets,
            blockModel: DocumentHeightModel,
            textContainerOriginY: CGFloat,
            totalHeight: CGFloat,
            viewportTop: CGFloat,
            viewportHeight: CGFloat
        ) -> PreviewDocumentMap {
            let headingMarks = headings.compactMap { heading -> HeadingMark? in
                guard let top = offsets.offset(forBlockIndex: heading.blockIndex) else { return nil }
                return HeadingMark(
                    id: heading.id,
                    blockIndex: heading.blockIndex,
                    title: heading.title,
                    level: heading.level,
                    y: top - textContainerOriginY
                )
            }
            let commentMarks = comments.compactMap { comment -> CommentMark? in
                guard let blockIndex = blockModel.blockIndex(containing: comment.range.location),
                      let top = offsets.offset(forBlockIndex: blockIndex)
                else { return nil }
                return CommentMark(
                    id: comment.id,
                    range: comment.range,
                    blockIndex: blockIndex,
                    y: top - textContainerOriginY
                )
            }
            let blocks = blockBands(
                blockModel: blockModel, offsets: offsets,
                textContainerOriginY: textContainerOriginY, totalHeight: totalHeight
            )
            return PreviewDocumentMap(
                totalHeight: totalHeight,
                viewportTop: viewportTop,
                viewportHeight: viewportHeight,
                headings: headingMarks,
                comments: commentMarks,
                blocks: blocks
            )
        }

        /// Each block's scroll-space extent by kind, tiling the document with no gaps
        /// (``BlockBand`` defines the per-band `height` convention).
        private static func blockBands(
            blockModel: DocumentHeightModel,
            offsets: DocumentBlockOffsets,
            textContainerOriginY: CGFloat,
            totalHeight: CGFloat
        ) -> [BlockBand] {
            let spans = blockModel.blocks
            return spans.enumerated().compactMap { offset, span -> BlockBand? in
                guard let top = offsets.offset(forBlockIndex: span.index) else { return nil }
                let y = top - textContainerOriginY
                let nextTop = offset + 1 < spans.count
                    ? offsets.offset(forBlockIndex: spans[offset + 1].index)
                    : nil
                let bottom = nextTop.map { $0 - textContainerOriginY } ?? totalHeight
                return BlockBand(id: span.index, kind: span.kind, y: y, height: max(bottom - y, 0))
            }
        }

        /// `y` as a fraction in [0, 1] of the document height, for placing a mark on a track.
        func normalized(_ y: CGFloat) -> CGFloat {
            guard totalHeight > 0 else { return 0 }
            return min(max(y / totalHeight, 0), 1)
        }

        /// The viewport as a normalized `(top, height)` fraction of the document, clamped
        /// so the thumb stays within the track even when the viewport overhangs the end.
        var normalizedViewport: (top: CGFloat, height: CGFloat) {
            guard totalHeight > 0 else { return (0, 0) }
            let top = min(max(viewportTop / totalHeight, 0), 1)
            let height = min(max(viewportHeight / totalHeight, 0), 1 - top)
            return (top, height)
        }
    }
#endif
