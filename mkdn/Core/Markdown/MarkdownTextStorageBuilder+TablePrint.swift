#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Print-only table text generation for `MarkdownTextStorageBuilder`.
///
/// Produces visible plain text (bold headers, body font for data rows)
/// using tab stops for column alignment. Unlike the deleted inline-text
/// path, this does not create `TableCellMap`, `TableAttributes`, or
/// `TableColorInfo` — print doesn't need selection, find, or overlay.
extension MarkdownTextStorageBuilder {
    // MARK: - Types

    private struct PrintRowStyle {
        let font: PlatformTypeConverter.PlatformFont
        let foregroundColor: PlatformTypeConverter.PlatformColor
        let tabStops: [NSTextTab]
        let rowHeight: CGFloat
        let paragraphSpacing: CGFloat
    }

    // MARK: - Print Table Text

    // swiftlint:disable:next function_body_length
    static func appendTablePrintText(
        to result: NSMutableAttributedString,
        columns: [TableColumn],
        rows: [[AttributedString]],
        colors: ThemeColors,
        scaleFactor: CGFloat
    ) {
        let columnCount = columns.count
        guard columnCount > 0 else { return }

        let font = PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor)
        let boldFont = PlatformTypeConverter.convertFont(font, toHaveTrait: .bold)

        let sizer = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: defaultEstimationContainerWidth,
            font: font
        )
        let columnWidths = sizer.columnWidths

        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let boldLineHeight = ceil(boldFont.ascender - boldFont.descender + boldFont.leading)

        let tabStops = buildPrintTabStops(columns: columns, columnWidths: columnWidths)

        let headingColor = PlatformTypeConverter.color(from: colors.headingColor)
        let foreground = PlatformTypeConverter.color(from: colors.foreground)

        // Header row
        let headerHeight = estimatePrintRowHeight(
            cells: columns.map(\.header),
            columnWidths: columnWidths,
            font: boldFont,
            lineHeight: boldLineHeight
        )
        let headerStyle = PrintRowStyle(
            font: boldFont,
            foregroundColor: headingColor,
            tabStops: tabStops,
            rowHeight: headerHeight,
            paragraphSpacing: rows.isEmpty ? blockSpacing : 0
        )
        appendPrintRow(
            to: result,
            cells: columns.map { String($0.header.characters) },
            style: headerStyle
        )

        // Data rows
        for (rowIdx, row) in rows.enumerated() {
            let cells = (0 ..< columnCount).map { colIdx in
                colIdx < row.count ? String(row[colIdx].characters) : ""
            }
            let rowHeight = estimatePrintRowHeight(
                cells: row,
                columnWidths: columnWidths,
                font: font,
                lineHeight: lineHeight
            )
            let isLastRow = rowIdx == rows.count - 1
            let rowStyle = PrintRowStyle(
                font: font,
                foregroundColor: foreground,
                tabStops: tabStops,
                rowHeight: rowHeight,
                paragraphSpacing: isLastRow ? blockSpacing : 0
            )
            appendPrintRow(
                to: result,
                cells: cells,
                style: rowStyle
            )
        }
    }

    // MARK: - Tab Stop Construction

    private static func buildPrintTabStops(
        columns: [TableColumn],
        columnWidths: [CGFloat]
    ) -> [NSTextTab] {
        var tabStops: [NSTextTab] = []
        var cumWidth: CGFloat = 0
        for colIdx in 0 ..< columns.count {
            let alignment: NSTextAlignment = switch columns[colIdx].alignment {
            case .left: .left
            case .center: .center
            case .right: .right
            }
            cumWidth += columnWidths[colIdx]
            tabStops.append(NSTextTab(textAlignment: alignment, location: cumWidth))
        }
        return tabStops
    }

    // MARK: - Row Rendering

    private static func appendPrintRow(
        to result: NSMutableAttributedString,
        cells: [String],
        style: PrintRowStyle
    ) {
        let rowParagraphStyle = NSMutableParagraphStyle()
        rowParagraphStyle.lineSpacing = 0
        rowParagraphStyle.paragraphSpacing = style.paragraphSpacing
        rowParagraphStyle.minimumLineHeight = style.rowHeight
        rowParagraphStyle.maximumLineHeight = style.rowHeight
        rowParagraphStyle.lineBreakMode = .byClipping
        rowParagraphStyle.tabStops = style.tabStops

        let rowContent = NSMutableAttributedString()
        for (colIdx, cellText) in cells.enumerated() {
            if colIdx > 0 {
                rowContent.append(NSAttributedString(string: "\t", attributes: [
                    .font: style.font,
                    .foregroundColor: style.foregroundColor,
                ]))
            }
            rowContent.append(NSAttributedString(string: cellText, attributes: [
                .font: style.font,
                .foregroundColor: style.foregroundColor,
            ]))
        }

        let fullRange = NSRange(location: 0, length: rowContent.length)
        rowContent.addAttribute(.paragraphStyle, value: rowParagraphStyle, range: fullRange)

        rowContent.append(NSAttributedString(string: "\n", attributes: [
            .font: style.font,
            .foregroundColor: style.foregroundColor,
            .paragraphStyle: rowParagraphStyle,
        ]))

        result.append(rowContent)
    }

    // MARK: - Row Height Estimation

    private static func estimatePrintRowHeight(
        cells: [AttributedString],
        columnWidths: [CGFloat],
        font: PlatformTypeConverter.PlatformFont,
        lineHeight: CGFloat
    ) -> CGFloat {
        let columnCount = columnWidths.count
        var maxCellHeight = lineHeight

        for colIndex in 0 ..< min(cells.count, columnCount) {
            let plainText = String(cells[colIndex].characters)
            guard !plainText.isEmpty else { continue }
            let availableWidth = columnWidths[colIndex] - TableColumnSizer.totalHorizontalPadding
            guard availableWidth > 0 else { continue }

            let measured = NSAttributedString(
                string: plainText,
                attributes: [.font: font]
            )
            let rect = measured.boundingRect(
                with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            maxCellHeight = max(maxCellHeight, ceil(rect.height))
        }

        return maxCellHeight + TableColumnSizer.verticalCellPadding * 2
    }
}
