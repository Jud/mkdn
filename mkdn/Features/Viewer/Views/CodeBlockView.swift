import Splash
import SwiftUI

/// Renders a fenced code block with syntax highlighting.
struct CodeBlockView: View {
    let language: String?
    let code: String

    @Environment(AppState.self) private var appState

    private var colors: ThemeColors {
        appState.theme.colors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language label
            if let language, !language.isEmpty {
                Text(language)
                    .font(.caption.monospaced())
                    .foregroundColor(colors.foregroundSecondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            // Code content
            ScrollView(.horizontal, showsIndicators: true) {
                Text(highlightedCode)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(colors.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(colors.border.opacity(0.3), lineWidth: 1)
        )
    }

    /// Produce syntax-highlighted attributed text using Splash.
    private var highlightedCode: AttributedString {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let language, !language.isEmpty, language == "swift" else {
            var result = AttributedString(trimmed)
            result.foregroundColor = colors.codeForeground
            return result
        }

        // Use Splash for Swift highlighting.
        let syntaxColors = appState.theme.syntaxColors
        let outputFormat = SolarizedOutputFormat(
            plainTextColor: syntaxColors.comment,
            tokenColorMap: [
                .keyword: syntaxColors.keyword,
                .string: syntaxColors.string,
                .type: syntaxColors.type,
                .call: syntaxColors.function,
                .number: syntaxColors.number,
                .comment: syntaxColors.comment,
                .property: syntaxColors.property,
                .dotAccess: syntaxColors.property,
                .preprocessing: syntaxColors.preprocessor,
            ]
        )
        let highlighter = SyntaxHighlighter(format: outputFormat)
        return highlighter.highlight(trimmed)
    }
}

// MARK: - Splash Output Format for SwiftUI AttributedString

/// Splash output format producing `AttributedString` with SwiftUI Colors.
/// Uses `SwiftUI.Color` explicitly to avoid ambiguity with Splash's Color typealias.
struct SolarizedOutputFormat: OutputFormat {
    let plainTextColor: SwiftUI.Color
    let tokenColorMap: [TokenType: SwiftUI.Color]

    func makeBuilder() -> Builder {
        Builder(plainTextColor: plainTextColor, tokenColorMap: tokenColorMap)
    }

    struct Builder: OutputBuilder {
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
            result.append(AttributedString(whitespace))
        }

        func build() -> AttributedString {
            result
        }
    }
}
