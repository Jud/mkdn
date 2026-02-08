import AppKit
import SwiftUI

/// Block-type-specific rendering methods for `MarkdownTextStorageBuilder`.
extension MarkdownTextStorageBuilder {
    // MARK: - Heading

    static func appendHeading(
        to result: NSMutableAttributedString,
        level: Int,
        text: AttributedString,
        colors: ThemeColors
    ) {
        let font = PlatformTypeConverter.headingFont(level: level)
        let foreground = PlatformTypeConverter.nsColor(from: colors.headingColor)
        let linkColor = PlatformTypeConverter.nsColor(from: colors.linkColor)
        let spacingBefore: CGFloat = level <= 2 ? 8 : 4

        let content = convertInlineContent(
            text,
            baseFont: font,
            baseForegroundColor: foreground,
            linkColor: linkColor
        )
        let style = makeParagraphStyle(
            paragraphSpacing: blockSpacing,
            paragraphSpacingBefore: spacingBefore
        )
        let range = NSRange(location: 0, length: content.length)
        content.addAttribute(.paragraphStyle, value: style, range: range)
        content.append(terminator(with: style))
        result.append(content)
    }

    // MARK: - Paragraph

    static func appendParagraph(
        to result: NSMutableAttributedString,
        text: AttributedString,
        colors: ThemeColors
    ) {
        let font = PlatformTypeConverter.bodyFont()
        let foreground = PlatformTypeConverter.nsColor(from: colors.foreground)
        let linkColor = PlatformTypeConverter.nsColor(from: colors.linkColor)

        let content = convertInlineContent(
            text,
            baseFont: font,
            baseForegroundColor: foreground,
            linkColor: linkColor
        )
        let style = makeParagraphStyle(paragraphSpacing: blockSpacing)
        let range = NSRange(location: 0, length: content.length)
        content.addAttribute(.paragraphStyle, value: style, range: range)
        content.append(terminator(with: style))
        result.append(content)
    }

    // MARK: - Code Block

    static func appendCodeBlock(
        to result: NSMutableAttributedString,
        language: String?,
        code: String,
        colors: ThemeColors,
        theme: AppTheme
    ) {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let codeBackground = PlatformTypeConverter.nsColor(from: colors.codeBackground)
        let codeForeground = PlatformTypeConverter.nsColor(from: colors.codeForeground)
        let monoFont = PlatformTypeConverter.monospacedFont()

        appendCodeLabel(to: result, language: language, codeBackground: codeBackground, colors: colors)

        let codeContent: NSMutableAttributedString
        if language == "swift" {
            codeContent = highlightSwiftCode(trimmedCode, theme: theme)
            codeContent.addAttribute(.font, value: monoFont, range: NSRange(location: 0, length: codeContent.length))
        } else {
            codeContent = NSMutableAttributedString(
                string: trimmedCode,
                attributes: [.font: monoFont, .foregroundColor: codeForeground]
            )
        }

        let fullRange = NSRange(location: 0, length: codeContent.length)
        codeContent.addAttribute(.backgroundColor, value: codeBackground, range: fullRange)

        let tightStyle = makeParagraphStyle(paragraphSpacing: 0)
        codeContent.addAttribute(.paragraphStyle, value: tightStyle, range: fullRange)
        codeContent.append(NSAttributedString(string: "\n", attributes: [
            .font: monoFont, .backgroundColor: codeBackground,
        ]))

        setLastParagraphSpacing(codeContent, spacing: blockSpacing, baseStyle: tightStyle)
        result.append(codeContent)
    }

    // MARK: - Attachment Block

    static func appendAttachmentBlock(
        to result: NSMutableAttributedString,
        blockIndex: Int,
        block: MarkdownBlock,
        height: CGFloat,
        attachments: inout [AttachmentInfo]
    ) {
        let attachment = NSTextAttachment()
        attachment.bounds = CGRect(x: 0, y: 0, width: 1, height: height)

        let attachmentStr = NSMutableAttributedString(attachment: attachment)
        let style = makeParagraphStyle(paragraphSpacing: blockSpacing)
        let range = NSRange(location: 0, length: attachmentStr.length)
        attachmentStr.addAttribute(.paragraphStyle, value: style, range: range)
        attachmentStr.append(terminator(with: style))

        attachments.append(AttachmentInfo(
            blockIndex: blockIndex,
            block: block,
            attachment: attachment
        ))

        result.append(attachmentStr)
    }

    // MARK: - HTML Block

    static func appendHTMLBlock(
        to result: NSMutableAttributedString,
        content: String,
        colors: ThemeColors
    ) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let monoFont = PlatformTypeConverter.monospacedFont()
        let codeBackground = PlatformTypeConverter.nsColor(from: colors.codeBackground)
        let codeForeground = PlatformTypeConverter.nsColor(from: colors.codeForeground)

        let htmlContent = NSMutableAttributedString(
            string: trimmed,
            attributes: [
                .font: monoFont,
                .foregroundColor: codeForeground,
                .backgroundColor: codeBackground,
            ]
        )

        let tightStyle = makeParagraphStyle(paragraphSpacing: 0)
        let range = NSRange(location: 0, length: htmlContent.length)
        htmlContent.addAttribute(.paragraphStyle, value: tightStyle, range: range)
        htmlContent.append(NSAttributedString(string: "\n", attributes: [
            .font: monoFont, .backgroundColor: codeBackground,
        ]))

        setLastParagraphSpacing(htmlContent, spacing: blockSpacing, baseStyle: tightStyle)
        result.append(htmlContent)
    }

    // MARK: - Code Block Helpers

    private static func appendCodeLabel(
        to result: NSMutableAttributedString,
        language: String?,
        codeBackground: NSColor,
        colors: ThemeColors
    ) {
        guard let language, !language.isEmpty else { return }
        let labelStyle = makeParagraphStyle(paragraphSpacing: codeLabelSpacing)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: PlatformTypeConverter.captionMonospacedFont(),
            .foregroundColor: PlatformTypeConverter.nsColor(from: colors.foregroundSecondary),
            .backgroundColor: codeBackground,
            .paragraphStyle: labelStyle,
        ]
        result.append(NSAttributedString(string: language + "\n", attributes: labelAttrs))
    }
}
