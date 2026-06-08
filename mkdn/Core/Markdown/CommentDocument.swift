import Foundation

/// A markdown document split into its renderable body and its comment metadata.
///
/// Comments live only in the EOF ``CommentSidecar`` block. Parsing strips that
/// block and any stray inline `<mkdn-comment …/>` markers (from the retired
/// inline-anchor format) so neither reaches the renderer; the body renders as
/// ordinary markdown and comments anchor to it by content.
struct CommentDocument: Equatable {
    let body: String
    let entries: [CommentSidecar.Entry]

    static func parse(_ raw: String) -> CommentDocument {
        var entries: [CommentSidecar.Entry] = []
        var text = raw
        if let decoded = CommentSidecar.decode(from: raw) {
            entries = decoded.entries
            text.removeSubrange(decoded.blockRange)
        }
        var body = stripInlineMarkers(text)
        // Trim trailing newlines (they never affect rendering): removing a sidecar
        // leaves the separator newlines behind, so trimming keeps `body` stable
        // across the no-sidecar↔sidecar transition — the comment-only-change
        // detector stays exact and adding the first comment doesn't force a rebuild.
        while body.last?.isNewline == true { body.removeLast() }
        return CommentDocument(body: body, entries: entries)
    }

    private static let markerOpen = "<mkdn-comment "

    /// Remove well-formed self-closing `<mkdn-comment id="…" edge="start|end"/>`
    /// markers, leaving any malformed or literal occurrence untouched so prose that
    /// merely mentions the tag survives.
    private static func stripInlineMarkers(_ text: String) -> String {
        var result = ""
        var copiedUpTo = text.startIndex
        var search = text.startIndex
        while let open = text.range(of: markerOpen, range: search ..< text.endIndex) {
            // Close at the first '>': never scan ahead to a distant '/>', which would
            // let a literal "<mkdn-comment " in prose swallow text up to a real marker.
            guard let gt = text[open.upperBound...].firstIndex(of: ">") else { break }
            let inside = text[open.upperBound ..< gt]
            if inside.last == "/", !inside.contains("<") {
                let attributes = inside.dropLast()
                if let id = attributeValue("id", in: attributes), !id.isEmpty,
                   let edge = attributeValue("edge", in: attributes), edge == "start" || edge == "end" {
                    result += text[copiedUpTo ..< open.lowerBound]
                    copiedUpTo = text.index(after: gt)
                    search = copiedUpTo
                    continue
                }
            }
            search = open.upperBound
        }
        result += text[copiedUpTo...]
        return result
    }

    /// The double-quoted value of attribute `name`, anchored to a boundary (tag
    /// start or after a space) so `id="…"` doesn't match inside `data-id="…"`.
    private static func attributeValue(_ name: String, in attributes: Substring) -> String? {
        let token = "\(name)=\""
        var searchStart = attributes.startIndex
        while let opening = attributes.range(of: token, range: searchStart ..< attributes.endIndex) {
            let atBoundary = opening.lowerBound == attributes.startIndex
                || attributes[attributes.index(before: opening.lowerBound)] == " "
            if atBoundary {
                guard let close = attributes[opening.upperBound...].firstIndex(of: "\"") else { return nil }
                return String(attributes[opening.upperBound ..< close])
            }
            searchStart = opening.upperBound
        }
        return nil
    }
}
