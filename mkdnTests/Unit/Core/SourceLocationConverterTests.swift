import Foundation
import Markdown
import Testing
@testable import mkdnLib

@Suite("SourceLocationConverter")
struct SourceLocationConverterTests {
    @Test("Maps line/column on a plain ASCII document")
    func asciiLineColumn() {
        let source = "hello\nworld"
        let converter = SourceLocationConverter(source: source)

        let start = converter.index(line: 1, column: 1)
        #expect(start == source.startIndex)

        let secondLine = try! #require(converter.index(line: 2, column: 1))
        #expect(source[secondLine...] == "world")

        let midSecond = try! #require(converter.index(line: 2, column: 3))
        #expect(source[midSecond...] == "rld")
    }

    @Test("Column counts UTF-8 bytes, not characters")
    func multiByteColumn() {
        // "é" is 2 UTF-8 bytes, so the "l" after "hé" sits at byte column 4.
        let source = "héllo"
        let converter = SourceLocationConverter(source: source)

        let afterAccent = try! #require(converter.index(line: 1, column: 4))
        #expect(source[afterAccent...] == "llo")
    }

    @Test("Handles emoji (4-byte scalar)")
    func emojiColumn() {
        // "😀" is 4 UTF-8 bytes; "b" follows at byte column 6 (a=1 byte, 😀=4 bytes).
        let source = "a😀b"
        let converter = SourceLocationConverter(source: source)

        let afterEmoji = try! #require(converter.index(line: 1, column: 6))
        #expect(source[afterEmoji...] == "b")
    }

    @Test("Returns nil for a column inside a multi-byte scalar")
    func midScalarReturnsNil() {
        let source = "a😀b" // bytes: a | f0 9f 98 80 | b
        let converter = SourceLocationConverter(source: source)

        // Column 3 lands inside the emoji's UTF-8 bytes — not a Character boundary.
        #expect(converter.index(line: 1, column: 3) == nil)
    }

    @Test("Returns nil between a base character and its combining mark")
    func combiningMarkReturnsNil() {
        // "e" + combining acute accent form a single Character but two scalars.
        let source = "e\u{0301}x"
        let converter = SourceLocationConverter(source: source)

        // After "e" (1 byte) sits the combining mark (2 bytes); column 2 is
        // mid-grapheme and must not resolve to a Character boundary.
        #expect(converter.index(line: 1, column: 2) == nil)
    }

    @Test("CRLF line endings start the next line after the newline")
    func crlfLineStarts() {
        let source = "a\r\nb"
        let converter = SourceLocationConverter(source: source)

        let secondLine = try! #require(converter.index(line: 2, column: 1))
        #expect(source[secondLine...] == "b")
    }

    @Test("Out-of-bounds line or column returns nil")
    func outOfBounds() {
        let source = "abc"
        let converter = SourceLocationConverter(source: source)

        #expect(converter.index(line: 0, column: 1) == nil)
        #expect(converter.index(line: 5, column: 1) == nil)
        #expect(converter.index(line: 1, column: 0) == nil)
        #expect(converter.index(line: 1, column: 100) == nil)
    }

    @Test("Resolves a real swift-markdown InlineCode SourceRange")
    func resolvesAstSourceRange() {
        let source = "before `code` after"
        let document = Document(parsing: source, options: [])
        let converter = SourceLocationConverter(source: source)

        var found: Range<String.Index>?
        for node in document.inlineCodeNodes() {
            if let sourceRange = node.range {
                found = converter.range(for: sourceRange)
            }
        }
        let range = try! #require(found)
        #expect(source[range] == "`code`")
    }
}

private extension Markup {
    /// Depth-first collection of inline code descendants, for tests.
    func inlineCodeNodes() -> [InlineCode] {
        var result: [InlineCode] = []
        if let code = self as? InlineCode { result.append(code) }
        for child in children { result.append(contentsOf: child.inlineCodeNodes()) }
        return result
    }
}
