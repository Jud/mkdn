import AppKit
import Testing
@testable import mkdnLib

@Suite("MarkdownTextStorageBuilder - Math")
struct MarkdownTextStorageBuilderMathTests {
    let theme: AppTheme = .solarizedDark

    private func buildSingle(
        _ block: MarkdownBlock,
        isPrint: Bool = false
    ) -> TextStorageResult {
        let indexed = IndexedBlock(index: 0, block: block)
        return MarkdownTextStorageBuilder.build(
            blocks: [indexed], theme: theme, isPrint: isPrint
        )
    }

    // MARK: - Math Block (Screen Mode)

    @Test("Math block produces attachment in screen mode")
    func mathBlockProducesAttachment() {
        let result = buildSingle(.mathBlock(code: "E = mc^2"))
        #expect(!result.attachments.isEmpty)
        #expect(result.attachments[0].blockIndex == 0)
    }

    @Test("Math block attachment has placeholder height")
    func mathBlockAttachmentHeight() {
        let result = buildSingle(.mathBlock(code: "x^2"))
        let attachment = result.attachments.first?.attachment
        #expect(attachment?.bounds.height == MarkdownTextStorageBuilder.attachmentPlaceholderHeight)
    }

    @Test("Math block attachment block is mathBlock")
    func mathBlockAttachmentBlockType() {
        let result = buildSingle(.mathBlock(code: "x^2"))
        guard case .mathBlock = result.attachments.first?.block else {
            Issue.record("Expected mathBlock in attachment info")
            return
        }
    }

    // MARK: - Math Block (Print Mode)

    @Test("Math block print produces inline content, not attachment")
    func mathBlockPrintProducesInlineContent() {
        let result = buildSingle(.mathBlock(code: "E = mc^2"), isPrint: true)
        #expect(result.attachments.isEmpty)
        #expect(result.attributedString.length > 0)
    }

    @Test("Math block print has centered paragraph style")
    func mathBlockPrintCentered() {
        let result = buildSingle(.mathBlock(code: "x^2"), isPrint: true)
        let attrs = result.attributedString.attributes(at: 0, effectiveRange: nil)
        let style = attrs[.paragraphStyle] as? NSParagraphStyle
        #expect(style?.alignment == .center)
    }

    @Test("Math block print fallback uses monospaced font")
    func mathBlockPrintFallbackMonospace() {
        let result = buildSingle(
            .mathBlock(code: "\\invalidcommandthatdoesnotexist"),
            isPrint: true
        )
        let attrs = result.attributedString.attributes(at: 0, effectiveRange: nil)
        guard let font = attrs[.font] as? NSFont else {
            Issue.record("Expected NSFont attribute on fallback text")
            return
        }
        let traits = NSFontManager.shared.traits(of: font)
        #expect(traits.contains(.fixedPitchFontMask))
    }

    // MARK: - Inline Math

    @Test("Inline math produces NSTextAttachment in attributed string")
    func inlineMathProducesAttachment() {
        var text = AttributedString("x^2")
        text.mathExpression = "x^2"
        let result = buildSingle(.paragraph(text: text))
        let str = result.attributedString

        var hasAttachment = false
        str.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: str.length)
        ) { value, _, _ in
            if value is NSTextAttachment {
                hasAttachment = true
            }
        }
        #expect(hasAttachment)
    }

    @Test("Inline math fallback uses monospaced font for invalid LaTeX")
    func inlineMathFallbackMonospace() {
        var text = AttributedString("\\invalidcommandthatdoesnotexist")
        text.mathExpression = "\\invalidcommandthatdoesnotexist"
        let result = buildSingle(.paragraph(text: text))
        let str = result.attributedString

        var hasMonospace = false
        str.enumerateAttribute(
            .font,
            in: NSRange(location: 0, length: str.length)
        ) { value, _, _ in
            if let font = value as? NSFont {
                let traits = NSFontManager.shared.traits(of: font)
                if traits.contains(.fixedPitchFontMask) {
                    hasMonospace = true
                }
            }
        }
        #expect(hasMonospace)
    }

    @Test("Inline math fallback uses reduced alpha foreground color")
    func inlineMathFallbackColor() throws {
        var text = AttributedString("\\invalidcommandthatdoesnotexist")
        text.mathExpression = "\\invalidcommandthatdoesnotexist"
        let result = buildSingle(.paragraph(text: text))
        let str = result.attributedString

        var foundAlpha: CGFloat?
        str.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: str.length)
        ) { value, _, stop in
            if let color = value as? NSColor {
                let alpha = color.alphaComponent
                if alpha < 1.0, alpha > 0 {
                    foundAlpha = alpha
                    stop.pointee = true
                }
            }
        }
        #expect(foundAlpha != nil)
        #expect(try #require(foundAlpha) < 1.0)
    }

    // MARK: - Plain Text Extraction

    @Test("plainText extracts math block code")
    func plainTextMathBlock() {
        let text = MarkdownTextStorageBuilder.plainText(
            from: .mathBlock(code: "E = mc^2")
        )
        #expect(text == "E = mc^2")
    }

    // MARK: - Multi-Block Integration

    @Test("Math block in multi-block produces attachment without text contribution")
    func mathBlockInMultiBlock() {
        let blocks = [
            IndexedBlock(index: 0, block: .paragraph(text: AttributedString("Above"))),
            IndexedBlock(index: 1, block: .mathBlock(code: "x^2")),
            IndexedBlock(index: 2, block: .paragraph(text: AttributedString("Below"))),
        ]
        let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: theme)
        let plainText = result.attributedString.string

        #expect(plainText.contains("Above"))
        #expect(plainText.contains("Below"))
        #expect(!plainText.contains("x^2"))
        #expect(result.attachments.count == 1)
    }
}
