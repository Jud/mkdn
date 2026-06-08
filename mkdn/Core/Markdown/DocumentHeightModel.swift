#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// A per-block handle for measuring laid-out height without re-running TextKit
/// layout. Heights are measured from the immutable final `NSAttributedString`
/// via `attributedRange`, so fonts, indents, line spacing, and paragraph
/// spacing can never drift from what actually renders. `attachment` is non-nil
/// for block-level attachments (table, image, mermaid, math block, thematic
/// break), whose height comes from the attachment bounds rather than text
/// wrapping.
public struct BlockHeightDescriptor {
    public let blockIndex: Int
    public let attributedRange: NSRange
    public let attachment: NSTextAttachment?
}

/// The per-block sidecar the builder emits alongside the attributed string, in
/// document order. Consumed by `DocumentHeightEstimator` to size the scroller
/// without laying out the document.
public struct DocumentHeightModel {
    public let blocks: [BlockHeightDescriptor]
}
