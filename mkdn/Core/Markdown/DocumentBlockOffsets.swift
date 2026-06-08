#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Per-block vertical offsets in the markdown preview, computed from the final
/// attributed string without running the renderer's TextKit fragment layout.
/// `offsets[i]` is the top y of the block at position `i`, with a trailing entry
/// holding the document height — so the block at position `i` spans
/// `[offsets[i], offsets[i + 1])`. Enables mapping a scroll y to a block and back
/// for scroll-to-anchor, the scrollbar, and a minimap.
///
/// Each offset is one cumulative-prefix measure (`O(blocks)` measures total), so
/// the lone trailing-newline seam each prefix carries is a near-constant shift
/// rather than per-block accumulating drift. It is `O(n^2)` in block count;
/// intended to be computed once and cached, not per frame.
public struct DocumentBlockOffsets {
    public let offsets: [CGFloat]
    /// Source block index for each position, parallel to the leading offsets.
    public let blockIndices: [Int]

    public var totalHeight: CGFloat { offsets.last ?? 0 }
    public var isEmpty: Bool { blockIndices.isEmpty }

    /// Top y of the block with source `index`, or nil if absent.
    public func offset(forBlockIndex index: Int) -> CGFloat? {
        guard let position = blockIndices.firstIndex(of: index) else { return nil }
        return offsets[position]
    }

    /// Source index of the block whose span contains `y` (the last block whose
    /// top is at or above `y`), or nil when empty.
    public func blockIndex(atY y: CGFloat) -> Int? {
        guard !blockIndices.isEmpty else { return nil }
        var low = 0
        var high = blockIndices.count - 1
        var result = 0
        while low <= high {
            let mid = (low + high) / 2
            if offsets[mid] <= y {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return blockIndices[result]
    }

    @MainActor
    public static func compute(
        of attributedString: NSAttributedString,
        model: DocumentHeightModel,
        textWidth: CGFloat,
        verticalInset: CGFloat
    ) -> DocumentBlockOffsets {
        guard textWidth > 0, !model.blocks.isEmpty else {
            return DocumentBlockOffsets(offsets: [], blockIndices: [])
        }
        var offsets = model.blocks.map { block -> CGFloat in
            let prefix = NSRange(location: 0, length: block.range.location)
            let prefixHeight = prefix.length == 0 ? 0 : DocumentHeightEstimator.contentHeight(
                of: attributedString.attributedSubstring(from: prefix), textWidth: textWidth
            )
            return verticalInset + prefixHeight
        }
        offsets.append(DocumentHeightEstimator.estimatedHeight(
            of: attributedString, textWidth: textWidth, verticalInset: verticalInset
        ))
        return DocumentBlockOffsets(offsets: offsets, blockIndices: model.blocks.map(\.index))
    }
}
