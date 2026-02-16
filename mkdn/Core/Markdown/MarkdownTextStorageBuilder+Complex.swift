import AppKit
import SwiftUI

/// Blockquote, list, and table rendering for `MarkdownTextStorageBuilder`.
extension MarkdownTextStorageBuilder {
    // MARK: - Blockquote

    static func appendBlockquote(
        to result: NSMutableAttributedString,
        blocks: [MarkdownBlock],
        colors: ThemeColors,
        syntaxColors: SyntaxColors,
        depth: Int,
        scaleFactor: CGFloat = 1.0
    ) {
        let ctx = BlockBuildContext(colors: colors, syntaxColors: syntaxColors, scaleFactor: scaleFactor)
        let indent = blockquoteIndent * CGFloat(depth + 1)

        for block in blocks {
            switch block {
            case let .paragraph(text):
                appendIndentedParagraph(
                    to: result,
                    text: text,
                    indent: indent,
                    foreground: ctx.resolved.foreground,
                    linkColor: ctx.resolved.linkColor,
                    scaleFactor: scaleFactor
                )

            case let .heading(level, text):
                appendIndentedHeading(
                    to: result,
                    level: level,
                    text: text,
                    indent: indent,
                    headingColor: ctx.resolved.headingColor,
                    linkColor: ctx.resolved.linkColor,
                    scaleFactor: scaleFactor
                )

            case let .blockquote(innerBlocks):
                appendBlockquote(
                    to: result,
                    blocks: innerBlocks,
                    colors: colors,
                    syntaxColors: syntaxColors,
                    depth: depth + 1,
                    scaleFactor: scaleFactor
                )

            default:
                let text = plainText(from: block)
                guard !text.isEmpty else { continue }
                appendIndentedPlainText(
                    to: result,
                    text: text,
                    indent: indent,
                    foreground: ctx.resolved.foreground,
                    scaleFactor: scaleFactor
                )
            }
        }
    }

    // MARK: - Lists

    static func appendOrderedList(
        to result: NSMutableAttributedString,
        items: [ListItem],
        colors: ThemeColors,
        syntaxColors: SyntaxColors,
        depth: Int,
        scaleFactor: CGFloat = 1.0
    ) {
        let ctx = BlockBuildContext(colors: colors, syntaxColors: syntaxColors, scaleFactor: scaleFactor)
        for (index, item) in items.enumerated() {
            appendListItem(
                to: result,
                item: item,
                prefix: "\(index + 1).",
                ctx: ctx,
                depth: depth
            )
        }
    }

    static func appendUnorderedList(
        to result: NSMutableAttributedString,
        items: [ListItem],
        colors: ThemeColors,
        syntaxColors: SyntaxColors,
        depth: Int,
        scaleFactor: CGFloat = 1.0
    ) {
        let bulletIndex = min(depth, bulletStyles.count - 1)
        let bullet = bulletStyles[bulletIndex]
        let ctx = BlockBuildContext(colors: colors, syntaxColors: syntaxColors, scaleFactor: scaleFactor)
        for item in items {
            appendListItem(
                to: result,
                item: item,
                prefix: item.checkbox != nil ? "" : bullet,
                ctx: ctx,
                depth: depth
            )
        }
    }

    // MARK: - Table

