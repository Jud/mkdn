import AppKit
import Splash
import SwiftUI

/// Information about a non-text attachment placeholder in the attributed string.
struct AttachmentInfo {
    let blockIndex: Int
    let block: MarkdownBlock
    let attachment: NSTextAttachment
}

/// Result of converting `[IndexedBlock]` to an `NSAttributedString`.
struct TextStorageResult {
    let attributedString: NSAttributedString
    let attachments: [AttachmentInfo]
}

/// Converts an array of `IndexedBlock` into a single `NSAttributedString`
/// suitable for display in an `NSTextView`, plus a mapping of attachment
/// positions to their source block data.
enum MarkdownTextStorageBuilder {
    // MARK: - Constants

    static let blockSpacing: CGFloat = 12
    static let codeBlockPadding: CGFloat = 12
    static let codeBlockTopPaddingWithLabel: CGFloat = 8
    static let codeLabelSpacing: CGFloat = 4
    static let listItemSpacing: CGFloat = 4
    static let listPrefixWidth: CGFloat = 32
    static let listLeftPadding: CGFloat = 4
    static let blockquoteIndent: CGFloat = 19
    static let attachmentPlaceholderHeight: CGFloat = 100
    static let thematicBreakHeight: CGFloat = 17
    static let tableColumnWidth: CGFloat = 120

    static let bulletStyles: [String] = [
        "\u{2022}",
        "\u{25E6}",
        "\u{25AA}",
        "\u{25AB}",
    ]

    // MARK: - Public API

    static func build(
        blocks: [IndexedBlock],
        theme: AppTheme
    ) -> TextStorageResult {
        let result = NSMutableAttributedString()
        var attachments: [AttachmentInfo] = []
        let colors = theme.colors

        for indexedBlock in blocks {
            appendBlock(
                indexedBlock,
                to: result,
                colors: colors,
                theme: theme,
                attachments: &attachments
            )
        }

        return TextStorageResult(
            attributedString: result,
            attachments: attachments
        )
    }

    // MARK: - Block Dispatch

    private static func appendBlock(
        _ indexedBlock: IndexedBlock,
        to result: NSMutableAttributedString,
        colors: ThemeColors,
        theme: AppTheme,
        attachments: inout [AttachmentInfo]
    ) {
        switch indexedBlock.block {
        case let .heading(level, text):
            appendHeading(to: result, level: level, text: text, colors: colors)
        case let .paragraph(text):
            appendParagraph(to: result, text: text, colors: colors)
        case let .codeBlock(language, code):
            appendCodeBlock(to: result, language: language, code: code, colors: colors, theme: theme)
        case .mermaidBlock, .image:
            appendAttachmentBlock(
                to: result,
                blockIndex: indexedBlock.index,
                block: indexedBlock.block,
                height: attachmentPlaceholderHeight,
                attachments: &attachments
            )
        case let .blockquote(blocks):
            appendBlockquote(to: result, blocks: blocks, colors: colors, theme: theme, depth: 0)
        case let .orderedList(items):
            appendOrderedList(to: result, items: items, colors: colors, theme: theme, depth: 0)
        case let .unorderedList(items):
            appendUnorderedList(to: result, items: items, colors: colors, theme: theme, depth: 0)
        case .thematicBreak:
            appendAttachmentBlock(
                to: result,
                blockIndex: indexedBlock.index,
                block: indexedBlock.block,
                height: thematicBreakHeight,
                attachments: &attachments
            )
        case let .table(columns, rows):
            appendTable(to: result, columns: columns, rows: rows, colors: colors)
        case let .htmlBlock(content):
            appendHTMLBlock(to: result, content: content, colors: colors)
        }
    }

    // MARK: - Inline Content Conversion

    static func convertInlineContent(
        _ content: AttributedString,
        baseFont: NSFont,
        baseForegroundColor: NSColor,
        linkColor: NSColor
    ) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()

        for run in content.runs {
            let text = String(content[run.range].characters)
            var attributes: [NSAttributedString.Key: Any] = [:]

            let intent = run.inlinePresentationIntent ?? []
            var font = baseFont

            if intent.contains(.code) {
                font = PlatformTypeConverter.monospacedFont()
            } else {
                let isBold = intent.contains(.stronglyEmphasized)
                let isItalic = intent.contains(.emphasized)
                if isBold || isItalic {
                    var traits: NSFontTraitMask = []
                    if isBold { traits.insert(.boldFontMask) }
                    if isItalic { traits.insert(.italicFontMask) }
                    font = NSFontManager.shared.convert(font, toHaveTrait: traits)
                }
            }
            attributes[.font] = font

            var foreground = baseForegroundColor
            if let link = run.link {
                foreground = linkColor
                attributes[.link] = link
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            attributes[.foregroundColor] = foreground

            if run.strikethroughStyle != nil {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }

            result.append(NSAttributedString(string: text, attributes: attributes))
        }

        return result
    }

