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

        init(id: String, body: String, quote: String = "", prefix: String = "", suffix: String = "") {
            self.id = id
            self.body = body
            self.quote = quote
            self.prefix = prefix
            self.suffix = suffix
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
            quote = try container.decodeIfPresent(String.self, forKey: .quote) ?? ""
            prefix = try container.decodeIfPresent(String.self, forKey: .prefix) ?? ""
            suffix = try container.decodeIfPresent(String.self, forKey: .suffix) ?? ""
        }
    }

    /// The schema version written into the block; bumped if the shape changes.
    static let currentVersion = 1

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
        guard let openRange = raw.range(of: blockOpen, options: .backwards) else { return nil }
        // Escaped JSON never contains "-->", so the first close after the marker
        // is the true terminator.
        guard let closeRange = raw.range(of: blockClose, range: openRange.upperBound ..< raw.endIndex) else {
            return nil
        }
        // The sidecar is appended metadata: recognize it only as the document's
        // TRAILING block (nothing but whitespace after its close). A
        // `<!--mkdn-comments…-->` inside a code fence or mid-document is then left
        // as ordinary user content, never stripped.
        guard raw[closeRange.upperBound...].allSatisfy(\.isWhitespace) else { return nil }
        // The extracted text still holds the `>`/`-` escapes; JSONDecoder
        // restores them to `>`/`-` natively, so no inverse step is needed.
        let jsonText = String(raw[openRange.upperBound ..< closeRange.lowerBound])
        guard let data = jsonText.data(using: .utf8),
              let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data)
        else {
            return nil
        }
        return (wrapper.comments, openRange.lowerBound ..< closeRange.upperBound)
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
