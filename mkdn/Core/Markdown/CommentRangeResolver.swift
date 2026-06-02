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

        guard let rawRange = document.rawRange(forTransformed: lower ..< upper) else {
            return nil
        }

        // Reject text inside an existing comment: re-commenting there would nest
        // CriticMarkup and corrupt the existing annotation (v1 has no threading).
        if document.comments.contains(where: { rawRange.overlaps($0.rawFullRange) }) {
            return nil
        }
        return rawRange
    }
}
