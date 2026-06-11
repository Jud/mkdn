#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Pure-computation engine that measures column widths from table cell content.
///
/// Implements the CSS automatic table layout algorithm (the one Chrome/Blink
/// uses for `table { width: max-content; max-width: 100% }`):
///
/// 1. Per column, measure the **min-content** width (widest unbreakable word)
///    and **max-content** width (widest single-line cell).
/// 2. If the max-content widths fit the container, use them — the table hugs
///    its content.
/// 3. If even the min-content widths overflow the container, use them anyway —
///    the table overflows (callers scroll horizontally); a column is never
///    squeezed below its longest word, so text never wraps mid-word.
/// 4. Otherwise distribute the width between the two bounds: each column gets
///    its min-content width plus a share of the surplus proportional to
///    `max − min`, exactly filling the container.
///
/// Uses `NSAttributedString` Core Text measurement for deterministic widths
/// with the same font metrics that SwiftUI `Text` ultimately resolves through.
enum TableColumnSizer {
    // MARK: - Constants

    static let horizontalCellPadding: CGFloat = 12
    static let verticalCellPadding: CGFloat = 8
    static let totalHorizontalPadding: CGFloat = horizontalCellPadding * 2
    static let headerDividerHeight: CGFloat = 1
    static let borderChrome: CGFloat = 2

    // MARK: - Result

    struct Result {
        let columnWidths: [CGFloat]
        /// Sum of the column widths. Greater than the container width when
        /// even min-content widths overflow; callers scroll horizontally.
        let totalWidth: CGFloat
    }

    /// Width-independent measurement of a table's columns: per column, the
    /// padded min-content (widest unbreakable word) and max-content (widest
    /// single-line cell) widths. Cacheable per font scale, so callers
    /// re-fitting at many widths (a width animation) pay only the O(columns)
    /// `fit` per frame.
    struct ColumnConstraints: Equatable {
        let minWidths: [CGFloat]
        let maxWidths: [CGFloat]
    }

    // MARK: - Column Width Computation

    /// Computes content-aware column widths for a Markdown table within
    /// `containerWidth`, per the CSS automatic table layout algorithm.
    /// The result overflows `containerWidth` only when the min-content
    /// widths cannot fit.
    static func computeWidths(
        columns: [TableColumn],
        rows: [[AttributedString]],
        containerWidth: CGFloat,
        font: PlatformTypeConverter.PlatformFont
    ) -> Result {
        fit(
            constraints: measureConstraints(columns: columns, rows: rows, font: font),
            containerWidth: containerWidth
        )
    }

    /// The per-cell Core Text measurement pass: min-content and max-content
    /// widths per column, padded.
    static func measureConstraints(
        columns: [TableColumn],
        rows: [[AttributedString]],
        font: PlatformTypeConverter.PlatformFont
    ) -> ColumnConstraints {
        let columnCount = columns.count
        guard columnCount > 0 else {
            return ColumnConstraints(minWidths: [], maxWidths: [])
        }

        let boldFont = PlatformTypeConverter.convertFont(font, toHaveTrait: .bold)

        var minWidths = [CGFloat](repeating: 0, count: columnCount)
        var maxWidths = [CGFloat](repeating: 0, count: columnCount)

        func accumulate(_ cell: AttributedString, column: Int, font: PlatformTypeConverter.PlatformFont) {
            let cellMax = measureCellWidth(cell, font: font)
            maxWidths[column] = max(maxWidths[column], cellMax)
            // The widest word can't be wider than the whole cell, so skip the
            // word measure when it can't raise the column's min.
            if cellMax > minWidths[column] {
                minWidths[column] = max(minWidths[column], measureCellMinWidth(cell, font: font))
            }
        }

        for (colIndex, column) in columns.enumerated() {
            accumulate(column.header, column: colIndex, font: boldFont)
        }
        for row in rows {
            for colIndex in 0 ..< min(row.count, columnCount) {
                accumulate(row[colIndex], column: colIndex, font: font)
            }
        }

        return ColumnConstraints(
            minWidths: minWidths.map { max($0 + totalHorizontalPadding, totalHorizontalPadding) },
            maxWidths: maxWidths.map { max($0 + totalHorizontalPadding, totalHorizontalPadding) }
        )
    }

    /// Distributes `containerWidth` across the columns per CSS automatic
    /// table layout (see type docs for the three cases).
    static func fit(constraints: ColumnConstraints, containerWidth: CGFloat) -> Result {
        let minWidths = constraints.minWidths
        let maxWidths = constraints.maxWidths
        guard !maxWidths.isEmpty else {
            return Result(columnWidths: [], totalWidth: 0)
        }

        let totalMax = maxWidths.reduce(0, +)
        if totalMax <= containerWidth {
            return Result(columnWidths: maxWidths, totalWidth: totalMax)
        }

        let totalMin = minWidths.reduce(0, +)
        if totalMin >= containerWidth {
            return Result(columnWidths: minWidths, totalWidth: totalMin)
        }

        let surplus = containerWidth - totalMin
        let range = totalMax - totalMin
        let widths = zip(minWidths, maxWidths).map { minWidth, maxWidth in
            minWidth + (maxWidth - minWidth) * surplus / range
        }
        return Result(columnWidths: widths, totalWidth: containerWidth)
    }

