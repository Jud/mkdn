import AppKit

/// Context for building a single table row's invisible inline text.
struct TableRowContext {
    let font: NSFont
    let foregroundColor: NSColor
    let tabStops: [NSTextTab]
    let rowHeight: CGFloat
    let isLastRow: Bool
    let tableID: String
    let colorInfo: TableColorInfo
    let isHeader: Bool
    let textStartOffset: Int
}

/// Table invisible-text generation for `MarkdownTextStorageBuilder`.
///
/// Replaces the attachment-based table rendering with inline invisible text
/// (clear foreground) that participates in NSTextView selection, find, and
/// clipboard operations. The visual table rendering remains unchanged via
/// the existing SwiftUI `TableBlockView` overlay.
extension MarkdownTextStorageBuilder {
    // MARK: - Table Inline Text

    // swiftlint:disable:next function_parameter_count function_body_length
    static func appendTableInlineText(
        to result: NSMutableAttributedString,
        blockIndex: Int,
        block: MarkdownBlock,
        columns: [TableColumn],
        rows: [[AttributedString]],
        colors: ThemeColors,
        isPrint: Bool,
        tableOverlays: inout [TableOverlayInfo]
    ) {
        let columnCount = columns.count
        guard columnCount > 0 else { return }

        let scaleFactor: CGFloat = 1.0
        let font = PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor)
        let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)

        let sizer = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: defaultEstimationContainerWidth,
            font: font
        )
        let columnWidths = sizer.columnWidths

        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let boldLineHeight = ceil(boldFont.ascender - boldFont.descender + boldFont.leading)
        var rowHeights: [CGFloat] = []

        let headerHeight = estimateInlineRowHeight(
            cells: columns.map(\.header),
            columnWidths: columnWidths,
            font: boldFont,
            lineHeight: boldLineHeight
        )
        rowHeights.append(headerHeight)

        for row in rows {
            let rh = estimateInlineRowHeight(
                cells: row,
                columnWidths: columnWidths,
                font: font,
                lineHeight: lineHeight
            )
            rowHeights.append(rh)
        }

        let tableID = UUID().uuidString

        let colorInfo = TableColorInfo(
            background: PlatformTypeConverter.nsColor(from: colors.background),
            backgroundSecondary: PlatformTypeConverter.nsColor(from: colors.backgroundSecondary),
            border: PlatformTypeConverter.nsColor(from: colors.border),
            headerBackground: PlatformTypeConverter.nsColor(from: colors.backgroundSecondary),
            foreground: PlatformTypeConverter.nsColor(from: colors.foreground),
            headingColor: PlatformTypeConverter.nsColor(from: colors.headingColor)
        )

        let tabStops = buildTableTabStops(columns: columns, columnWidths: columnWidths)
        let textStartOffset = result.length
        var cellEntries: [TableCellMap.CellEntry] = []

        let headerForeground: NSColor = isPrint ? colorInfo.headingColor : .clear
        let headerCtx = TableRowContext(
            font: boldFont,
            foregroundColor: headerForeground,
            tabStops: tabStops,
            rowHeight: headerHeight,
            isLastRow: rows.isEmpty,
            tableID: tableID,
            colorInfo: colorInfo,
            isHeader: true,
            textStartOffset: textStartOffset
        )
        appendTableInlineRow(
            to: result,
            cells: columns.map { String($0.header.characters) },
            rowIndex: -1,
            ctx: headerCtx,
            cellEntries: &cellEntries
        )

        let dataForeground: NSColor = isPrint ? colorInfo.foreground : .clear
        for (rowIdx, row) in rows.enumerated() {
            let cells = (0 ..< columnCount).map { colIdx in
                colIdx < row.count ? String(row[colIdx].characters) : ""
            }
            let rowCtx = TableRowContext(
                font: font,
                foregroundColor: dataForeground,
                tabStops: tabStops,
                rowHeight: rowHeights[rowIdx + 1],
                isLastRow: rowIdx == rows.count - 1,
                tableID: tableID,
                colorInfo: colorInfo,
                isHeader: false,
                textStartOffset: textStartOffset
            )
            appendTableInlineRow(
                to: result,
                cells: cells,
                rowIndex: rowIdx,
                ctx: rowCtx,
                cellEntries: &cellEntries
            )
        }

        let cellMap = TableCellMap(
            cells: cellEntries,
            columnCount: columnCount,
            rowCount: rows.count,
            columnWidths: columnWidths,
            rowHeights: rowHeights,
            columns: columns
        )

        let tableRange = NSRange(
            location: textStartOffset,
            length: result.length - textStartOffset
        )
        result.addAttribute(TableAttributes.cellMap, value: cellMap, range: tableRange)

        tableOverlays.append(TableOverlayInfo(
            blockIndex: blockIndex,
            block: block,
            tableRangeID: tableID,
            cellMap: cellMap
        ))
    }

    // MARK: - Table Tab Stops

    private static func buildTableTabStops(
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

    // MARK: - Table Inline Row

    private static func appendTableInlineRow(
        to result: NSMutableAttributedString,
        cells: [String],
        rowIndex: Int,
        ctx: TableRowContext,
        cellEntries: inout [TableCellMap.CellEntry]
    ) {
        let rowStyle = NSMutableParagraphStyle()
        rowStyle.lineSpacing = 0
        rowStyle.paragraphSpacing = ctx.isLastRow ? blockSpacing : 0
        rowStyle.minimumLineHeight = ctx.rowHeight
        rowStyle.maximumLineHeight = ctx.rowHeight
        rowStyle.tabStops = ctx.tabStops

        let rowContent = NSMutableAttributedString()
        for (colIdx, cellText) in cells.enumerated() {
            if colIdx > 0 {
                rowContent.append(NSAttributedString(string: "\t", attributes: [
                    .font: ctx.font,
                    .foregroundColor: ctx.foregroundColor,
                ]))
            }

            let relativeOffset = result.length - ctx.textStartOffset + rowContent.length

            rowContent.append(NSAttributedString(string: cellText, attributes: [
                .font: ctx.font,
                .foregroundColor: ctx.foregroundColor,
            ]))

            let cellLength = cellText.utf16.count
            if cellLength > 0 {
                cellEntries.append(TableCellMap.CellEntry(
                    position: TableCellMap.CellPosition(row: rowIndex, column: colIdx),
                    range: NSRange(location: relativeOffset, length: cellLength),
                    content: cellText
                ))
            }
        }

        let fullRange = NSRange(location: 0, length: rowContent.length)
        rowContent.addAttribute(.paragraphStyle, value: rowStyle, range: fullRange)
        rowContent.addAttribute(TableAttributes.range, value: ctx.tableID, range: fullRange)
        rowContent.addAttribute(TableAttributes.colors, value: ctx.colorInfo, range: fullRange)

        if ctx.isHeader {
            // swiftlint:disable:next legacy_objc_type
            rowContent.addAttribute(TableAttributes.isHeader, value: true as NSNumber, range: fullRange)
        }

        rowContent.append(NSAttributedString(string: "\n", attributes: [
            .font: ctx.font,
            .foregroundColor: ctx.foregroundColor,
            .paragraphStyle: rowStyle,
            TableAttributes.range: ctx.tableID,
            TableAttributes.colors: ctx.colorInfo,
        ]))

        result.append(rowContent)
    }

    // MARK: - Table Row Height Estimation

    static func estimateInlineRowHeight(
        cells: [AttributedString],
        columnWidths: [CGFloat],
        font: NSFont,
        lineHeight: CGFloat
    ) -> CGFloat {
        let columnCount = columnWidths.count
        var maxLines = 1

        for colIndex in 0 ..< min(cells.count, columnCount) {
            let plainText = String(cells[colIndex].characters)
            guard !plainText.isEmpty else { continue }
            let measured = NSAttributedString(
                string: plainText,
                attributes: [.font: font]
            )
            let contentWidth = ceil(measured.size().width)
            let availableWidth = columnWidths[colIndex] - TableColumnSizer.totalHorizontalPadding
            if availableWidth > 0, contentWidth > availableWidth {
                let rawLines = contentWidth / availableWidth
                let adjustedLines = rawLines * TableColumnSizer.wrappingOverhead
                maxLines = max(maxLines, Int(ceil(adjustedLines)))
            }
        }

        return CGFloat(maxLines) * lineHeight + TableColumnSizer.verticalCellPadding * 2
    }
}
