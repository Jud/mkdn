import AppKit
import SwiftUI

/// Block-type-specific rendering methods for `MarkdownTextStorageBuilder`.
extension MarkdownTextStorageBuilder {
    // MARK: - Heading

    static func appendHeading(
        to result: NSMutableAttributedString,
        level: Int,
        text: AttributedString,
        colors: ThemeColors,
        scaleFactor: CGFloat = 1.0
    ) {
        let font = PlatformTypeConverter.headingFont(level: level, scaleFactor: scaleFactor)
        let foreground = PlatformTypeConverter.nsColor(from: colors.headingColor)
        let linkColor = PlatformTypeConverter.nsColor(from: colors.linkColor)
        let spacingBefore: CGFloat = switch level {
        case 1: 48
        case 2: 20
        default: 14
        }

        let content = convertInlineContent(
            text,
            baseFont: font,
            baseForegroundColor: foreground,
            linkColor: linkColor,
            scaleFactor: scaleFactor
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
        colors: ThemeColors,
        scaleFactor: CGFloat = 1.0
    ) {
        let font = PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor)
        let foreground = PlatformTypeConverter.nsColor(from: colors.foreground)
        let linkColor = PlatformTypeConverter.nsColor(from: colors.linkColor)

        let content = convertInlineContent(
            text,
            baseFont: font,
            baseForegroundColor: foreground,
            linkColor: linkColor,
            scaleFactor: scaleFactor
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
        theme: AppTheme,
        scaleFactor: CGFloat = 1.0
    ) {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let codeForeground = PlatformTypeConverter.nsColor(from: colors.codeForeground)
        let monoFont = PlatformTypeConverter.monospacedFont(scaleFactor: scaleFactor)

        let blockID = UUID().uuidString
        let colorInfo = CodeBlockColorInfo(
            background: PlatformTypeConverter.nsColor(from: colors.codeBackground),
            border: PlatformTypeConverter.nsColor(from: colors.border)
        )

        let hasLabel = !(language ?? "").isEmpty
        appendCodeLabel(
            to: result,
            language: language,
            blockID: blockID,
            colorInfo: colorInfo,
            colors: colors,
            scaleFactor: scaleFactor
        )

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
        codeContent.addAttribute(CodeBlockAttributes.range, value: blockID, range: fullRange)
        codeContent.addAttribute(CodeBlockAttributes.colors, value: colorInfo, range: fullRange)

        let codeStyle = makeCodeBlockParagraphStyle()
        codeContent.addAttribute(.paragraphStyle, value: codeStyle, range: fullRange)

        let spacingBefore: CGFloat = hasLabel ? codeBlockTopPaddingWithLabel : codeBlockPadding
        setFirstParagraphSpacing(codeContent, spacingBefore: spacingBefore)

        codeContent.append(NSAttributedString(string: "\n", attributes: [
            .font: monoFont,
            CodeBlockAttributes.range: blockID,
            CodeBlockAttributes.colors: colorInfo,
            .paragraphStyle: codeStyle,
        ]))

        setLastParagraphSpacing(codeContent, spacing: blockSpacing, baseStyle: codeStyle)
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
        let placeholderImage = NSImage(
            size: NSSize(width: 1, height: height)
        )
        attachment.image = placeholderImage
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
        colors: ThemeColors,
        scaleFactor: CGFloat = 1.0
    ) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let monoFont = PlatformTypeConverter.monospacedFont(scaleFactor: scaleFactor)
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

    private static func makeCodeBlockParagraphStyle() -> NSParagraphStyle {
        makeParagraphStyle(
            paragraphSpacing: 0,
            headIndent: codeBlockPadding,
            firstLineHeadIndent: codeBlockPadding,
            tailIndent: -codeBlockPadding
        )
    }

    private static func setFirstParagraphSpacing(
        _ attrStr: NSMutableAttributedString,
        spacingBefore: CGFloat
    ) {
        guard attrStr.length > 0 else { return }
        // swiftlint:disable:next legacy_objc_type
        let firstParaRange = (attrStr.string as NSString)
            .paragraphRange(for: NSRange(location: 0, length: 0))
        guard let baseStyle = attrStr.attribute(
            .paragraphStyle,
            at: 0,
            effectiveRange: nil
        ) as? NSParagraphStyle
        else { return }
        // swiftlint:disable:next force_cast
        let mutable = baseStyle.mutableCopy() as! NSMutableParagraphStyle
        mutable.paragraphSpacingBefore = spacingBefore
        attrStr.addAttribute(.paragraphStyle, value: mutable, range: firstParaRange)
    }

    private static func appendCodeLabel(
        to result: NSMutableAttributedString,
        language: String?,
        blockID: String,
        colorInfo: CodeBlockColorInfo,
        colors: ThemeColors,
        scaleFactor: CGFloat = 1.0
    ) {
        guard let language, !language.isEmpty else { return }
        let labelStyle = makeParagraphStyle(
            paragraphSpacing: codeLabelSpacing,
            paragraphSpacingBefore: codeBlockPadding,
            headIndent: codeBlockPadding,
            firstLineHeadIndent: codeBlockPadding,
            tailIndent: -codeBlockPadding
        )
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: PlatformTypeConverter.captionMonospacedFont(scaleFactor: scaleFactor),
            .foregroundColor: PlatformTypeConverter.nsColor(from: colors.foregroundSecondary),
            .paragraphStyle: labelStyle,
            CodeBlockAttributes.range: blockID,
            CodeBlockAttributes.colors: colorInfo,
        ]
        result.append(NSAttributedString(string: language + "\n", attributes: labelAttrs))
    }
}
