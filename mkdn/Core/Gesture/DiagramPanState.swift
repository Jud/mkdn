import Foundation

/// Tracks the pan offset for a single Mermaid diagram and enforces
/// content-boundary clamping.
///
/// Pure arithmetic -- no dependencies, no side effects beyond updating
/// the internal `offset`. Returns an `ApplyResult` that splits each
/// delta into a consumed portion (applied to the offset) and an overflow
/// portion (excess beyond the content boundary) for forwarding to the
/// parent document scroll view.
struct DiagramPanState {
    struct ApplyResult {
        let consumedDelta: CGSize
        let overflowDelta: CGSize
    }

    var offset: CGSize = .zero

    /// Apply a scroll delta and return how much was consumed vs. overflowed.
    ///
    /// The pannable range per axis is determined by the scaled content size
    /// minus the visible frame size:
    /// ```
    /// maxOffset = max(0, (contentSize * zoomScale - frameSize) / 2)
    /// ```
    /// When content fits within the frame at the current zoom, `maxOffset`
    /// is zero, meaning all delta overflows (BR-05 satisfied structurally).
    ///
    /// - Parameters:
    ///   - dx: Horizontal scroll delta (positive = pan right).
    ///   - dy: Vertical scroll delta (positive = pan down).
    ///   - contentSize: The natural (unscaled) size of the diagram image.
    ///   - frameSize: The visible frame size of the diagram container.
    ///   - zoomScale: The current zoom multiplier applied to the diagram.
    /// - Returns: An `ApplyResult` with consumed and overflow portions.
    mutating func applyDelta(
        dx: CGFloat,
        dy: CGFloat,
        contentSize: CGSize,
        frameSize: CGSize,
        zoomScale: CGFloat
    ) -> ApplyResult {
        let maxOffsetX = max(0, (contentSize.width * zoomScale - frameSize.width) / 2)
        let maxOffsetY = max(0, (contentSize.height * zoomScale - frameSize.height) / 2)

        let proposedX = offset.width + dx
        let proposedY = offset.height + dy

        let clampedX = min(max(proposedX, -maxOffsetX), maxOffsetX)
        let clampedY = min(max(proposedY, -maxOffsetY), maxOffsetY)

        let consumedX = clampedX - offset.width
        let consumedY = clampedY - offset.height

        let overflowX = dx - consumedX
        let overflowY = dy - consumedY

        offset = CGSize(width: clampedX, height: clampedY)

        return ApplyResult(
            consumedDelta: CGSize(width: consumedX, height: consumedY),
            overflowDelta: CGSize(width: overflowX, height: overflowY)
        )
    }
}
