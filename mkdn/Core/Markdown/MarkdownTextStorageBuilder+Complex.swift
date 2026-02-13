import AppKit
import SwiftUI

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
    let theme: AppTheme
    let resolved: ResolvedColors

    init(colors: ThemeColors, theme: AppTheme) {
        self.colors = colors
        self.theme = theme
        resolved = ResolvedColors(colors: colors)
    }
}

/// Blockquote, list, and table rendering for `MarkdownTextStorageBuilder`.
extension MarkdownTextStorageBuilder {
    // MARK: - Blockquote

    static func appendBlockquote(
        to result: NSMutableAttributedString,
        blocks: [MarkdownBlock],
        colors: ThemeColors,
        theme: AppTheme,
        depth: Int
    ) {
        let ctx = BlockBuildContext(colors: colors, theme: theme)
        let indent = blockquoteIndent * CGFloat(depth + 1)

        for block in blocks {
            switch block {
            case let .paragraph(text):
                appendIndentedParagraph(
                    to: result,
                    text: text,
                    indent: indent,
                    foreground: ctx.resolved.foreground,
                    linkColor: ctx.resolved.linkColor
                )

            case let .heading(level, text):
                appendIndentedHeading(
                    to: result,
                    level: level,
                    text: text,
                    indent: indent,
                    headingColor: ctx.resolved.headingColor,
                    linkColor: ctx.resolved.linkColor
                )

            case let .blockquote(innerBlocks):
                appendBlockquote(
                    to: result,
                    blocks: innerBlocks,
                    colors: colors,
                    theme: theme,
                    depth: depth + 1
                )

            default:
                let text = plainText(from: block)
                guard !text.isEmpty else { continue }
                appendIndentedPlainText(
                    to: result,
                    text: text,
                    indent: indent,
                    foreground: ctx.resolved.foreground
                )
            }
        }
    }

    // MARK: - Lists

    static func appendOrderedList(
        to result: NSMutableAttributedString,
        items: [ListItem],
        colors: ThemeColors,
        theme: AppTheme,
        depth: Int
    ) {
        let ctx = BlockBuildContext(colors: colors, theme: theme)
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
        theme: AppTheme,
        depth: Int
    ) {
        let bulletIndex = min(depth, bulletStyles.count - 1)
        let bullet = bulletStyles[bulletIndex]
        let ctx = BlockBuildContext(colors: colors, theme: theme)
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
        colors: ThemeColors
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
            tabStops: tabStops
        )
        appendTableRows(
            to: result,
            rows: rows,
            resolved: resolved,
            tabStops: tabStops
        )

        if rows.isEmpty {
            result.append(NSAttributedString(string: "\n", attributes: [
                .font: PlatformTypeConverter.bodyFont(),
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
        linkColor: NSColor
    ) {
        let font = PlatformTypeConverter.bodyFont()
        let content = convertInlineContent(
            text,
            baseFont: font,
            baseForegroundColor: foreground,
            linkColor: linkColor
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
        linkColor: NSColor
    ) {
        let font = PlatformTypeConverter.headingFont(level: level)
        let content = convertInlineContent(
            text,
            baseFont: font,
            baseForegroundColor: headingColor,
            linkColor: linkColor
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
        foreground: NSColor
    ) {
        let style = makeParagraphStyle(
            paragraphSpacing: 8,
            headIndent: indent,
            firstLineHeadIndent: indent
        )
        let attrs: [NSAttributedString.Key: Any] = [
            .font: PlatformTypeConverter.bodyFont(),
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
        let prefixAttr = resolvedListPrefix(prefix: prefix, checkbox: item.checkbox, color: ctx.resolved.secondaryColor)

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
                    resolved: ctx.resolved
                )
            case let .orderedList(items):
                appendOrderedList(to: result, items: items, colors: ctx.colors, theme: ctx.theme, depth: depth + 1)
            case let .unorderedList(items):
                appendUnorderedList(to: result, items: items, colors: ctx.colors, theme: ctx.theme, depth: depth + 1)
            default:
                let text = plainText(from: block)
                guard !text.isEmpty else { continue }
                appendListFallback(
                    to: result,
                    text: text,
                    isFirstBlock: isFirstBlock,
                    prefixAttr: prefixAttr,
                    style: style,
                    resolved: ctx.resolved
                )
            }
            isFirstBlock = false
        }
    }

    private static func resolvedListPrefix(
        prefix: String,
        checkbox: CheckboxState?,
        color: NSColor
    ) -> NSAttributedString {
        if let checkbox {
            return checkboxPrefix(checkbox, color: color)
        }
        return listPrefix(prefix, color: color)
    }

    private static func appendListParagraph(
        to result: NSMutableAttributedString,
        text: AttributedString,
        isFirstBlock: Bool,
        prefixAttr: NSAttributedString,
        style: NSParagraphStyle,
        resolved: ResolvedColors
    ) {
        let content = NSMutableAttributedString()
        if isFirstBlock {
            content.append(prefixAttr)
        }
        let inlineContent = convertInlineContent(
            text,
            baseFont: PlatformTypeConverter.bodyFont(),
            baseForegroundColor: resolved.foreground,
            linkColor: resolved.linkColor
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
        resolved: ResolvedColors
    ) {
        let content = NSMutableAttributedString()
        if isFirstBlock {
            content.append(prefixAttr)
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: PlatformTypeConverter.bodyFont(),
            .foregroundColor: resolved.foreground,
        ]
        content.append(NSAttributedString(string: text, attributes: attrs))
        let range = NSRange(location: 0, length: content.length)
        content.addAttribute(.paragraphStyle, value: style, range: range)
        content.append(terminator(with: style))
        result.append(content)
    }

    private static func listPrefix(_ prefix: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: prefix + "\t",
            attributes: [
                .font: PlatformTypeConverter.bodyFont(),
                .foregroundColor: color,
            ]
        )
    }

    private static func checkboxPrefix(_ state: CheckboxState, color: NSColor) -> NSAttributedString {
        let symbolName = state == .checked ? "checkmark.square.fill" : "square"
        let font = PlatformTypeConverter.bodyFont()
        let symbolSize = font.pointSize

        guard let symbolImage = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: state == .checked ? "checked" : "unchecked"
        )
        else {
            return listPrefix(state == .checked ? "[x]" : "[ ]", color: color)
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
        tabStops: [NSTextTab]
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
                PlatformTypeConverter.bodyFont(),
                toHaveTrait: .boldFontMask
            )
            let cellContent = convertInlineContent(
                column.header,
                baseFont: font,
                baseForegroundColor: resolved.headingColor,
                linkColor: resolved.linkColor
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
        tabStops: [NSTextTab]
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
                    baseFont: PlatformTypeConverter.bodyFont(),
                    baseForegroundColor: resolved.foreground,
                    linkColor: resolved.linkColor
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
