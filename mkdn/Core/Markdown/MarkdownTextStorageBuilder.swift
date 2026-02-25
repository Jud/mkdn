import AppKit
import SwiftUI

/// Information about a non-text attachment placeholder in the attributed string.
struct AttachmentInfo {
    let blockIndex: Int
    let block: MarkdownBlock
    let attachment: NSTextAttachment
}

/// Information about a table rendered as invisible inline text in the attributed string.
struct TableOverlayInfo {
    let blockIndex: Int
    let block: MarkdownBlock
    let tableRangeID: String
    let cellMap: TableCellMap
}

/// Result of converting `[IndexedBlock]` to an `NSAttributedString`.
struct TextStorageResult {
    let attributedString: NSAttributedString
    let attachments: [AttachmentInfo]
    let tableOverlays: [TableOverlayInfo]

    init(
        attributedString: NSAttributedString,
        attachments: [AttachmentInfo],
        tableOverlays: [TableOverlayInfo] = []
    ) {
        self.attributedString = attributedString
        self.attachments = attachments
        self.tableOverlays = tableOverlays
    }
}

/// Resolved NSColor values from a ThemeColors palette for text storage building.
struct ResolvedColors {
    let foreground: NSColor
    let headingColor: NSColor
    let secondaryColor: NSColor
    let linkColor: NSColor

    init(colors: ThemeColors) {
        foreground = PlatformTypeConverter.nsColor(from: colors.foreground)
        headingColor = PlatformTypeConverter.nsColor(from: colors.headingColor)
        secondaryColor = PlatformTypeConverter.nsColor(from: colors.foregroundSecondary)
        linkColor = PlatformTypeConverter.nsColor(from: colors.linkColor)
    }
}

/// Context for recursive list/blockquote rendering.
struct BlockBuildContext {
    let colors: ThemeColors
    let syntaxColors: SyntaxColors
    let resolved: ResolvedColors
    let scaleFactor: CGFloat

    init(colors: ThemeColors, syntaxColors: SyntaxColors, scaleFactor: CGFloat = 1.0) {
        self.colors = colors
        self.syntaxColors = syntaxColors
        self.scaleFactor = scaleFactor
        resolved = ResolvedColors(colors: colors)
    }
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

    static let bulletStyles: [String] = [
        "\u{2022}",
        "\u{25E6}",
        "\u{25AA}",
        "\u{25AB}",
    ]

    // MARK: - Public API

    static func build(
        blocks: [IndexedBlock],
        theme: AppTheme,
        scaleFactor: CGFloat = 1.0,
        isPrint: Bool = false
    ) -> TextStorageResult {
        build(
            blocks: blocks,
            colors: theme.colors,
            syntaxColors: theme.syntaxColors,
            scaleFactor: scaleFactor,
            isPrint: isPrint
        )
    }

    static func build(
        blocks: [IndexedBlock],
        colors: ThemeColors,
        syntaxColors: SyntaxColors,
        scaleFactor: CGFloat = 1.0,
        isPrint: Bool = false
    ) -> TextStorageResult {
        let result = NSMutableAttributedString()
        var attachments: [AttachmentInfo] = []
        var tableOverlays: [TableOverlayInfo] = []

        for (offset, indexedBlock) in blocks.enumerated() {
            appendBlock(
                indexedBlock,
                to: result,
                colors: colors,
                syntaxColors: syntaxColors,
                scaleFactor: scaleFactor,
                attachments: &attachments,
                tableOverlays: &tableOverlays,
                isPrint: isPrint
            )

            // Collapse the first block's top spacing so textContainerInset
            // alone controls the window-top-to-text distance.
            if offset == 0, result.length > 0 {
                let firstParaRange = (result.string as NSString) // swiftlint:disable:this legacy_objc_type
                    .paragraphRange(for: NSRange(location: 0, length: 0))
                if let style = result.attribute(
                    .paragraphStyle, at: 0, effectiveRange: nil
                ) as? NSParagraphStyle {
                    // swiftlint:disable:next force_cast
                    let mutable = style.mutableCopy() as! NSMutableParagraphStyle
                    mutable.paragraphSpacingBefore = 0
                    result.addAttribute(.paragraphStyle, value: mutable, range: firstParaRange)
                }
            }
        }

        return TextStorageResult(
            attributedString: result,
            attachments: attachments,
            tableOverlays: tableOverlays
        )
    }

