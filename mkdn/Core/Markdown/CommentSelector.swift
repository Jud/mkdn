import Foundation

/// The content-anchored selector captured for a comment: the normalized `quote`
/// plus disambiguation `prefix`/`suffix` context and a `start`/`end` position
/// hint into the rendered tape. The write-side mirror of
/// ``CommentAnchorResolver`` — what this records is what the resolver searches
/// for, both over the same normalized ``AnchorTape``.
public struct CommentSelector: Equatable {
    public var quote: String
    public var prefix: String
    public var suffix: String
    public var start: Int
    public var end: Int
    public var norm: Int
}

extension CommentSidecar.Entry {
    /// Overwrite this entry's anchor fields with a freshly captured selector,
    /// leaving `id`/`body` untouched.
    mutating func setAnchor(_ selector: CommentSelector) {
        quote = selector.quote
        prefix = selector.prefix
        suffix = selector.suffix
        start = selector.start
        end = selector.end
        norm = selector.norm
    }
}

#if os(macOS)
    import AppKit

    enum CommentSelectorCapture {
        /// Capture a selector for a builder-space text selection against the
        /// rendered tape, or nil when the selection maps to no anchorable text
        /// (e.g. it lands entirely in excluded/collapsed source).
        static func capture(builderRange: NSRange, in tape: AnchorTape) -> CommentSelector? {
            guard let range = tape.normalizedRange(forBuilder: builderRange) else { return nil }
            let ns = tape.text as NSString
            let context = CommentSidecar.contextLength
            var prefixStart = max(0, range.lowerBound - context)
            var suffixEnd = min(ns.length, range.upperBound + context)
            // Keep the context windows valid Unicode: if a window edge lands inside
            // a surrogate pair, shrink it to drop the orphaned half (context is soft,
            // so trimming one boundary char is harmless).
            if prefixStart > 0, UTF16.isTrailSurrogate(ns.character(at: prefixStart)) { prefixStart += 1 }
            if suffixEnd < ns.length, UTF16.isLeadSurrogate(ns.character(at: suffixEnd - 1)) { suffixEnd -= 1 }
            return CommentSelector(
                quote: ns.substring(with: NSRange(location: range.lowerBound, length: range.count)),
                prefix: ns.substring(with: NSRange(location: prefixStart, length: range.lowerBound - prefixStart)),
                suffix: ns.substring(with: NSRange(location: range.upperBound, length: suffixEnd - range.upperBound)),
                start: range.lowerBound,
                end: range.upperBound,
                norm: AnchorTape.normalizationVersion
            )
        }
    }
#endif
