import AppKit
import Testing

@testable import mkdnLib

@Suite("TableColumnSizer")
struct TableColumnSizerTests {
    let font = PlatformTypeConverter.bodyFont()
    let containerWidth: CGFloat = 600

    // MARK: - Width Computation

    @Test("Narrow table fits content within container")
    func narrowTableFitsContent() {
        let columns = [
            TableColumn(header: AttributedString("Name"), alignment: .left),
            TableColumn(header: AttributedString("Age"), alignment: .left),
        ]
        let rows: [[AttributedString]] = [
            [AttributedString("Alice"), AttributedString("30")],
        ]

        let result = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: containerWidth,
            font: font
        )

        #expect(result.totalWidth < containerWidth)
        #expect(result.totalWidth <= containerWidth)
    }

    @Test("Widest cell sets column width with 26pt padding")
    func widestCellSetsColumnWidth() {
        let columns = [
            TableColumn(header: AttributedString("X"), alignment: .left),
        ]
        let rows: [[AttributedString]] = [
            [AttributedString("Short")],
            [AttributedString("A longer cell value")],
        ]

        let result = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: containerWidth,
            font: font
        )

        let widestText = "A longer cell value"
        let nsAttrString = NSAttributedString(
            string: widestText,
            attributes: [.font: font]
        )
        let expectedWidth = ceil(nsAttrString.size().width)
            + TableColumnSizer.totalHorizontalPadding

        #expect(result.columnWidths.count == 1)
        #expect(result.columnWidths[0] == expectedWidth)
    }

    @Test("Equal content produces approximately equal widths")
    func equalContentProducesEqualWidths() {
        let columns = [
            TableColumn(header: AttributedString("AAAA"), alignment: .left),
            TableColumn(header: AttributedString("AAAA"), alignment: .left),
            TableColumn(header: AttributedString("AAAA"), alignment: .left),
        ]
        let rows: [[AttributedString]] = [
            [
                AttributedString("Data1"),
                AttributedString("Data2"),
                AttributedString("Data3"),
            ],
        ]

        let result = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: containerWidth,
            font: font
        )

        #expect(result.columnWidths.count == 3)
        guard let maxWidth = result.columnWidths.max(),
              let minWidth = result.columnWidths.min()
        else {
            Issue.record("Expected non-empty column widths")
            return
        }
        #expect(maxWidth - minWidth <= 2)
    }

    @Test("Wide table with 12 columns compresses to fit container")
    func wideTableCompressesToFitContainer() {
        let columns = (0 ..< 12).map { idx in
            TableColumn(
                header: AttributedString("Column\(idx)"),
                alignment: .left
            )
        }
        let rows: [[AttributedString]] = [
            (0 ..< 12).map { AttributedString("Value\($0)") },
        ]

        let result = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: containerWidth,
            font: font
        )

        #expect(result.totalWidth <= containerWidth)
        #expect(result.columnWidths.count == 12)
        for width in result.columnWidths {
            #expect(width >= TableColumnSizer.totalHorizontalPadding)
        }
    }

    @Test("Single wide column capped at containerWidth")
    func singleWideColumnCappedAtContainer() {
        let longString = String(repeating: "W", count: 500)
        let columns = [
            TableColumn(header: AttributedString("H"), alignment: .left),
        ]
        let rows: [[AttributedString]] = [
            [AttributedString(longString)],
        ]

        let result = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: containerWidth,
            font: font
        )

        #expect(result.columnWidths.count == 1)
        #expect(result.totalWidth <= containerWidth)
    }

    @Test("Padding included in every column width (>= 26pt)")
    func paddingIncludedInWidth() {
        let columns = [
            TableColumn(header: AttributedString("A"), alignment: .left),
            TableColumn(header: AttributedString("B"), alignment: .left),
        ]
        let rows: [[AttributedString]] = [
            [AttributedString("x"), AttributedString("y")],
        ]

        let result = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: containerWidth,
            font: font
        )

        for width in result.columnWidths {
            #expect(width >= TableColumnSizer.totalHorizontalPadding)
        }
    }

    @Test("Header bold font used for measurement when header is wider")
    func headerBoldFontUsedForMeasurement() {
        let wideHeader = "WideHeaderText"
        let narrowData = "x"
        let columns = [
            TableColumn(
                header: AttributedString(wideHeader),
                alignment: .left
            ),
        ]
        let rows: [[AttributedString]] = [
            [AttributedString(narrowData)],
        ]

        let result = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: containerWidth,
            font: font
        )

        let boldFont = NSFontManager.shared.convert(
            font,
            toHaveTrait: .boldFontMask
        )
        let boldWidth = ceil(
            NSAttributedString(
                string: wideHeader,
                attributes: [.font: boldFont]
            ).size().width
        )
        let regularWidth = ceil(
            NSAttributedString(
                string: wideHeader,
                attributes: [.font: font]
            ).size().width
        )
        let expectedColumnWidth = boldWidth
            + TableColumnSizer.totalHorizontalPadding

        #expect(boldWidth > regularWidth)
        #expect(result.columnWidths[0] == expectedColumnWidth)
    }

    @Test("Empty rows produce minimum widths (26pt = totalHorizontalPadding)")
    func emptyRowsProduceMinimumWidths() {
        let columns = [
            TableColumn(header: AttributedString(""), alignment: .left),
            TableColumn(header: AttributedString(""), alignment: .left),
        ]
        let rows: [[AttributedString]] = [
            [AttributedString(""), AttributedString("")],
        ]

        let result = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: containerWidth,
            font: font
        )

        for width in result.columnWidths {
            #expect(width == TableColumnSizer.totalHorizontalPadding)
        }
    }

    // MARK: - Height Estimation

    @Test("Height estimate accounts for wrapping in long content")
    func heightEstimateAccountsForWrapping() {
        let columns = [
            TableColumn(header: AttributedString("Info"), alignment: .left),
        ]
        let shortRows: [[AttributedString]] = [
            [AttributedString("OK")],
        ]
        let longContent = String(repeating: "word ", count: 80)
        let longRows: [[AttributedString]] = [
            [AttributedString(longContent)],
        ]

        let shortResult = TableColumnSizer.computeWidths(
            columns: columns,
            rows: shortRows,
            containerWidth: containerWidth,
            font: font
        )
        let longResult = TableColumnSizer.computeWidths(
            columns: columns,
            rows: longRows,
            containerWidth: containerWidth,
            font: font
        )

        let shortHeight = TableColumnSizer.estimateTableHeight(
            columns: columns,
            rows: shortRows,
            columnWidths: shortResult.columnWidths,
            font: font
        )
        let longHeight = TableColumnSizer.estimateTableHeight(
            columns: columns,
            rows: longRows,
            columnWidths: longResult.columnWidths,
            font: font
        )

        #expect(longHeight > shortHeight)
    }
}
