import AppKit
import SwiftUI
import Testing
@testable import mkdnLib

@Suite("PlatformTypeConverter")
struct PlatformTypeConverterTests {
    // MARK: - Heading Font Sizes

    @Test(
        "Heading font size matches design spec",
        arguments: [
            (1, CGFloat(28)),
            (2, CGFloat(24)),
            (3, CGFloat(20)),
            (4, CGFloat(18)),
            (5, CGFloat(16)),
            (6, CGFloat(14)),
        ]
    )
    func headingFontSize(level: Int, expectedSize: CGFloat) {
        let font = PlatformTypeConverter.headingFont(level: level)
        #expect(font.pointSize == expectedSize)
    }

    // MARK: - Heading Font Weights

    @Test("H1 and H2 use bold weight")
    func headingBoldWeight() {
        for level in 1 ... 2 {
            let font = PlatformTypeConverter.headingFont(level: level)
            let traits = NSFontManager.shared.traits(of: font)
            #expect(traits.contains(.boldFontMask))
        }
    }

    @Test("H3 and H4 use semibold weight")
    func headingSemiboldWeight() {
        for level in 3 ... 4 {
            let font = PlatformTypeConverter.headingFont(level: level)
            let weight = NSFontManager.shared.weight(of: font)
            #expect(weight >= 8)
        }
    }

    @Test("H5 and H6 use medium weight")
    func headingMediumWeight() {
        for level in 5 ... 6 {
            let font = PlatformTypeConverter.headingFont(level: level)
            let weight = NSFontManager.shared.weight(of: font)
            #expect(weight >= 6)
        }
    }

    @Test("Out-of-range heading level falls back to H6 spec")
    func headingOutOfRange() {
        let font = PlatformTypeConverter.headingFont(level: 7)
        #expect(font.pointSize == 14)
    }

    // MARK: - Body Font

    @Test("Body font matches system body text style")
    func bodyFontMatchesSystem() {
        let font = PlatformTypeConverter.bodyFont()
        let expected = NSFont.preferredFont(forTextStyle: .body)
        #expect(font.pointSize == expected.pointSize)
        #expect(font.familyName == expected.familyName)
    }

    // MARK: - Monospaced Fonts

    @Test("Monospaced font uses system font size")
    func monospacedFontSize() {
        let font = PlatformTypeConverter.monospacedFont()
        #expect(font.pointSize == NSFont.systemFontSize)
    }

    @Test("Monospaced font has fixed-pitch trait")
    func monospacedFontIsFixedPitch() {
        let font = PlatformTypeConverter.monospacedFont()
        let traits = NSFontManager.shared.traits(of: font)
        #expect(traits.contains(.fixedPitchFontMask))
    }

    @Test("Caption monospaced font uses small system font size")
    func captionMonospacedFontSize() {
        let font = PlatformTypeConverter.captionMonospacedFont()
        #expect(font.pointSize == NSFont.smallSystemFontSize)
    }

    @Test("Caption monospaced font has fixed-pitch trait")
    func captionMonospacedIsFixedPitch() {
        let font = PlatformTypeConverter.captionMonospacedFont()
        let traits = NSFontManager.shared.traits(of: font)
        #expect(traits.contains(.fixedPitchFontMask))
    }

    // MARK: - Color Conversion

    @Test("Color conversion produces non-nil NSColor for theme colors")
    func colorConversionProducesNSColor() {
        let colors = AppTheme.solarizedDark.colors
        let nsColor = PlatformTypeConverter.nsColor(from: colors.foreground)
        #expect(nsColor.colorSpace.colorSpaceModel != .unknown)
    }

    @Test("Different theme colors produce different NSColors")
    func differentColorsProduceDifferentNSColors() {
        let colors = AppTheme.solarizedDark.colors
        let fg = PlatformTypeConverter.nsColor(from: colors.foreground)
        let bg = PlatformTypeConverter.nsColor(from: colors.background)
        #expect(fg != bg)
    }

    // MARK: - Paragraph Style

    @Test("Paragraph style applies line spacing")
    func paragraphStyleLineSpacing() {
        let style = PlatformTypeConverter.paragraphStyle(
            lineSpacing: 6,
            paragraphSpacing: 0
        )
        #expect(style.lineSpacing == 6)
    }

    @Test("Paragraph style applies paragraph spacing")
    func paragraphStyleParagraphSpacing() {
        let style = PlatformTypeConverter.paragraphStyle(
            lineSpacing: 0,
            paragraphSpacing: 12
        )
        #expect(style.paragraphSpacing == 12)
    }

    @Test("Paragraph style applies alignment")
    func paragraphStyleAlignment() {
        let style = PlatformTypeConverter.paragraphStyle(
            alignment: .center
        )
        #expect(style.alignment == .center)
    }

    @Test("Paragraph style defaults to left alignment")
    func paragraphStyleDefaultAlignment() {
        let style = PlatformTypeConverter.paragraphStyle()
        #expect(style.alignment == .left)
    }
}
