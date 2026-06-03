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
        // Reject hostile/degenerate ranges before any arithmetic: a negative
        // location (e.g. NSNotFound from a failed search), an empty selection, or
        // an upper bound that would overflow Int (NSRange uses Int).
        guard nsRange.location >= 0, nsRange.length > 0,
              nsRange.location <= Int.max - nsRange.length
        else {
            return nil
        }
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

        // A selection inside or across existing comments is allowed: v3 supports
        // nested and overlapping comments (anchors are matched by id, not
        // stacked), so wrapping here adds another comment rather than corrupting
        // the existing one. A cross-anchor selection maps to the raw span
        // enclosing the stripped anchors, which the new outer pair then wraps.
        return document.rawRange(forTransformed: lower ..< upper)
    }
}
