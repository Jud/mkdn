import AppKit

/// Maps character offsets in a table's invisible text to cell positions
/// and provides content extraction for clipboard operations.
///
/// Stored as an `NSAttributedString` attribute value (via ``TableAttributes/cellMap``)
/// on every character within a table's invisible text range. Provides O(log n) cell
/// lookup via binary search on sorted cell start positions, and O(n) range intersection
/// for selection mapping.
///
/// This is a class (not struct) because `NSAttributedString` attribute values must be
/// `NSObject` subclasses or bridged types for reliable attribute enumeration.
final class TableCellMap: NSObject {
    /// Identifies a cell by its row and column within the table.
    ///
    /// Header row uses `row == -1`. Data rows use `row >= 0`.
    struct CellPosition: Hashable, Comparable, Sendable {
        let row: Int
        let column: Int

        static func < (lhs: Self, rhs: Self) -> Bool {
            if lhs.row != rhs.row { return lhs.row < rhs.row }
            return lhs.column < rhs.column
        }
    }

    /// A single cell's metadata: position, character range, and plain text content.
    struct CellEntry: Sendable {
        let position: CellPosition
        /// Character range relative to the table's text start offset.
        let range: NSRange
        let content: String
    }

    /// All cells sorted by `range.location` (ascending).
    let cells: [CellEntry]
    let columnCount: Int
    /// Number of data rows (header excluded).
    let rowCount: Int
    var columnWidths: [CGFloat]
    /// Row heights indexed as: 0 = header, 1+ = data rows.
    var rowHeights: [CGFloat]
    let columns: [TableColumn]

    init(
        cells: [CellEntry],
        columnCount: Int,
        rowCount: Int,
        columnWidths: [CGFloat],
        rowHeights: [CGFloat],
        columns: [TableColumn]
    ) {
        self.cells = cells.sorted { $0.range.location < $1.range.location }
        self.columnCount = columnCount
        self.rowCount = rowCount
        self.columnWidths = columnWidths
        self.rowHeights = rowHeights
        self.columns = columns
    }

    // MARK: - Cell Lookup

    /// Binary search: character offset (relative to table text start) -> CellPosition.
    ///
    /// Returns `nil` if the offset falls outside any cell range (e.g., in a tab
    /// or newline separator between cells).
    func cellAt(offset: Int) -> CellPosition? {
        guard !cells.isEmpty else { return nil }

        var low = 0
        var high = cells.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let entry = cells[mid]
            let start = entry.range.location
            let end = start + entry.range.length

            if offset < start {
                high = mid - 1
            } else if offset >= end {
                low = mid + 1
            } else {
                return entry.position
            }
        }

