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

    @Test("Wide table of unbreakable cells overflows at min-content widths")
    func wideTableOverflowsAtMinContent() {
        // Single-word cells: min-content == max-content per column, and the
        // sum exceeds the container, so the table overflows (callers scroll)
        // rather than wrapping any word mid-glyph.
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

        #expect(result.columnWidths.count == 12)
        #expect(result.totalWidth > containerWidth)
        let constraints = TableColumnSizer.measureConstraints(
            columns: columns,
            rows: rows,
            font: font
        )
        #expect(result.columnWidths == constraints.minWidths)
        #expect(constraints.minWidths == constraints.maxWidths)
    }

    @Test("Single unbreakable wide column overflows the container")
    func singleWideColumnOverflowsContainer() {
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

        // An unbreakable run is the column's min-content width; Chrome never
        // shrinks a column below it, the table overflows instead.
        #expect(result.columnWidths.count == 1)
        #expect(result.totalWidth > containerWidth)
        let expectedWidth = ceil(
            NSAttributedString(string: longString, attributes: [.font: font]).size().width
        ) + TableColumnSizer.totalHorizontalPadding
        #expect(result.columnWidths[0] == expectedWidth)
    }

    @Test("Column never compressed below its longest word")
    func minContentFloorHolds() {
        let longToken = "supercalifragilisticexpialidocious-identifier"
        let columns = [
            TableColumn(header: AttributedString("Token"), alignment: .left),
            TableColumn(header: AttributedString("Description"), alignment: .left),
        ]
        let rows: [[AttributedString]] = [
            [
                AttributedString(longToken),
                AttributedString(
                    String(repeating: "some wrapping descriptive text ", count: 10)
                ),
            ],
        ]

        let narrowContainer: CGFloat = 360
        let result = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: narrowContainer,
            font: font
        )

        let tokenWidth = ceil(
            NSAttributedString(string: longToken, attributes: [.font: font]).size().width
        ) + TableColumnSizer.totalHorizontalPadding
        #expect(result.columnWidths[0] >= tokenWidth)
    }

    @Test("Constrained table distributes surplus proportional to max minus min")
    func cssDistributionFormula() {
        let columns = [
            TableColumn(header: AttributedString("A"), alignment: .left),
            TableColumn(header: AttributedString("B"), alignment: .left),
        ]
        let rows: [[AttributedString]] = [
            [
                AttributedString(String(repeating: "alpha beta ", count: 20)),
                AttributedString(String(repeating: "gamma delta epsilon ", count: 20)),
            ],
        ]

        let constraints = TableColumnSizer.measureConstraints(
            columns: columns,
            rows: rows,
            font: font
        )
        let totalMin = constraints.minWidths.reduce(0, +)
        let totalMax = constraints.maxWidths.reduce(0, +)
        // Pick a container strictly between the two bounds so the
        // distribution case is exercised.
        let container = (totalMin + totalMax) / 2
        let result = TableColumnSizer.fit(constraints: constraints, containerWidth: container)

        #expect(abs(result.totalWidth - container) < 0.5)
        #expect(abs(result.columnWidths.reduce(0, +) - container) < 0.5)
        let surplus = container - totalMin
        let range = totalMax - totalMin
        for idx in 0 ..< 2 {
            let expected = constraints.minWidths[idx]
                + (constraints.maxWidths[idx] - constraints.minWidths[idx]) * surplus / range
            #expect(abs(result.columnWidths[idx] - expected) < 0.5)
        }
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

    @Test("Column widths and height track the container width")
    func sizingTracksContainerWidth() {
        let columns = [
            TableColumn(header: AttributedString("Info"), alignment: .left),
        ]
        let longContent = String(repeating: "word ", count: 80)
        let rows: [[AttributedString]] = [
            [AttributedString(longContent)],
        ]
        let narrowWidth: CGFloat = 300
        let wideWidth: CGFloat = 900

        let narrow = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: narrowWidth,
            font: font
        )
        let wide = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: wideWidth,
            font: font
        )

        // A reflow must change the column layout, not merely clamp the total.
        #expect(narrow.columnWidths != wide.columnWidths)
        #expect(narrow.totalWidth <= narrowWidth)

        let narrowHeight = TableColumnSizer.estimateTableHeight(
            columns: columns,
            rows: rows,
            columnWidths: narrow.columnWidths,
            font: font
        )
        let wideHeight = TableColumnSizer.estimateTableHeight(
            columns: columns,
            rows: rows,
            columnWidths: wide.columnWidths,
            font: font
        )

        // Narrower columns wrap more, so the table is taller.
        #expect(narrowHeight > wideHeight)
    }
}
