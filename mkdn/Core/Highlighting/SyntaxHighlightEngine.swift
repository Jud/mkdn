import AppKit
import SwiftTreeSitter

/// Synchronous syntax highlighting engine using tree-sitter.
/// Stateless design: parser and query are created per call.
/// Thread-safe by construction (no shared mutable state).
enum SyntaxHighlightEngine {
    /// Highlight code for a given language, returning a colored NSMutableAttributedString.
    /// Returns nil if the language is not supported (caller should fall back to plain text).
    static func highlight(
        code: String,
        language: String,
        syntaxColors: SyntaxColors
    ) -> NSMutableAttributedString? {
        guard let config = TreeSitterLanguageMap.configuration(for: language) else {
            return nil
        }

        let parser = Parser()
        do {
            try parser.setLanguage(config.language)
        } catch {
            return nil
        }

        guard let tree = parser.parse(code) else {
            return nil
        }

        let plainColor = PlatformTypeConverter.nsColor(from: syntaxColors.variable)
        let result = NSMutableAttributedString(
            string: code,
            attributes: [.foregroundColor: plainColor]
        )

        let resultLength = result.length

        do {
            let queryData = Data(config.highlightQuery.utf8)
            let query = try Query(language: config.language, data: queryData)
            let cursor = query.execute(in: tree)

            for match in cursor {
                for capture in match.captures {
                    guard let captureName = capture.name else { continue }
                    guard let tokenType = TokenType.from(captureName: captureName) else { continue }

                    let range = capture.range
                    guard range.location >= 0,
                          range.location + range.length <= resultLength
                    else { continue }

                    let color = PlatformTypeConverter.nsColor(
                        from: tokenType.color(from: syntaxColors)
                    )
                    result.addAttribute(.foregroundColor, value: color, range: range)
                }
            }
        } catch {
            return result
        }

        return result
    }
}
