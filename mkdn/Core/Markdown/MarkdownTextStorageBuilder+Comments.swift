#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

extension NSAttributedString.Key {
    /// The id of the CriticMarkup comment whose highlight covers this range.
    static let mkdnCommentID = NSAttributedString.Key("mkdnCommentID")
}

@MainActor
extension MarkdownTextStorageBuilder {
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
        let utf16 = document.transformedSource.utf16
        for comment in document.comments {
            let lower = utf16.distance(from: utf16.startIndex, to: comment.transformedHighlightRange.lowerBound)
            let upper = utf16.distance(from: utf16.startIndex, to: comment.transformedHighlightRange.upperBound)
            for builderRange in sourceMap.builderUTF16Ranges(forSource: lower ..< upper) {
                let nsRange = NSRange(
                    location: builderRange.lowerBound,
                    length: builderRange.upperBound - builderRange.lowerBound
                )
                guard nsRange.location >= 0, NSMaxRange(nsRange) <= attributedString.length else {
                    continue
                }
                attributedString.addAttribute(.backgroundColor, value: color, range: nsRange)
                attributedString.addAttribute(.mkdnCommentID, value: comment.id, range: nsRange)
            }
        }
    }
}
