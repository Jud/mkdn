import Foundation

/// A single comment: a span of rendered text bracketed in the raw source by an
/// invisible paired anchor — `<!--mkc s=ID-->…<!--mkc e=ID-->` — whose body and
/// re-anchoring data live in the document's `CommentSidecar` block, keyed by the
/// same `ID`. Anchors are HTML comments, so they are invisible in every markdown
/// renderer and survive round-trips; mkdn strips them before parsing.
struct CriticComment: Equatable {
    /// The anchor id (`s=ID`/`e=ID`), this comment's durable on-disk identity.
    let id: String
    /// The comment text, from the sidecar entry.
    let body: String
    /// The whole `<!--mkc s=ID-->…<!--mkc e=ID-->` region in the raw source,
    /// anchors included.
    let rawFullRange: Range<String.Index>
    /// The commented text between the anchors in the raw source. With nesting,
    /// this can itself contain other comments' anchors.
    let rawHighlightRange: Range<String.Index>
    /// The commented text's location in the *transformed* source (anchors and
    /// sidecar stripped) — the bridge rendering uses to attach the highlight.
    let transformedHighlightRange: Range<String.Index>
}

/// The result of stripping comment anchors and the sidecar block out of a raw
/// markdown source before it reaches swift-markdown. `transformedSource` is
/// ordinary markdown (anchors and sidecar removed, commented text retained) and
/// is what gets parsed/rendered; the preserved-text segments let callers map a
/// position in the transformed source back to the raw source for editing.
struct CriticMarkupDocument {
    let rawSource: String
    let transformedSource: String
    let comments: [CriticComment]

