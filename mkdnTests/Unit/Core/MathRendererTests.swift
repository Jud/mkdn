import AppKit
import Testing
@testable import mkdnLib

@Suite("MathRenderer")
struct MathRendererTests {
    @Test("Renders simple expression to non-nil image")
    func rendersSimpleExpression() throws {
        let result = MathRenderer.renderToImage(
            latex: "x^2",
            fontSize: 16,
            textColor: .black
        )

        #expect(result != nil)
        #expect(try #require(result?.image.size.width) > 0)
        #expect(try #require(result?.image.size.height) > 0)
    }

    @Test("Returns nil for invalid LaTeX")
    func returnsNilForInvalidLatex() {
        let result = MathRenderer.renderToImage(
            latex: "\\invalidcommandthatdoesnotexist",
            fontSize: 16,
            textColor: .black
        )

        #expect(result == nil)
    }

    @Test("Returns nil for empty input")
    func returnsNilForEmptyInput() {
        let result = MathRenderer.renderToImage(
            latex: "",
            fontSize: 16,
            textColor: .black
        )

        #expect(result == nil)
    }

    @Test("Returns nil for whitespace-only input")
    func returnsNilForWhitespaceOnly() {
        let result = MathRenderer.renderToImage(
            latex: "   \n  ",
            fontSize: 16,
            textColor: .black
        )

        #expect(result == nil)
    }

    @Test("Reports baseline for expressions with descenders")
    func reportsBaseline() throws {
        let result = MathRenderer.renderToImage(
            latex: "\\frac{a}{b}",
            fontSize: 16,
            textColor: .black
        )

        #expect(result != nil)
        #expect(try #require(result?.baseline) > 0)
    }

    @Test("Display mode produces different size than text mode")
    func displayModeSize() throws {
        let displayResult = MathRenderer.renderToImage(
            latex: "\\sum_{i=1}^{n} i",
            fontSize: 16,
            textColor: .black,
            displayMode: true
        )

        let textResult = MathRenderer.renderToImage(
            latex: "\\sum_{i=1}^{n} i",
            fontSize: 16,
            textColor: .black,
            displayMode: false
        )

        #expect(displayResult != nil)
        #expect(textResult != nil)

        let displayHeight = try #require(displayResult?.image.size.height)
        let textHeight = try #require(textResult?.image.size.height)

        #expect(displayHeight != textHeight)
    }

    @Test("Renders common LaTeX expressions without failure")
    func rendersCommonExpressions() {
        let expressions = [
            "E = mc^2",
            "\\alpha + \\beta = \\gamma",
            "\\frac{1}{2}",
            "\\sqrt{x}",
            "x \\leq y",
            "\\int_0^1 f(x)\\,dx",
        ]

        for latex in expressions {
            let result = MathRenderer.renderToImage(
                latex: latex,
                fontSize: 16,
                textColor: .black
            )
            #expect(result != nil, "Expected successful render for: \(latex)")
        }
    }
}
