import AppKit

/// Pure-computation engine that measures column widths from table cell content.
///
/// Uses `NSAttributedString.size()` for deterministic width measurement with the same
/// Core Text font metrics that SwiftUI `Text` ultimately resolves through.
enum TableColumnSizer {
    // MARK: - Constants

    static let horizontalCellPadding: CGFloat = 13
    static let verticalCellPadding: CGFloat = 6
    static let totalHorizontalPadding: CGFloat = horizontalCellPadding * 2
    static let maxColumnWidthFraction: CGFloat = 0.6
    static let headerDividerHeight: CGFloat = 1
    static let borderChrome: CGFloat = 2

    // MARK: - Result

    struct Result {
        let columnWidths: [CGFloat]
        let totalWidth: CGFloat
        let needsHorizontalScroll: Bool
    }

    // MARK: - Column Width Computation

    /// Computes content-aware column widths for a Markdown table.
    ///
    /// Algorithm:
    /// 1. Measure intrinsic single-line width of every cell (header + data rows).
    /// 2. Take the maximum intrinsic width per column.
    /// 3. Add horizontal cell padding (13pt x 2 = 26pt) to each column.
    /// 4. Cap each column at `containerWidth * 0.6`.
    /// 5. Sum all column widths; determine table width and scroll need.
    static func computeWidths(
        columns: [TableColumn],
        rows: [[AttributedString]],
        containerWidth: CGFloat,
        font: NSFont
    ) -> Result {
        let columnCount = columns.count
        guard columnCount > 0 else {
            return Result(columnWidths: [], totalWidth: 0, needsHorizontalScroll: false)
        }

        let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        let maxColumnWidth = containerWidth * maxColumnWidthFraction

        var columnWidths = [CGFloat](repeating: 0, count: columnCount)

        for (colIndex, column) in columns.enumerated() {
            let headerWidth = measureCellWidth(column.header, font: boldFont)
            columnWidths[colIndex] = headerWidth
        }

        for row in rows {
            for colIndex in 0 ..< min(row.count, columnCount) {
                let cellWidth = measureCellWidth(row[colIndex], font: font)
                columnWidths[colIndex] = max(columnWidths[colIndex], cellWidth)
            }
        }

        for colIndex in 0 ..< columnCount {
            let paddedWidth = columnWidths[colIndex] + totalHorizontalPadding
            columnWidths[colIndex] = min(paddedWidth, maxColumnWidth)
            columnWidths[colIndex] = max(columnWidths[colIndex], totalHorizontalPadding)
        }

        let totalContentWidth = columnWidths.reduce(0, +)
        let needsHorizontalScroll = totalContentWidth > containerWidth
        let totalWidth = min(totalContentWidth, containerWidth)

        return Result(
            columnWidths: columnWidths,
            totalWidth: totalWidth,
            needsHorizontalScroll: needsHorizontalScroll
        )
    }

    // MARK: - Height Estimation

    /// Estimates the total table height accounting for text wrapping.
    ///
    /// For each row, checks whether any cell's content width exceeds its column width.
    /// When wrapping is expected, estimates the number of wrapped lines and scales
    /// the row height accordingly.
    static func estimateTableHeight(
        columns: [TableColumn],
        rows: [[AttributedString]],
        columnWidths: [CGFloat],
        font: NSFont
    ) -> CGFloat {
        let columnCount = columns.count
        guard columnCount > 0 else { return 0 }

        let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let boldLineHeight = ceil(boldFont.ascender - boldFont.descender + boldFont.leading)

        let headerRowHeight = estimateRowHeight(
            cells: columns.map(\.header),
            columnWidths: columnWidths,
            font: boldFont,
            lineHeight: boldLineHeight
        )

        var totalHeight = headerRowHeight + headerDividerHeight

        for row in rows {
            let rowHeight = estimateRowHeight(
                cells: row,
                columnWidths: columnWidths,
                font: font,
                lineHeight: lineHeight
            )
            totalHeight += rowHeight
        }

        totalHeight += borderChrome

        return ceil(totalHeight)
    }

    // MARK: - Private Helpers

    private static func measureCellWidth(
        _ content: AttributedString,
        font: NSFont
    ) -> CGFloat {
        let plainText = String(content.characters)
        guard !plainText.isEmpty else { return 0 }
        let nsAttrString = NSAttributedString(
            string: plainText,
            attributes: [.font: font]
        )
        return ceil(nsAttrString.size().width)
    }

    private static func estimateRowHeight(
        cells: [AttributedString],
        columnWidths: [CGFloat],
        font: NSFont,
        lineHeight: CGFloat
    ) -> CGFloat {
        let columnCount = columnWidths.count
        var maxLines = 1

        for colIndex in 0 ..< min(cells.count, columnCount) {
            let contentWidth = measureCellWidth(cells[colIndex], font: font)
            let availableWidth = columnWidths[colIndex] - totalHorizontalPadding
            if availableWidth > 0, contentWidth > availableWidth {
                let estimatedLines = Int(ceil(contentWidth / availableWidth))
                maxLines = max(maxLines, estimatedLines)
            }
        }

        return CGFloat(maxLines) * lineHeight + verticalCellPadding * 2
    }
}
