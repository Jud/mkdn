import Foundation
import Testing
@testable import mkdnLib

@Suite("TableClipboardSerializer")
struct TableClipboardSerializerTests {
    // MARK: - Test Fixtures

    private let columns = [
        TableColumn(header: AttributedString("Name"), alignment: .left),
        TableColumn(header: AttributedString("Age"), alignment: .right),
        TableColumn(header: AttributedString("City"), alignment: .center),
    ]

    private let rows: [[AttributedString]] = [
        [AttributedString("Alice"), AttributedString("30"), AttributedString("NYC")],
        [AttributedString("Bob"), AttributedString("25"), AttributedString("LA")],
        [AttributedString("Carol"), AttributedString("35"), AttributedString("SF")],
    ]

    // MARK: - Tab-Delimited: .all

    @Test("Tab-delimited output for .all contains all cells")
    func tabDelimitedAll() {
        let text = TableClipboardSerializer.tabDelimitedText(
            selection: .all, columns: columns, rows: rows
        )

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 4)
        #expect(lines[0] == "Name\tAge\tCity")
        #expect(lines[1] == "Alice\t30\tNYC")
        #expect(lines[2] == "Bob\t25\tLA")
        #expect(lines[3] == "Carol\t35\tSF")
    }

    // MARK: - Tab-Delimited: .cells

    @Test("Tab-delimited output for .cells returns only selected cells")
    func tabDelimitedCells() {
        let selected: Set<CellPosition> = [
            CellPosition(row: 0, column: 0),
            CellPosition(row: 0, column: 2),
        ]
        let text = TableClipboardSerializer.tabDelimitedText(
            selection: .cells(selected), columns: columns, rows: rows
        )

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 1)
        #expect(lines[0] == "Alice\t\tNYC")
    }

    // MARK: - Tab-Delimited: .rectangular

    @Test("Tab-delimited output for .rectangular returns sub-grid")
    func tabDelimitedRectangular() {
        let text = TableClipboardSerializer.tabDelimitedText(
            selection: .rectangular(rows: 0 ..< 2, columns: 0 ..< 2),
            columns: columns,
            rows: rows
        )

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[0] == "Alice\t30\t")
        #expect(lines[1] == "Bob\t25\t")
    }

    // MARK: - Tab-Delimited: .rows

    @Test("Tab-delimited output for .rows returns complete rows")
    func tabDelimitedRows() {
        let text = TableClipboardSerializer.tabDelimitedText(
            selection: .rows(IndexSet([0, 2])),
            columns: columns,
            rows: rows
        )

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[0] == "Alice\t30\tNYC")
        #expect(lines[1] == "Carol\t35\tSF")
    }

    // MARK: - Tab-Delimited: .columns

    @Test("Tab-delimited output for .columns returns complete columns including headers")
    func tabDelimitedColumns() {
        let text = TableClipboardSerializer.tabDelimitedText(
            selection: .columns(IndexSet([1])),
            columns: columns,
            rows: rows
        )

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 4)
        #expect(lines[0] == "\tAge\t")
        #expect(lines[1] == "\t30\t")
        #expect(lines[2] == "\t25\t")
        #expect(lines[3] == "\t35\t")
    }

    // MARK: - Tab-Delimited: .empty

    @Test("Tab-delimited output for .empty returns empty string")
    func tabDelimitedNone() {
        let text = TableClipboardSerializer.tabDelimitedText(
            selection: .empty, columns: columns, rows: rows
        )
        #expect(text.isEmpty)
    }

    // MARK: - Tab-Delimited: header row

    @Test("Header row (row == -1) included when selected via .cells")
    func tabDelimitedHeaderRow() {
        let selected: Set<CellPosition> = [
            CellPosition(row: -1, column: 0),
            CellPosition(row: -1, column: 1),
            CellPosition(row: -1, column: 2),
        ]
        let text = TableClipboardSerializer.tabDelimitedText(
            selection: .cells(selected), columns: columns, rows: rows
        )

        #expect(text == "Name\tAge\tCity")
    }

    // MARK: - Markdown Output

    @Test("Markdown output produces valid table syntax with alignment markers")
    func markdownAllSelection() {
        let text = TableClipboardSerializer.markdownText(
            selection: .all, columns: columns, rows: rows
        )

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 5)
        #expect(lines[0] == "| Name | Age | City |")
        #expect(lines[1] == "| :--- | ---: | :---: |")
        #expect(lines[2] == "| Alice | 30 | NYC |")
        #expect(lines[3] == "| Bob | 25 | LA |")
        #expect(lines[4] == "| Carol | 35 | SF |")
    }

    @Test("Markdown output for .empty returns empty string")
    func markdownNone() {
        let text = TableClipboardSerializer.markdownText(
            selection: .empty, columns: columns, rows: rows
        )
        #expect(text.isEmpty)
    }

    @Test("Markdown output for .rows includes placeholder header")
    func markdownRowsWithoutHeader() {
        let text = TableClipboardSerializer.markdownText(
            selection: .rows(IndexSet([0])),
            columns: columns,
            rows: rows
        )

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        // Placeholder header for data-only selection
        #expect(lines[0] == "|  |  |  |")
        #expect(lines[1] == "| :--- | ---: | :---: |")
        #expect(lines[2] == "| Alice | 30 | NYC |")
    }

    // MARK: - CellPosition

    @Test("CellPosition sorts by row then column")
    func cellPositionOrdering() {
        let positions: [CellPosition] = [
            CellPosition(row: 1, column: 1),
            CellPosition(row: -1, column: 0),
            CellPosition(row: 0, column: 1),
            CellPosition(row: 0, column: 0),
            CellPosition(row: -1, column: 1),
        ]

        let sorted = positions.sorted()
        #expect(sorted[0] == CellPosition(row: -1, column: 0))
        #expect(sorted[1] == CellPosition(row: -1, column: 1))
        #expect(sorted[2] == CellPosition(row: 0, column: 0))
        #expect(sorted[3] == CellPosition(row: 0, column: 1))
        #expect(sorted[4] == CellPosition(row: 1, column: 1))
    }

    @Test("CellPosition equality works correctly")
    func cellPositionEquality() {
        let pos1 = CellPosition(row: 0, column: 1)
        let pos2 = CellPosition(row: 0, column: 1)
        let pos3 = CellPosition(row: 1, column: 0)

        #expect(pos1 == pos2)
        #expect(pos1 != pos3)
    }

    @Test("CellPosition is Hashable for use in Sets")
    func cellPositionHashable() {
        var positions = Set<CellPosition>()
        positions.insert(CellPosition(row: 0, column: 0))
        positions.insert(CellPosition(row: 0, column: 0))
        positions.insert(CellPosition(row: 1, column: 0))

        #expect(positions.count == 2)
    }

    // MARK: - SelectionShape

    @Test("SelectionShape .empty produces empty tab-delimited output")
    func selectionShapeNone() {
        let text = TableClipboardSerializer.tabDelimitedText(
            selection: .empty, columns: columns, rows: rows
        )
        #expect(text.isEmpty)
    }

    @Test("SelectionShape .all includes header and all data rows")
    func selectionShapeAll() {
        let text = TableClipboardSerializer.tabDelimitedText(
            selection: .all, columns: columns, rows: rows
        )
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        // Header + 3 data rows
        #expect(lines.count == 4)
    }
}