    // MARK: - Height Estimation

    /// Measures the total table height by wrapping each cell's text at its
    /// column width with Core Text, mirroring how the rendered SwiftUI grid
    /// wraps. Each row is as tall as its tallest cell.
    static func estimateTableHeight(
        columns: [TableColumn],
        rows: [[AttributedString]],
        columnWidths: [CGFloat],
        font: PlatformTypeConverter.PlatformFont
    ) -> CGFloat {
        let columnCount = columns.count
        guard columnCount > 0 else { return 0 }

        let boldFont = PlatformTypeConverter.convertFont(font, toHaveTrait: .bold)
        let lineHeight = PlatformTypeConverter.lineHeight(of: font)
        let boldLineHeight = PlatformTypeConverter.lineHeight(of: boldFont)

        let headerRowHeight = measureRowHeight(
            cells: columns.map(\.header),
            columnWidths: columnWidths,
            font: boldFont,
            lineHeight: boldLineHeight
        )

        var totalHeight = headerRowHeight + headerDividerHeight

        for row in rows {
            let rowHeight = measureRowHeight(
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

    // MARK: - Styled Measurement Text

    /// The cell text with bold/italic/code presentation intents applied per
    /// run — the same styles the rendered SwiftUI `Text` resolves — so
    /// column sizing, selection hit-testing, and highlight painting all wrap
    /// identically (`TableCellTextLayout` builds its mirror from this too).
    static func styledText(
        _ content: AttributedString,
        baseFont: PlatformTypeConverter.PlatformFont
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for run in content.runs {
            let runText = String(content.characters[run.range])
            var font = baseFont
            let intents = run.inlinePresentationIntent ?? []
            if intents.contains(.code) {
                font = .monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
            }
            var traits: PlatformTypeConverter.FontTrait = []
            if intents.contains(.stronglyEmphasized) { traits.insert(.bold) }
            if intents.contains(.emphasized) { traits.insert(.italic) }
            if !traits.isEmpty {
                font = PlatformTypeConverter.convertFont(font, toHaveTrait: traits)
            }
            result.append(NSAttributedString(string: runText, attributes: [.font: font]))
        }
        return result
    }

    // MARK: - Private Helpers

    private static func measureCellWidth(
        _ content: AttributedString,
        font: PlatformTypeConverter.PlatformFont
    ) -> CGFloat {
        guard !content.characters.isEmpty else { return 0 }
        return ceil(styledText(content, baseFont: font).size().width)
    }

    /// Min-content width of a cell: the widest unbreakable word. Measured in
    /// one Core Text pass by breaking at whitespace in place — attributes
    /// survive, so each word measures in its real font — and taking the
    /// bounding width of the multi-line layout.
    private static func measureCellMinWidth(
        _ content: AttributedString,
        font: PlatformTypeConverter.PlatformFont
    ) -> CGFloat {
        let styled = NSMutableAttributedString(
            attributedString: styledText(content, baseFont: font)
        )
        let plainText = styled.string as NSString // swiftlint:disable:this legacy_objc_type
        guard plainText.length > 0 else { return 0 }
        // Same-length replacements, so indices captured up front stay valid.
        for index in 0 ..< plainText.length {
            guard let scalar = Unicode.Scalar(plainText.character(at: index)),
                  CharacterSet.whitespacesAndNewlines.contains(scalar)
            else { continue }
            styled.replaceCharacters(in: NSRange(location: index, length: 1), with: "\n")
        }
        let bounds = styled.boundingRect(
            with: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return ceil(bounds.width)
    }

    /// Overshoot factor for the cheap provisional-height heuristic
    /// (`ProvisionalHeightEstimator`), which estimates wrapped lines from
    /// character counts rather than measuring; word-boundary breaks produce
    /// lines shorter than the available width, so the simple estimate runs
    /// too optimistic without it.
    static let wrappingOverhead: CGFloat = 1.2

    private static func measureRowHeight(
        cells: [AttributedString],
        columnWidths: [CGFloat],
        font: PlatformTypeConverter.PlatformFont,
        lineHeight: CGFloat
    ) -> CGFloat {
        let columnCount = columnWidths.count
        var maxTextHeight = lineHeight

        for colIndex in 0 ..< min(cells.count, columnCount) {
            let availableWidth = columnWidths[colIndex] - totalHorizontalPadding
            guard availableWidth > 0 else { continue }
            guard !cells[colIndex].characters.isEmpty else { continue }
            let nsAttrString = styledText(cells[colIndex], baseFont: font)
            let bounds = nsAttrString.boundingRect(
                with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            maxTextHeight = max(maxTextHeight, ceil(bounds.height))
        }

        return maxTextHeight + verticalCellPadding * 2
    }
}
