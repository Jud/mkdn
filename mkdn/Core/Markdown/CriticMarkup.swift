import Foundation
import Markdown

/// A single CriticMarkup annotation: a highlighted span `{==…==}` immediately
/// followed by a comment `{>>…<<}`. All ranges index the *raw* source string,
/// which is the comment's durable on-disk identity.
struct CriticComment: Equatable {
    /// Deterministic, document-order id (`c1`, `c2`, …). Stable per parse.
    let id: String
    let body: String
    /// The entire `{==…==}{>>…<<}` span in the raw source.
    let rawFullRange: Range<String.Index>
    /// The highlight's inner text in the raw source (the part kept on screen).
    let rawHighlightRange: Range<String.Index>
    /// The comment body's text in the raw source.
    let rawBodyRange: Range<String.Index>
    /// The highlight inner text's location in the *transformed* source — the
    /// bridge rendering uses to attach the highlight attribute.
    let transformedHighlightRange: Range<String.Index>
}

/// The result of stripping CriticMarkup out of a raw markdown source before it
/// reaches swift-markdown. `transformedSource` is ordinary markdown (delimiters
/// and comment bodies removed, highlight inner text retained) and is what gets
/// parsed/rendered; the preserved-text segments let callers map a position in
/// the transformed source back to the raw source for editing.
struct CriticMarkupDocument {
    let rawSource: String
    let transformedSource: String
    let comments: [CriticComment]

    /// Contiguous spans of text copied verbatim from raw into transformed.
    /// `transformed` offsets are Character counts from the transformed start.
    fileprivate struct Segment {
        let transformedStart: Int
        let transformedEnd: Int
        let raw: Range<String.Index>
    }

    private let segments: [Segment]

    fileprivate init(
        rawSource: String,
        transformedSource: String,
        comments: [CriticComment],
        segments: [Segment]
    ) {
        self.rawSource = rawSource
        self.transformedSource = transformedSource
        self.comments = comments
        self.segments = segments
    }

    /// Map a non-empty range in the transformed source back to the raw source.
    ///
    /// Returns `nil` when the range is empty or spans more than one preserved
    /// segment. Distinct segments always have a CriticMarkup deletion between
    /// them in the raw source, so a cross-segment transformed range has no
    /// contiguous raw counterpart — this is the reject-first contract that
    /// keeps a selection touching an existing comment from being editable.
    func rawRange(forTransformed range: Range<String.Index>) -> Range<String.Index>? {
        let lo = transformedSource.distance(from: transformedSource.startIndex, to: range.lowerBound)
        let hi = transformedSource.distance(from: transformedSource.startIndex, to: range.upperBound)
        guard lo < hi else { return nil }
        guard let segment = segments.first(where: { $0.transformedStart <= lo && hi <= $0.transformedEnd })
        else {
            return nil
        }
        let rawLo = rawSource.index(segment.raw.lowerBound, offsetBy: lo - segment.transformedStart)
        let rawHi = rawSource.index(segment.raw.lowerBound, offsetBy: hi - segment.transformedStart)
        return rawLo ..< rawHi
    }
}

