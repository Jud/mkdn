import Foundation

/// Identifies a cell by its row and column within a table.
///
/// Header row uses `row == -1`. Data rows use `row >= 0`.
/// This replaces `TableCellMap.CellPosition` with a standalone definition
/// for use across the attachment-based table pipeline.
public struct CellPosition: Hashable, Comparable, Sendable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.row != rhs.row { return lhs.row < rhs.row }
        return lhs.column < rhs.column
    }
}

/// Stateless serialization of table cell content for clipboard operations.
///
/// Produces the plain text Chrome puts on the clipboard for a selection that
/// spans table cells: cells joined with tabs, rows with newlines, and the
/// endpoint cells contributing only the selected substring.
public enum TableClipboardSerializer {
    /// Extracts the selected text for a Chrome-style document-order range.
    ///
    /// Every row from `start` to `end` contributes one line: the first row
    /// from the start cell rightward, the last row up to the end cell, rows
    /// between in full. Returns "" for a collapsed range.
    public static func plainText(
        range: TableTextRange,
        columns: [TableColumn],
        rows: [[AttributedString]]
    ) -> String {
        guard !range.isCollapsed, !columns.isEmpty else { return "" }
        let start = range.start
        let end = range.end

        var lines: [String] = []
        for row in start.cell.row ... end.cell.row {
            let firstColumn = row == start.cell.row ? start.cell.column : 0
            let lastColumn = row == end.cell.row ? end.cell.column : columns.count - 1
            guard firstColumn <= lastColumn else { continue }
            var values: [String] = []
            for column in firstColumn ... lastColumn {
                // swiftlint:disable:next legacy_objc_type
                let text = cellText(row: row, column: column, columns: columns, rows: rows) as NSString
                let position = CellPosition(row: row, column: column)
                if let selected = range.selectedRange(in: position, textLength: text.length) {
                    values.append(text.substring(with: selected))
                } else {
                    values.append("")
                }
            }
            lines.append(values.joined(separator: "\t"))
        }

        return lines.joined(separator: "\n")
    }

    /// Extracts plain text from a cell at the given row and column.
    private static func cellText(
        row: Int,
        column: Int,
        columns: [TableColumn],
        rows: [[AttributedString]]
    ) -> String {
        if row == -1 {
            guard column < columns.count else { return "" }
            return String(columns[column].header.characters)
        }
        guard row >= 0, row < rows.count, column < rows[row].count else { return "" }
        return String(rows[row][column].characters)
    }
}
