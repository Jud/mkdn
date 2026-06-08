import Foundation

/// One top-level block's span in the final attributed string, in document order.
/// The builder emits these so the height engine can locate per-block boundaries
/// without re-parsing the markdown.
public struct BlockSpan {
    public let index: Int // source block index
    public let range: NSRange // range in the final attributed string
}

/// Per-block spans emitted alongside the attributed string. Consumed by
/// ``DocumentBlockOffsets`` to map document y-positions to blocks (and back)
/// without running the renderer's TextKit layout.
public struct DocumentHeightModel {
    public let blocks: [BlockSpan]
}
