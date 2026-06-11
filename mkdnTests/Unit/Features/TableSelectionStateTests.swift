import Foundation
import Testing
@testable import mkdnLib

@Suite("TableSelectionState")
@MainActor
struct TableSelectionStateTests {
    private func point(_ row: Int, _ column: Int, _ offset: Int) -> TableTextPoint {
        TableTextPoint(cell: CellPosition(row: row, column: column), offset: offset)
    }

    private func segment(
        _ start: TableTextPoint, _ end: TableTextPoint
    ) -> TableSelectionState.Segment {
        .init(start: start, end: end)
    }

    // MARK: - Drag Lifecycle

    @Test("Single-click begin is collapsed; mouse-up clears it (a click selects nothing)")
    func clickWithoutDragClearsSelection() {
        let state = TableSelectionState()
        state.beginDrag(segment: .init(point: point(0, 0, 3)), granularity: .character)
        #expect(state.range?.isCollapsed == true)
        state.endDrag()
        #expect(state.range == nil)
        #expect(state.dragSegment == nil)
    }

    @Test("Character drag extends from the anchor point")
    func characterDragExtends() {
        let state = TableSelectionState()
        state.beginDrag(segment: .init(point: point(0, 0, 3)), granularity: .character)
        state.continueDrag(to: .init(point: point(1, 1, 7)))
        state.endDrag()
        #expect(state.range == TableTextRange(anchor: point(0, 0, 3), focus: point(1, 1, 7)))
    }

    @Test("Backward character drag anchors on the far side")
    func backwardDragAnchorsFarSide() {
        let state = TableSelectionState()
        state.beginDrag(segment: .init(point: point(1, 1, 7)), granularity: .character)
        state.continueDrag(to: .init(point: point(0, 0, 3)))
        #expect(state.range?.start == point(0, 0, 3))
        #expect(state.range?.end == point(1, 1, 7))
    }

    @Test("Double-click selects the word; dragging unions anchor and focus words")
    func wordDragUnionsWords() {
        let state = TableSelectionState()
        // "alpha |beta| gamma": word at the click.
        state.beginDrag(
            segment: segment(point(0, 0, 6), point(0, 0, 10)),
            granularity: .word
        )
        #expect(state.range == TableTextRange(anchor: point(0, 0, 6), focus: point(0, 0, 10)))
        // Drag forward into another cell's word: anchor word start → focus word end.
        state.continueDrag(to: segment(point(1, 0, 0), point(1, 0, 5)))
        #expect(state.range == TableTextRange(anchor: point(0, 0, 6), focus: point(1, 0, 5)))
        // Drag back before the anchor word: anchor word end → focus word start.
        state.continueDrag(to: segment(point(0, 0, 0), point(0, 0, 5)))
        #expect(state.range == TableTextRange(anchor: point(0, 0, 10), focus: point(0, 0, 0)))
    }

    @Test("Triple-click drag extends by whole cells")
    func cellDragExtendsByCells() {
        let state = TableSelectionState()
        state.beginDrag(
            segment: segment(point(0, 1, 0), point(0, 1, 29)),
            granularity: .cell
        )
        state.continueDrag(to: segment(point(1, 1, 0), point(1, 1, 28)))
        #expect(state.range == TableTextRange(anchor: point(0, 1, 0), focus: point(1, 1, 28)))
    }

    @Test("Shift+click keeps the existing anchor and moves the focus")
    func shiftClickExtends() {
        let state = TableSelectionState()
        state.beginDrag(segment: .init(point: point(0, 0, 2)), granularity: .character)
        state.continueDrag(to: .init(point: point(0, 0, 8)))
        state.endDrag()
        state.extendSelection(to: point(2, 2, 4))
        #expect(state.range == TableTextRange(anchor: point(0, 0, 2), focus: point(2, 2, 4)))
    }

    @Test("Shift+click with no selection starts a collapsed one")
    func shiftClickWithoutSelection() {
        let state = TableSelectionState()
        state.extendSelection(to: point(1, 1, 3))
        #expect(state.range?.isCollapsed == true)
    }

    @Test("clearSelection drops range and drag session")
    func clearSelection() {
        let state = TableSelectionState()
        state.beginDrag(segment: .init(point: point(0, 0, 1)), granularity: .character)
        state.continueDrag(to: .init(point: point(0, 2, 4)))
        state.clearSelection()
        #expect(state.range == nil)
        #expect(state.dragSegment == nil)
    }

    // MARK: - Find State

    @Test("Find matches are queryable per cell")
    func findMatchQueries() {
        let state = TableSelectionState()
        state.findMatches = [
            CellPosition(row: -1, column: 0),
            CellPosition(row: 1, column: 2),
        ]
        state.currentFindMatch = CellPosition(row: 1, column: 2)

        #expect(state.isFindMatch(row: -1, column: 0))
        #expect(state.isFindMatch(row: 1, column: 2))
        #expect(!state.isFindMatch(row: 0, column: 0))
        #expect(state.isCurrentFindMatch(row: 1, column: 2))
        #expect(!state.isCurrentFindMatch(row: -1, column: 0))
    }
}