        return nil
    }

    /// Range intersection: selected range -> set of all cell positions whose
    /// character ranges overlap the given range.
    ///
    /// Both `range` and cell entry ranges are relative to the table text start.
    func cellsInRange(_ range: NSRange) -> Set<CellPosition> {
        guard range.length > 0, !cells.isEmpty else { return [] }

        let rangeEnd = range.location + range.length
        var result = Set<CellPosition>()

        // Find the first cell that could overlap via binary search
        var low = 0
        var high = cells.count - 1
        var firstIndex = cells.count

        while low <= high {
            let mid = (low + high) / 2
            let cellEnd = cells[mid].range.location + cells[mid].range.length
            if cellEnd <= range.location {
                low = mid + 1
            } else {
                firstIndex = mid
                high = mid - 1
            }
        }

        // Walk forward from firstIndex, collecting overlapping cells
        for idx in firstIndex ..< cells.count {
            let entry = cells[idx]
            if entry.range.location >= rangeEnd {
                break
            }
            result.insert(entry.position)
        }

        return result
    }

    /// Cell position -> character range (relative to table text start).
    ///
    /// Returns `nil` if the position does not exist in this table.
    func rangeFor(cell: CellPosition) -> NSRange? {
        cells.first { $0.position == cell }?.range
    }

    // MARK: - Content Extraction

    /// Generates tab-delimited text from the given set of selected cells.
    ///
    /// Rows are separated by newlines. Columns within a row are separated by
    /// tab characters. Only rows that contain at least one selected cell are
    /// included. Within each included row, all columns are output (empty string
    /// for unselected cells) to preserve column alignment.
    func tabDelimitedText(for selectedCells: Set<CellPosition>) -> String {
        guard !selectedCells.isEmpty else { return "" }

        let cellsByPosition = Dictionary(cells.map { ($0.position, $0.content) }) { first, _ in first }

        let rows = selectedRows(from: selectedCells)
        var lines: [String] = []

        for row in rows {
            var columns: [String] = []
            for col in 0 ..< columnCount {
                let pos = CellPosition(row: row, column: col)
                if selectedCells.contains(pos) {
                    columns.append(cellsByPosition[pos] ?? "")
                } else {
                    columns.append("")
                }
            }
            lines.append(columns.joined(separator: "\t"))
        }

        return lines.joined(separator: "\n")
    }

    /// Generates RTF data representing the selected cells as a table.
    ///
    /// The RTF output uses standard table markup (`\trowd`, `\cell`, `\row`)
    /// so that rich text editors render it as a formatted table. Column widths
    /// are derived from `columnWidths` converted to twips (1pt = 20 twips).
    func rtfData(for selectedCells: Set<CellPosition>, colors: ThemeColors) -> Data? {
        guard !selectedCells.isEmpty else { return nil }

        let cellsByPosition = Dictionary(cells.map { ($0.position, $0.content) }) { first, _ in first }

        let rows = selectedRows(from: selectedCells)

        var rtf = "{\\rtf1\\ansi\\deff0\n"
        rtf += "{\\fonttbl{\\f0 Helvetica;}}\n"

        let fgColor = PlatformTypeConverter.nsColor(from: colors.foreground)
        let hdColor = PlatformTypeConverter.nsColor(from: colors.headingColor)
        let fgRGB = rgbComponents(fgColor)
        let hdRGB = rgbComponents(hdColor)
        rtf += "{\\colortbl;"
        rtf += "\\red\(fgRGB.r)\\green\(fgRGB.g)\\blue\(fgRGB.b);"
        rtf += "\\red\(hdRGB.r)\\green\(hdRGB.g)\\blue\(hdRGB.b);"
        rtf += "}\n"

        let cumulativeTwips = cumulativeColumnTwips()

        for row in rows {
            let isHeader = row == -1
            rtf += "\\trowd\\trgaph108"
            for twip in cumulativeTwips {
                rtf += "\\cellx\(twip)"
            }
            rtf += "\n"

            let colorIndex = isHeader ? 2 : 1
            let fontStyle = isHeader ? "\\b" : ""

            for col in 0 ..< columnCount {
                let pos = CellPosition(row: row, column: col)
                let text: String = if selectedCells.contains(pos) {
                    escapeRTF(cellsByPosition[pos] ?? "")
                } else {
                    ""
                }
                rtf += "\\intbl\\cf\(colorIndex)\(fontStyle) \(text)\\cell\n"
            }
            rtf += "\\row\n"
        }

        rtf += "}"
        return rtf.data(using: .utf8)
    }

    // MARK: - Private Helpers

    /// Returns sorted unique row indices from the selected cells.
    private func selectedRows(from selectedCells: Set<CellPosition>) -> [Int] {
        Set(selectedCells.map(\.row)).sorted()
    }

    /// Computes cumulative column boundary positions in twips for RTF table markup.
    private func cumulativeColumnTwips() -> [Int] {
        var cumulative: CGFloat = 0
        return columnWidths.map { width in
            cumulative += width
            return Int(cumulative * 20)
        }
    }

    /// Extracts RGB components (0-255) from an NSColor.
    private func rgbComponents(_ color: NSColor) -> (r: Int, g: Int, b: Int) {
        let converted = color.usingColorSpace(.sRGB) ?? color
        return (
            r: Int(converted.redComponent * 255),
            g: Int(converted.greenComponent * 255),
            b: Int(converted.blueComponent * 255)
        )
    }

    /// Escapes special RTF characters in plain text.
    private func escapeRTF(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
    }
}