    static func appendTable(
        to result: NSMutableAttributedString,
        columns: [TableColumn],
        rows: [[AttributedString]],
        colors: ThemeColors,
        scaleFactor: CGFloat = 1.0
    ) {
        let resolved = ResolvedColors(colors: colors)

        let tabStops = columns.enumerated().map { index, column in
            let alignment: NSTextAlignment = switch column.alignment {
            case .left: .left
            case .center: .center
            case .right: .right
            }
            return NSTextTab(
                textAlignment: alignment,
                location: CGFloat(index + 1) * tableColumnWidth
            )
        }

        appendTableHeader(
            to: result,
            columns: columns,
            resolved: resolved,
            tabStops: tabStops,
            scaleFactor: scaleFactor
        )
        appendTableRows(
            to: result,
            rows: rows,
            resolved: resolved,
            tabStops: tabStops,
            scaleFactor: scaleFactor
        )

        if rows.isEmpty {
            result.append(NSAttributedString(string: "\n", attributes: [
                .font: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor),
                .paragraphStyle: makeParagraphStyle(paragraphSpacing: blockSpacing),
            ]))
        } else {
            setLastParagraphSpacing(result, spacing: blockSpacing)
        }
    }

    // MARK: - Blockquote Helpers

    private static func appendIndentedParagraph(
        to result: NSMutableAttributedString,
        text: AttributedString,
        indent: CGFloat,
        foreground: NSColor,
        linkColor: NSColor,
        scaleFactor: CGFloat = 1.0
    ) {
        let font = PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor)
        let content = convertInlineContent(
            text,
            baseFont: font,
            baseForegroundColor: foreground,
            linkColor: linkColor,
            scaleFactor: scaleFactor
        )
        let style = makeParagraphStyle(
            paragraphSpacing: 8,
            headIndent: indent,
            firstLineHeadIndent: indent
        )
        let range = NSRange(location: 0, length: content.length)
        content.addAttribute(.paragraphStyle, value: style, range: range)
        content.append(terminator(with: style))
        result.append(content)
    }

    private static func appendIndentedHeading(
        to result: NSMutableAttributedString,
        level: Int,
        text: AttributedString,
        indent: CGFloat,
        headingColor: NSColor,
        linkColor: NSColor,
        scaleFactor: CGFloat = 1.0
    ) {
        let font = PlatformTypeConverter.headingFont(level: level, scaleFactor: scaleFactor)
        let content = convertInlineContent(
            text,
            baseFont: font,
            baseForegroundColor: headingColor,
            linkColor: linkColor,
            scaleFactor: scaleFactor
        )
        let style = makeParagraphStyle(
            paragraphSpacing: 8,
            paragraphSpacingBefore: level <= 2 ? 8 : 4,
            headIndent: indent,
            firstLineHeadIndent: indent
        )
        let range = NSRange(location: 0, length: content.length)
        content.addAttribute(.paragraphStyle, value: style, range: range)
        content.append(terminator(with: style))
        result.append(content)
    }

    private static func appendIndentedPlainText(
        to result: NSMutableAttributedString,
        text: String,
        indent: CGFloat,
        foreground: NSColor,
        scaleFactor: CGFloat = 1.0
    ) {
        let style = makeParagraphStyle(
            paragraphSpacing: 8,
            headIndent: indent,
            firstLineHeadIndent: indent
        )
        let attrs: [NSAttributedString.Key: Any] = [
            .font: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor),
            .foregroundColor: foreground,
            .paragraphStyle: style,
        ]
        result.append(NSAttributedString(string: text + "\n", attributes: attrs))
    }

    // MARK: - List Helpers

    private static func appendListItem(
        to result: NSMutableAttributedString,
        item: ListItem,
        prefix: String,
        ctx: BlockBuildContext,
        depth: Int
    ) {
        let baseIndent = listLeftPadding + CGFloat(depth) * (listPrefixWidth + listLeftPadding)
        let contentIndent = baseIndent + listPrefixWidth
        let style = makeParagraphStyle(
            paragraphSpacing: listItemSpacing,
            headIndent: contentIndent,
            firstLineHeadIndent: baseIndent,
            tabStops: [NSTextTab(textAlignment: .left, location: contentIndent)]
        )
        let prefixAttr = resolvedListPrefix(
            prefix: prefix,
            checkbox: item.checkbox,
            color: ctx.resolved.secondaryColor,
            scaleFactor: ctx.scaleFactor
        )
        let cl = ctx.colors
        let sc = ctx.syntaxColors
        let sf = ctx.scaleFactor
        let nextDepth = depth + 1
        var isFirstBlock = true
        for block in item.blocks {
            switch block {
            case let .paragraph(text):
                appendListParagraph(
                    to: result,
                    text: text,
                    isFirstBlock: isFirstBlock,
                    prefixAttr: prefixAttr,
                    style: style,
                    resolved: ctx.resolved,
                    scaleFactor: sf
                )
            case let .orderedList(items):
                appendOrderedList(
                    to: result,
                    items: items,
                    colors: cl,
                    syntaxColors: sc,
                    depth: nextDepth,
                    scaleFactor: sf
                )
            case let .unorderedList(items):
                appendUnorderedList(
                    to: result,
                    items: items,
                    colors: cl,
                    syntaxColors: sc,
                    depth: nextDepth,
                    scaleFactor: sf
                )
            default:
                let text = plainText(from: block)
                guard !text.isEmpty else { continue }
                appendListFallback(
                    to: result,
                    text: text,
                    isFirstBlock: isFirstBlock,
                    prefixAttr: prefixAttr,
                    style: style,
                    resolved: ctx.resolved,
                    scaleFactor: sf
                )
            }
            isFirstBlock = false
        }
    }

    private static func resolvedListPrefix(
        prefix: String,
        checkbox: CheckboxState?,
        color: NSColor,
        scaleFactor: CGFloat = 1.0
    ) -> NSAttributedString {
        if let checkbox {
            return checkboxPrefix(checkbox, color: color, scaleFactor: scaleFactor)
        }
        return listPrefix(prefix, color: color, scaleFactor: scaleFactor)
    }

    private static func appendListParagraph(
        to result: NSMutableAttributedString,
        text: AttributedString,
        isFirstBlock: Bool,
        prefixAttr: NSAttributedString,
        style: NSParagraphStyle,
        resolved: ResolvedColors,
        scaleFactor: CGFloat = 1.0
    ) {
        let content = NSMutableAttributedString()
        if isFirstBlock {
            content.append(prefixAttr)
        }
        let inlineContent = convertInlineContent(
            text,
            baseFont: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor),
            baseForegroundColor: resolved.foreground,
            linkColor: resolved.linkColor,
            scaleFactor: scaleFactor
        )
        content.append(inlineContent)
        let range = NSRange(location: 0, length: content.length)
        content.addAttribute(.paragraphStyle, value: style, range: range)
        content.append(terminator(with: style))
        result.append(content)
    }

    private static func appendListFallback(
        to result: NSMutableAttributedString,
        text: String,
        isFirstBlock: Bool,
        prefixAttr: NSAttributedString,
        style: NSParagraphStyle,
        resolved: ResolvedColors,
        scaleFactor: CGFloat = 1.0
    ) {
        let content = NSMutableAttributedString()
        if isFirstBlock {
            content.append(prefixAttr)
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor),
            .foregroundColor: resolved.foreground,
        ]
        content.append(NSAttributedString(string: text, attributes: attrs))
        let range = NSRange(location: 0, length: content.length)
        content.addAttribute(.paragraphStyle, value: style, range: range)
        content.append(terminator(with: style))
        result.append(content)
    }

    private static func listPrefix(_ prefix: String, color: NSColor, scaleFactor: CGFloat = 1.0) -> NSAttributedString {
        NSAttributedString(
            string: prefix + "\t",
            attributes: [
                .font: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor),
                .foregroundColor: color,
            ]
        )
    }

    private static func checkboxPrefix(
        _ state: CheckboxState, color: NSColor, scaleFactor: CGFloat = 1.0
    ) -> NSAttributedString {
        let symbolName = state == .checked ? "checkmark.square.fill" : "square"
        let font = PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor)
        let symbolSize = font.pointSize

        guard let symbolImage = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: state == .checked ? "checked" : "unchecked"
        )
        else {
            return listPrefix(state == .checked ? "[x]" : "[ ]", color: color, scaleFactor: scaleFactor)
        }

        let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .regular)
        let configuredImage = symbolImage.withSymbolConfiguration(config) ?? symbolImage

        let tintedImage = NSImage(size: configuredImage.size, flipped: false) { rect in
            color.set()
            configuredImage.draw(in: rect)
            rect.fill(using: .sourceAtop)
            return true
        }

        let attachment = NSTextAttachment()
        attachment.image = tintedImage
        let yOffset = (font.capHeight - configuredImage.size.height) / 2
        attachment.bounds = CGRect(
            x: 0,
            y: yOffset,
            width: configuredImage.size.width,
            height: configuredImage.size.height
        )

        let result = NSMutableAttributedString(attachment: attachment)
        result.append(NSAttributedString(
            string: "\t",
            attributes: [
                .font: font,
                .foregroundColor: color,
            ]
        ))
        return result
    }

    // MARK: - Table Helpers

    private static func appendTableHeader(
        to result: NSMutableAttributedString,
        columns: [TableColumn],
        resolved: ResolvedColors,
        tabStops: [NSTextTab],
        scaleFactor: CGFloat = 1.0
    ) {
        let headerStyle = makeParagraphStyle(
            paragraphSpacing: 4,
            tabStops: tabStops
        )
        let headerContent = NSMutableAttributedString()
        for (colIndex, column) in columns.enumerated() {
            if colIndex > 0 {
                headerContent.append(NSAttributedString(string: "\t"))
            }
            let font = NSFontManager.shared.convert(
                PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor),
                toHaveTrait: .boldFontMask
            )
            let cellContent = convertInlineContent(
                column.header,
                baseFont: font,
                baseForegroundColor: resolved.headingColor,
                linkColor: resolved.linkColor,
                scaleFactor: scaleFactor
            )
            headerContent.append(cellContent)
        }
        let range = NSRange(location: 0, length: headerContent.length)
        headerContent.addAttribute(.paragraphStyle, value: headerStyle, range: range)
        headerContent.append(terminator(with: headerStyle))
        result.append(headerContent)
    }

    private static func appendTableRows(
        to result: NSMutableAttributedString,
        rows: [[AttributedString]],
        resolved: ResolvedColors,
        tabStops: [NSTextTab],
        scaleFactor: CGFloat = 1.0
    ) {
        let rowStyle = makeParagraphStyle(
            paragraphSpacing: 2,
            tabStops: tabStops
        )
        for row in rows {
            let rowContent = NSMutableAttributedString()
            for (colIndex, cell) in row.enumerated() {
                if colIndex > 0 {
                    rowContent.append(NSAttributedString(string: "\t"))
                }
                let cellContent = convertInlineContent(
                    cell,
                    baseFont: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor),
                    baseForegroundColor: resolved.foreground,
                    linkColor: resolved.linkColor,
                    scaleFactor: scaleFactor
                )
                rowContent.append(cellContent)
            }
            let range = NSRange(location: 0, length: rowContent.length)
            rowContent.addAttribute(.paragraphStyle, value: rowStyle, range: range)
            rowContent.append(terminator(with: rowStyle))
            result.append(rowContent)
        }
    }
}
