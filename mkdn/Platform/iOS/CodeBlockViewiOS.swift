#if os(iOS)
    import SwiftUI
    import UIKit

    /// Renders a fenced code block with syntax highlighting and a copy button on iOS.
    ///
    /// Uses ``SyntaxHighlightEngine`` for tree-sitter-based highlighting when a
    /// recognized language tag is present. Falls back to plain monospace text for
    /// unsupported or untagged code blocks. A copy button in the top-trailing
    /// corner invokes the ``MarkdownInteraction/onCodeCopy`` handler and copies
    /// the raw code to the system pasteboard.
    struct CodeBlockViewiOS: View {
        let language: String?
        let code: String
        let theme: AppTheme
        let scaleFactor: CGFloat

        @Environment(\.markdownInteraction) private var interaction

        @State private var isCopied = false

        private var colors: ThemeColors {
            theme.colors
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.codeBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(colors.border.opacity(0.3), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                copyButton
                    .padding(8)
            }
        }

        // MARK: - Copy Button

        private var copyButton: some View {
            Button {
                performCopy()
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }

        private func performCopy() {
            let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
            UIPasteboard.general.string = trimmed
            interaction.onCodeCopy?(trimmed, language)

            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = true
            }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCopied = false
                }
            }
        }

        // MARK: - Syntax Highlighting

        private var highlightedCode: AttributedString {
            let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

            guard let language,
                  let nsResult = SyntaxHighlightEngine.highlight(
                      code: trimmed,
                      language: language,
                      syntaxColors: theme.syntaxColors
                  )
            else {
                var result = AttributedString(trimmed)
                result.foregroundColor = colors.codeForeground
                return result
            }

            do {
                return try AttributedString(nsResult, including: \.uiKit)
            } catch {
                var result = AttributedString(trimmed)
                result.foregroundColor = colors.codeForeground
                return result
            }
        }
    }
#endif
