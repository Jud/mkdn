import Foundation
import Testing
@testable import mkdnLib

@Suite("TableSelectionState")
struct TableSelectionStateTests {
    // MARK: - selectCell

    @Test("selectCell produces .cells with single element")
    @MainActor func selectCellSingle() {
        let state = TableSelectionState()
        let position = CellPosition(row: 0, column: 1)

        state.selectCell(position)

        if case let .cells(positions) = state.selection {
            #expect(positions.count == 1)
            #expect(positions.contains(position))
        } else {
            Issue.record("Expected .cells selection shape")
        }
        #expect(state.isFocused == true)
    }

    // MARK: - extendSelection

    @Test("extendSelection from (0,0) to (2,2) produces .rectangular(0..<3, 0..<3)")
    @MainActor func extendSelectionRectangular() {
        let state = TableSelectionState()
        state.selectCell(CellPosition(row: 0, column: 0))

        state.extendSelection(to: CellPosition(row: 2, column: 2))

        if case let .rectangular(rowRange, colRange) = state.selection {
            #expect(rowRange == 0 ..< 3)
            #expect(colRange == 0 ..< 3)
        } else {
            Issue.record("Expected .rectangular selection shape")
        }
    }

    @Test("extendSelection from existing rectangular expands bounds")
    @MainActor func extendFromRectangular() {
        let state = TableSelectionState()
        state.selectCell(CellPosition(row: 1, column: 1))
        state.extendSelection(to: CellPosition(row: 2, column: 2))

        // Now extend further
        state.extendSelection(to: CellPosition(row: 0, column: 0))

        if case let .rectangular(rowRange, colRange) = state.selection {
            #expect(rowRange == 0 ..< 3)
            #expect(colRange == 0 ..< 3)
        } else {
            Issue.record("Expected .rectangular selection shape")
        }
    }

    // MARK: - toggleCell

    @Test("toggleCell adds to and removes from selection")
    @MainActor func toggleCellAddRemove() {
        let state = TableSelectionState()
        let pos1 = CellPosition(row: 0, column: 0)
        let pos2 = CellPosition(row: 1, column: 1)

        // Toggle first cell on
        state.toggleCell(pos1)
        if case let .cells(positions) = state.selection {
            #expect(positions.count == 1)
            #expect(positions.contains(pos1))
        } else {
            Issue.record("Expected .cells after first toggle")
        }

        // Toggle second cell on
        state.toggleCell(pos2)
        if case let .cells(positions) = state.selection {
            #expect(positions.count == 2)
            #expect(positions.contains(pos1))
            #expect(positions.contains(pos2))
        } else {
            Issue.record("Expected .cells with two elements")
        }

        // Toggle first cell off
        state.toggleCell(pos1)
        if case let .cells(positions) = state.selection {
            #expect(positions.count == 1)
            #expect(positions.contains(pos2))
        } else {
            Issue.record("Expected .cells with one element after removal")
        }
    }

    @Test("toggleCell on last selected cell clears to .empty")
    @MainActor func toggleCellClearsToEmpty() {
        let state = TableSelectionState()
        let pos = CellPosition(row: 0, column: 0)

        state.toggleCell(pos)
        state.toggleCell(pos)

        if case .empty = state.selection {
            // Expected
        } else {
            Issue.record("Expected .empty after toggling sole cell off")
        }
    }

    // MARK: - selectAll

    @Test("selectAll produces .all")
    @MainActor func selectAllProducesAll() {
        let state = TableSelectionState()

        state.selectAll()

        if case .all = state.selection {
            // Expected
        } else {
            Issue.record("Expected .all selection shape")
        }
        #expect(state.isFocused == true)
    }

    // MARK: - clearSelection

    @Test("clearSelection produces .empty and clears isFocused")
    @MainActor func clearSelectionResetsState() {
        let state = TableSelectionState()
        state.selectAll()
        #expect(state.isFocused == true)

        state.clearSelection()

        if case .empty = state.selection {
            // Expected
        } else {
            Issue.record("Expected .empty after clearSelection")
        }
        #expect(state.isFocused == false)
    }

