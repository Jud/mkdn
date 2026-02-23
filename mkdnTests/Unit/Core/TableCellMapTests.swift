import AppKit
import Testing
@testable import mkdnLib

@Suite("TableCellMap")
struct TableCellMapTests {
    // MARK: - Test Fixtures

    /// Creates a simple 2-column, 2-data-row table cell map.
    ///
    /// Layout (character offsets relative to table start):
    /// - Header row: "Name\tAge\n"  -> Name at 0..3, Age at 5..7
    /// - Row 0:      "Alice\tThirty\n" -> Alice at 9..13, Thirty at 15..20
    /// - Row 1:      "Bob\tForty\n"    -> Bob at 22..24, Forty at 26..30
    private func makeSampleMap() -> TableCellMap {
        let columns = [
            TableColumn(header: AttributedString("Name"), alignment: .left),
            TableColumn(header: AttributedString("Age"), alignment: .right),
        ]

        let cells: [TableCellMap.CellEntry] = [
            .init(position: .init(row: -1, column: 0), range: NSRange(location: 0, length: 4), content: "Name"),
            .init(position: .init(row: -1, column: 1), range: NSRange(location: 5, length: 3), content: "Age"),
            .init(position: .init(row: 0, column: 0), range: NSRange(location: 9, length: 5), content: "Alice"),
            .init(position: .init(row: 0, column: 1), range: NSRange(location: 15, length: 6), content: "Thirty"),
            .init(position: .init(row: 1, column: 0), range: NSRange(location: 22, length: 3), content: "Bob"),
            .init(position: .init(row: 1, column: 1), range: NSRange(location: 26, length: 5), content: "Forty"),
        ]

        return TableCellMap(
            cells: cells,
            columnCount: 2,
            rowCount: 2,
            columnWidths: [100, 80],
            rowHeights: [24, 24, 24],
            columns: columns
        )
    }

    // MARK: - Binary Search

    @Test("Binary search finds correct cell for offset at start of cell")
    func cellAtStartOffset() {
        let map = makeSampleMap()
        let pos = map.cellAt(offset: 0)
        #expect(pos == TableCellMap.CellPosition(row: -1, column: 0))
    }

    @Test("Binary search finds correct cell for offset within cell")
    func cellAtMiddleOffset() {
        let map = makeSampleMap()
        let pos = map.cellAt(offset: 10)
        #expect(pos == TableCellMap.CellPosition(row: 0, column: 0))
    }

    @Test("Binary search finds correct cell for last character in cell")
    func cellAtLastCharOffset() {
        let map = makeSampleMap()
        // "Alice" is at 9..13 (length 5), so last char is at offset 13
        let pos = map.cellAt(offset: 13)
        #expect(pos == TableCellMap.CellPosition(row: 0, column: 0))
    }

    @Test("Binary search returns nil for offset in separator (tab/newline)")
    func cellAtSeparatorOffset() {
        let map = makeSampleMap()
        // Offset 4 is the tab between "Name" and "Age"
        let pos = map.cellAt(offset: 4)
        #expect(pos == nil)
    }

    @Test("Binary search returns nil for offset past all cells")
    func cellAtPastEnd() {
        let map = makeSampleMap()
        let pos = map.cellAt(offset: 999)
        #expect(pos == nil)
    }

    @Test("Binary search returns nil for negative offset")
    func cellAtNegativeOffset() {
        let map = makeSampleMap()
        let pos = map.cellAt(offset: -1)
        #expect(pos == nil)
    }

    @Test("Binary search returns nil on empty cell map")
    func cellAtEmptyMap() {
        let map = TableCellMap(
            cells: [],
            columnCount: 0,
            rowCount: 0,
            columnWidths: [],
            rowHeights: [],
            columns: []
        )
        #expect(map.cellAt(offset: 0) == nil)
    }

    // MARK: - Range Intersection

    @Test("Range intersection returns all overlapping cells")
    func cellsInRangeMultiple() {
        let map = makeSampleMap()
        // Range covering "Alice\tThirty" (offsets 9..20)
        let cells = map.cellsInRange(NSRange(location: 9, length: 12))
        #expect(cells.count == 2)
        #expect(cells.contains(TableCellMap.CellPosition(row: 0, column: 0)))
        #expect(cells.contains(TableCellMap.CellPosition(row: 0, column: 1)))
    }

    @Test("Range intersection returns single cell for exact range")
    func cellsInRangeExact() {
        let map = makeSampleMap()
        let cells = map.cellsInRange(NSRange(location: 0, length: 4))
        #expect(cells.count == 1)
        #expect(cells.contains(TableCellMap.CellPosition(row: -1, column: 0)))
    }

    @Test("Range intersection returns cells across rows")
    func cellsInRangeCrossRow() {
        let map = makeSampleMap()
        // Range spanning from row 0 col 1 through row 1 col 0
        let cells = map.cellsInRange(NSRange(location: 15, length: 10))
        #expect(cells.contains(TableCellMap.CellPosition(row: 0, column: 1)))
        #expect(cells.contains(TableCellMap.CellPosition(row: 1, column: 0)))
    }

