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

    /// Produce syntax-highlighted attributed text using tree-sitter.
    ///
    /// Attempts tree-sitter highlighting for all supported languages.
    /// Code blocks whose language is unsupported or untagged are rendered
    /// as plain monospace text with the theme's `codeForeground` color.
    private var highlightedCode: AttributedString {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let language,
              let nsResult = SyntaxHighlightEngine.highlight(
                  code: trimmed,
                  language: language,
                  syntaxColors: appSettings.theme.syntaxColors
              )
        else {
            var result = AttributedString(trimmed)
            result.foregroundColor = colors.codeForeground
            return result
        }

        do {
            return try AttributedString(nsResult, including: \.appKit)
        } catch {
            var result = AttributedString(trimmed)
            result.foregroundColor = colors.codeForeground
            return result
        }
    }
}
