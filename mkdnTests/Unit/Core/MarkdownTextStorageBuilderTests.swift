import AppKit
import Testing

@testable import mkdnLib

@Suite("MarkdownTextStorageBuilder")
struct MarkdownTextStorageBuilderTests {
    let theme: AppTheme = .solarizedDark

    // MARK: - Helper

    private func buildSingle(_ block: MarkdownBlock) -> TextStorageResult {
        let indexed = IndexedBlock(index: 0, block: block)
        return MarkdownTextStorageBuilder.build(blocks: [indexed], theme: theme)
    }

    private func attributes(
        of result: TextStorageResult,
        at location: Int = 0
    ) -> [NSAttributedString.Key: Any] {
        result.attributedString.attributes(
            at: location,
            effectiveRange: nil
        )
    }

    // MARK: - Heading Block

    @Test("Heading uses correct font size for each level")
    func headingFontSize() {
        let expectedSizes: [(Int, CGFloat)] = [
            (1, 28), (2, 24), (3, 20), (4, 18), (5, 16), (6, 14),
        ]

        for (level, expectedSize) in expectedSizes {
            let result = buildSingle(.heading(level: level, text: AttributedString("Title")))
            let attrs = attributes(of: result)
            let font = attrs[.font] as? NSFont
            #expect(font?.pointSize == expectedSize)
        }
    }

    @Test("Heading uses heading color from theme")
    func headingColor() {
        let result = buildSingle(.heading(level: 1, text: AttributedString("Title")))
        let attrs = attributes(of: result)
        let color = attrs[.foregroundColor] as? NSColor
        let expected = PlatformTypeConverter.nsColor(from: theme.colors.headingColor)
        #expect(color == expected)
    }

    @Test("Heading has paragraph spacing")
    func headingParagraphSpacing() {
        let result = buildSingle(.heading(level: 1, text: AttributedString("Title")))
        let attrs = attributes(of: result)
        let style = attrs[.paragraphStyle] as? NSParagraphStyle
        #expect(style?.paragraphSpacing == MarkdownTextStorageBuilder.blockSpacing)
    }

    // MARK: - Paragraph Block

    @Test("Paragraph uses body font")
    func paragraphBodyFont() {
        let result = buildSingle(.paragraph(text: AttributedString("Hello world")))
        let attrs = attributes(of: result)
        let font = attrs[.font] as? NSFont
        let expected = PlatformTypeConverter.bodyFont()
        #expect(font?.pointSize == expected.pointSize)
    }

    @Test("Paragraph uses foreground color from theme")
    func paragraphForegroundColor() {
        let result = buildSingle(.paragraph(text: AttributedString("Hello world")))
        let attrs = attributes(of: result)
        let color = attrs[.foregroundColor] as? NSColor
        let expected = PlatformTypeConverter.nsColor(from: theme.colors.foreground)
        #expect(color == expected)
    }

    // MARK: - Code Block

    @Test("Code block uses monospaced font")
    func codeBlockMonospacedFont() {
        let result = buildSingle(.codeBlock(language: nil, code: "let x = 1"))
        let str = result.attributedString
        var found = false
        str.enumerateAttribute(
            .font,
            in: NSRange(location: 0, length: str.length)
        ) { value, _, _ in
            if let font = value as? NSFont {
                let traits = NSFontManager.shared.traits(of: font)
                if traits.contains(.fixedPitchFontMask) {
                    found = true
                }
            }
        }
        #expect(found)
    }

    @Test("Code block carries code block color info attribute")
    func codeBlockBackgroundColor() {
        let result = buildSingle(.codeBlock(language: nil, code: "let x = 1"))
        let str = result.attributedString
        var hasColorInfo = false
        str.enumerateAttribute(
            CodeBlockAttributes.colors,
            in: NSRange(location: 0, length: str.length)
        ) { value, _, _ in
            if value is CodeBlockColorInfo {
                hasColorInfo = true
            }
        }
        #expect(hasColorInfo)
    }

