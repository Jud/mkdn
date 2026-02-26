import AppKit
import Testing
@testable import mkdnLib

extension MarkdownTextStorageBuilderTests {
    // MARK: - Print Palette Integration

    @Test("Build with explicit colors produces valid non-empty attributed string")
    @MainActor func buildWithExplicitColors() {
        let blocks = [
            IndexedBlock(index: 0, block: .heading(level: 1, text: AttributedString("Title"))),
            IndexedBlock(index: 1, block: .paragraph(text: AttributedString("Body text."))),
            IndexedBlock(index: 2, block: .codeBlock(language: "swift", code: "let x = 1")),
        ]
        let result = MarkdownTextStorageBuilder.build(
            blocks: blocks,
            colors: PrintPalette.colors,
            syntaxColors: PrintPalette.syntaxColors
        )
        #expect(result.attributedString.length > 0)
        let plainText = result.attributedString.string
        #expect(plainText.contains("Title"))
        #expect(plainText.contains("Body text."))
        #expect(plainText.contains("let x = 1"))
    }

    @Test("Build with theme delegates to build with explicit colors producing same content")
    @MainActor func buildThemeDelegatesToExplicitColors() {
        let blocks = [
            IndexedBlock(index: 0, block: .heading(level: 2, text: AttributedString("Section"))),
            IndexedBlock(index: 1, block: .paragraph(text: AttributedString("Paragraph."))),
        ]
        let themeResult = MarkdownTextStorageBuilder.build(blocks: blocks, theme: theme)
        let explicitResult = MarkdownTextStorageBuilder.build(
            blocks: blocks,
            colors: theme.colors,
            syntaxColors: theme.syntaxColors
        )

        #expect(themeResult.attributedString.string == explicitResult.attributedString.string)
        #expect(themeResult.attributedString.length == explicitResult.attributedString.length)
        #expect(themeResult.attachments.count == explicitResult.attachments.count)

        let themeAttrs = themeResult.attributedString.attributes(at: 0, effectiveRange: nil)
        let explicitAttrs = explicitResult.attributedString.attributes(at: 0, effectiveRange: nil)
        let themeFont = themeAttrs[.font] as? NSFont
        let explicitFont = explicitAttrs[.font] as? NSFont
        #expect(themeFont == explicitFont)
        let themeColor = themeAttrs[.foregroundColor] as? NSColor
        let explicitColor = explicitAttrs[.foregroundColor] as? NSColor
        #expect(themeColor == explicitColor)
    }

    @Test("Code block ColorInfo uses provided palette colors for background and border")
    @MainActor func codeBlockColorInfoUsesPrintPalette() {
        let block = IndexedBlock(
            index: 0,
            block: .codeBlock(language: nil, code: "print(42)")
        )
        let result = MarkdownTextStorageBuilder.build(
            blocks: [block],
            colors: PrintPalette.colors,
            syntaxColors: PrintPalette.syntaxColors
        )
        let str = result.attributedString
        var foundColorInfo: CodeBlockColorInfo?
        str.enumerateAttribute(
            CodeBlockAttributes.colors,
            in: NSRange(location: 0, length: str.length)
        ) { value, _, stop in
            if let info = value as? CodeBlockColorInfo {
                foundColorInfo = info
                stop.pointee = true
            }
        }

        #expect(foundColorInfo != nil)
        let expectedBg = PlatformTypeConverter.nsColor(from: PrintPalette.colors.codeBackground)
        let expectedBorder = PlatformTypeConverter.nsColor(from: PrintPalette.colors.border)
        #expect(foundColorInfo?.background == expectedBg)
        #expect(foundColorInfo?.border == expectedBorder)
    }
}
