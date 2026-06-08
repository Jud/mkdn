#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Top y of one block in the document.
public struct BlockOffset {
    public let index: Int // source block index
    public let top: CGFloat // top y in text-view coordinates
}

/// Per-block vertical offsets in the markdown preview, computed from the final
/// attributed string without running the renderer's TextKit fragment layout.
/// Block `blocks[i]` spans `[blocks[i].top, blocks[i + 1].top)`; the last block
/// runs to `totalHeight`. Maps a document y to a block and back for
/// scroll-to-anchor, the scrollbar, and a minimap.
///
/// Each top is a cumulative-prefix measure corrected to the real block position
/// (see `compute`), so offsets land on the real TextKit block tops. `O(blocks)`
/// measures (`O(n^2)` in block count): computed once and cached, not per frame.
public struct DocumentBlockOffsets {
    public let blocks: [BlockOffset]
    public let totalHeight: CGFloat

    /// Top y of the block with source `index`, or nil if absent.
    public func offset(forBlockIndex index: Int) -> CGFloat? {
        blocks.first { $0.index == index }?.top
    }

    /// Source index of the block whose span contains `y` (the last block whose top
    /// is at or above `y`), clamped to the document; nil when empty.
    public func blockIndex(atY y: CGFloat) -> Int? {
        guard !blocks.isEmpty else { return nil }
        var low = 0
        var high = blocks.count - 1
        var result = 0
        while low <= high {
            let mid = (low + high) / 2
            if blocks[mid].top <= y {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return blocks[result].index
    }

    @MainActor
    public static func compute(
        of attributedString: NSAttributedString,
        model: DocumentHeightModel,
        textWidth: CGFloat,
        verticalInset: CGFloat
    ) -> DocumentBlockOffsets {
        guard textWidth > 0, !model.blocks.isEmpty else {
            return DocumentBlockOffsets(blocks: [], totalHeight: 0)
        }
        let blocks = model.blocks.map { block -> BlockOffset in
            let start = block.range.location
            guard start > 0 else { return BlockOffset(index: block.index, top: verticalInset) }
            let prefixHeight = DocumentHeightEstimator.contentHeight(
                of: attributedString.attributedSubstring(from: NSRange(location: 0, length: start)),
                textWidth: textWidth
            )
            // Two corrections land the top on the real first-glyph position that
            // boundingRect(forCharacterRange:) reports:
            //  - the prefix ends in the previous block's terminating newline, which
            //    boundingRect renders as a phantom empty line the contiguous layout
            //    doesn't have at a boundary — subtract that line (the previous block's
            //    real trailing paragraphSpacing stays in prefixHeight);
            //  - the prefix excludes this block's own paragraphSpacingBefore (a heading
            //    top-margin, a code-block top padding) which sits above its first
            //    glyph — add it back.
            let phantom = trailingNewlinePhantom(at: start - 1, in: attributedString)
            // A zero-length trailing block (e.g. an empty list) can have start == length;
            // only read its leading spacing when there's a character there.
            let spacingBefore = start < attributedString.length
                ? ((attributedString.attribute(.paragraphStyle, at: start, effectiveRange: nil)
                        as? NSParagraphStyle)?.paragraphSpacingBefore ?? 0)
                : 0
            return BlockOffset(
                index: block.index, top: verticalInset + prefixHeight - phantom + spacingBefore)
        }
        let total = DocumentHeightEstimator.estimatedHeight(
            of: attributedString, textWidth: textWidth, verticalInset: verticalInset
        )
        return DocumentBlockOffsets(blocks: blocks, totalHeight: total)
    }

    /// Height of the lone empty line `boundingRect` adds for the newline at
    /// `location`, isolated from paragraph spacing — the seam to subtract from each
    /// prefix measure. Measured from the boundary's own attributes (terminators
    /// carry no font, so this tracks whatever default they resolve to) rather than
    /// assumed constant.
    @MainActor
    private static func trailingNewlinePhantom(
        at location: Int, in attributedString: NSAttributedString
    ) -> CGFloat {
        var attributes = attributedString.attributes(at: location, effectiveRange: nil)
        if let style = (attributes[.paragraphStyle] as? NSParagraphStyle)?
            .mutableCopy() as? NSMutableParagraphStyle {
            // Zero only the trailing paragraphSpacing (the previous block's real spacing
            // is already in prefixHeight). KEEP paragraphSpacingBefore: boundingRect
            // applies it to the phantom empty line, so it is part of the seam — a heading
            // terminator's 24pt top-margin would otherwise be under-subtracted.
            style.paragraphSpacing = 0
            attributes[.paragraphStyle] = style
        }
        let wide = CGFloat.greatestFiniteMagnitude
        let withNewline = DocumentHeightEstimator.contentHeight(
            of: NSAttributedString(string: "x\n", attributes: attributes), textWidth: wide)
        let withoutNewline = DocumentHeightEstimator.contentHeight(
            of: NSAttributedString(string: "x", attributes: attributes), textWidth: wide)
        return withNewline - withoutNewline
    }
}
