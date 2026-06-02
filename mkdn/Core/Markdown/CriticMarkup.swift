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
    /// CriticMarkup-looking text inside regions that are not plain rendered
    /// prose — code (fenced/indented/inline), HTML, and link/image syntax — is
    /// left untouched, so it is never silently mutated.
    static func preprocess(_ raw: String) -> CriticMarkupDocument {
        // No opener means nothing to strip; skip the protective parse entirely.
        guard raw.contains("{==") else {
            let wholeSegment: [CriticMarkupDocument.Segment] = raw.isEmpty ? [] : [.init(
                transformedStart: 0,
                transformedEnd: raw.count,
                raw: raw.startIndex ..< raw.endIndex
            )]
            return CriticMarkupDocument(
                rawSource: raw,
                transformedSource: raw,
                comments: [],
                segments: wholeSegment
            )
        }

        let protected = protectedRanges(in: raw)

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

        var runStart = raw.startIndex
        var searchStart = raw.startIndex
        // Opener-driven scan: jump to each "{==" via range(of:) and never
        // re-scan earlier text, so adversarial opener spam stays linear.
        while let openRange = raw.range(of: "{==", range: searchStart ..< raw.endIndex) {
            let open = openRange.lowerBound
            let highlightStart = openRange.upperBound
            guard let closeRange = raw.range(of: "==}", range: highlightStart ..< raw.endIndex) else {
                break // no highlight terminator remains anywhere ahead
            }
            let highlightEnd = closeRange.lowerBound
            let afterHighlight = closeRange.upperBound

            // This is the first "==}" after `open`, so every opener up to here
            // shares it and fails the same check — resume past it, don't retry each.
            guard highlightStart < highlightEnd, raw[afterHighlight...].hasPrefix("{>>") else {
                searchStart = afterHighlight
                continue
            }
            let bodyStart = raw.index(afterHighlight, offsetBy: 3)
            guard let bodyCloseRange = raw.range(of: "<<}", range: bodyStart ..< raw.endIndex) else {
                break // no comment terminator remains anywhere ahead
            }
            let fullRange = open ..< bodyCloseRange.upperBound

            let overlapsProtected = protected.contains {
                $0.lowerBound < fullRange.upperBound && fullRange.lowerBound < $0.upperBound
            }
            guard !overlapsProtected else {
                searchStart = afterHighlight
                continue
            }

            appendPreserved(runStart ..< open)
            let highlightStartCount = transformedCount
            appendPreserved(highlightStart ..< highlightEnd)
            let transformedHighlight =
                transformed.index(transformed.startIndex, offsetBy: highlightStartCount)
                ..< transformed.index(transformed.startIndex, offsetBy: transformedCount)

            commentCounter += 1
            comments.append(CriticComment(
                id: "c\(commentCounter)",
                body: String(raw[bodyStart ..< bodyCloseRange.lowerBound]),
                rawFullRange: fullRange,
                rawHighlightRange: highlightStart ..< highlightEnd,
                rawBodyRange: bodyStart ..< bodyCloseRange.lowerBound,
                transformedHighlightRange: transformedHighlight
            ))
            searchStart = fullRange.upperBound
            runStart = searchStart
        }
        appendPreserved(runStart ..< raw.endIndex)

        return CriticMarkupDocument(
            rawSource: raw,
            transformedSource: transformed,
            comments: comments,
            segments: segments
        )
    }

    /// Raw-source ranges that are not plain rendered prose and must be shielded
    /// from the CriticMarkup scan. Reuses swift-markdown's own detection rather
    /// than re-deriving CommonMark rules.
    private static func protectedRanges(in raw: String) -> [Range<String.Index>] {
        let document = Document(parsing: raw, options: [])
        let converter = SourceLocationConverter(source: raw)
        var ranges: [Range<String.Index>] = []
        collectProtectedRanges(in: document, converter: converter, into: &ranges)
        ranges.append(contentsOf: referenceDefinitionRanges(in: raw))
        return ranges
    }

    /// Raw-source ranges of link/image *reference definition* lines
    /// (`[label]: destination`). swift-markdown resolves these onto use-site
    /// `Link` nodes and exposes no node for the definition line itself, so the
    /// AST walk cannot shield them; CriticMarkup in a definition URL would
    /// otherwise be silently stripped. Detected by a minimal line scan: up to
    /// three leading spaces, `[label]:`, protected through end of line.
    private static func referenceDefinitionRanges(in raw: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var lineStart = raw.startIndex
        while lineStart < raw.endIndex {
            let lineEnd = raw[lineStart...].firstIndex { $0 == "\n" || $0 == "\r" } ?? raw.endIndex
            if isReferenceDefinition(in: raw, lineStart: lineStart, lineEnd: lineEnd) {
                ranges.append(lineStart ..< lineEnd)
            }
            lineStart = lineEnd < raw.endIndex ? raw.index(after: lineEnd) : raw.endIndex
        }
        return ranges
    }

    private static func isReferenceDefinition(
        in raw: String,
        lineStart: String.Index,
        lineEnd: String.Index
    ) -> Bool {
        var index = lineStart
        var leadingSpaces = 0
        while index < lineEnd, raw[index] == " ", leadingSpaces < 3 {
            index = raw.index(after: index)
            leadingSpaces += 1
        }
        guard index < lineEnd, raw[index] == "[" else { return false }
        let labelStart = raw.index(after: index)
        guard let labelEnd = raw[labelStart ..< lineEnd].firstIndex(of: "]"),
              labelEnd > labelStart // a non-empty label
        else {
            return false
        }
        let afterLabel = raw.index(after: labelEnd)
        return afterLabel < lineEnd && raw[afterLabel] == ":"
    }

    /// Shields code (fenced/indented `CodeBlock`, `InlineCode`), HTML
    /// (`HTMLBlock`/`InlineHTML`, rendered as raw text), and link/image syntax.
    /// CriticMarkup inside a link destination would silently rewrite the URL
    /// with no visible comment, so the whole node is treated as non-commentable.
    /// v1 limitation: this conservatively rejects comments that merely overlap a
    /// link (e.g. a highlight enclosing linked prose), not only those inside the
    /// destination. The precise rule — block only delimiters that land in
    /// non-rendered syntax — belongs with the rendered-text mapping (later phase).
    private static func collectProtectedRanges(
        in markup: any Markup,
        converter: SourceLocationConverter,
        into ranges: inout [Range<String.Index>]
    ) {
        switch markup {
        case is CodeBlock, is InlineCode, is HTMLBlock, is InlineHTML, is Markdown.Link, is Markdown.Image:
            if let sourceRange = markup.range, let resolved = converter.range(for: sourceRange) {
                ranges.append(resolved)
            }
        default:
            break
        }
        for child in markup.children {
            collectProtectedRanges(in: child, converter: converter, into: &ranges)
        }
    }
}