    // MARK: - isSelected

    @Test("isSelected returns true for cells within a .rectangular selection")
    @MainActor func isSelectedRectangular() {
        let state = TableSelectionState()
        state.selectCell(CellPosition(row: 0, column: 0))
        state.extendSelection(to: CellPosition(row: 2, column: 2))

        #expect(state.isSelected(row: 0, column: 0) == true)
        #expect(state.isSelected(row: 1, column: 1) == true)
        #expect(state.isSelected(row: 2, column: 2) == true)
        #expect(state.isSelected(row: 3, column: 0) == false)
        #expect(state.isSelected(row: 0, column: 3) == false)
    }

    @Test("isSelected returns true for header row (row == -1) in .all")
    @MainActor func isSelectedHeaderInAll() {
        let state = TableSelectionState()
        state.selectAll()

        #expect(state.isSelected(row: -1, column: 0) == true)
        #expect(state.isSelected(row: -1, column: 5) == true)
        #expect(state.isSelected(row: 0, column: 0) == true)
    }

    @Test("isSelected returns false for .empty selection")
    @MainActor func isSelectedEmpty() {
        let state = TableSelectionState()

        #expect(state.isSelected(row: 0, column: 0) == false)
        #expect(state.isSelected(row: -1, column: 0) == false)
    }

    @Test("isSelected returns true for matching .rows selection")
    @MainActor func isSelectedRows() {
        let state = TableSelectionState()
        state.selectRow(1, columnCount: 3)

        #expect(state.isSelected(row: 1, column: 0) == true)
        #expect(state.isSelected(row: 1, column: 2) == true)
        #expect(state.isSelected(row: 0, column: 0) == false)
    }

    @Test("isSelected returns true for matching .columns selection")
    @MainActor func isSelectedColumns() {
        let state = TableSelectionState()
        state.selectColumn(2)

        #expect(state.isSelected(row: 0, column: 2) == true)
        #expect(state.isSelected(row: 5, column: 2) == true)
        #expect(state.isSelected(row: 0, column: 0) == false)
    }

    // MARK: - selectRow / selectColumn

    @Test("selectRow produces .rows selection")
    @MainActor func selectRowProducesRows() {
        let state = TableSelectionState()
        state.selectRow(2, columnCount: 4)

        if case let .rows(indexSet) = state.selection {
            #expect(indexSet.contains(2))
            #expect(indexSet.count == 1)
        } else {
            Issue.record("Expected .rows selection shape")
        }
        #expect(state.isFocused == true)
    }

    @Test("selectColumn produces .columns selection")
    @MainActor func selectColumnProducesColumns() {
        let state = TableSelectionState()
        state.selectColumn(1)

        if case let .columns(indexSet) = state.selection {
            #expect(indexSet.contains(1))
            #expect(indexSet.count == 1)
        } else {
            Issue.record("Expected .columns selection shape")
        }
        #expect(state.isFocused == true)
    }

    // MARK: - Find State Queries

    @Test("isFindMatch returns true for positions in findMatches")
    @MainActor func isFindMatchQuery() {
        let state = TableSelectionState()
        state.findMatches = [
            CellPosition(row: 0, column: 1),
            CellPosition(row: 2, column: 0),
        ]

        #expect(state.isFindMatch(row: 0, column: 1) == true)
        #expect(state.isFindMatch(row: 2, column: 0) == true)
        #expect(state.isFindMatch(row: 0, column: 0) == false)
    }

    @Test("isCurrentFindMatch returns true only for currentFindMatch")
    @MainActor func isCurrentFindMatchQuery() {
        let state = TableSelectionState()
        state.currentFindMatch = CellPosition(row: 1, column: 2)

        #expect(state.isCurrentFindMatch(row: 1, column: 2) == true)
        #expect(state.isCurrentFindMatch(row: 0, column: 0) == false)
    }

    @Test("isCurrentFindMatch returns false when currentFindMatch is nil")
    @MainActor func isCurrentFindMatchNil() {
        let state = TableSelectionState()

        #expect(state.isCurrentFindMatch(row: 0, column: 0) == false)
    }
}