    @Test("Range intersection returns empty set for zero-length range")
    func cellsInRangeZeroLength() {
        let map = makeSampleMap()
        let cells = map.cellsInRange(NSRange(location: 5, length: 0))
        #expect(cells.isEmpty)
    }

    @Test("Range intersection returns empty set for range outside all cells")
    func cellsInRangeOutside() {
        let map = makeSampleMap()
        let cells = map.cellsInRange(NSRange(location: 100, length: 10))
        #expect(cells.isEmpty)
    }

    @Test("Full table selection returns all cells")
    func cellsInRangeFullTable() {
        let map = makeSampleMap()
        let cells = map.cellsInRange(NSRange(location: 0, length: 31))
        #expect(cells.count == 6)
    }

    @Test("Range touching only separator returns empty set")
    func cellsInRangeSeparatorOnly() {
        let map = makeSampleMap()
        // Offset 4 is the tab between header cells; offset 8 is newline
        let cells = map.cellsInRange(NSRange(location: 4, length: 1))
        #expect(cells.isEmpty)
    }

    // MARK: - Range For Cell

    @Test("rangeFor returns correct range for existing cell")
    func rangeForExistingCell() {
        let map = makeSampleMap()
        let range = map.rangeFor(cell: TableCellMap.CellPosition(row: 0, column: 0))
        #expect(range == NSRange(location: 9, length: 5))
    }

    @Test("rangeFor returns nil for non-existent cell")
    func rangeForNonExistent() {
        let map = makeSampleMap()
        let range = map.rangeFor(cell: TableCellMap.CellPosition(row: 5, column: 0))
        #expect(range == nil)
    }

    @Test("rangeFor returns correct range for header cell")
    func rangeForHeaderCell() {
        let map = makeSampleMap()
        let range = map.rangeFor(cell: TableCellMap.CellPosition(row: -1, column: 1))
        #expect(range == NSRange(location: 5, length: 3))
    }

    // MARK: - Header Cell Distinction

    @Test("Header cells use row index -1")
    func headerCellsDistinguished() {
        let map = makeSampleMap()
        let headerCells = map.cells.filter { $0.position.row == -1 }
        #expect(headerCells.count == 2)
        #expect(headerCells[0].content == "Name")
        #expect(headerCells[1].content == "Age")
    }

    @Test("Data cells use row index 0+")
    func dataCellsDistinguished() {
        let map = makeSampleMap()
        let dataCells = map.cells.filter { $0.position.row >= 0 }
        #expect(dataCells.count == 4)
        for cell in dataCells {
            #expect(cell.position.row >= 0)
        }
    }

    // MARK: - Tab-Delimited Output

    @Test("Tab-delimited output preserves row/column structure")
    func tabDelimitedStructure() {
        let map = makeSampleMap()
        let allCells = Set(map.cells.map(\.position))
        let text = map.tabDelimitedText(for: allCells)

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        #expect(lines[0] == "Name\tAge")
        #expect(lines[1] == "Alice\tThirty")
        #expect(lines[2] == "Bob\tForty")
    }

