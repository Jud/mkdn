import Foundation

/// Resolves a selection in the built attributed string back to a range in the
/// raw markdown source, composing the two maps produced by the comment
/// pipeline: builder → transformed source (`SourceMap`) and transformed → raw
/// source (`CriticMarkupDocument`). Returns nil whenever the selection cannot be
/// safely mapped (reject-first), so authoring only ever wraps source-backed text.
struct CommentRangeResolver {
    let document: CriticMarkupDocument
    let sourceMap: SourceMap

    func rawRange(forBuilderRange nsRange: NSRange) -> Range<String.Index>? {
        let builderRange = nsRange.location ..< (nsRange.location + nsRange.length)
        guard let sourceUTF16 = sourceMap.sourceUTF16Range(forBuilder: builderRange) else {
            return nil
        }

        let transformed = document.transformedSource
        let utf16 = transformed.utf16
        guard let lowerUTF16 = utf16.index(
            utf16.startIndex, offsetBy: sourceUTF16.lowerBound, limitedBy: utf16.endIndex
        ),
            let upperUTF16 = utf16.index(
                utf16.startIndex, offsetBy: sourceUTF16.upperBound, limitedBy: utf16.endIndex
            ),
            let lower = lowerUTF16.samePosition(in: transformed),
            let upper = upperUTF16.samePosition(in: transformed)
        else {
            return nil
        }

        // A selection inside an existing comment is allowed: v3 supports nested
        // and overlapping comments (anchors are matched by id, not stacked), so
        // wrapping here adds a nested comment rather than corrupting the existing
        // one. (Cross-anchor selections still fail to map — rawRange returns nil
        // for a transformed range that spans a stripped anchor.)
        return document.rawRange(forTransformed: lower ..< upper)
    }
}
