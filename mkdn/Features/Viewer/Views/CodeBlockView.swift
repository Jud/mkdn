import Splash
import SwiftUI

/// Renders a fenced code block with syntax highlighting.
struct CodeBlockView: View {
    let language: String?
    let code: String

    @Environment(AppSettings.self) private var appSettings

    private var colors: ThemeColors {
        appSettings.theme.colors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty {
                Text(language)
                    .font(.caption.monospaced())
                    .foregroundColor(colors.foregroundSecondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Text(highlightedCode)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(colors.codeForeground)
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
    ///
    /// Splash only ships SwiftGrammar; it has no built-in grammars for Python,
    /// JavaScript, or other languages. Code blocks whose language is anything
    /// other than `"swift"` are rendered as plain monospace text with the
    /// theme's `codeForeground` color -- never as an error or blank block.
    private var highlightedCode: AttributedString {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard language == "swift" else {
            var result = AttributedString(trimmed)
            result.foregroundColor = colors.codeForeground
            return result
        }

        let syntaxColors = appSettings.theme.syntaxColors
        let outputFormat = ThemeOutputFormat(
            plainTextColor: PlatformTypeConverter.nsColor(from: syntaxColors.comment),
            tokenColorMap: [
                .keyword: PlatformTypeConverter.nsColor(from: syntaxColors.keyword),
                .string: PlatformTypeConverter.nsColor(from: syntaxColors.string),
                .type: PlatformTypeConverter.nsColor(from: syntaxColors.type),
                .call: PlatformTypeConverter.nsColor(from: syntaxColors.function),
                .number: PlatformTypeConverter.nsColor(from: syntaxColors.number),
                .comment: PlatformTypeConverter.nsColor(from: syntaxColors.comment),
                .property: PlatformTypeConverter.nsColor(from: syntaxColors.property),
                .dotAccess: PlatformTypeConverter.nsColor(from: syntaxColors.property),
                .preprocessing: PlatformTypeConverter.nsColor(from: syntaxColors.preprocessor),
            ]
        )
        let highlighter = SyntaxHighlighter(format: outputFormat)
        return highlighter.highlight(trimmed)
    }
}
