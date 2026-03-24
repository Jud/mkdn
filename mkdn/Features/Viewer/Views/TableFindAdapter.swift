import Foundation

/// Stateless find-in-table adapter that searches cell content for query matches.
///
/// Searches each cell's plain text and returns `CellPosition` values for every
/// cell containing a match. Header cells use `row == -1`.
public enum TableFindAdapter {
    /// Searches all cells for the given query and returns matching positions.
    ///
    /// - Parameters:
    ///   - query: The search string. Empty query returns an empty array.
    ///   - columns: Table column definitions (headers searched with `row == -1`).
    ///   - rows: Table row data as attributed strings.
    ///   - caseSensitive: Whether to perform case-sensitive matching. Defaults to `false`.
    /// - Returns: An array of `CellPosition` values for every cell containing a match.
    public static func findMatches(
        query: String,
        columns: [TableColumn],
        rows: [[AttributedString]],
        caseSensitive: Bool = false
    ) -> [CellPosition] {
        guard !query.isEmpty else { return [] }

        let options: String.CompareOptions = caseSensitive ? [] : .caseInsensitive
        var matches: [CellPosition] = []

        // Search header cells
        for (colIndex, column) in columns.enumerated() {
            let headerText = String(column.header.characters)
            if headerText.range(of: query, options: options) != nil {
                matches.append(CellPosition(row: -1, column: colIndex))
            }
        }

        // Search data cells
        for (rowIndex, row) in rows.enumerated() {
            for (colIndex, cell) in row.enumerated() {
                let cellText = String(cell.characters)
                if cellText.range(of: query, options: options) != nil {
                    matches.append(CellPosition(row: rowIndex, column: colIndex))
                }
            }
        }

        return matches
    }
}
