import AppKit
@preconcurrency import Splash

/// Splash OutputFormat producing `AttributedString` with AppKit-scoped
/// `NSColor` foreground colors so that `NSMutableAttributedString` conversion
/// yields `.foregroundColor` keyed as `"NSColor"` -- the key NSTextView
/// actually reads for text rendering.
struct ThemeOutputFormat: OutputFormat, Sendable {
    let plainTextColor: NSColor
    let tokenColorMap: [TokenType: NSColor]

    func makeBuilder() -> Builder {
        Builder(plainTextColor: plainTextColor, tokenColorMap: tokenColorMap)
    }

    struct Builder: OutputBuilder, Sendable {
        let plainTextColor: NSColor
        let tokenColorMap: [TokenType: NSColor]
        var result = AttributedString()

        mutating func addToken(_ token: String, ofType type: TokenType) {
            var attributed = AttributedString(token)
            attributed.appKit.foregroundColor = tokenColorMap[type] ?? plainTextColor
            result.append(attributed)
        }

        mutating func addPlainText(_ text: String) {
            var attributed = AttributedString(text)
            attributed.appKit.foregroundColor = plainTextColor
            result.append(attributed)
        }

        mutating func addWhitespace(_ whitespace: String) {
            var attributed = AttributedString(whitespace)
            attributed.appKit.foregroundColor = plainTextColor
            result.append(attributed)
        }

        func build() -> AttributedString {
            result
        }
    }
}
