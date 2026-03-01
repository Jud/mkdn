import SwiftUI

/// Target for programmatic scroll-to-block behavior in `MarkdownContentView`.
///
/// Bound via the `.scrollTarget` modifier and consumed by `ScrollViewReader`
/// in `MarkdownContentView` to scroll to a specific block by index.
public struct BlockScrollTarget: Equatable {
    public let blockIndex: Int
    public let anchor: UnitPoint

    public init(blockIndex: Int, anchor: UnitPoint = .top) {
        self.blockIndex = blockIndex
        self.anchor = anchor
    }
}
