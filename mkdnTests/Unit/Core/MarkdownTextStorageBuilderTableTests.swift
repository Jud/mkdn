import AppKit
import Testing
@testable import mkdnLib

@Suite("MarkdownTextStorageBuilder Table Inline Text")
struct MarkdownTextStorageBuilderTableTests {
    let theme: AppTheme = .solarizedDark

    // MARK: - Helpers

    private func buildSingle(_ block: MarkdownBlock) -> TextStorageResult {
        let indexed = IndexedBlock(index: 0, block: block)
        return MarkdownTextStorageBuilder.build(blocks: [indexed], theme: theme)
    }

    private var tableColumns: [TableColumn] {
        [
            TableColumn(header: AttributedString("Name"), alignment: .left),
            TableColumn(header: AttributedString("Age"), alignment: .right),
        ]
    }

    private var tableRows: [[AttributedString]] {
        [
            [AttributedString("Alice"), AttributedString("30")],
            [AttributedString("Bob"), AttributedString("25")],
        ]
    }

    // MARK: - Inline Text Generation

    @Test("Table generates inline text instead of attachment")
    func tableGeneratesInlineText() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        #expect(result.attachments.isEmpty)
        let plainText = result.attributedString.string
        #expect(plainText.contains("Name"))
        #expect(plainText.contains("Alice"))
        #expect(plainText.contains("Bob"))
    }

    @Test("Table text has clear foreground color for invisible rendering")
    func tableTextClearForeground() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let str = result.attributedString
        var hasClearForeground = false
        str.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: str.length)
        ) { value, _, _ in
            if let color = value as? NSColor, color == .clear {
                hasClearForeground = true
            }
        }
        #expect(hasClearForeground)
    }

    @Test("Table text contains tab-separated cell content")
    func tableTextTabSeparated() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let plainText = result.attributedString.string
        #expect(plainText.contains("Name\tAge"))
        #expect(plainText.contains("Alice\t30"))
        #expect(plainText.contains("Bob\t25"))
    }

    // MARK: - Table Attributes

    @Test("Table text has TableAttributes.range on all table characters")
    func tableTextHasRangeAttribute() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let str = result.attributedString
        var tableCharCount = 0
        str.enumerateAttribute(
            TableAttributes.range,
            in: NSRange(location: 0, length: str.length)
        ) { value, range, _ in
            if value is String {
                tableCharCount += range.length
            }
        }
        #expect(tableCharCount > 0)
    }

    @Test("Table text has TableAttributes.cellMap on all table characters")
    func tableTextHasCellMapAttribute() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let str = result.attributedString
        var hasCellMap = false
        str.enumerateAttribute(
            TableAttributes.cellMap,
            in: NSRange(location: 0, length: str.length)
        ) { value, _, _ in
            if value is TableCellMap {
                hasCellMap = true
            }
        }
        #expect(hasCellMap)
    }

    @Test("Table text has TableAttributes.colors on all table characters")
    func tableTextHasColorsAttribute() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let str = result.attributedString
        var hasColors = false
        str.enumerateAttribute(
            TableAttributes.colors,
            in: NSRange(location: 0, length: str.length)
        ) { value, _, _ in
            if value is TableColorInfo {
                hasColors = true
            }
        }
        #expect(hasColors)
    }

    @Test("Table header row has isHeader attribute set to true")
    func tableHeaderHasIsHeaderAttribute() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let str = result.attributedString
        var headerCharCount = 0
        str.enumerateAttribute(
            TableAttributes.isHeader,
            in: NSRange(location: 0, length: str.length)
        ) { value, range, _ in
            // swiftlint:disable:next legacy_objc_type
            if let num = value as? NSNumber, num.boolValue {
                headerCharCount += range.length
            }
        }
        #expect(headerCharCount > 0)
    }

    @Test("Table data rows do not have isHeader attribute")
    func tableDataRowsNoIsHeader() {
        let columns = [TableColumn(header: AttributedString("X"), alignment: .left)]
        let rows: [[AttributedString]] = [[AttributedString("Data")]]
        let result = buildSingle(.table(columns: columns, rows: rows))
        let str = result.attributedString
        let plainText = str.string
        guard let dataRange = plainText.range(of: "Data") else {
            Issue.record("Expected to find 'Data' in table text")
            return
        }
        let nsRange = NSRange(dataRange, in: plainText)
        let isHeader = str.attribute(
            TableAttributes.isHeader,
            at: nsRange.location,
            effectiveRange: nil
        )
        #expect(isHeader == nil)
    }

    // MARK: - Print Mode

    @Test("Print mode table text has visible foreground")
    func printModeTableVisibleForeground() {
        let indexed = IndexedBlock(
            index: 0,
            block: .table(columns: tableColumns, rows: tableRows)
        )
        let result = MarkdownTextStorageBuilder.build(
            blocks: [indexed],
            theme: theme,
            isPrint: true
        )
        let str = result.attributedString
        var allClear = true
        str.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: str.length)
        ) { value, _, _ in
            if let color = value as? NSColor, color != .clear {
                allClear = false
            }
        }
        #expect(!allClear)
    }

    // MARK: - TableOverlayInfo

    @Test("TextStorageResult includes tableOverlays for table blocks")
    func textStorageResultIncludesTableOverlays() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        #expect(result.tableOverlays.count == 1)
        #expect(!result.tableOverlays[0].tableRangeID.isEmpty)
        #expect(result.tableOverlays[0].cellMap.columnCount == 2)
        #expect(result.tableOverlays[0].cellMap.rowCount == 2)
        #expect(result.tableOverlays[0].blockIndex == 0)
    }

    @Test("Multiple tables produce separate tableOverlays entries")
    func multipleTablesProduceSeparateOverlays() {
        let columns = [TableColumn(header: AttributedString("A"), alignment: .left)]
        let blocks = [
            IndexedBlock(index: 0, block: .table(columns: columns, rows: [[AttributedString("1")]])),
            IndexedBlock(index: 1, block: .table(columns: columns, rows: [[AttributedString("2")]])),
        ]
        let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: theme)
        #expect(result.tableOverlays.count == 2)
        #expect(result.tableOverlays[0].tableRangeID != result.tableOverlays[1].tableRangeID)
    }

    @Test("Table with no rows generates header-only text")
    func tableEmptyRowsGeneratesHeaderOnly() {
        let columns = [TableColumn(header: AttributedString("Col"), alignment: .left)]
        let result = buildSingle(.table(columns: columns, rows: []))
        let plainText = result.attributedString.string
        #expect(plainText.contains("Col"))
        #expect(result.tableOverlays.count == 1)
        #expect(result.tableOverlays[0].cellMap.rowCount == 0)
    }

    // MARK: - CellMap Accuracy

    @Test("Table cellMap entries have correct cell positions")
    func tableCellMapPositions() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let cellMap = result.tableOverlays[0].cellMap
        let allPositions = Set(cellMap.cells.map(\.position))
        #expect(allPositions.contains(TableCellMap.CellPosition(row: -1, column: 0)))
        #expect(allPositions.contains(TableCellMap.CellPosition(row: -1, column: 1)))
        #expect(allPositions.contains(TableCellMap.CellPosition(row: 0, column: 0)))
        #expect(allPositions.contains(TableCellMap.CellPosition(row: 0, column: 1)))
        #expect(allPositions.contains(TableCellMap.CellPosition(row: 1, column: 0)))
        #expect(allPositions.contains(TableCellMap.CellPosition(row: 1, column: 1)))
    }

    @Test("Table cellMap entries have correct content strings")
    func tableCellMapContent() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let cellMap = result.tableOverlays[0].cellMap
        let contentByPosition = Dictionary(
            cellMap.cells.map { ($0.position, $0.content) }
        ) { first, _ in first }
        #expect(contentByPosition[TableCellMap.CellPosition(row: -1, column: 0)] == "Name")
        #expect(contentByPosition[TableCellMap.CellPosition(row: -1, column: 1)] == "Age")
        #expect(contentByPosition[TableCellMap.CellPosition(row: 0, column: 0)] == "Alice")
        #expect(contentByPosition[TableCellMap.CellPosition(row: 0, column: 1)] == "30")
    }

    @Test("Table cellMap ranges correctly identify cell text in attributed string")
    func tableCellMapRangesAccurate() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let str = result.attributedString
        let cellMap = result.tableOverlays[0].cellMap

        var tableStart = 0
        str.enumerateAttribute(
            TableAttributes.range,
            in: NSRange(location: 0, length: str.length)
        ) { value, range, stop in
            if value is String {
                tableStart = range.location
                stop.pointee = true
            }
        }

        for cell in cellMap.cells {
            let absRange = NSRange(
                location: tableStart + cell.range.location,
                length: cell.range.length
            )
            // swiftlint:disable:next legacy_objc_type
            let cellText = (str.string as NSString).substring(with: absRange)
            #expect(cellText == cell.content)
        }
    }

    // MARK: - Paragraph Style

    @Test("Table paragraph style has fixed line heights matching row height estimates")
    func tableParagraphStyleLineHeights() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let str = result.attributedString
        let attrs = str.attributes(at: 0, effectiveRange: nil)
        guard let style = attrs[.paragraphStyle] as? NSParagraphStyle else {
            Issue.record("Expected paragraph style on table text")
            return
        }
        #expect(style.minimumLineHeight > 0)
        #expect(style.minimumLineHeight == style.maximumLineHeight)
    }
}
