import Foundation
import Testing
@testable import mkdnLib

@Suite("MarkdownVisitor - Math Detection")
struct MarkdownVisitorMathTests {
    // MARK: - Code Fence Detection

    @Test("Detects math code fence")
    func detectsMathCodeFence() {
        let markdown = """
        ```math
        E = mc^2
        ```
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        guard case let .mathBlock(code) = blocks.first?.block else {
            Issue.record("Expected a mathBlock, got \(blocks.first.debugDescription)")
            return
        }

        #expect(code == "E = mc^2")
    }

    @Test("Detects latex code fence")
    func detectsLatexCodeFence() {
        let markdown = """
        ```latex
        \\frac{a}{b}
        ```
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        guard case let .mathBlock(code) = blocks.first?.block else {
            Issue.record("Expected a mathBlock, got \(blocks.first.debugDescription)")
            return
        }

        #expect(code == "\\frac{a}{b}")
    }

    @Test("Detects tex code fence")
    func detectsTexCodeFence() {
        let markdown = """
        ```tex
        \\sqrt{x}
        ```
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        guard case let .mathBlock(code) = blocks.first?.block else {
            Issue.record("Expected a mathBlock, got \(blocks.first.debugDescription)")
            return
        }

        #expect(code == "\\sqrt{x}")
    }

    @Test("Case-insensitive code fence language detection")
    func caseInsensitiveCodeFence() {
        let markdown = """
        ```MATH
        x^2
        ```
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        guard case .mathBlock = blocks.first?.block else {
            Issue.record("Expected a mathBlock for uppercase MATH language")
            return
        }
    }

    @Test("Non-math code fence stays as codeBlock")
    func nonMathCodeFenceUnchanged() {
        let markdown = """
        ```swift
        let x = 1
        ```
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        guard case .codeBlock = blocks.first?.block else {
            Issue.record("Expected a codeBlock for swift language")
            return
        }
    }

    // MARK: - Standalone $$ Detection

    @Test("Detects standalone $$ as mathBlock")
    func detectsStandaloneDollarDollar() {
        let blocks = MarkdownRenderer.render(
            text: "$$E = mc^2$$",
            theme: .solarizedDark
        )

        guard case let .mathBlock(code) = blocks.first?.block else {
            Issue.record("Expected a mathBlock, got \(blocks.first.debugDescription)")
            return
        }

        #expect(code == "E = mc^2")
    }

    @Test("Detects standalone $$ with whitespace inside")
    func detectsStandaloneDollarDollarWithWhitespace() {
        let blocks = MarkdownRenderer.render(
            text: "$$  x + y  $$",
            theme: .solarizedDark
        )

        guard case let .mathBlock(code) = blocks.first?.block else {
            Issue.record("Expected a mathBlock")
            return
        }

        #expect(code == "x + y")
    }

    @Test("Does not detect $$ in mixed paragraph")
    func doesNotDetectDollarDollarInMixedParagraph() {
        let blocks = MarkdownRenderer.render(
            text: "The cost is $$5.00 and $$10.00",
            theme: .solarizedDark
        )

        guard case .paragraph = blocks.first?.block else {
            Issue.record("Expected a paragraph, not mathBlock")
            return
        }
    }

    @Test("Empty $$ produces no mathBlock")
    func emptyDollarDollarNoMath() {
        let blocks = MarkdownRenderer.render(
            text: "$$$$",
            theme: .solarizedDark
        )

        if case .mathBlock = blocks.first?.block {
            Issue.record("Should not produce mathBlock for empty $$$$")
        }
    }

    // MARK: - Inline $ Detection

    @Test("Detects inline $ math expression")
    func detectsInlineMath() {
        let blocks = MarkdownRenderer.render(
            text: "Given $x^2$ value",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph")
            return
        }

        let hasMath = text.runs.contains { run in
            text[run.range].mathExpression != nil
        }
        #expect(hasMath)
    }

    @Test("Inline math has correct LaTeX content")
    func inlineMathContent() {
        let blocks = MarkdownRenderer.render(
            text: "Value is $x^2$ here",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph")
            return
        }

        var foundLatex: String?
        for run in text.runs {
            if let latex = text[run.range].mathExpression {
                foundLatex = latex
                break
            }
        }

        #expect(foundLatex == "x^2")
    }

    @Test("Escaped $ is literal, not math delimiter")
    func escapedDollarIsLiteral() {
        let blocks = MarkdownRenderer.render(
            text: "Cost is \\$5 total",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph")
            return
        }

        let hasMath = text.runs.contains { run in
            text[run.range].mathExpression != nil
        }
        #expect(!hasMath)
    }

    @Test("Adjacent $$ not treated as inline math delimiter")
    func adjacentDollarDollarNotInline() {
        let blocks = MarkdownRenderer.render(
            text: "A $$ token in text",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph")
            return
        }

        let hasMath = text.runs.contains { run in
            text[run.range].mathExpression != nil
        }
        #expect(!hasMath)
    }

    @Test("Unclosed $ is literal text")
    func unclosedDollarIsLiteral() {
        let blocks = MarkdownRenderer.render(
            text: "Price is $5 with no closer",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph")
            return
        }

        let hasMath = text.runs.contains { run in
            text[run.range].mathExpression != nil
        }
        #expect(!hasMath)
    }

    @Test("Multiple inline math in one paragraph")
    func multipleInlineMath() {
        let blocks = MarkdownRenderer.render(
            text: "Given $x$ and $y$ then $z$",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph")
            return
        }

        var mathCount = 0
        for run in text.runs where text[run.range].mathExpression != nil {
            mathCount += 1
        }

        #expect(mathCount == 3)
    }

    @Test("$ followed by whitespace is not a math delimiter")
    func dollarFollowedByWhitespace() {
        let blocks = MarkdownRenderer.render(
            text: "Pay $ 5 for the item",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph")
            return
        }

        let hasMath = text.runs.contains { run in
            text[run.range].mathExpression != nil
        }
        #expect(!hasMath)
    }

    @Test("Whitespace before closing $ is not a delimiter")
    func whitespaceBeforeClosingDollar() {
        let blocks = MarkdownRenderer.render(
            text: "Test $value $ end",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph")
            return
        }

        let hasMath = text.runs.contains { run in
            text[run.range].mathExpression != nil
        }
        #expect(!hasMath)
    }

    @Test("Math block ID uses stable hash")
    func mathBlockIdStability() {
        let block1 = MarkdownBlock.mathBlock(code: "E = mc^2")
        let block2 = MarkdownBlock.mathBlock(code: "E = mc^2")
        #expect(block1.id == block2.id)
    }

    @Test("Different math blocks have different IDs")
    func differentMathBlockIds() {
        let block1 = MarkdownBlock.mathBlock(code: "x^2")
        let block2 = MarkdownBlock.mathBlock(code: "y^2")
        #expect(block1.id != block2.id)
    }
}
