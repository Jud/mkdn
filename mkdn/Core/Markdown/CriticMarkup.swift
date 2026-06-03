import Foundation
import Markdown

/// A single comment: a span of rendered text bracketed in the raw source by an
/// invisible paired anchor — `<mkdn-comment id="ID" edge="start"/>…
/// <mkdn-comment id="ID" edge="end"/>` — whose body and re-anchoring data live in
/// the document's `CommentSidecar` block, keyed by the same `ID`. The anchors are
/// empty self-closing custom elements, so they render invisibly and survive
/// round-trips; mkdn strips them before parsing.
struct CriticComment: Equatable {
    /// The anchor id, this comment's durable on-disk identity.
    let id: String
    /// The comment text, from the sidecar entry.
    let body: String
    /// The whole `<mkdn-comment …start/>…<mkdn-comment …end/>` region in the raw
    /// source, anchors included.
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

    /// The comments for `ids`, ordered smallest span first — so overlapping
    /// comments stack innermost (most specific) at the top. Unknown ids ignored.
    func commentsInnermostFirst(among ids: [String]) -> [CriticComment] {
        let wanted = Set(ids)
        return comments.filter { wanted.contains($0.id) }
            .sorted { spanLength(of: $0) < spanLength(of: $1) }
    }

    private func spanLength(of comment: CriticComment) -> Int {
        transformedSource.distance(
            from: comment.transformedHighlightRange.lowerBound,
            to: comment.transformedHighlightRange.upperBound
        )
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
        CriticMarkupDocument.rawRange(
            forTransformed: range, transformed: transformedSource, segments: segments, raw: rawSource
        )
    }

    /// Shared segment mapping, also used during re-anchoring before a document is
    /// constructed.
    fileprivate static func rawRange(
        forTransformed range: Range<String.Index>,
        transformed: String,
        segments: [Segment],
        raw: String
    ) -> Range<String.Index>? {
        let lo = transformed.distance(from: transformed.startIndex, to: range.lowerBound)
        let hi = transformed.distance(from: transformed.startIndex, to: range.upperBound)
        guard lo < hi else { return nil }
        guard let segment = segments.first(where: { $0.transformedStart <= lo && hi <= $0.transformedEnd })
        else {
            return nil
        }
        let rawLo = raw.index(segment.raw.lowerBound, offsetBy: lo - segment.transformedStart)
        let rawHi = raw.index(segment.raw.lowerBound, offsetBy: hi - segment.transformedStart)
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
        let sidecarEntries = sidecar?.entries ?? []

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

        var comments = pairComments(
            anchors: allAnchors,
            transformedOffsets: anchorTransformedOffset,
            transformed: transformed,
            sidecarEntries: sidecarEntries
        )

        // Resilience: a sidecar entry whose anchor pair was lost to an external
        // edit (git merge, another editor, an agent rewriting prose) is recovered
        // by locating its TextQuote, so the comment survives the anchor loss.
        comments += reanchoredComments(
            sidecarEntries: sidecarEntries,
            anchoredIDs: Set(comments.map(\.id)),
            transformed: transformed,
            segments: segments,
            raw: raw
        )
        comments.sort { $0.transformedHighlightRange.lowerBound < $1.transformedHighlightRange.lowerBound }

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
            switch anchor.edge {
            case .start: startIndices[anchor.id, default: []].append(i)
            case .end: endIndices[anchor.id, default: []].append(i)
            }
        }

        // Duplicate ids are malformed; keep the first, matching `commentsByID`.
        var seenIDs = Set<String>()
        let uniqueEntries = sidecarEntries.filter { seenIDs.insert($0.id).inserted }

        var comments: [CriticComment] = []
        for entry in uniqueEntries {
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
        // preprocess sorts the combined paired + re-anchored list, so no sort here.
        return comments
    }

    /// "\r\n" is a single grapheme-cluster Character in Swift, distinct from a
    /// lone "\r" or "\n"; all three are newlines.
    private static func isNewline(_ character: Character) -> Bool {
        character == "\n" || character == "\r" || character == "\r\n"
    }