    // MARK: - Block Dispatch

    // swiftlint:disable:next function_parameter_count function_body_length
    private static func appendBlock(
        _ indexedBlock: IndexedBlock,
        to result: NSMutableAttributedString,
        colors: ThemeColors,
        syntaxColors: SyntaxColors,
        scaleFactor: CGFloat,
        attachments: inout [AttachmentInfo],
        tableOverlays: inout [TableOverlayInfo],
        isPrint: Bool
    ) {
        let sf = scaleFactor
        let block = indexedBlock.block
        switch block {
        case let .heading(level, text):
            appendHeading(
                to: result,
                level: level,
                text: text,
                colors: colors,
                scaleFactor: sf
            )
        case let .paragraph(text):
            appendParagraph(to: result, text: text, colors: colors, scaleFactor: sf)
        case let .codeBlock(lang, code):
            appendCodeBlock(
                to: result,
                language: lang,
                code: code,
                colors: colors,
                syntaxColors: syntaxColors,
                scaleFactor: sf
            )
        case .mermaidBlock, .image:
            appendAttachmentPlaceholder(indexedBlock, to: result, attachments: &attachments)
        case let .mathBlock(code):
            if isPrint {
                appendMathBlockInline(
                    to: result, code: code, colors: colors, scaleFactor: sf
                )
            } else {
                appendAttachmentPlaceholder(indexedBlock, to: result, attachments: &attachments)
            }
        case let .blockquote(blocks):
            appendBlockquote(
                to: result,
                blocks: blocks,
                colors: colors,
                syntaxColors: syntaxColors,
                depth: 0,
                scaleFactor: sf
            )
        case let .orderedList(items):
            appendOrderedList(
                to: result,
                items: items,
                colors: colors,
                syntaxColors: syntaxColors,
                depth: 0,
                scaleFactor: sf
            )
        case let .unorderedList(items):
            appendUnorderedList(
                to: result,
                items: items,
                colors: colors,
                syntaxColors: syntaxColors,
                depth: 0,
                scaleFactor: sf
            )
        case .thematicBreak:
            appendAttachmentPlaceholder(indexedBlock, to: result, attachments: &attachments)
        case let .table(columns, rows):
            appendTableInlineText(
                to: result,
                blockIndex: indexedBlock.index,
                block: block,
                columns: columns,
                rows: rows,
                colors: colors,
                isPrint: isPrint,
                tableOverlays: &tableOverlays
            )
        case let .htmlBlock(content):
            appendHTMLBlock(to: result, content: content, colors: colors, scaleFactor: sf)
        }
    }

    private static func appendAttachmentPlaceholder(
        _ indexedBlock: IndexedBlock,
        to result: NSMutableAttributedString,
        attachments: inout [AttachmentInfo]
    ) {
        let height: CGFloat = switch indexedBlock.block {
        case .thematicBreak: thematicBreakHeight
        default: attachmentPlaceholderHeight
        }
        appendAttachmentBlock(
            to: result,
            blockIndex: indexedBlock.index,
            block: indexedBlock.block,
            height: height,
            attachments: &attachments
        )
    }

    // MARK: - Table Height Estimation

    static let defaultEstimationContainerWidth: CGFloat = 600

    // MARK: - Inline Content Conversion

    static func convertInlineContent(
        _ content: AttributedString,
        baseFont: NSFont,
        baseForegroundColor: NSColor,
        linkColor: NSColor,
        scaleFactor: CGFloat = 1.0
    ) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()

        for run in content.runs {
            if let mathResult = renderInlineMath(
                from: run,
                content: content,
                baseFont: baseFont,
                baseForegroundColor: baseForegroundColor,
                scaleFactor: scaleFactor
            ) {
                result.append(mathResult)
                continue
            }

            let text = String(content[run.range].characters)
            var attributes: [NSAttributedString.Key: Any] = [:]

            let intent = run.inlinePresentationIntent ?? []
            var font = baseFont

            if intent.contains(.code) {
                font = PlatformTypeConverter.monospacedFont(scaleFactor: scaleFactor)
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

    static func highlightCode(
        _ code: String,
        language: String,
        syntaxColors: SyntaxColors
    ) -> NSMutableAttributedString? {
        SyntaxHighlightEngine.highlight(
            code: code,
            language: language,
            syntaxColors: syntaxColors
        )
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
        case let .mathBlock(code):
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
