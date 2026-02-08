import Splash
import SwiftUI
import Testing

@testable import mkdnLib

@Suite("ThemeOutputFormat")
struct ThemeOutputFormatTests {
    private let red: SwiftUI.Color = .red
    private let blue: SwiftUI.Color = .blue
    private let green: SwiftUI.Color = .green

    @Test("addToken applies correct color from tokenColorMap")
    func tokenColorApplied() {
        let format = ThemeOutputFormat(
            plainTextColor: red,
            tokenColorMap: [TokenType.keyword: blue]
        )
        var builder = format.makeBuilder()
        builder.addToken("let", ofType: TokenType.keyword)
        let result = builder.build()

        let runs = Array(result.runs)
        #expect(runs.count == 1)
        #expect(runs[0].foregroundColor == blue)
    }

    @Test("addToken with unmapped TokenType falls back to plainTextColor")
    func unmappedTokenFallback() {
        let format = ThemeOutputFormat(
            plainTextColor: red,
            tokenColorMap: [TokenType.keyword: blue]
        )
        var builder = format.makeBuilder()
        builder.addToken("42", ofType: TokenType.number)
        let result = builder.build()

        let runs = Array(result.runs)
        #expect(runs.count == 1)
        #expect(runs[0].foregroundColor == red)
    }

    @Test("addPlainText applies plainTextColor")
    func plainTextColor() {
        let format = ThemeOutputFormat(
            plainTextColor: green,
            tokenColorMap: [:]
        )
        var builder = format.makeBuilder()
        builder.addPlainText("hello")
        let result = builder.build()

        let runs = Array(result.runs)
        #expect(runs.count == 1)
        #expect(runs[0].foregroundColor == green)
    }

    @Test("addWhitespace applies plainTextColor as foreground color")
    func whitespaceHasForegroundColor() {
        let format = ThemeOutputFormat(
            plainTextColor: red,
            tokenColorMap: [:]
        )
        var builder = format.makeBuilder()
        builder.addWhitespace("  \n")
        let result = builder.build()

        #expect(String(result.characters) == "  \n")
        let runs = Array(result.runs)
        #expect(runs.count == 1)
        #expect(runs[0].foregroundColor == red)
    }

    @Test("build returns non-empty result after adding content")
    func buildReturnsContent() {
        let format = ThemeOutputFormat(
            plainTextColor: red,
            tokenColorMap: [TokenType.keyword: blue]
        )
        var builder = format.makeBuilder()
        builder.addToken("func", ofType: TokenType.keyword)
        builder.addWhitespace(" ")
        builder.addPlainText("main")
        let result = builder.build()

        #expect(String(result.characters) == "func main")
    }

    @Test("different color maps produce different AttributedString output")
    func differentColorMaps() {
        let formatA = ThemeOutputFormat(
            plainTextColor: red,
            tokenColorMap: [TokenType.keyword: blue]
        )
        let formatB = ThemeOutputFormat(
            plainTextColor: red,
            tokenColorMap: [TokenType.keyword: green]
        )

        var builderA = formatA.makeBuilder()
        builderA.addToken("let", ofType: TokenType.keyword)
        let resultA = builderA.build()

        var builderB = formatB.makeBuilder()
        builderB.addToken("let", ofType: TokenType.keyword)
        let resultB = builderB.build()

        let runsA = Array(resultA.runs)
        let runsB = Array(resultB.runs)
        #expect(runsA[0].foregroundColor != runsB[0].foregroundColor)
    }
}