    @Test("Code block with language label includes label text")
    func codeBlockLanguageLabel() {
        let result = buildSingle(.codeBlock(language: "swift", code: "let x = 1"))
        let plainText = result.attributedString.string
        #expect(plainText.contains("swift"))
    }

    // MARK: - Mermaid Block

    @Test("Mermaid block produces NSTextAttachment")
    func mermaidBlockProducesAttachment() {
        let result = buildSingle(.mermaidBlock(code: "graph TD\nA --> B"))
        #expect(!result.attachments.isEmpty)
        #expect(result.attachments[0].blockIndex == 0)
    }

    @Test("Mermaid attachment has placeholder height")
    func mermaidAttachmentHeight() {
        let result = buildSingle(.mermaidBlock(code: "graph TD\nA --> B"))
        let attachment = result.attachments.first?.attachment
        #expect(attachment?.bounds.height == MarkdownTextStorageBuilder.attachmentPlaceholderHeight)
    }

    // MARK: - Image Block

    @Test("Image block produces NSTextAttachment")
    func imageBlockProducesAttachment() {
        let result = buildSingle(.image(source: "cat.png", alt: "A cat"))
        #expect(!result.attachments.isEmpty)
    }

    // MARK: - Thematic Break

    @Test("Thematic break produces NSTextAttachment")
    func thematicBreakProducesAttachment() {
        let result = buildSingle(.thematicBreak)
        #expect(!result.attachments.isEmpty)
    }

    @Test("Thematic break attachment has correct height")
    func thematicBreakHeight() {
        let result = buildSingle(.thematicBreak)
        let attachment = result.attachments.first?.attachment
        #expect(attachment?.bounds.height == MarkdownTextStorageBuilder.thematicBreakHeight)
    }

    // MARK: - Unordered List

    @Test("Unordered list includes bullet prefix")
    func unorderedListBulletPrefix() {
        let item = ListItem(blocks: [.paragraph(text: AttributedString("Item one"))])
        let result = buildSingle(.unorderedList(items: [item]))
        let plainText = result.attributedString.string
        let bullet = MarkdownTextStorageBuilder.bulletStyles[0]
        #expect(plainText.contains(bullet))
    }

    @Test("Unordered list items have indentation")
    func unorderedListIndentation() {
        let item = ListItem(blocks: [.paragraph(text: AttributedString("Item"))])
        let result = buildSingle(.unorderedList(items: [item]))
        let attrs = attributes(of: result)
        let style = attrs[.paragraphStyle] as? NSParagraphStyle
        #expect((style?.headIndent ?? 0) > 0)
    }

    // MARK: - Ordered List

    @Test("Ordered list includes number prefix")
    func orderedListNumberPrefix() {
        let item = ListItem(blocks: [.paragraph(text: AttributedString("First"))])
        let result = buildSingle(.orderedList(items: [item]))
        let plainText = result.attributedString.string
        #expect(plainText.contains("1."))
    }

    // MARK: - Blockquote

    @Test("Blockquote content has head indent")
    func blockquoteIndentation() {
        let result = buildSingle(.blockquote(blocks: [.paragraph(text: AttributedString("Quoted"))]))
        let attrs = attributes(of: result)
        let style = attrs[.paragraphStyle] as? NSParagraphStyle
        #expect((style?.headIndent ?? 0) >= MarkdownTextStorageBuilder.blockquoteIndent)
    }

    @Test("Blockquote content has first line head indent")
    func blockquoteFirstLineIndent() {
        let result = buildSingle(.blockquote(blocks: [.paragraph(text: AttributedString("Quoted"))]))
        let attrs = attributes(of: result)
        let style = attrs[.paragraphStyle] as? NSParagraphStyle
        #expect((style?.firstLineHeadIndent ?? 0) >= MarkdownTextStorageBuilder.blockquoteIndent)
    }

    // MARK: - HTML Block

