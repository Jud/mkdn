import Testing
@testable import mkdnLib

@Suite("MarkdownRenderer")
struct MarkdownRendererTests {
    @Test("Parses a heading")
    func parsesHeading() {
        let blocks = MarkdownRenderer.render(text: "# Hello World", theme: .solarizedDark)

        #expect(!blocks.isEmpty)

        guard case let .heading(level, _) = blocks.first?.block else {
            Issue.record("Expected a heading block")
            return
        }

        #expect(level == 1)
    }

    @Test("Parses a paragraph")
    func parsesParagraph() {
        let blocks = MarkdownRenderer.render(text: "Just a paragraph.", theme: .solarizedDark)

        #expect(!blocks.isEmpty)

        guard case .paragraph = blocks.first?.block else {
            Issue.record("Expected a paragraph block")
            return
        }
    }

    @Test("Detects fenced code block")
    func parsesCodeBlock() {
        let markdown = """
        ```swift
        let x = 42
        ```
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        #expect(!blocks.isEmpty)

        guard case let .codeBlock(language, code) = blocks.first?.block else {
            Issue.record("Expected a code block")
            return
        }

        #expect(language == "swift")
        #expect(code.contains("42"))
    }

    @Test("Detects Mermaid code block")
    func parsesMermaidBlock() {
        let markdown = """
        ```mermaid
        graph TD
            A --> B
        ```
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        #expect(!blocks.isEmpty)

        guard case let .mermaidBlock(code) = blocks.first?.block else {
            Issue.record("Expected a mermaid block")
            return
        }

        #expect(code.contains("graph TD"))
    }

    @Test("Parses a blockquote")
    func parsesBlockquote() {
        let blocks = MarkdownRenderer.render(text: "> Quoted text", theme: .solarizedDark)

        #expect(!blocks.isEmpty)

        guard case let .blockquote(children) = blocks.first?.block else {
            Issue.record("Expected a blockquote block")
            return
        }

        #expect(!children.isEmpty)
    }

    @Test("Parses an unordered list")
    func parsesUnorderedList() {
        let markdown = """
        - Item one
        - Item two
        - Item three
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        #expect(!blocks.isEmpty)

        guard case let .unorderedList(items) = blocks.first?.block else {
            Issue.record("Expected an unordered list block")
            return
        }

        #expect(items.count == 3)
    }

    @Test("Parses an ordered list")
    func parsesOrderedList() {
        let markdown = """
        1. First
        2. Second
        3. Third
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        #expect(!blocks.isEmpty)

        guard case let .orderedList(items) = blocks.first?.block else {
            Issue.record("Expected an ordered list block")
            return
        }

        #expect(items.count == 3)
    }

    @Test("Parses a thematic break")
    func parsesThematicBreak() {
        let blocks = MarkdownRenderer.render(text: "---", theme: .solarizedDark)

        #expect(!blocks.isEmpty)

        guard case .thematicBreak = blocks.first?.block else {
            Issue.record("Expected a thematic break block")
            return
        }
    }

    @Test("Parses a table")
    func parsesTable() {
        let markdown = """
        | Name | Age |
        |------|-----|
        | Alice | 30 |
        | Bob | 25 |
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        #expect(!blocks.isEmpty)

        guard case let .table(columns, rows) = blocks.first?.block else {
            Issue.record("Expected a table block")
            return
        }

        #expect(columns.count == 2)
        #expect(rows.count == 2)
    }

    @Test("Renders multiple heading levels")
    func parsesMultipleHeadingLevels() {
        let markdown = """
        # H1
        ## H2
        ### H3
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        #expect(blocks.count == 3)

        for (index, expectedLevel) in [1, 2, 3].enumerated() {
            guard case let .heading(level, _) = blocks[index].block else {
                Issue.record("Expected heading at index \(index)")
                continue
            }
            #expect(level == expectedLevel)
        }
    }

    @Test("Handles empty input")
    func handlesEmptyInput() {
        let blocks = MarkdownRenderer.render(text: "", theme: .solarizedDark)
        #expect(blocks.isEmpty)
    }

    @Test("Multiple thematic breaks produce unique IDs")
    func multipleThematicBreaksUniqueIDs() {
        let markdown = "---\n\n---\n\n---"
        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)
        #expect(blocks.count == 3)
        let ids = Set(blocks.map(\.id))
        #expect(ids.count == 3)
    }
}