    /// Comments keyed by id, for hit-test/edit/delete lookups.
    var commentsByID: [String: CriticComment] {
        Dictionary(comments.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

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
    /// segment. Distinct segments always have a stripped anchor (or the sidecar)
    /// between them in the raw source, so a cross-segment transformed range has
    /// no contiguous raw counterpart — the reject-first contract that keeps a
    /// selection touching an existing anchor from being editable.
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
    // MARK: - Parsing

    /// Strip comment anchors and the sidecar block out of `raw`, leaving ordinary
    /// markdown plus the metadata needed to render and edit the comments. A
    /// comment is active only when its id has exactly one start anchor, one end
    /// anchor (start before end), and a sidecar entry; everything else (orphaned
    /// anchors, half-pairs, duplicate ids, anchor-only ids) yields no comment but
    /// its anchors are still stripped so they never render.
    static func preprocess(_ raw: String) -> CriticMarkupDocument {
        let sidecar = CommentSidecar.decode(from: raw)
        let sidecarRange = sidecar?.blockRange

        let allAnchors = anchors(in: raw, excluding: sidecarRange)

        // No anchors and no sidecar: the whole document is preserved verbatim.
        guard !allAnchors.isEmpty || sidecarRange != nil else {
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

        // Cuts: regions removed from the transformed output, in source order.
        var cuts: [(range: Range<String.Index>, anchorIndex: Int?)] =
            allAnchors.enumerated().map { ($1.range, $0) }
        if let sidecarRange {
            // The sidecar is appended metadata; absorb the blank lines around it
            // so stripping it doesn't leave dangling newlines in the rendered text.
            cuts.append((absorbingSurroundingNewlines(of: sidecarRange, in: raw), nil))
        }
        cuts.sort { $0.range.lowerBound < $1.range.lowerBound }

        var transformed = ""
        var transformedCount = 0
        var segments: [CriticMarkupDocument.Segment] = []
        var anchorTransformedOffset = [Int](repeating: 0, count: allAnchors.count)
        var cursor = raw.startIndex

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

        for cut in cuts {
            appendPreserved(cursor ..< cut.range.lowerBound)
            if let anchorIndex = cut.anchorIndex {
                anchorTransformedOffset[anchorIndex] = transformedCount
            }
            cursor = cut.range.upperBound
        }
        appendPreserved(cursor ..< raw.endIndex)

        let comments = pairComments(
            anchors: allAnchors,
            transformedOffsets: anchorTransformedOffset,
            transformed: transformed,
            sidecarEntries: sidecar?.entries ?? []
        )

        return CriticMarkupDocument(
            rawSource: raw,
            transformedSource: transformed,
            comments: comments,
            segments: segments
        )
    }

    /// Match start/end anchors by id into comments. Crossing pairs are accepted
    /// (matched by id, not stack-nesting), so overlapping comments are
    /// representable. Document order is by transformed start offset.
    private static func pairComments(
        anchors: [Anchor],
        transformedOffsets: [Int],
        transformed: String,
        sidecarEntries: [CommentSidecar.Entry]
    ) -> [CriticComment] {
        var startIndices: [String: [Int]] = [:]
        var endIndices: [String: [Int]] = [:]
        for (i, anchor) in anchors.enumerated() {
            switch anchor.kind {
            case .start: startIndices[anchor.id, default: []].append(i)
            case .end: endIndices[anchor.id, default: []].append(i)
            }
        }

        var comments: [CriticComment] = []
        for entry in sidecarEntries {
            guard let starts = startIndices[entry.id], starts.count == 1,
                  let ends = endIndices[entry.id], ends.count == 1
            else {
                continue
            }
            let startAnchor = anchors[starts[0]]
            let endAnchor = anchors[ends[0]]
            // The commented text must be non-empty: the start anchor must close
            // before the end anchor opens, with at least one character between.
            guard startAnchor.range.upperBound < endAnchor.range.lowerBound,
                  transformedOffsets[starts[0]] < transformedOffsets[ends[0]]
            else {
                continue
            }
            let tStart = transformed.index(transformed.startIndex, offsetBy: transformedOffsets[starts[0]])
            let tEnd = transformed.index(transformed.startIndex, offsetBy: transformedOffsets[ends[0]])
            comments.append(CriticComment(
                id: entry.id,
                body: entry.body,
                rawFullRange: startAnchor.range.lowerBound ..< endAnchor.range.upperBound,
                rawHighlightRange: startAnchor.range.upperBound ..< endAnchor.range.lowerBound,
                transformedHighlightRange: tStart ..< tEnd
            ))
        }
        comments.sort { $0.transformedHighlightRange.lowerBound < $1.transformedHighlightRange.lowerBound }
        return comments
    }

    /// Extend a range to swallow newlines immediately before and after it.
    private static func absorbingSurroundingNewlines(
        of range: Range<String.Index>,
        in raw: String
    ) -> Range<String.Index> {
        var lower = range.lowerBound
        while lower > raw.startIndex {
            let previous = raw.index(before: lower)
            guard raw[previous] == "\n" else { break }
            lower = previous
        }
        var upper = range.upperBound
        while upper < raw.endIndex, raw[upper] == "\n" {
            upper = raw.index(after: upper)
        }
        return lower ..< upper
    }

    // MARK: - Anchors

    private struct Anchor {
        enum Kind { case start, end }
        let kind: Kind
        let id: String
        /// The full `<!--mkc s=ID-->` token range in the raw source.
        let range: Range<String.Index>
    }

    private static let anchorMarker = "<!--mkc "

    /// Locate every well-formed `<!--mkc s=ID-->` / `<!--mkc e=ID-->` token in
    /// `raw`, skipping any that fall inside the sidecar block. IDs are
    /// `[A-Za-z0-9]+`; malformed candidates are ignored.
    private static func anchors(in raw: String, excluding sidecar: Range<String.Index>?) -> [Anchor] {
        var result: [Anchor] = []
        var search = raw.startIndex
        while let markerRange = raw.range(of: anchorMarker, range: search ..< raw.endIndex) {
            search = markerRange.upperBound
            var index = markerRange.upperBound
            guard index < raw.endIndex else { break }
            let kind: Anchor.Kind
            switch raw[index] {
            case "s": kind = .start
            case "e": kind = .end
            default: continue
            }
            index = raw.index(after: index)
            guard index < raw.endIndex, raw[index] == "=" else { continue }
            index = raw.index(after: index)
            let idStart = index
            while index < raw.endIndex, raw[index].isLetter || raw[index].isNumber {
                index = raw.index(after: index)
            }
            guard index > idStart, raw[index...].hasPrefix("-->") else { continue }
            let tokenEnd = raw.index(index, offsetBy: 3)
            let tokenRange = markerRange.lowerBound ..< tokenEnd
            if let sidecar, tokenRange.overlaps(sidecar) {
                search = tokenEnd
                continue
            }
            result.append(Anchor(kind: kind, id: String(raw[idStart ..< index]), range: tokenRange))
            search = tokenEnd
        }
        return result
    }

    // MARK: - Authoring

    /// Wrap a raw-source span as a commented anchor pair, adding its body to the
    /// sidecar block. Returns the edited source, or nil when the span is empty or
    /// the result fails to re-parse as the intended comment.
    static func wrapComment(
        in raw: String,
        range: Range<String.Index>,
        body: String,
        idGenerator: () -> String = randomID
    ) -> String? {
        guard !range.isEmpty else { return nil }

        let id = uniqueID(in: raw, idGenerator: idGenerator)
        let quote = String(raw[range])
        let prefix = context(in: raw, before: range.lowerBound)
        let suffix = context(in: raw, after: range.upperBound)

        var candidate = String(raw[..<range.lowerBound])
            + "\(anchorMarker)s=\(id)-->" + quote + "\(anchorMarker)e=\(id)-->"
            + String(raw[range.upperBound...])

        let entry = CommentSidecar.Entry(id: id, body: body, quote: quote, prefix: prefix, suffix: suffix)
        candidate = upsertSidecar(in: candidate, entry: entry)

        // Verify the new comment re-parses with the intended id and body, so a
        // malformed selection (e.g. text that itself looks like an anchor) can't
        // silently produce a different comment.
        let parsed = preprocess(candidate)
        guard let inserted = parsed.commentsByID[id], inserted.body == body else { return nil }
        return candidate
    }

    /// Rewrite a comment's body in the sidecar, returning the edited source, or
    /// nil if no sidecar entry has that id.
    static func editComment(in raw: String, id: String, newBody: String) -> String? {
        guard let decoded = CommentSidecar.decode(from: raw),
              decoded.entries.contains(where: { $0.id == id })
        else {
            return nil
        }
        var entries = decoded.entries
        for index in entries.indices where entries[index].id == id {
            entries[index].body = newBody
        }
        var result = raw
        result.replaceSubrange(decoded.blockRange, with: CommentSidecar.encode(entries))
        return result
    }

    /// Remove a comment (resolve), leaving its commented text behind: strip the
    /// id's anchor pair and its sidecar entry. Returns the source unchanged if
    /// the id has neither.
    static func deleteComment(in raw: String, id: String) -> String {
        var result = raw

        if let decoded = CommentSidecar.decode(from: result) {
            let remaining = decoded.entries.filter { $0.id != id }
            if remaining.count != decoded.entries.count {
                result = writeSidecar(in: result, blockRange: decoded.blockRange, entries: remaining)
            }
        }

        let sidecarRange = CommentSidecar.decode(from: result)?.blockRange
        let toRemove = anchors(in: result, excluding: sidecarRange)
            .filter { $0.id == id }
            .map(\.range)
            .sorted { $0.lowerBound > $1.lowerBound } // back-to-front keeps indices valid
        for range in toRemove {
            result.removeSubrange(range)
        }
        return result
    }

    // MARK: - Authoring helpers

    /// A short random base-36 id, unique within a document at insertion time.
    static func randomID() -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        return String((0 ..< 5).map { _ in alphabet.randomElement()! })
    }

    private static func uniqueID(in raw: String, idGenerator: () -> String) -> String {
        var used = Set(anchors(in: raw, excluding: CommentSidecar.decode(from: raw)?.blockRange).map(\.id))
        used.formUnion(CommentSidecar.decode(from: raw)?.entries.map(\.id) ?? [])
        var id = idGenerator()
        while used.contains(id) { id = idGenerator() }
        return id
    }

    /// Up to 32 characters of context immediately before `index`, for TextQuote
    /// re-anchoring.
    private static func context(in raw: String, before index: String.Index) -> String {
        let start = raw.index(index, offsetBy: -32, limitedBy: raw.startIndex) ?? raw.startIndex
        return String(raw[start ..< index])
    }

    private static func context(in raw: String, after index: String.Index) -> String {
        let end = raw.index(index, offsetBy: 32, limitedBy: raw.endIndex) ?? raw.endIndex
        return String(raw[index ..< end])
    }

    /// Insert or update `entry` in the document's sidecar block, creating the
    /// block at the end of the document if none exists yet.
    private static func upsertSidecar(in raw: String, entry: CommentSidecar.Entry) -> String {
        if let decoded = CommentSidecar.decode(from: raw) {
            var entries = decoded.entries.filter { $0.id != entry.id }
            entries.append(entry)
            return writeSidecar(in: raw, blockRange: decoded.blockRange, entries: entries)
        }
        var trimmed = raw
        while let last = trimmed.last, last == "\n" { trimmed.removeLast() }
        let separator = trimmed.isEmpty ? "" : "\n\n"
        return trimmed + separator + CommentSidecar.encode([entry]) + "\n"
    }

    /// Replace the sidecar block, or remove it (and its trailing blank line) when
    /// no entries remain.
    private static func writeSidecar(
        in raw: String,
        blockRange: Range<String.Index>,
        entries: [CommentSidecar.Entry]
    ) -> String {
        var result = raw
        guard !entries.isEmpty else {
            result.removeSubrange(blockRange)
            while let last = result.last, last == "\n" || last == " " { result.removeLast() }
            if !result.isEmpty { result.append("\n") }
            return result
        }
        result.replaceSubrange(blockRange, with: CommentSidecar.encode(entries))
        return result
    }
}