    @Test("HTML block uses monospaced font")
    func htmlBlockMonospacedFont() {
        let result = buildSingle(.htmlBlock(content: "<div>hello</div>"))
        let attrs = attributes(of: result)
        guard let font = attrs[.font] as? NSFont else {
            Issue.record("Expected NSFont attribute on HTML block")
            return
        }
        let traits = NSFontManager.shared.traits(of: font)
        #expect(traits.contains(.fixedPitchFontMask))
    }

    @Test("HTML block has background color")
    func htmlBlockBackground() {
        let result = buildSingle(.htmlBlock(content: "<div>hello</div>"))
        let attrs = attributes(of: result)
        #expect(attrs[.backgroundColor] is NSColor)
    }

    // MARK: - Table

    @Test("Table produces NSTextAttachment for overlay rendering")
    func tableProducesAttachment() {
        let columns = [
            TableColumn(header: AttributedString("Name"), alignment: .left),
            TableColumn(header: AttributedString("Age"), alignment: .left),
        ]
        let rows: [[AttributedString]] = [
            [AttributedString("Alice"), AttributedString("30")],
        ]
        let result = buildSingle(.table(columns: columns, rows: rows))
        #expect(!result.attachments.isEmpty)
        #expect(result.attachments.first?.attachment.bounds.height ?? 0 > 0)
    }

    // MARK: - Block Separation