    // MARK: - Syntax Highlighting

    static func highlightSwiftCode(
        _ code: String,
        theme: AppTheme
    ) -> NSMutableAttributedString {
        let syntaxColors = theme.syntaxColors
        let format = ThemeOutputFormat(
            plainTextColor: PlatformTypeConverter.nsColor(from: syntaxColors.comment),
            tokenColorMap: [
                .keyword: PlatformTypeConverter.nsColor(from: syntaxColors.keyword),
                .string: PlatformTypeConverter.nsColor(from: syntaxColors.string),
                .type: PlatformTypeConverter.nsColor(from: syntaxColors.type),
                .call: PlatformTypeConverter.nsColor(from: syntaxColors.function),
                .number: PlatformTypeConverter.nsColor(from: syntaxColors.number),
                .comment: PlatformTypeConverter.nsColor(from: syntaxColors.comment),
                .property: PlatformTypeConverter.nsColor(from: syntaxColors.property),
                .dotAccess: PlatformTypeConverter.nsColor(from: syntaxColors.property),
                .preprocessing: PlatformTypeConverter.nsColor(from: syntaxColors.preprocessor),
            ]
        )
        let highlighter = SyntaxHighlighter(format: format)
        let highlighted = highlighter.highlight(code)
        return NSMutableAttributedString(highlighted)
    }

    // MARK: - Paragraph Style Helpers

    static func makeParagraphStyle(
        lineSpacing: CGFloat = 2,
        paragraphSpacing: CGFloat = 0,
        paragraphSpacingBefore: CGFloat = 0,
        headIndent: CGFloat = 0,
        firstLineHeadIndent: CGFloat = 0,
        tailIndent: CGFloat = 0,
        alignment: NSTextAlignment = .left,
        tabStops: [NSTextTab] = []
    ) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = paragraphSpacing
        style.paragraphSpacingBefore = paragraphSpacingBefore
        style.headIndent = headIndent
        style.firstLineHeadIndent = firstLineHeadIndent
        style.tailIndent = tailIndent
        style.alignment = alignment
        if !tabStops.isEmpty {
            style.tabStops = tabStops
        }
        return style
    }

    static func terminator(with style: NSParagraphStyle) -> NSAttributedString {
        NSAttributedString(string: "\n", attributes: [.paragraphStyle: style])
    }

    static func setLastParagraphSpacing(
        _ attrStr: NSMutableAttributedString,
        spacing: CGFloat,
        baseStyle: NSParagraphStyle? = nil
    ) {
        guard attrStr.length > 0 else { return }
        let nsString = attrStr.string as NSString // swiftlint:disable:this legacy_objc_type
        let lastCharLoc = nsString.length - 1
        let lastParaRange = nsString.paragraphRange(
            for: NSRange(location: lastCharLoc, length: 0)
        )

        let existing: NSParagraphStyle = if let base = baseStyle {
            base
        } else if let found = attrStr.attribute(
            .paragraphStyle,
            at: lastParaRange.location,
            effectiveRange: nil
        ) as? NSParagraphStyle {
            found
        } else {
            .default
        }

        // swiftlint:disable:next force_cast
        let mutable = existing.mutableCopy() as! NSMutableParagraphStyle
        mutable.paragraphSpacing = spacing
        attrStr.addAttribute(.paragraphStyle, value: mutable, range: lastParaRange)
    }

    static func plainText(from block: MarkdownBlock) -> String {
        switch block {
        case let .heading(_, text):
            return String(text.characters)
        case let .paragraph(text):
            return String(text.characters)
        case let .codeBlock(_, code):
            return code.trimmingCharacters(in: .whitespacesAndNewlines)
        case let .mermaidBlock(code):
            return code.trimmingCharacters(in: .whitespacesAndNewlines)
        case let .htmlBlock(content):
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        case let .image(_, alt):
            return alt
        case .thematicBreak:
            return ""
        case let .blockquote(blocks):
            return blocks.map { plainText(from: $0) }.joined(separator: "\n")
        case let .orderedList(items):
            return items
                .map { $0.blocks.map { plainText(from: $0) }.joined(separator: "\n") }
                .joined(separator: "\n")
        case let .unorderedList(items):
            return items
                .map { $0.blocks.map { plainText(from: $0) }.joined(separator: "\n") }
                .joined(separator: "\n")
        case let .table(columns, rows):
            let header = columns.map { String($0.header.characters) }.joined(separator: "\t")
            let body = rows
                .map { row in row.map { String($0.characters) }.joined(separator: "\t") }
                .joined(separator: "\n")
            return [header, body].filter { !$0.isEmpty }.joined(separator: "\n")
        }
    }
}