    /// Extend a range to swallow newlines after it, and (only when the block
    /// trails the document) before it. Leading newlines are absorbed only for a
    /// trailing block so a hand-placed mid-document sidecar can't merge the
    /// paragraphs around it.
    private static func absorbingSurroundingNewlines(
        of range: Range<String.Index>,
        in raw: String
    ) -> Range<String.Index> {
        var upper = range.upperBound
        while upper < raw.endIndex, isNewline(raw[upper]) {
            upper = raw.index(after: upper)
        }
        var lower = range.lowerBound
        if upper == raw.endIndex {
            while lower > raw.startIndex {
                let previous = raw.index(before: lower)
                guard isNewline(raw[previous]) else { break }
                lower = previous
            }
        }
        return lower ..< upper
    }

    // MARK: - Re-anchoring

    /// Recover comments whose anchor pair is missing by locating each orphaned
    /// sidecar entry's TextQuote in the rendered text. Conservative: requires a
    /// UNIQUE exact `prefix+quote+suffix` match (no fuzzy matching); otherwise the
    /// entry stays orphaned and produces no comment.
    private static func reanchoredComments(
        sidecarEntries: [CommentSidecar.Entry],
        anchoredIDs: Set<String>,
        transformed: String,
        segments: [CriticMarkupDocument.Segment],
        raw: String
    ) -> [CriticComment] {
        var seen = anchoredIDs
        var result: [CriticComment] = []
        for entry in sidecarEntries where !seen.contains(entry.id) && !entry.quote.isEmpty {
            seen.insert(entry.id)
            guard let highlight = reanchorRange(for: entry, in: transformed),
                  let rawRange = CriticMarkupDocument.rawRange(
                      forTransformed: highlight, transformed: transformed, segments: segments, raw: raw
                  )
            else {
                continue
            }
            result.append(CriticComment(
                id: entry.id,
                body: entry.body,
                rawFullRange: rawRange,
                rawHighlightRange: rawRange,
                transformedHighlightRange: highlight
            ))
        }
        return result
    }

    /// The unique location of `entry`'s quote in `transformed`, validated by its
    /// stored prefix/suffix context. Returns nil unless exactly one occurrence of
    /// the quote has the matching surrounding context. Searching the quote
    /// directly (rather than the concatenated `prefix+quote+suffix`) keeps the
    /// returned range exactly the quote, with no grapheme-boundary mis-slicing.
    private static func reanchorRange(
        for entry: CommentSidecar.Entry,
        in transformed: String
    ) -> Range<String.Index>? {
        guard !entry.quote.isEmpty else { return nil }

        var match: Range<String.Index>?
        var searchStart = transformed.startIndex
        while let found = transformed.range(of: entry.quote, range: searchStart ..< transformed.endIndex) {
            let prefixMatches = entry.prefix.isEmpty
                || transformed[..<found.lowerBound].hasSuffix(entry.prefix)
            let suffixMatches = entry.suffix.isEmpty
                || transformed[found.upperBound...].hasPrefix(entry.suffix)
            if prefixMatches, suffixMatches {
                if match != nil { return nil } // not unique → orphan
                match = found
            }
            searchStart = transformed.index(after: found.lowerBound)
        }
        return match
    }

    // MARK: - Anchors

    /// Which edge of a commented span an anchor marks.
    enum AnchorEdge: String { case start, end }

    private struct Anchor {
        let edge: AnchorEdge
        let id: String
        /// The full `<mkdn-comment …/>` token range in the raw source.
        let range: Range<String.Index>
    }

    /// The invisible paired anchor token. A self-closing custom element rather
    /// than an HTML comment because, unlike `<!--…-->`, it parses as INLINE html
    /// even at the start of a line/heading — so any text, including a line's
    /// first word, is commentable without changing how a standard CommonMark
    /// renderer (GitHub, Obsidian) lays out the document. Empty + unknown, so it
    /// renders invisibly; greppable via `mkdn-comment`.
    static func anchorToken(id: String, edge: AnchorEdge) -> String {
        "<mkdn-comment id=\"\(id)\" edge=\"\(edge.rawValue)\"/>"
    }

    private static let anchorTagOpen = "<mkdn-comment "

