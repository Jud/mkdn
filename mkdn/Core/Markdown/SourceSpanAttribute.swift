import Foundation

/// Marks a run of `AttributedString` whose rendered text is a verbatim 1:1 copy
/// of the parsed source, carrying the UTF-16 offset into that source of the
/// run's first character. `MarkdownTextStorageBuilder` reads it to build a
/// builder-output → source map for resolving selections back to source.
///
/// It is attached ONLY where rendered text equals the source substring exactly.
/// Runs that the parser transformed — escapes (`\*` → `*`), entities
/// (`&amp;` → `&`), soft breaks (newline → space), inline code, math — carry no
/// span, which marks them unsafe so selections touching them are rejected.
enum SourceSpanAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
    typealias Value = Int

    static let name = "mkdnSourceSpan"
}

extension AttributeScopes {
    struct MkdnSourceAttributes: AttributeScope {
        let sourceSpan: SourceSpanAttribute
    }
}

extension AttributeDynamicLookup {
    subscript<T>(
        dynamicMember keyPath: KeyPath<AttributeScopes.MkdnSourceAttributes, T> // swiftlint:disable:this unused_parameter
    ) -> T where T: AttributedStringKey {
        self[T.self]
    }
}
