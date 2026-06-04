import Foundation

/// The persisted body + re-anchoring metadata for each comment, stored in a
/// single HTML-comment block at the end of the document:
///
/// ```
/// <!--mkdn-comments
/// {"v":1,"comments":[{"id":"k7","body":"…","quote":"…","prefix":"…","suffix":"…"}]}
/// -->
/// ```
///
/// The block is an HTML comment so it stays invisible in every markdown
/// renderer and survives round-trips. Bodies/quotes are arbitrary text, so the
/// JSON is escaped to guarantee it can never contain `-->` — which would
/// terminate the comment early. We also escape bare `--`, which CommonMark
/// ≥0.30 permits but older CommonMark and strict HTML/XML parsers forbid inside
/// comment content; the cost is nil and the portability is worth it. Agents
/// read comments by grepping `mkdn-comments`.
enum CommentSidecar {
    /// One comment's durable data, keyed to its anchor pair by `id`.
    struct Entry: Equatable, Codable {
        var id: String
        var body: String
        /// The exact commented text (TextQuote), refreshed from intact anchors
        /// on save and used to re-anchor after an external edit breaks them.
        var quote: String
        /// Short text immediately before/after the quote, for disambiguating a
        /// non-unique quote during re-anchoring.
        var prefix: String
        var suffix: String
        /// v2 TextPositionSelector — start/end offsets into the normalized anchor
        /// tape, captured at creation. A *hint* used only to disambiguate when the
        /// quote+context still matches more than once (W3C calls the position
        /// selector "very brittle"), never the primary locator. nil for v1 entries.
        var start: Int?
        var end: Int?
        /// Version of the text normalizer the quote/prefix/suffix/offsets were
        /// recorded under, so a future normalizer change can re-anchor rather than
        /// silently mismatch. nil for v1 entries.
        var norm: Int?

        init(
            id: String, body: String, quote: String = "", prefix: String = "", suffix: String = "",
            start: Int? = nil, end: Int? = nil, norm: Int? = nil
        ) {
            self.id = id
            self.body = body
            self.quote = quote
            self.prefix = prefix
            self.suffix = suffix
            self.start = start
            self.end = end
            self.norm = norm
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
            quote = try container.decodeIfPresent(String.self, forKey: .quote) ?? ""
            prefix = try container.decodeIfPresent(String.self, forKey: .prefix) ?? ""
            suffix = try container.decodeIfPresent(String.self, forKey: .suffix) ?? ""
            start = try container.decodeIfPresent(Int.self, forKey: .start)
            end = try container.decodeIfPresent(Int.self, forKey: .end)
            norm = try container.decodeIfPresent(Int.self, forKey: .norm)
        }

        // `encode(to:)` is synthesized: it emits the non-optional fields and uses
        // `encodeIfPresent` for the optionals, so an absent start/end/norm writes
        // no key — a v1 entry re-encodes byte-for-byte as before (guarded by
        // `v1EntryOmitsV2Keys`). Only `init(from:)` is hand-written, to default
        // absent strings to "".
    }

    /// The schema version written into the block. Bumped for a breaking shape
    /// change; absent-by-default additions (the v2 start/end/norm fields) stay
    /// readable as `v:1`, so the writer bumps to 2 only when it starts emitting
    /// those fields (the anchoring units), not merely because Entry can hold them.
    static let currentVersion = 1

    /// TextQuote context kept on each side of the quote (prefix/suffix), in
    /// characters. Shared by every capture path so the v1 (raw-source) and v2
    /// (rendered-tape) windows can't drift apart. ~32 per W3C/Hypothes.is.
    static let contextLength = 32

    static let blockOpen = "<!--mkdn-comments"
    static let blockClose = "-->"

    private struct Wrapper: Codable {
        let v: Int
        let comments: [Entry]
    }

