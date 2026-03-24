import Foundation
import Testing
@testable import mkdnLib

@Suite("TableFindAdapter")
struct TableFindAdapterTests {
    // MARK: - Test Fixtures

    private let columns = [
        TableColumn(header: AttributedString("Name"), alignment: .left),
        TableColumn(header: AttributedString("Age"), alignment: .right),
        TableColumn(header: AttributedString("City"), alignment: .center),
    ]

    private let rows: [[AttributedString]] = [
        [AttributedString("Alice"), AttributedString("30"), AttributedString("NYC")],
        [AttributedString("Bob"), AttributedString("25"), AttributedString("LA")],
        [AttributedString("Carol"), AttributedString("35"), AttributedString("San Francisco")],
    ]

    // MARK: - Empty Query

    @Test("Empty query returns empty matches")
    func emptyQuery() {
        let matches = TableFindAdapter.findMatches(
            query: "", columns: columns, rows: rows
        )
        #expect(matches.isEmpty)
    }

    // MARK: - Single Match

    @Test("Single match in one cell returns that cell's position")
    func singleMatch() {
        let matches = TableFindAdapter.findMatches(
            query: "Bob", columns: columns, rows: rows
        )
        #expect(matches.count == 1)
        #expect(matches[0] == CellPosition(row: 1, column: 0))
    }

    // MARK: - Case Insensitive

    @Test("Case-insensitive match works (query 'alice' matches 'Alice')")
    func caseInsensitive() {
        let matches = TableFindAdapter.findMatches(
            query: "alice", columns: columns, rows: rows
        )
        #expect(matches.count == 1)
        #expect(matches[0] == CellPosition(row: 0, column: 0))
    }

    @Test("Case-sensitive match does not find mismatched case")
    func caseSensitiveNoMatch() {
        let matches = TableFindAdapter.findMatches(
            query: "alice", columns: columns, rows: rows, caseSensitive: true
        )
        #expect(matches.isEmpty)
    }

    @Test("Case-sensitive match finds exact case")
    func caseSensitiveExactMatch() {
        let matches = TableFindAdapter.findMatches(
            query: "Alice", columns: columns, rows: rows, caseSensitive: true
        )
        #expect(matches.count == 1)
        #expect(matches[0] == CellPosition(row: 0, column: 0))
    }

    // MARK: - Multiple Matches

    @Test("Multiple matches across cells return all positions")
    func multipleMatches() {
        // "a" appears in: header "Name" (col 0), header "Age" (col 1),
        // "Alice" (0,0), "LA" (1,2), "Carol" (2,0), "San Francisco" (2,2)
        let matches = TableFindAdapter.findMatches(
            query: "a", columns: columns, rows: rows
        )
        #expect(matches.count >= 4)

        // Verify at least the known positions are present
        let matchSet = Set(matches)
        #expect(matchSet.contains(CellPosition(row: -1, column: 0))) // "Name"
        #expect(matchSet.contains(CellPosition(row: 0, column: 0))) // "Alice"
        #expect(matchSet.contains(CellPosition(row: 1, column: 2))) // "LA"
        #expect(matchSet.contains(CellPosition(row: 2, column: 0))) // "Carol"
    }

    // MARK: - Header Search

    @Test("Header cells are searched and returned with row == -1")
    func headerCells() {
        let matches = TableFindAdapter.findMatches(
            query: "City", columns: columns, rows: rows
        )
        #expect(matches.count == 1)
        #expect(matches[0] == CellPosition(row: -1, column: 2))
        #expect(matches[0].row == -1)
    }

    // MARK: - No Match

    @Test("No match returns empty array")
    func noMatch() {
        let matches = TableFindAdapter.findMatches(
            query: "zzz_not_found", columns: columns, rows: rows
        )
        #expect(matches.isEmpty)
    }

    // MARK: - Partial Match

    @Test("Partial string match finds containing cells")
    func partialMatch() {
        let matches = TableFindAdapter.findMatches(
            query: "San", columns: columns, rows: rows
        )
        #expect(matches.count == 1)
        #expect(matches[0] == CellPosition(row: 2, column: 2))
    }

    // MARK: - Order

    @Test("Matches are returned in header-first, row-sequential order")
    func matchOrder() {
        let matches = TableFindAdapter.findMatches(
            query: "a", columns: columns, rows: rows
        )

        // All header matches should come before data matches
        let headerMatches = matches.filter { $0.row == -1 }
        let dataMatches = matches.filter { $0.row >= 0 }

        guard let lastHeaderIndex = matches.lastIndex(where: { $0.row == -1 }),
              let firstDataIndex = matches.firstIndex(where: { $0.row >= 0 })
        else { return }

        #expect(lastHeaderIndex < firstDataIndex)

        // Data matches should be in row order
        for i in 1 ..< dataMatches.count {
            #expect(dataMatches[i - 1].row <= dataMatches[i].row)
        }

        // Verify we have both header and data results
        #expect(!headerMatches.isEmpty)
        #expect(!dataMatches.isEmpty)
    }
}
