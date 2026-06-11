import Foundation
import Testing
@testable import mkdnLib

/// Fixture and expected strings mirror a live headless-Chrome capture of the
/// same table (2026-06-11): selections were set with `setBaseAndExtent` and
/// the expected values are Chrome's `selection.toString()` output verbatim.
@Suite("TableClipboardSerializer")
struct TableClipboardSerializerTests {
    let columns = [
        TableColumn(header: AttributedString("Name"), alignment: .left),
        TableColumn(header: AttributedString("Description"), alignment: .left),
        TableColumn(header: AttributedString("Status"), alignment: .left),
    ]
    let rows: [[AttributedString]] = [
        [
            AttributedString("alpha beta gamma"),
            AttributedString("first row middle cell content"),
            AttributedString("active"),
        ],
        [
            AttributedString("delta epsilon"),
            AttributedString("second row middle cell words"),
            AttributedString("paused"),
        ],
        [
            AttributedString("zeta eta theta"),
            AttributedString("third row middle cell tail"),
            AttributedString("done"),
        ],
    ]

    private func point(_ row: Int, _ column: Int, _ offset: Int) -> TableTextPoint {
        TableTextPoint(cell: CellPosition(row: row, column: column), offset: offset)
    }

    private func text(anchor: TableTextPoint, focus: TableTextPoint) -> String {
        TableClipboardSerializer.plainText(
            range: TableTextRange(anchor: anchor, focus: focus),
            columns: columns,
            rows: rows
        )
    }

    @Test("Cross-row selection matches Chrome: partial endpoints, full cells between")
    func crossRowSelection() {
        #expect(
            text(anchor: point(0, 0, 6), focus: point(1, 1, 10))
                == "beta gamma\tfirst row middle cell content\tactive\ndelta epsilon\tsecond row"
        )
    }

    @Test("Same-row span matches Chrome: tab-joined with partial endpoint cells")
    func sameRowSpan() {
        #expect(
            text(anchor: point(1, 0, 2), focus: point(1, 2, 3))
                == "lta epsilon\tsecond row middle cell words\tpau"
        )
    }

    @Test("Backward selection normalizes to document order")
    func backwardSelection() {
        #expect(
            text(anchor: point(2, 1, 5), focus: point(0, 1, 9))
                == " middle cell content\tactive\ndelta epsilon\t"
                + "second row middle cell words\tpaused\nzeta eta theta\tthird"
        )
    }

    @Test("Header participates as the first document-order row")
    func headerSpan() {
        #expect(
            text(anchor: point(-1, 1, 0), focus: point(0, 1, 5))
                == "Description\tStatus\nalpha beta gamma\tfirst"
        )
    }

    @Test("Intra-cell selection is the bare substring")
    func intraCellSelection() {
        #expect(text(anchor: point(0, 1, 6), focus: point(0, 1, 9)) == "row")
    }

    @Test("Collapsed range produces empty text")
    func collapsedRange() {
        #expect(text(anchor: point(0, 1, 6), focus: point(0, 1, 6)).isEmpty)
    }

    @Test("Full-table range serializes every cell")
    func fullTable() {
        let all = text(anchor: point(-1, 0, 0), focus: point(2, 2, 4))
        #expect(all == """
        Name\tDescription\tStatus
        alpha beta gamma\tfirst row middle cell content\tactive
        delta epsilon\tsecond row middle cell words\tpaused
        zeta eta theta\tthird row middle cell tail\tdone
        """)
    }

    @Test("Offsets beyond a cell's length clamp instead of crashing")
    func offsetsClamp() {
        #expect(
            text(anchor: point(0, 2, 0), focus: point(0, 2, 999)) == "active"
        )
    }
}

@Suite("TableTextRange")
struct TableTextRangeTests {
    private func point(_ row: Int, _ column: Int, _ offset: Int) -> TableTextPoint {
        TableTextPoint(cell: CellPosition(row: row, column: column), offset: offset)
    }

    @Test("Points order in document order: header first, then row-major")
    func pointOrdering() {
        #expect(point(-1, 2, 5) < point(0, 0, 0))
        #expect(point(0, 0, 3) < point(0, 0, 4))
        #expect(point(0, 2, 9) < point(1, 0, 0))
        #expect(point(1, 0, 0) < point(1, 1, 0))
    }

    @Test("Backward range normalizes start/end")
    func backwardNormalization() {
        let range = TableTextRange(anchor: point(2, 1, 5), focus: point(0, 1, 9))
        #expect(range.start == point(0, 1, 9))
        #expect(range.end == point(2, 1, 5))
        #expect(!range.isCollapsed)
    }

    @Test("Per-cell ranges: partial endpoints, full middles, nil outside")
    func perCellRanges() {
        let range = TableTextRange(anchor: point(0, 1, 4), focus: point(1, 1, 7))
        // Before the span.
        #expect(range.selectedRange(in: CellPosition(row: 0, column: 0), textLength: 10) == nil)
        // Start cell: from the anchor offset to the end.
        #expect(
            range.selectedRange(in: CellPosition(row: 0, column: 1), textLength: 10)
                == NSRange(location: 4, length: 6)
        )
        // Strictly between: fully covered.
        #expect(
            range.selectedRange(in: CellPosition(row: 0, column: 2), textLength: 6)
                == NSRange(location: 0, length: 6)
        )
        #expect(
            range.selectedRange(in: CellPosition(row: 1, column: 0), textLength: 13)
                == NSRange(location: 0, length: 13)
        )
        // End cell: from the start to the focus offset.
        #expect(
            range.selectedRange(in: CellPosition(row: 1, column: 1), textLength: 28)
                == NSRange(location: 0, length: 7)
        )
        // After the span.
        #expect(range.selectedRange(in: CellPosition(row: 1, column: 2), textLength: 6) == nil)
    }

    @Test("Collapsed range selects nothing")
    func collapsedSelectsNothing() {
        let range = TableTextRange(anchor: point(0, 0, 3), focus: point(0, 0, 3))
        #expect(range.selectedRange(in: CellPosition(row: 0, column: 0), textLength: 10) == nil)
    }
}
