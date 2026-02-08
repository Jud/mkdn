@preconcurrency import Splash
import SwiftUI

/// Splash OutputFormat producing `AttributedString` with SwiftUI Colors.
/// Theme-agnostic: accepts any token-to-color mapping.
struct ThemeOutputFormat: OutputFormat, Sendable {
    let plainTextColor: SwiftUI.Color
    let tokenColorMap: [TokenType: SwiftUI.Color]

    func makeBuilder() -> Builder {
        Builder(plainTextColor: plainTextColor, tokenColorMap: tokenColorMap)
    }

    struct Builder: OutputBuilder, Sendable {
        let plainTextColor: SwiftUI.Color
        let tokenColorMap: [TokenType: SwiftUI.Color]
        var result = AttributedString()

        mutating func addToken(_ token: String, ofType type: TokenType) {
            var attributed = AttributedString(token)
            attributed.foregroundColor = tokenColorMap[type] ?? plainTextColor
            result.append(attributed)
        }

        mutating func addPlainText(_ text: String) {
            var attributed = AttributedString(text)
            attributed.foregroundColor = plainTextColor
            result.append(attributed)
        }

        mutating func addWhitespace(_ whitespace: String) {
            var attributed = AttributedString(whitespace)
            attributed.foregroundColor = plainTextColor
            result.append(attributed)
        }

        func build() -> AttributedString {
            result
        }
    }
}
