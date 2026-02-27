import AppKit
import Testing
@testable import mkdnLib

@Suite("LineNumberGutterView")
struct LineNumberGutterTests {
    private func makeFont(size: CGFloat = 11) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    @Test("Single-digit line counts use minimum two-digit width")
    @MainActor func singleDigitUsesMinimumWidth() {
        let font = makeFont()
        let width1 = LineNumberGutterView.calculateThickness(lineCount: 1, font: font)
        let width9 = LineNumberGutterView.calculateThickness(lineCount: 9, font: font)
        let width10 = LineNumberGutterView.calculateThickness(lineCount: 10, font: font)
        #expect(width1 == width9)
        #expect(width1 == width10)
        #expect(width1 > 0)
    }

    @Test("Two-digit line counts produce stable width")
    @MainActor func twoDigitWidthIsStable() {
        let font = makeFont()
        let width10 = LineNumberGutterView.calculateThickness(lineCount: 10, font: font)
        let width50 = LineNumberGutterView.calculateThickness(lineCount: 50, font: font)
        let width99 = LineNumberGutterView.calculateThickness(lineCount: 99, font: font)
        #expect(width10 == width50)
        #expect(width50 == width99)
    }

    @Test("Width increases at three-digit boundary")
    @MainActor func threeDigitBoundary() {
        let font = makeFont()
        let width99 = LineNumberGutterView.calculateThickness(lineCount: 99, font: font)
        let width100 = LineNumberGutterView.calculateThickness(lineCount: 100, font: font)
        #expect(width100 > width99)
    }

    @Test("Width increases at four-digit boundary")
    @MainActor func fourDigitBoundary() {
        let font = makeFont()
        let width999 = LineNumberGutterView.calculateThickness(lineCount: 999, font: font)
        let width1000 = LineNumberGutterView.calculateThickness(lineCount: 1_000, font: font)
        #expect(width1000 > width999)
    }

    @Test("Width increases at five-digit boundary")
    @MainActor func fiveDigitBoundary() {
        let font = makeFont()
        let width9999 = LineNumberGutterView.calculateThickness(lineCount: 9_999, font: font)
        let width10000 = LineNumberGutterView.calculateThickness(lineCount: 10_000, font: font)
        #expect(width10000 > width9999)
    }

    @Test("Width monotonically increases across digit boundaries")
    @MainActor func monotonicIncrease() {
        let font = makeFont()
        let widths = [1, 10, 100, 1_000, 10_000].map { lineCount in
            LineNumberGutterView.calculateThickness(lineCount: lineCount, font: font)
        }
        #expect(widths[0] == widths[1])
        for i in 1 ..< widths.count - 1 {
            #expect(widths[i + 1] > widths[i])
        }
    }

    @Test("Width scales with font size")
    @MainActor func widthScalesWithFontSize() {
        let smallFont = makeFont(size: 10)
        let largeFont = makeFont(size: 20)
        let smallWidth = LineNumberGutterView.calculateThickness(
            lineCount: 100,
            font: smallFont
        )
        let largeWidth = LineNumberGutterView.calculateThickness(
            lineCount: 100,
            font: largeFont
        )
        #expect(largeWidth > smallWidth)
    }
}
