#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

extension NSAttributedString.Key {
    /// The ids (`[String]`) of every comment whose highlight covers this range.
    /// A list, not a single id, so overlapping comments are all recoverable at a
    /// point (the click picks the innermost).
    static let mkdnCommentID = NSAttributedString.Key("mkdnCommentID")
}

@MainActor
extension MarkdownTextStorageBuilder {
    /// A mutable copy of `base` with `document`'s comment highlights applied (or
    /// just a copy when there are no comments). Shared by the initial build and
    /// the live comment-only repaint so both derive highlights identically.
    static func highlighted(
        base: NSAttributedString,
        document: CriticMarkupDocument?,
        sourceMap: SourceMap,
        color: PlatformTypeConverter.PlatformColor
    ) -> NSMutableAttributedString {
        let mutable = NSMutableAttributedString(attributedString: base)
        if let document, !document.comments.isEmpty {
            applyCommentHighlights(to: mutable, document: document, sourceMap: sourceMap, color: color)
        }
        return mutable
    }

    /// Paint each comment's highlight span with `color` and tag it with the
    /// comment id, mapping the comment's transformed-source range to builder
    /// ranges via `sourceMap`. The raw CriticMarkup delimiters are already gone
    /// (stripped by the preprocessor), so only the highlighted text is tinted.
    static func applyCommentHighlights(
        to attributedString: NSMutableAttributedString,
        document: CriticMarkupDocument,
        sourceMap: SourceMap,
        color: PlatformTypeConverter.PlatformColor
    ) {
        for comment in document.comments {
            for nsRange in highlightRanges(
                for: comment, in: document, sourceMap: sourceMap, maxLength: attributedString.length
            ) {
                attributedString.addAttribute(.backgroundColor, value: color, range: nsRange)
                appendCommentID(comment.id, to: attributedString, in: nsRange)
            }
        }
    }

    /// The bounds-checked builder NSRanges a comment's highlight covers — mapping
    /// its transformed-source span through `sourceMap`. Shared by the build-time
    /// highlighter and the live hover-emphasis painter so the mapping lives once.
    static func highlightRanges(
        for comment: CriticComment,
        in document: CriticMarkupDocument,
        sourceMap: SourceMap,
        maxLength: Int
    ) -> [NSRange] {
        let utf16 = document.transformedSource.utf16
        let lower = utf16.distance(from: utf16.startIndex, to: comment.transformedHighlightRange.lowerBound)
        let upper = utf16.distance(from: utf16.startIndex, to: comment.transformedHighlightRange.upperBound)
        return sourceMap.builderUTF16Ranges(forSource: lower ..< upper).compactMap { builderRange in
            let nsRange = NSRange(
                location: builderRange.lowerBound,
                length: builderRange.upperBound - builderRange.lowerBound
            )
            guard nsRange.location >= 0, NSMaxRange(nsRange) <= maxLength else { return nil }
            return nsRange
        }
    }

    /// Append `id` to the `mkdnCommentID` list across `range`, preserving any ids
    /// already there so overlapping comments accumulate rather than overwrite.
    private static func appendCommentID(
        _ id: String,
        to attributedString: NSMutableAttributedString,
        in range: NSRange
    ) {
        var updates: [(NSRange, [String])] = []
        attributedString.enumerateAttribute(.mkdnCommentID, in: range, options: []) { value, subRange, _ in
            updates.append((subRange, ((value as? [String]) ?? []) + [id]))
        }
        for (subRange, ids) in updates {
            attributedString.addAttribute(.mkdnCommentID, value: ids, range: subRange)
        }
    }
}