    /// Render entries as the sidecar block text (no surrounding newlines). The
    /// caller decides placement/spacing in the document.
    static func encode(_ entries: [Entry]) -> String {
        let wrapper = Wrapper(v: currentVersion, comments: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let json: String
        if let data = try? encoder.encode(wrapper), let text = String(data: data, encoding: .utf8) {
            json = escape(text)
        } else {
            json = "{\"v\":\(currentVersion),\"comments\":[]}"
        }
        return "\(blockOpen)\n\(json)\n\(blockClose)"
    }

    /// Find and decode the sidecar block in `raw`, returning the parsed entries
    /// and the block's raw range (so the parser can strip it). Returns nil when
    /// there is no block or its JSON is unreadable.
    ///
    /// The sidecar is always appended at the end of the document, so we match the
    /// LAST `<!--mkdn-comments` — earlier prose or code that merely mentions the
    /// marker can't shadow the real trailing block.
    static func decode(from raw: String) -> (entries: [Entry], blockRange: Range<String.Index>)? {
        // Scan marker candidates from last to first and return the first that is a
        // real sidecar: trailing metadata after its close AND decodable JSON. This
        // skips a shadow marker the user wrote inside a trailing HTML comment
        // (e.g. docs mentioning `<!--mkdn-comments`), which would otherwise hide
        // the genuine trailing block.
        var searchEnd = raw.endIndex
        while let openRange = raw.range(of: blockOpen, options: .backwards, range: raw.startIndex ..< searchEnd) {
            searchEnd = openRange.lowerBound // next iteration considers earlier candidates
            // Escaped JSON never contains "-->", so the first close after the
            // marker is the true terminator.
            guard let closeRange = raw.range(of: blockClose, range: openRange.upperBound ..< raw.endIndex) else {
                continue
            }
            // The sidecar is appended metadata: accept it only when nothing but
            // trailing metadata (whitespace and the user's own HTML comments, e.g.
            // a license or TODO note) follows its close. A `<!--mkdn-comments…-->`
            // embedded in prose or a code fence is left as ordinary content.
            guard isTrailingMetadata(raw[closeRange.upperBound...]) else { continue }
            // The extracted text still holds the `>`/`-` escapes; JSONDecoder
            // restores them to `>`/`-` natively, so no inverse step is needed.
            let jsonText = String(raw[openRange.upperBound ..< closeRange.lowerBound])
            guard let data = jsonText.data(using: .utf8),
                  let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data)
            else {
                continue
            }
            return (wrapper.comments, openRange.lowerBound ..< closeRange.upperBound)
        }
        return nil
    }

    /// Whether everything after the sidecar's close is "trailing metadata" — only
    /// whitespace and complete HTML comments. Lets a user keep their own trailing
    /// `<!-- … -->` after the sidecar without detaching their comments, while
    /// still rejecting a marker block followed by real prose or a fence close.
    private static func isTrailingMetadata(_ tail: Substring) -> Bool {
        var rest = tail
        while true {
            rest = rest.drop(while: \.isWhitespace)
            guard !rest.isEmpty else { return true }
            // HTML comments can't contain "-->", so the first one closes this tag.
            guard rest.hasPrefix("<!--"), let close = rest.range(of: "-->") else { return false }
            rest = rest[close.upperBound...]
        }
    }

    // MARK: - Authoring

    /// A short random base-36 id (anchor-attribute safe: no quotes/`<>`/spaces).
    static func randomID() -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        return String((0 ..< 5).map { _ in alphabet.randomElement()! })
    }

    /// An id not already used by an entry in `raw`.
    static func uniqueID(in raw: String) -> String {
        let used = Set(decode(from: raw)?.entries.map(\.id) ?? [])
        for _ in 0 ..< 100 {
            let id = randomID()
            if !used.contains(id) { return id }
        }
        let base = randomID()
        var suffix = 1
        var id = base
        while used.contains(id) {
            id = "\(base)\(suffix)"
            suffix += 1
        }
        return id
    }

    /// Insert or replace `entry` (by id) in `raw`'s sidecar block, creating the
    /// block at the end of the document if none exists yet.
    static func upsert(_ entry: Entry, into raw: String) -> String {
        guard let decoded = decode(from: raw) else {
            var trimmed = raw
            while let last = trimmed.last, last.isNewline { trimmed.removeLast() }
            let separator = trimmed.isEmpty ? "" : "\n\n"
            return trimmed + separator + encode([entry]) + "\n"
        }
        var entries = decoded.entries.filter { $0.id != entry.id }
        entries.append(entry)
        var result = raw
        result.replaceSubrange(decoded.blockRange, with: encode(entries))
        return result
    }

    /// Remove the entry with `id` (no-op if absent), removing the block and its
    /// trailing blank line when no entries remain. Removes orphaned entries too.
    static func remove(id: String, from raw: String) -> String {
        guard let decoded = decode(from: raw) else { return raw }
        let entries = decoded.entries.filter { $0.id != id }
        guard entries.count != decoded.entries.count else { return raw }
        var result = raw
        guard !entries.isEmpty else {
            result.removeSubrange(decoded.blockRange)
            // Trim only trailing newlines (the separator), never spaces (a hard break).
            while let last = result.last, last.isNewline { result.removeLast() }
            if !result.isEmpty { result.append("\n") }
            return result
        }
        result.replaceSubrange(decoded.blockRange, with: encode(entries))
        return result
    }

    // MARK: - `-->`-safe escaping

    /// Replace every `>` and `-` with their JSON `\uXXXX` escapes so the encoded
    /// text can never form `-->` (hard requirement) or bare `--` (defensive).
    /// JSONDecoder restores them transparently, so no inverse step is needed.
    private static func escape(_ json: String) -> String {
        json
            .replacingOccurrences(of: ">", with: "\\u003e")
            .replacingOccurrences(of: "-", with: "\\u002d")
    }
}
