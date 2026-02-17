import SwiftUI

/// Universal syntax token types for cross-language highlighting.
/// Maps tree-sitter highlight query capture names to a finite set of
/// color-resolved categories used by all 16 supported languages.
enum TokenType: Sendable {
    case keyword
    case string
    case comment
    case type
    case number
    case function
    case property
    case preprocessor
    case `operator`
    case variable
    case constant
    case attribute
    case punctuation

    private static let captureNameMap: [String: Self] = [
        "keyword": .keyword,
        "conditional": .keyword,
        "repeat": .keyword,
        "exception": .keyword,
        "string": .string,
        "character": .string,
        "escape": .string,
        "comment": .comment,
        "type": .type,
        "number": .number,
        "float": .number,
        "function": .function,
        "method": .function,
        "property": .property,
        "field": .property,
        "preproc": .preprocessor,
        "include": .preprocessor,
        "operator": .operator,
        "variable": .variable,
        "parameter": .variable,
        "constant": .constant,
        "boolean": .constant,
        "attribute": .attribute,
        "decorator": .attribute,
        "punctuation": .punctuation,
        "delimiter": .punctuation,
        "constructor": .type,
        "label": .keyword,
        "tag": .keyword,
        "namespace": .type,
        "module": .type,
    ]

    /// Map a tree-sitter highlight capture name to a TokenType.
    /// Returns nil for captures that should use plain text color.
    static func from(captureName: String) -> Self? {
        let base = captureName.split(separator: ".").first.map(String.init) ?? captureName
        return captureNameMap[base]
    }

    /// Resolve to a Color from the given SyntaxColors palette.
    func color(from syntaxColors: SyntaxColors) -> Color {
        switch self {
        case .keyword: syntaxColors.keyword
        case .string: syntaxColors.string
        case .comment: syntaxColors.comment
        case .type: syntaxColors.type
        case .number: syntaxColors.number
        case .function: syntaxColors.function
        case .property: syntaxColors.property
        case .preprocessor: syntaxColors.preprocessor
        case .operator: syntaxColors.operator
        case .variable: syntaxColors.variable
        case .constant: syntaxColors.constant
        case .attribute: syntaxColors.attribute
        case .punctuation: syntaxColors.punctuation
        }
    }
}
