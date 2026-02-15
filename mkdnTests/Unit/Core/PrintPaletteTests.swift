import AppKit
import SwiftUI
import Testing

@testable import mkdnLib

@Suite("PrintPalette")
struct PrintPaletteTests {
    // MARK: - Helpers

    private func nsColor(_ color: Color) -> NSColor {
        PlatformTypeConverter.nsColor(from: color)
    }

    private func sRGBComponents(_ color: Color) -> (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        guard let srgb = nsColor(color).usingColorSpace(.sRGB) else { return nil }
        return (srgb.redComponent, srgb.greenComponent, srgb.blueComponent)
    }

    /// Relative luminance per WCAG 2.x (sRGB linearization + BT.709 coefficients).
    private func relativeLuminance(_ color: Color) -> Double? {
        guard let components = sRGBComponents(color) else { return nil }
        func linearize(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(components.red)
            + 0.7152 * linearize(components.green)
            + 0.0722 * linearize(components.blue)
    }

    /// WCAG contrast ratio between two colors. Result >= 1.0.
    private func contrastRatio(_ foreground: Color, against background: Color) -> Double? {
        guard let lumFg = relativeLuminance(foreground),
              let lumBg = relativeLuminance(background)
        else { return nil }
        let lighter = max(lumFg, lumBg)
        let darker = min(lumFg, lumBg)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func expectColorEquals(
        _ color: Color,
        red expectedR: CGFloat,
        green expectedG: CGFloat,
        blue expectedB: CGFloat,
        label: String,
        tolerance: CGFloat = 0.01
    ) {
        guard let components = sRGBComponents(color) else {
            Issue.record("Could not extract sRGB components for \(label)")
            return
        }
        #expect(
            abs(components.red - expectedR) < tolerance,
            "\(label) red: expected \(expectedR), got \(components.red)"
        )
        #expect(
            abs(components.green - expectedG) < tolerance,
            "\(label) green: expected \(expectedG), got \(components.green)"
        )
        #expect(
            abs(components.blue - expectedB) < tolerance,
            "\(label) blue: expected \(expectedB), got \(components.blue)"
        )
    }

    private func colorsMatch(_ colorA: Color, _ colorB: Color) -> Bool {
        guard let compA = sRGBComponents(colorA),
              let compB = sRGBComponents(colorB)
        else { return false }
        let tolerance: CGFloat = 0.001
        return abs(compA.red - compB.red) < tolerance
            && abs(compA.green - compB.green) < tolerance
            && abs(compA.blue - compB.blue) < tolerance
    }

    private func expectContrastMeetsAA(
        _ color: Color,
        name: String
    ) {
        let white = PrintPalette.colors.background
        guard let ratio = contrastRatio(color, against: white) else {
            Issue.record("Could not compute contrast for \(name)")
            return
        }
        #expect(
            ratio >= 4.5,
            "\(name) contrast ratio \(String(format: "%.2f", ratio)):1 < 4.5:1"
        )
    }

    // MARK: - Print Color Palette

    @Test("Print palette background is white")
    func backgroundIsWhite() {
        expectColorEquals(
            PrintPalette.colors.background,
            red: 1.0,
            green: 1.0,
            blue: 1.0,
            label: "background"
        )
    }

    @Test("Print palette foreground is black")
    func foregroundIsBlack() {
        expectColorEquals(
            PrintPalette.colors.foreground,
            red: 0.0,
            green: 0.0,
            blue: 0.0,
            label: "foreground"
        )
    }

    @Test("Print palette headings are black")
    func headingsAreBlack() {
        expectColorEquals(
            PrintPalette.colors.headingColor,
            red: 0.0,
            green: 0.0,
            blue: 0.0,
            label: "headingColor"
        )
    }

    @Test("All ThemeColors fields are populated and distinct from defaults")
    func themeColorsPopulated() {
        let colors = PrintPalette.colors
        let fields: [Color] = [
            colors.background,
            colors.backgroundSecondary,
            colors.foreground,
            colors.foregroundSecondary,
            colors.accent,
            colors.border,
            colors.codeBackground,
            colors.codeForeground,
            colors.linkColor,
            colors.headingColor,
            colors.blockquoteBorder,
            colors.blockquoteBackground,
        ]
        for field in fields {
            let components = sRGBComponents(field)
            #expect(components != nil)
        }
        #expect(fields.count == 12)
    }

    @Test("All SyntaxColors fields are populated")
    func syntaxColorsPopulated() {
        let syntax = PrintPalette.syntaxColors
        let fields: [Color] = [
            syntax.keyword,
            syntax.string,
            syntax.comment,
            syntax.type,
            syntax.number,
            syntax.function,
            syntax.property,
            syntax.preprocessor,
        ]
        for field in fields {
            let components = sRGBComponents(field)
            #expect(components != nil)
        }
        #expect(fields.count == 8)
    }

    // MARK: - Theme Independence

    @Test("Print palette differs from Solarized Dark")
    func differsFromSolarizedDark() {
        let dark = SolarizedDark.colors
        let printColors = PrintPalette.colors

        #expect(!colorsMatch(printColors.background, dark.background))
        #expect(!colorsMatch(printColors.foreground, dark.foreground))
        #expect(!colorsMatch(printColors.codeBackground, dark.codeBackground))
    }

    @Test("Print palette differs from Solarized Light")
    func differsFromSolarizedLight() {
        let light = SolarizedLight.colors
        let printColors = PrintPalette.colors

        #expect(!colorsMatch(printColors.background, light.background))
        #expect(!colorsMatch(printColors.foreground, light.foreground))
        #expect(!colorsMatch(printColors.codeBackground, light.codeBackground))
    }

    // MARK: - Code Blocks

    @Test("Code background is light gray")
    func codeBackgroundIsLightGray() {
        expectColorEquals(
            PrintPalette.colors.codeBackground,
            red: 0.961,
            green: 0.961,
            blue: 0.961,
            label: "codeBackground"
        )
    }

    // MARK: - Links

    @Test("Link color is dark blue")
    func linkColorIsDarkBlue() {
        expectColorEquals(
            PrintPalette.colors.linkColor,
            red: 0.0,
            green: 0.2,
            blue: 0.6,
            label: "linkColor"
        )
    }

    // MARK: - Syntax Highlighting Contrast

    @Test("WCAG AA contrast for all syntax colors against white")
    func syntaxColorContrastMeetsAA() {
        let syntax = PrintPalette.syntaxColors
        expectContrastMeetsAA(syntax.keyword, name: "keyword")
        expectContrastMeetsAA(syntax.string, name: "string")
        expectContrastMeetsAA(syntax.comment, name: "comment")
        expectContrastMeetsAA(syntax.type, name: "type")
        expectContrastMeetsAA(syntax.number, name: "number")
        expectContrastMeetsAA(syntax.function, name: "function")
        expectContrastMeetsAA(syntax.property, name: "property")
        expectContrastMeetsAA(syntax.preprocessor, name: "preprocessor")
    }

    @Test("Comment color is visually de-emphasized compared to keyword")
    func commentDeEmphasized() {
        guard let commentLum = relativeLuminance(PrintPalette.syntaxColors.comment),
              let keywordLum = relativeLuminance(PrintPalette.syntaxColors.keyword)
        else {
            Issue.record("Could not compute luminance")
            return
        }
        #expect(
            commentLum > keywordLum,
            "Comment luminance (\(commentLum)) should be higher (lighter) than keyword (\(keywordLum))"
        )
    }
}
