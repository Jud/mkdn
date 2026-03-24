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

/// Describes the shape of a table selection for clipboard and highlight operations.
public enum SelectionShape: Sendable {
    case empty
    case cells(Set<CellPosition>)
    case rows(IndexSet)
    case columns(IndexSet)
    case rectangular(rows: Range<Int>, columns: Range<Int>)
    case all
}

/// Stateless serialization of table cell content for clipboard operations.
///
/// Produces tab-delimited plain text or Markdown table syntax from a selection
/// shape applied to table data.
public enum TableClipboardSerializer {
    // MARK: - Tab-Delimited Text

    /// Extracts plain text from selected cells, joining columns with tabs
    /// and rows with newlines.
    ///
    /// For `.empty` returns empty string. For `.all` returns all cells.
    /// For `.cells` returns only those cells. For `.rectangular` returns the sub-grid.
    /// For `.rows` / `.columns` returns those slices.
    /// Header row uses `row == -1` convention.
    public static func tabDelimitedText(
        selection: SelectionShape,
        columns: [TableColumn],
        rows: [[AttributedString]]
    ) -> String {
        let columnCount = columns.count
        guard columnCount > 0 else { return "" }

        let selectedCells = expandSelection(
            selection, columnCount: columnCount, rowCount: rows.count
        )
        guard !selectedCells.isEmpty else { return "" }

        let sortedRows = Set(selectedCells.map(\.row)).sorted()
        var lines: [String] = []

        for row in sortedRows {
            var values: [String] = []
            for col in 0 ..< columnCount {
                let pos = CellPosition(row: row, column: col)
                if selectedCells.contains(pos) {
                    values.append(cellText(row: row, column: col, columns: columns, rows: rows))
                } else {
                    values.append("")
                }
            }
            lines.append(values.joined(separator: "\t"))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Markdown Text

    /// Produces valid Markdown table syntax for the selected region.
    public static func markdownText(
        selection: SelectionShape,
        columns: [TableColumn],
        rows: [[AttributedString]]
    ) -> String {
        let columnCount = columns.count
        guard columnCount > 0 else { return "" }

        let selectedCells = expandSelection(
            selection, columnCount: columnCount, rowCount: rows.count
        )
        guard !selectedCells.isEmpty else { return "" }

        let selectedColumns = Set(selectedCells.map(\.column)).sorted()
        let selectedRows = Set(selectedCells.map(\.row)).sorted()

        let hasHeader = selectedRows.contains(-1)
        let dataRows = selectedRows.filter { $0 >= 0 }

        var lines: [String] = []

        // Header row
        if hasHeader {
            let headerCells = selectedColumns.map { col in
                cellText(row: -1, column: col, columns: columns, rows: rows)
            }
            lines.append("| " + headerCells.joined(separator: " | ") + " |")
        } else {
            // Generate placeholder header if data rows are selected without header
            let placeholderCells = selectedColumns.map { _ in "" }
            lines.append("| " + placeholderCells.joined(separator: " | ") + " |")
        }

        // Alignment row
        let alignmentCells = selectedColumns.map { col -> String in
            guard col < columns.count else { return "---" }
            switch columns[col].alignment {
            case .left: return ":---"
            case .center: return ":---:"
            case .right: return "---:"
            }
        }
        lines.append("| " + alignmentCells.joined(separator: " | ") + " |")

        // Data rows
        for row in dataRows {
            let rowCells = selectedColumns.map { col in
                cellText(row: row, column: col, columns: columns, rows: rows)
            }
            lines.append("| " + rowCells.joined(separator: " | ") + " |")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private Helpers

    /// Expands a `SelectionShape` into a concrete set of cell positions.
    private static func expandSelection(
        _ selection: SelectionShape,
        columnCount: Int,
        rowCount: Int
    ) -> Set<CellPosition> {
        switch selection {
        case .empty:
            return []
        case let .cells(positions):
            return positions
        case let .rows(indexSet):
            var result = Set<CellPosition>()
            for row in indexSet {
                for col in 0 ..< columnCount {
                    result.insert(CellPosition(row: row, column: col))
                }
            }
            return result
        case let .columns(indexSet):
            var result = Set<CellPosition>()
            for col in indexSet {
                // Include header
                result.insert(CellPosition(row: -1, column: col))
                for row in 0 ..< rowCount {
                    result.insert(CellPosition(row: row, column: col))
                }
            }
            return result
        case let .rectangular(rowRange, colRange):
            var result = Set<CellPosition>()
            for row in rowRange {
                for col in colRange {
                    result.insert(CellPosition(row: row, column: col))
                }
            }
            return result
        case .all:
            var result = Set<CellPosition>()
            for col in 0 ..< columnCount {
                result.insert(CellPosition(row: -1, column: col))
            }
            for row in 0 ..< rowCount {
                for col in 0 ..< columnCount {
                    result.insert(CellPosition(row: row, column: col))
                }
            }
            return result
        }
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