    @Test("Tab-delimited output for partial selection includes empty columns")
    func tabDelimitedPartialSelection() {
        let map = makeSampleMap()
        let selected: Set<TableCellMap.CellPosition> = [
            .init(row: 0, column: 0),
        ]
        let text = map.tabDelimitedText(for: selected)

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 1)
        #expect(lines[0] == "Alice\t")
    }

    @Test("Tab-delimited output for empty selection returns empty string")
    func tabDelimitedEmptySelection() {
        let map = makeSampleMap()
        let text = map.tabDelimitedText(for: [])
        #expect(text.isEmpty)
    }

    @Test("Tab-delimited output excludes rows with no selected cells")
    func tabDelimitedSkipsUnselectedRows() {
        let map = makeSampleMap()
        let selected: Set<TableCellMap.CellPosition> = [
            .init(row: -1, column: 0),
            .init(row: -1, column: 1),
            .init(row: 1, column: 0),
            .init(row: 1, column: 1),
        ]
        let text = map.tabDelimitedText(for: selected)

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[0] == "Name\tAge")
        #expect(lines[1] == "Bob\tForty")
    }

    // MARK: - RTF Output

    @Test("RTF output generates valid data for selected cells")
    func rtfOutputGeneratesData() {
        let map = makeSampleMap()
        let allCells = Set(map.cells.map(\.position))
        let data = map.rtfData(for: allCells, colors: AppTheme.solarizedDark.colors)
        #expect(data != nil)
    }

    @Test("RTF output contains table row markers")
    func rtfOutputContainsRowMarkers() throws {
        let map = makeSampleMap()
        let allCells = Set(map.cells.map(\.position))
        let data = try #require(map.rtfData(for: allCells, colors: AppTheme.solarizedDark.colors))
        let rtfString = try #require(String(data: data, encoding: .utf8))

        #expect(rtfString.contains("\\trowd"))
        #expect(rtfString.contains("\\cell"))
        #expect(rtfString.contains("\\row"))
    }

    @Test("RTF output contains cell content text")
    func rtfOutputContainsContent() throws {
        let map = makeSampleMap()
        let allCells = Set(map.cells.map(\.position))
        let data = try #require(map.rtfData(for: allCells, colors: AppTheme.solarizedDark.colors))
        let rtfString = try #require(String(data: data, encoding: .utf8))

        #expect(rtfString.contains("Name"))
        #expect(rtfString.contains("Age"))
        #expect(rtfString.contains("Alice"))
        #expect(rtfString.contains("Thirty"))
        #expect(rtfString.contains("Bob"))
        #expect(rtfString.contains("Forty"))
    }

    @Test("RTF output returns nil for empty selection")
    func rtfOutputEmptySelection() {
        let map = makeSampleMap()
        let data = map.rtfData(for: [], colors: AppTheme.solarizedDark.colors)
        #expect(data == nil)
    }

    @Test("RTF output uses bold for header row")
    func rtfOutputBoldHeader() throws {
        let map = makeSampleMap()
        let headerCells: Set<TableCellMap.CellPosition> = [
            .init(row: -1, column: 0),
            .init(row: -1, column: 1),
        ]
        let data = try #require(map.rtfData(for: headerCells, colors: AppTheme.solarizedDark.colors))
        let rtfString = try #require(String(data: data, encoding: .utf8))

        #expect(rtfString.contains("\\b"))
    }

    @Test("RTF output escapes special characters")
    func rtfOutputEscapesSpecialChars() throws {
        let cells: [TableCellMap.CellEntry] = [
            .init(
                position: .init(row: 0, column: 0),
                range: NSRange(location: 0, length: 5),
                content: "a{b}c"
            ),
        ]
        let map = TableCellMap(
            cells: cells,
            columnCount: 1,
            rowCount: 1,
            columnWidths: [100],
            rowHeights: [24, 24],
            columns: [TableColumn(header: AttributedString("Col"), alignment: .left)]
        )

        let selected: Set<TableCellMap.CellPosition> = [.init(row: 0, column: 0)]
        let data = try #require(map.rtfData(for: selected, colors: AppTheme.solarizedDark.colors))
        let rtfString = try #require(String(data: data, encoding: .utf8))

        #expect(rtfString.contains("a\\{b\\}c"))
    }

    // MARK: - CellPosition Ordering

    @Test("CellPosition sorts by row then column")
    func cellPositionOrdering() {
        let positions: [TableCellMap.CellPosition] = [
            .init(row: 1, column: 1),
            .init(row: -1, column: 0),
            .init(row: 0, column: 1),
            .init(row: 0, column: 0),
            .init(row: -1, column: 1),
        ]

        let sorted = positions.sorted()
        #expect(sorted[0] == .init(row: -1, column: 0))
        #expect(sorted[1] == .init(row: -1, column: 1))
        #expect(sorted[2] == .init(row: 0, column: 0))
        #expect(sorted[3] == .init(row: 0, column: 1))
        #expect(sorted[4] == .init(row: 1, column: 1))
    }

    // MARK: - Metadata

    @Test("Cell map preserves column and row counts")
    func metadataCounts() {
        let map = makeSampleMap()
        #expect(map.columnCount == 2)
        #expect(map.rowCount == 2)
        #expect(map.columnWidths.count == 2)
        #expect(map.rowHeights.count == 3)
        #expect(map.columns.count == 2)
    }

    @Test("Cells are sorted by range location after init")
    func cellsSortedAfterInit() {
        let cells: [TableCellMap.CellEntry] = [
            .init(position: .init(row: 0, column: 1), range: NSRange(location: 10, length: 3), content: "b"),
            .init(position: .init(row: 0, column: 0), range: NSRange(location: 0, length: 3), content: "a"),
        ]
        let map = TableCellMap(
            cells: cells,
            columnCount: 2,
            rowCount: 1,
            columnWidths: [50, 50],
            rowHeights: [24, 24],
            columns: []
        )

        #expect(map.cells[0].range.location == 0)
        #expect(map.cells[1].range.location == 10)
    }

    @Test("TableCellMap can be stored as NSAttributedString attribute value")
    func cellMapAsAttribute() {
        let map = makeSampleMap()
        let str = NSMutableAttributedString(string: "test")
        str.addAttribute(
            TableAttributes.cellMap,
            value: map,
            range: NSRange(location: 0, length: str.length)
        )

        let retrieved = str.attribute(
            TableAttributes.cellMap,
            at: 0,
            effectiveRange: nil
        ) as? TableCellMap

        #expect(retrieved === map)
    }
}
