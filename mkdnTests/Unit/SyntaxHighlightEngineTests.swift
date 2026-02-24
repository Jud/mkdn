import AppKit
import Testing
@testable import mkdnLib

@Suite("SyntaxHighlightEngine")
struct SyntaxHighlightEngineTests {
    private let syntaxColors = SolarizedDark.syntaxColors

    // MARK: - Language Coverage

    @Test(
        "All 16 supported languages produce non-nil highlighted result",
        arguments: [
            ("swift", "func greet() { let x = 1 }"),
            ("python", "def greet():\n    return 'hello'"),
            ("javascript", "function greet() { return 'hello'; }"),
            ("typescript", "function greet(): string { return 'hello'; }"),
            ("rust", "fn main() { let x: i32 = 42; }"),
            ("go", "func main() { x := 42 }"),
            ("bash", "echo \"hello\" && exit 0"),
            ("json", "{\"key\": \"value\", \"num\": 42}"),
            ("yaml", "key: value\nlist:\n  - item"),
            ("html", "<div class=\"test\">hello</div>"),
            ("css", "body { color: red; font-size: 14px; }"),
            ("c", "int main() { return 0; }"),
            ("c++", "int main() { std::cout << 42; }"),
            ("ruby", "def greet\n  puts 'hello'\nend"),
            ("java", "public class Main { public static void main(String[] args) {} }"),
            ("kotlin", "fun main() { val x = 42 }"),
        ]
    )
    func allLanguagesProduceResult(language: String, code: String) {
        let result = SyntaxHighlightEngine.highlight(
            code: code,
            language: language,
            syntaxColors: syntaxColors
        )
        #expect(result != nil, "Expected non-nil result for language '\(language)'")
    }

    // MARK: - Unsupported Languages

    @Test("Unsupported language returns nil")
    func unsupportedLanguageReturnsNil() {
        let result = SyntaxHighlightEngine.highlight(
            code: "some code",
            language: "elixir",
            syntaxColors: syntaxColors
        )
        #expect(result == nil)
    }

    @Test("Empty language string returns nil")
    func emptyLanguageReturnsNil() {
        let result = SyntaxHighlightEngine.highlight(
            code: "some code",
            language: "",
            syntaxColors: syntaxColors
        )
        #expect(result == nil)
    }

    // MARK: - Text Preservation

    @Test("Result string content matches input code")
    func resultPreservesTextContent() {
        let code = "func greet() -> String {\n    return \"hello\"\n}"
        let result = SyntaxHighlightEngine.highlight(
            code: code,
            language: "swift",
            syntaxColors: syntaxColors
        )

        #expect(result != nil)
        #expect(result?.string == code)
    }

    @Test(
        "Text preservation holds for all languages",
        arguments: [
            ("python", "def greet():\n    x = 42\n    return x"),
            ("javascript", "const x = () => { return 42; };"),
            ("json", "{\"a\": [1, 2, 3]}"),
        ]
    )
    func textPreservationAcrossLanguages(language: String, code: String) {
        let result = SyntaxHighlightEngine.highlight(
            code: code,
            language: language,
            syntaxColors: syntaxColors
        )
        #expect(result?.string == code)
    }

    // MARK: - Multiple Foreground Colors