    /// Locate every well-formed `<mkdn-comment …/>` token in `raw`, skipping any
    /// inside the sidecar block. Malformed candidates are ignored.
    private static func anchors(in raw: String, excluding sidecar: Range<String.Index>?) -> [Anchor] {
        var result: [Anchor] = []
        var search = raw.startIndex
        while let openRange = raw.range(of: anchorTagOpen, range: search ..< raw.endIndex) {
            search = openRange.upperBound
            // Close THIS tag at its first '>'; never scan ahead to a distant
            // '/>', which would let a literal `<mkdn-comment ` in prose/code
            // swallow everything up to a real anchor.
            guard let gt = raw[openRange.upperBound...].firstIndex(of: ">") else { break }
            let inside = raw[openRange.upperBound ..< gt]
            // A stray `<` before the `>` means this isn't one clean tag (the real
            // tag's `>` came earlier or this is malformed) — reject.
            guard inside.last == "/", !inside.contains("<") else { continue }
            let attributes = inside.dropLast()
            guard let id = attributeValue("id", in: attributes), !id.isEmpty,
                  let edgeValue = attributeValue("edge", in: attributes),
                  let edge = AnchorEdge(rawValue: edgeValue)
            else {
                continue
            }
            let tokenEnd = raw.index(after: gt)
            search = tokenEnd
            let tokenRange = openRange.lowerBound ..< tokenEnd
            if let sidecar, tokenRange.overlaps(sidecar) { continue }
            result.append(Anchor(edge: edge, id: id, range: tokenRange))
        }
        return result
    }

    /// The double-quoted value of attribute `name` within an anchor tag's
    /// attribute span, or nil if absent. The name must sit at a boundary (tag
    /// start or after a space) so `id="…"` doesn't match inside `data-id="…"`.
    private static func attributeValue(_ name: String, in attributes: Substring) -> String? {
        let token = "\(name)=\""
        var searchStart = attributes.startIndex
        while let opening = attributes.range(of: token, range: searchStart ..< attributes.endIndex) {
            let atBoundary = opening.lowerBound == attributes.startIndex
                || attributes[attributes.index(before: opening.lowerBound)] == " "
            if atBoundary {
                guard let closingQuote = attributes[opening.upperBound...].firstIndex(of: "\"") else {
                    return nil
                }
                return String(attributes[opening.upperBound ..< closingQuote])
            }
            searchStart = opening.upperBound
        }
        return nil
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

        // A selection overlapping the sidecar block would pull it inside the new
        // highlight and corrupt it; reject. (Selections containing other
        // comments' anchors are fine — that is legitimate nesting.)
        if let sidecar = CommentSidecar.decode(from: raw)?.blockRange, range.overlaps(sidecar) {
            return nil
        }

        let quote = String(raw[range])
        let id = uniqueID(in: raw, idGenerator: idGenerator)

        var candidate = String(raw[..<range.lowerBound])
            + anchorToken(id: id, edge: .start) + quote + anchorToken(id: id, edge: .end)
            + String(raw[range.upperBound...])
        candidate = upsertSidecar(in: candidate, entry: .init(id: id, body: body, quote: quote))

        // The real safety net: the inserted anchors must be parse-neutral in a
        // standard CommonMark renderer (one that does NOT strip them, e.g.
        // GitHub). Reject any placement that changes the rendered structure —
        // a marker at the first non-space of a line becoming an HTML block, a
        // split emphasis run, etc. mkdn itself always renders correctly (it
        // strips anchors first); this protects portability.
        guard rendersUnchanged(raw: raw, candidate: candidate) else { return nil }

        // And it must re-parse to the intended comment, so a selection whose text
        // itself looks like an anchor can't silently produce a different one.
        let parsed = preprocess(candidate)
        guard let inserted = parsed.commentsByID[id], inserted.body == body else { return nil }

        // Capture the TextQuote (quote + prefix/suffix context) from the RENDERED
        // text, which has no anchors or sidecar — so re-anchoring later can match
        // it directly, even for a comment authored next to another comment.
        return upsertSidecar(in: candidate, entry: textQuote(for: inserted, in: parsed.transformedSource))
    }

