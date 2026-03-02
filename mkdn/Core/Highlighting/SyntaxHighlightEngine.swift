#if os(macOS)
    import AppKit
#else
    import UIKit
#endif
import SwiftTreeSitter

/// Synchronous syntax highlighting engine using tree-sitter.
/// Query objects are cached per language to avoid recompilation.
@MainActor
public enum SyntaxHighlightEngine {
    private static var queryCache: [String: Query] = [:]

    /// Highlight code for a given language, returning a colored NSMutableAttributedString.
    /// Returns nil if the language is not supported (caller should fall back to plain text).
    public static func highlight(
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

        let plainColor = PlatformTypeConverter.color(from: syntaxColors.variable)
        let result = NSMutableAttributedString(
            string: code,
            attributes: [.foregroundColor: plainColor]
        )

        do {
            let query = try cachedQuery(for: language, config: config)
            applyCaptures(
                from: query.execute(in: tree),
                to: result,
                syntaxColors: syntaxColors
            )
        } catch {
            return result
        }

        return result
    }

    private static func cachedQuery(
        for language: String,
        config: LanguageConfig
    ) throws -> Query {
        if let cached = queryCache[language] { return cached }
        let query = try Query(
            language: config.language,
            data: Data(config.highlightQuery.utf8)
        )
        queryCache[language] = query
        return query
    }

    /// Resolves captures with pattern-index priority and applies colors.
    ///
    /// Later patterns (higher `patternIndex`) take priority over earlier ones
    /// for the same range, matching tree-sitter convention where more specific
    /// patterns appear later in the query file.
    private static func applyCaptures(
        from cursor: QueryCursor,
        to result: NSMutableAttributedString,
        syntaxColors: SyntaxColors
    ) {
        let resultLength = result.length
        var bestCapture: [NSRange: (patternIndex: Int, tokenType: TokenType)] = [:]

        for match in cursor {
            for capture in match.captures {
                guard let captureName = capture.name else { continue }
                guard let tokenType = TokenType.from(captureName: captureName) else { continue }

                let range = capture.range
                guard range.location >= 0,
                      range.location + range.length <= resultLength
                else { continue }

                let patternIndex = match.patternIndex
                if let existing = bestCapture[range], existing.patternIndex >= patternIndex {
                    continue
                }
                bestCapture[range] = (patternIndex, tokenType)
            }
        }

        for (range, entry) in bestCapture {
            let color = PlatformTypeConverter.color(
                from: entry.tokenType.color(from: syntaxColors)
            )
            result.addAttribute(.foregroundColor, value: color, range: range)
        }
    }
}