    @Test("Result contains multiple distinct foreground colors for code with mixed tokens")
    func resultContainsMultipleForegroundColors() {
        let code = "func greet() -> String {\n    // comment\n    return \"hello\"\n}"
        let result = SyntaxHighlightEngine.highlight(
            code: code,
            language: "swift",
            syntaxColors: syntaxColors
        )

        guard let attrString = result else {
            Issue.record("Expected non-nil result for Swift code")
            return
        }

        var colors = Set<NSColor>()
        attrString.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: attrString.length)
        ) { value, _, _ in
            if let color = value as? NSColor {
                colors.insert(color)
            }
        }

        #expect(
            colors.count > 1,
            "Expected multiple foreground colors but found \(colors.count)"
        )
    }

    @Test("Python code with mixed tokens produces multiple colors")
    func pythonMixedTokensMultipleColors() {
        let code = "# comment\ndef greet(name):\n    return 'hello ' + name"
        let result = SyntaxHighlightEngine.highlight(
            code: code,
            language: "python",
            syntaxColors: syntaxColors
        )

        guard let attrString = result else {
            Issue.record("Expected non-nil result for Python code")
            return
        }

        var colors = Set<NSColor>()
        attrString.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: attrString.length)
        ) { value, _, _ in
            if let color = value as? NSColor {
                colors.insert(color)
            }
        }

        #expect(
            colors.count > 1,
            "Expected multiple foreground colors for Python but found \(colors.count)"
        )
    }

    // MARK: - Keyword Color Verification

    @Test("Swift keyword 'func' receives keyword color")
    func swiftKeywordGetsKeywordColor() {
        let code = "func greet() { }"
        let result = SyntaxHighlightEngine.highlight(
            code: code,
            language: "swift",
            syntaxColors: syntaxColors
        )

        guard let attrString = result else {
            Issue.record("Expected non-nil result for Swift code")
            return
        }

        let expectedColor = PlatformTypeConverter.nsColor(from: syntaxColors.keyword)
        let funcRange = NSRange(location: 0, length: 4) // "func" is at start

        let actualColor = attrString.attribute(.foregroundColor, at: funcRange.location, effectiveRange: nil)
        #expect(
            actualColor as? NSColor == expectedColor,
            "Expected 'func' to have keyword color"
        )
    }

    @Test("Swift string literal receives string color")
    func swiftStringGetsStringColor() {
        let code = "let x = \"hello\""
        let result = SyntaxHighlightEngine.highlight(
            code: code,
            language: "swift",
            syntaxColors: syntaxColors
        )

        guard let attrString = result else {
            Issue.record("Expected non-nil result for Swift code")
            return
        }

        let expectedColor = PlatformTypeConverter.nsColor(from: syntaxColors.string)

        guard let quoteRange = code.range(of: "\"hello\"") else {
            Issue.record("Expected to find string literal in code")
            return
        }
        let nsRange = NSRange(quoteRange, in: code)
        let midpoint = nsRange.location + nsRange.length / 2

        let actualColor = attrString.attribute(.foregroundColor, at: midpoint, effectiveRange: nil)
        #expect(
            actualColor as? NSColor == expectedColor,
            "Expected string literal to have string color"
        )
    }
}

// MARK: - TokenType Mapping Tests

@Suite("TokenType")
struct TokenTypeTests {
    @Test(
        "Known capture names map to expected token types",
        arguments: [
            ("keyword", TokenType.keyword),
            ("keyword.control", TokenType.keyword),
            ("keyword.function", TokenType.keyword),
            ("string", TokenType.string),
            ("string.special", TokenType.string),
            ("comment", TokenType.comment),
            ("comment.line", TokenType.comment),
            ("type", TokenType.type),
            ("type.builtin", TokenType.type),
            ("number", TokenType.number),
            ("float", TokenType.number),
            ("function", TokenType.function),
            ("function.call", TokenType.function),
            ("method", TokenType.function),
            ("property", TokenType.property),
            ("field", TokenType.property),
            ("operator", TokenType.operator),
            ("variable", TokenType.variable),
            ("parameter", TokenType.variable),
            ("constant", TokenType.constant),
            ("boolean", TokenType.constant),
            ("attribute", TokenType.attribute),
            ("decorator", TokenType.attribute),
            ("punctuation", TokenType.punctuation),
            ("delimiter", TokenType.punctuation),
            ("constructor", TokenType.type),
            ("namespace", TokenType.type),
            ("module", TokenType.type),
            ("tag", TokenType.keyword),
            ("label", TokenType.keyword),
            ("preproc", TokenType.preprocessor),
            ("include", TokenType.preprocessor),
            ("conditional", TokenType.keyword),
            ("repeat", TokenType.keyword),
            ("exception", TokenType.keyword),
            ("character", TokenType.string),
            ("escape", TokenType.string),
        ]
    )
    func knownCaptureNameMapping(captureName: String, expected: TokenType) {
        let result = TokenType.from(captureName: captureName)
        #expect(result == expected, "Expected '\(captureName)' to map to \(expected)")
    }

    @Test("Unknown capture names return nil")
    func unknownCaptureNameReturnsNil() {
        #expect(TokenType.from(captureName: "unknown") == nil)
        #expect(TokenType.from(captureName: "spell") == nil)
        #expect(TokenType.from(captureName: "diagnostic") == nil)
        #expect(TokenType.from(captureName: "") == nil)
    }

    @Test("Subcategory capture names resolve via base prefix")
    func subcategoryResolvesViaBase() {
        #expect(TokenType.from(captureName: "keyword.operator") == .keyword)
        #expect(TokenType.from(captureName: "string.regex") == .string)
        #expect(TokenType.from(captureName: "comment.documentation") == .comment)
        #expect(TokenType.from(captureName: "variable.builtin") == .variable)
        #expect(TokenType.from(captureName: "punctuation.bracket") == .punctuation)
        #expect(TokenType.from(captureName: "type.qualifier") == .type)
    }
}
