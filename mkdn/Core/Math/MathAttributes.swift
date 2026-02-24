import Foundation

/// Marks a range of `AttributedString` as containing a LaTeX math expression.
/// Used by `MarkdownVisitor` to annotate inline `$...$` delimited math so that
/// `MarkdownTextStorageBuilder` can render it as an `NSTextAttachment` image.
enum MathExpressionAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
    typealias Value = String

    static let name = "mathExpression"
}

extension AttributeScopes {
    struct MathAttributes: AttributeScope {
        let mathExpression: MathExpressionAttribute
    }
}

extension AttributeDynamicLookup {
    subscript<T>(
        dynamicMember keyPath: KeyPath<AttributeScopes.MathAttributes, T> // swiftlint:disable:this unused_parameter
    ) -> T where T: AttributedStringKey {
        self[T.self]
    }
}
