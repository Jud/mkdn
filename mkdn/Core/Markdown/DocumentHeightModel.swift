import Foundation

/// One top-level block's span in the final attributed string, in document order.
/// The builder emits these so the height engine can locate per-block boundaries
/// without re-parsing the markdown.
public struct BlockSpan {
    public let index: Int // source block index
    public let range: NSRange // range in the final attributed string
    public let kind: BlockKind

    public init(index: Int, range: NSRange, kind: BlockKind = .paragraph) {
        self.index = index
        self.range = range
        self.kind = kind
    }
}

/// Per-block spans emitted alongside the attributed string. Consumed by
/// ``DocumentBlockOffsets`` to map document y-positions to blocks (and back)
/// without running the renderer's TextKit layout.
public struct DocumentHeightModel {
    public let blocks: [BlockSpan]
}

public extension DocumentHeightModel {
    /// Source index of the block containing `location`. Blocks are contiguous
    /// spans, so a location on a span boundary belongs to the later block; a
    /// location at or past the document end falls to the last block.
    func blockIndex(containing location: Int) -> Int? {
        for block in blocks where NSLocationInRange(location, block.range) {
            return block.index
        }
        if let last = blocks.last, location >= last.range.location {
            return last.index
        }
        return nil
    }
}