enum CriticMarkup {
    /// Strip CriticMarkup highlight+comment pairs out of `raw`, leaving ordinary
    /// markdown plus the metadata needed to render and edit the comments.
    ///
    /// CriticMarkup-looking text inside code (fenced, indented, or inline) is
    /// left untouched, so code samples containing `{==…==}` are never mutated.
    static func preprocess(_ raw: String) -> CriticMarkupDocument {
        let protected = protectedCodeRanges(in: raw)

        var transformed = ""
        var transformedCount = 0
        var segments: [CriticMarkupDocument.Segment] = []
        var comments: [CriticComment] = []
        var commentCounter = 0

        func appendPreserved(_ rawRange: Range<String.Index>) {
            guard !rawRange.isEmpty else { return }
            let length = raw.distance(from: rawRange.lowerBound, to: rawRange.upperBound)
            segments.append(.init(
                transformedStart: transformedCount,
                transformedEnd: transformedCount + length,
                raw: rawRange
            ))
            transformed += raw[rawRange]
            transformedCount += length
        }

        // Raw-source facts for one parsed pair; transformed-side ranges are
        // computed by the caller once the highlight has been appended.
        struct ParsedComment {
            let full: Range<String.Index>
            let highlight: Range<String.Index>
            let body: Range<String.Index>
        }

        func parseComment(at start: String.Index) -> ParsedComment? {
            guard raw[start...].hasPrefix("{==") else { return nil }
            let highlightStart = raw.index(start, offsetBy: 3)
            guard let hlEnd = raw.range(of: "==}", range: highlightStart ..< raw.endIndex)?.lowerBound
            else {
                return nil
            }
            let highlightRange = highlightStart ..< hlEnd
            guard !highlightRange.isEmpty else { return nil }

            let afterHighlight = raw.index(hlEnd, offsetBy: 3)
            guard raw[afterHighlight...].hasPrefix("{>>") else { return nil }
            let bodyStart = raw.index(afterHighlight, offsetBy: 3)
            guard let bodyEnd = raw.range(of: "<<}", range: bodyStart ..< raw.endIndex)?.lowerBound
            else {
                return nil
            }
            let fullRange = start ..< raw.index(bodyEnd, offsetBy: 3)

            let overlapsCode = protected.contains {
                $0.lowerBound < fullRange.upperBound && fullRange.lowerBound < $0.upperBound
            }
            guard !overlapsCode else { return nil }

            return ParsedComment(full: fullRange, highlight: highlightRange, body: bodyStart ..< bodyEnd)
        }

        var runStart = raw.startIndex
        var cursor = raw.startIndex
        while cursor < raw.endIndex {
            if let parsed = parseComment(at: cursor) {
                appendPreserved(runStart ..< cursor)
                let highlightStartCount = transformedCount
                appendPreserved(parsed.highlight)
                let transformedHighlight =
                    transformed.index(transformed.startIndex, offsetBy: highlightStartCount)
                    ..< transformed.index(transformed.startIndex, offsetBy: transformedCount)

                commentCounter += 1
                comments.append(CriticComment(
                    id: "c\(commentCounter)",
                    body: String(raw[parsed.body]),
                    rawFullRange: parsed.full,
                    rawHighlightRange: parsed.highlight,
                    rawBodyRange: parsed.body,
                    transformedHighlightRange: transformedHighlight
                ))
                cursor = parsed.full.upperBound
                runStart = cursor
            } else {
                cursor = raw.index(after: cursor)
            }
        }
        appendPreserved(runStart ..< raw.endIndex)

        return CriticMarkupDocument(
            rawSource: raw,
            transformedSource: transformed,
            comments: comments,
            segments: segments
        )
    }

    /// Raw-source ranges of every code region (fenced/indented `CodeBlock` and
    /// `InlineCode`), used to shield code samples from the CriticMarkup scan.
    /// Reuses swift-markdown's own code detection rather than re-deriving the
    /// CommonMark rules for fences and indentation.
    private static func protectedCodeRanges(in raw: String) -> [Range<String.Index>] {
        // Any code region implies one of these in the source: a backtick (inline
        // or ``` fence), a tilde (~~~ fence), or a tab / 4-space run (indented
        // block). Absent all of them there is no code to shield.
        guard raw.contains("`") || raw.contains("~") || raw.contains("    ") || raw.contains("\t")
        else {
            return []
        }
        let document = Document(parsing: raw, options: [])
        let converter = SourceLocationConverter(source: raw)
        var ranges: [Range<String.Index>] = []
        collectCodeRanges(in: document, converter: converter, into: &ranges)
        return ranges
    }

    private static func collectCodeRanges(
        in markup: any Markup,
        converter: SourceLocationConverter,
        into ranges: inout [Range<String.Index>]
    ) {
        if markup is CodeBlock || markup is InlineCode, let sourceRange = markup.range,
           let resolved = converter.range(for: sourceRange) {
            ranges.append(resolved)
        }
        for child in markup.children {
            collectCodeRanges(in: child, converter: converter, into: &ranges)
        }
    }
}