    /// The re-anchoring TextQuote for `comment`, read from the anchor-free
    /// transformed text around its highlight.
    private static func textQuote(for comment: CriticComment, in transformed: String) -> CommentSidecar.Entry {
        let highlight = comment.transformedHighlightRange
        let prefixStart = transformed.index(
            highlight.lowerBound, offsetBy: -contextLength, limitedBy: transformed.startIndex
        ) ?? transformed.startIndex
        let suffixEnd = transformed.index(
            highlight.upperBound, offsetBy: contextLength, limitedBy: transformed.endIndex
        ) ?? transformed.endIndex
        return CommentSidecar.Entry(
            id: comment.id,
            body: comment.body,
            quote: String(transformed[highlight]),
            prefix: String(transformed[prefixStart ..< highlight.lowerBound]),
            suffix: String(transformed[highlight.upperBound ..< suffixEnd])
        )
    }

    /// Whether `candidate` parses to the same rendered structure as `raw` once the
    /// invisible mkdn anchors and sidecar are ignored in both — the authoring
    /// safety net (see `wrapComment`).
    private static func rendersUnchanged(raw: String, candidate: String) -> Bool {
        renderSignature(Document(parsing: raw, options: []))
            == renderSignature(Document(parsing: candidate, options: []))
    }

    /// A structural + text signature of a parsed document that ignores mkdn
    /// anchors/sidecar and merges the text they split, so an invisible marker
    /// inserted mid-text registers as no change while one that alters block or
    /// inline structure does.
    private static func renderSignature(_ markup: Markup) -> String {
        var signature = "<\(type(of: markup))"
        switch markup {
        case let heading as Heading: signature += ":\(heading.level)"
        case let code as InlineCode: signature += ":\(code.code)"
        case let code as CodeBlock: signature += ":\(code.language ?? ""):\(code.code)"
        case let link as Markdown.Link: signature += ":\(link.destination ?? "")"
        case let image as Markdown.Image: signature += ":\(image.source ?? "")"
        case let html as InlineHTML: signature += ":\(html.rawHTML)"
        case let html as HTMLBlock: signature += ":\(html.rawHTML)"
        default: break
        }

        var text = ""
        func flushText() {
            if !text.isEmpty {
                signature += "[T:\(text)]"
                text = ""
            }
        }
        for child in markup.children {
            if isMkdnComment(child) { continue }
            if let textNode = child as? Markdown.Text {
                text += textNode.string
                continue
            }
            flushText()
            signature += renderSignature(child)
        }
        flushText()
        return signature + ">"
    }

    /// An HTML-comment node that is one of mkdn's invisible markers (an anchor or
    /// the sidecar), which standard renderers drop and the signature must ignore.
    private static func isMkdnComment(_ markup: Markup) -> Bool {
        let html: String
        if let inline = markup as? InlineHTML {
            html = inline.rawHTML
        } else if let block = markup as? HTMLBlock {
            html = block.rawHTML
        } else {
            return false
        }
        // Match the anchor element and the sidecar comment specifically (not just
        // the substring, so a user's own `<span class="mkdn-comment-x">` isn't
        // dropped). Standard renderers drop both of these.
        return html.contains(anchorTagOpen) || html.contains(CommentSidecar.blockOpen)
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

    /// TextQuote context length kept on each side of the quote.
    private static let contextLength = 32

    /// Insert or update `entry` in the document's sidecar block, creating the
    /// block at the end of the document if none exists yet.
    private static func upsertSidecar(in raw: String, entry: CommentSidecar.Entry) -> String {
        if let decoded = CommentSidecar.decode(from: raw) {
            var entries = decoded.entries.filter { $0.id != entry.id }
            entries.append(entry)
            return writeSidecar(in: raw, blockRange: decoded.blockRange, entries: entries)
        }
        var trimmed = raw
        while let last = trimmed.last, isNewline(last) { trimmed.removeLast() }
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
            // Trim only the trailing newlines (the separator we appended), never
            // spaces — trailing spaces can be a significant hard-break.
            while let last = result.last, isNewline(last) { result.removeLast() }
            if !result.isEmpty { result.append("\n") }
            return result
        }
        result.replaceSubrange(blockRange, with: CommentSidecar.encode(entries))
        return result
    }
}
