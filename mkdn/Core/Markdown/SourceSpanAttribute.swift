import Foundation

/// The UTF-16 range, in the parsed source, that a run of rendered text maps to.
///
/// - **Linear** runs render a verbatim 1:1 copy of their source substring, so
///   `end - start` equals the run's rendered UTF-16 length and interior
///   positions map proportionally.
/// - **Atomic** runs render a whole token whose source is longer than what shows
///   (a link `[docs](url)` → "docs", an inline code `` `x` `` → "x"); the run
///   length differs from `end - start`, and any selection inside snaps to the
///   whole `start..<end` token.
///
/// `SourceMap` tells the two apart by comparing the rendered length to
/// `end - start`, so no explicit kind flag is stored.
struct SourceSpan: Codable, Hashable {
    let start: Int
    let end: Int

    init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    /// NSAttributedString carries the span as a 2-element `[start, end]` array,
    /// which bridges to NSArray with reliable value equality so `SourceMap`'s
    /// enumeration coalesces a token's runs. These two members keep that
    /// positional encoding in one typed place.
    init?(attributeArray: [Int]) {
        guard attributeArray.count == 2 else { return nil }
        self.init(start: attributeArray[0], end: attributeArray[1])
    }

    var attributeArray: [Int] { [start, end] }
}

/// Marks a run of `AttributedString` that maps back to a `SourceSpan` in the
/// parsed source. `MarkdownTextStorageBuilder` reads it to build a
/// builder-output → source map for resolving selections back to source.
///
/// Runs the parser transformed with no clean source token — escapes (`\*` → `*`),
/// entities (`&amp;` → `&`), soft breaks (newline → space), math — carry no span,
/// which marks them unsafe so selections touching them are rejected.
enum SourceSpanAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
    typealias Value = SourceSpan

    static let name = "mkdnSourceSpan"
}

extension AttributeScopes {
    struct MkdnSourceAttributes: AttributeScope {
        let sourceSpan: SourceSpanAttribute
    }
}

extension AttributeDynamicLookup {
    subscript<T>(
        // swiftlint:disable:next unused_parameter
        dynamicMember keyPath: KeyPath<AttributeScopes.MkdnSourceAttributes, T>
    ) -> T where T: AttributedStringKey {
        self[T.self]
    }
}
