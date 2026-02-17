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
    static let headerDividerHeight: CGFloat = 1
    static let borderChrome: CGFloat = 2

    // MARK: - Result

    struct Result {
        let columnWidths: [CGFloat]
        let totalWidth: CGFloat
    }

    // MARK: - Column Width Computation

    /// Computes content-aware column widths for a Markdown table, always fitting
    /// within `containerWidth`.
    ///
    /// Algorithm:
    /// 1. Measure intrinsic single-line width of every cell (header + data rows).
    /// 2. Take the maximum intrinsic width per column, add horizontal cell padding.
    /// 3. If total fits within `containerWidth`, use intrinsic widths as-is.
    /// 4. Otherwise, lock columns at or below their fair share and distribute
    ///    remaining space proportionally among wider columns.
    static func computeWidths(
        columns: [TableColumn],
        rows: [[AttributedString]],
        containerWidth: CGFloat,
        font: NSFont
    ) -> Result {
        let columnCount = columns.count
        guard columnCount > 0 else {
            return Result(columnWidths: [], totalWidth: 0)
        }

        let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)

        var intrinsicWidths = [CGFloat](repeating: 0, count: columnCount)
        for (colIndex, column) in columns.enumerated() {
            intrinsicWidths[colIndex] = measureCellWidth(column.header, font: boldFont)
        }
        for row in rows {
            for colIndex in 0 ..< min(row.count, columnCount) {
                let cellWidth = measureCellWidth(row[colIndex], font: font)
                intrinsicWidths[colIndex] = max(intrinsicWidths[colIndex], cellWidth)
            }
        }

        let paddedWidths = intrinsicWidths.map { width in
            max(width + totalHorizontalPadding, totalHorizontalPadding)
        }

        let totalPadded = paddedWidths.reduce(0, +)
        if totalPadded <= containerWidth {
            return Result(columnWidths: paddedWidths, totalWidth: totalPadded)
        }

        let compressed = compressColumns(paddedWidths, toFit: containerWidth)
        let totalWidth = min(compressed.reduce(0, +), containerWidth)
        return Result(columnWidths: compressed, totalWidth: totalWidth)
    }

    /// Proportionally compresses columns to fit within `targetWidth`.
    ///
    /// Columns at or below their fair share keep their intrinsic width.
    /// Remaining space is distributed proportionally among wider columns.
    private static func compressColumns(
        _ paddedWidths: [CGFloat],
        toFit targetWidth: CGFloat
    ) -> [CGFloat] {
        let count = paddedWidths.count
        var widths = paddedWidths
        var locked = [Bool](repeating: false, count: count)
        var lockedWidth: CGFloat = 0
        var remaining = count

        var changed = true
        while changed {
            changed = false
            guard remaining > 0 else { break }
            let fairShare = (targetWidth - lockedWidth) / CGFloat(remaining)
            for idx in 0 ..< count where !locked[idx] {
                if paddedWidths[idx] <= fairShare {
                    locked[idx] = true
                    lockedWidth += paddedWidths[idx]
                    remaining -= 1
                    widths[idx] = paddedWidths[idx]
                    changed = true
                }
            }
        }

        let available = targetWidth - lockedWidth
        let unlockedTotal = (0 ..< count).filter { !locked[$0] }.map { paddedWidths[$0] }.reduce(0, +)
        if unlockedTotal > 0 {
            for idx in 0 ..< count where !locked[idx] {
                let proportion = paddedWidths[idx] / unlockedTotal
                widths[idx] = max(floor(proportion * available), totalHorizontalPadding)
            }
        }
        return widths
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

    /// Word wrapping overhead factor applied when columns are compressed.
    /// Accounts for word-boundary breaks producing lines shorter than the
    /// available width, which makes the simple `contentWidth / availableWidth`
    /// estimate too optimistic.
    static let wrappingOverhead: CGFloat = 1.2

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
                let rawLines = contentWidth / availableWidth
                let adjustedLines = rawLines * wrappingOverhead
                maxLines = max(maxLines, Int(ceil(adjustedLines)))
            }
        }

        return CGFloat(maxLines) * lineHeight + verticalCellPadding * 2
    }
}