    @Test("Blocks are separated by single newline, not double")
    func blockSeparationSingleNewline() {
        let blocks = [
            IndexedBlock(index: 0, block: .paragraph(text: AttributedString("First"))),
            IndexedBlock(index: 1, block: .paragraph(text: AttributedString("Second"))),
        ]
        let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: theme)
        let plainText = result.attributedString.string
        #expect(!plainText.contains("\n\n\n"))
    }

    @Test("Each block ends with exactly one newline")
    func blockEndsWithNewline() {
        let result = buildSingle(.paragraph(text: AttributedString("Hello")))
        let plainText = result.attributedString.string
        #expect(plainText.hasSuffix("\n"))
        #expect(!plainText.hasSuffix("\n\n"))
    }

    // MARK: - Inline Styles

    @Test("Bold text preserves bold trait in NSAttributedString")
    func boldPreserved() {
        var text = AttributedString("bold text")
        text.inlinePresentationIntent = .stronglyEmphasized
        let result = buildSingle(.paragraph(text: text))
        let attrs = attributes(of: result)
        guard let font = attrs[.font] as? NSFont else {
            Issue.record("Expected NSFont attribute on bold text")
            return
        }
        let traits = NSFontManager.shared.traits(of: font)
        #expect(traits.contains(.boldFontMask))
    }

    @Test("Italic text preserves italic trait in NSAttributedString")
    func italicPreserved() {
        var text = AttributedString("italic text")
        text.inlinePresentationIntent = .emphasized
        let result = buildSingle(.paragraph(text: text))
        let attrs = attributes(of: result)
        guard let font = attrs[.font] as? NSFont else {
            Issue.record("Expected NSFont attribute on italic text")
            return
        }
        let traits = NSFontManager.shared.traits(of: font)
        #expect(traits.contains(.italicFontMask))
    }

    @Test("Inline code text uses monospaced font")
    func inlineCodePreserved() {
        var text = AttributedString("code")
        text.inlinePresentationIntent = .code
        let result = buildSingle(.paragraph(text: text))
        let attrs = attributes(of: result)
        guard let font = attrs[.font] as? NSFont else {
            Issue.record("Expected NSFont attribute on inline code")
            return
        }
        let traits = NSFontManager.shared.traits(of: font)
        #expect(traits.contains(.fixedPitchFontMask))
    }

    @Test("Link has URL and underline in NSAttributedString")
    func linkPreserved() {
        var text = AttributedString("click")
        text.link = URL(string: "https://example.com")
        let result = buildSingle(.paragraph(text: text))
        let attrs = attributes(of: result)
        #expect(attrs[.link] as? URL == URL(string: "https://example.com"))
        #expect(attrs[.underlineStyle] as? Int == NSUnderlineStyle.single.rawValue)
    }

    @Test("Strikethrough preserved in NSAttributedString")
    func strikethroughPreserved() {
        var text = AttributedString("deleted")
        text.strikethroughStyle = .single
        let result = buildSingle(.paragraph(text: text))
        let attrs = attributes(of: result)
        #expect(attrs[.strikethroughStyle] as? Int == NSUnderlineStyle.single.rawValue)
    }

    // MARK: - Integration: Plain Text Extraction

    @Test("Multi-block document plain text includes all block content")
    func multiBlockPlainTextExtraction() {
        let blocks = [
            IndexedBlock(index: 0, block: .heading(level: 1, text: AttributedString("Title"))),
            IndexedBlock(index: 1, block: .paragraph(text: AttributedString("Body text here."))),
            IndexedBlock(index: 2, block: .codeBlock(language: "swift", code: "let x = 42")),
        ]
        let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: theme)
        let plainText = result.attributedString.string

        #expect(plainText.contains("Title"))
        #expect(plainText.contains("Body text here."))
        #expect(plainText.contains("let x = 42"))
    }

    @Test("Multi-block plain text has clean line breaks between blocks")
    func multiBlockCleanLineBreaks() {
        let blocks = [
            IndexedBlock(index: 0, block: .heading(level: 2, text: AttributedString("Section"))),
            IndexedBlock(index: 1, block: .paragraph(text: AttributedString("Paragraph one."))),
            IndexedBlock(index: 2, block: .paragraph(text: AttributedString("Paragraph two."))),
        ]
        let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: theme)
        let plainText = result.attributedString.string

        let lines = plainText.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 3)
        #expect(lines[0] == "Section")
        #expect(lines[1] == "Paragraph one.")
        #expect(lines[2] == "Paragraph two.")
    }

    @Test("Mermaid block in multi-block produces attachment without text contribution")
    func mermaidInMultiBlockDoesNotContributeText() {
        let blocks = [
            IndexedBlock(index: 0, block: .paragraph(text: AttributedString("Above"))),
            IndexedBlock(index: 1, block: .mermaidBlock(code: "graph TD\nA-->B")),
            IndexedBlock(index: 2, block: .paragraph(text: AttributedString("Below"))),
        ]
        let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: theme)
        let plainText = result.attributedString.string

        #expect(plainText.contains("Above"))
        #expect(plainText.contains("Below"))
        #expect(!plainText.contains("graph TD"))
        #expect(result.attachments.count == 1)
    }

    // MARK: - Table Height Estimation

    @Test("Table height estimate grows with longer cell content")
    func tableHeightEstimateGrowsWithContent() {
        let shortColumns = [
            TableColumn(header: AttributedString("Name"), alignment: .left),
            TableColumn(header: AttributedString("Value"), alignment: .left),
        ]
        let shortRows: [[AttributedString]] = [
            [AttributedString("A"), AttributedString("B")],
        ]
        let shortResult = buildSingle(.table(columns: shortColumns, rows: shortRows))
        let shortHeight = shortResult.attachments.first?.attachment.bounds.height ?? 0

        let longContent = String(repeating: "word ", count: 80)
        let longColumns = [
            TableColumn(header: AttributedString("Name"), alignment: .left),
            TableColumn(header: AttributedString("Value"), alignment: .left),
        ]
        let longRows: [[AttributedString]] = [
            [AttributedString(longContent), AttributedString(longContent)],
        ]
        let longResult = buildSingle(.table(columns: longColumns, rows: longRows))
        let longHeight = longResult.attachments.first?.attachment.bounds.height ?? 0

        #expect(longHeight > shortHeight)
    }

    // MARK: - Both Themes

    @Test("Build produces valid result for both themes")
    func buildBothThemes() {
        let block = IndexedBlock(index: 0, block: .paragraph(text: AttributedString("Hello")))

        for appTheme in AppTheme.allCases {
            let result = MarkdownTextStorageBuilder.build(blocks: [block], theme: appTheme)
            #expect(result.attributedString.length > 0)
        }
    }
}
