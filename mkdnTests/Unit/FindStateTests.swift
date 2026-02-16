import Foundation
import Testing

@testable import mkdnLib

@Suite("FindState")
struct FindStateTests {
    // MARK: - Search

    @Test("Empty query produces no matches")
    @MainActor func emptyQuery() {
        let state = FindState()
        state.query = ""
        state.performSearch(in: "Hello world hello")
        #expect(state.matchRanges.isEmpty)
        #expect(state.matchCount == 0)
        #expect(state.currentMatchIndex == 0)
    }

    @Test("Case-insensitive search finds matches regardless of case")
    @MainActor func caseInsensitive() {
        let state = FindState()
        state.query = "hello"
        state.performSearch(in: "Hello HELLO hello hElLo")
        #expect(state.matchCount == 4)
    }

    @Test("Multiple matches found with correct ranges")
    @MainActor func multipleMatches() {
        let text = "abcabcabc"
        let state = FindState()
        state.query = "abc"
        state.performSearch(in: text)
        #expect(state.matchCount == 3)
        #expect(state.matchRanges[0] == NSRange(location: 0, length: 3))
        #expect(state.matchRanges[1] == NSRange(location: 3, length: 3))
        #expect(state.matchRanges[2] == NSRange(location: 6, length: 3))
    }

    @Test("No matches for query not in text")
    @MainActor func noMatches() {
        let state = FindState()
        state.query = "missing"
        state.performSearch(in: "Hello world")
        #expect(state.matchCount == 0)
        #expect(state.matchRanges.isEmpty)
    }

    // MARK: - Navigation

    @Test("Navigation wraps forward from last match to first")
    @MainActor func wrapForward() {
        let state = FindState()
        state.query = "a"
        state.performSearch(in: "a b a b a")
        #expect(state.matchCount == 3)

        state.currentMatchIndex = 2
        state.nextMatch()
        #expect(state.currentMatchIndex == 0)
    }

    @Test("Navigation wraps backward from first match to last")
    @MainActor func wrapBackward() {
        let state = FindState()
        state.query = "a"
        state.performSearch(in: "a b a b a")
        #expect(state.matchCount == 3)

        state.currentMatchIndex = 0
        state.previousMatch()
        #expect(state.currentMatchIndex == 2)
    }

    @Test("nextMatch advances sequentially")
    @MainActor func nextMatchSequential() {
        let state = FindState()
        state.query = "x"
        state.performSearch(in: "x x x x")
        #expect(state.matchCount == 4)
        #expect(state.currentMatchIndex == 0)

        state.nextMatch()
        #expect(state.currentMatchIndex == 1)
        state.nextMatch()
        #expect(state.currentMatchIndex == 2)
        state.nextMatch()
        #expect(state.currentMatchIndex == 3)
        state.nextMatch()
        #expect(state.currentMatchIndex == 0)
    }

    @Test("previousMatch retreats sequentially")
    @MainActor func previousMatchSequential() {
        let state = FindState()
        state.query = "x"
        state.performSearch(in: "x x x")
        state.currentMatchIndex = 2

        state.previousMatch()
        #expect(state.currentMatchIndex == 1)
        state.previousMatch()
        #expect(state.currentMatchIndex == 0)
        state.previousMatch()
        #expect(state.currentMatchIndex == 2)
    }

    @Test("nextMatch is no-op when no matches")
    @MainActor func nextMatchNoOp() {
        let state = FindState()
        state.query = "missing"
        state.performSearch(in: "Hello")
        #expect(state.matchCount == 0)

        state.nextMatch()
        #expect(state.currentMatchIndex == 0)
    }

    @Test("previousMatch is no-op when no matches")
    @MainActor func previousMatchNoOp() {
        let state = FindState()
        state.query = "missing"
        state.performSearch(in: "Hello")
        #expect(state.matchCount == 0)

        state.previousMatch()
        #expect(state.currentMatchIndex == 0)
    }

    // MARK: - Lifecycle

    @Test("dismiss clears all state")
    @MainActor func dismissClearsState() {
        let state = FindState()
        state.query = "test"
        state.isVisible = true
        state.performSearch(in: "test test test")
        state.currentMatchIndex = 1

        #expect(state.matchCount == 3)
        #expect(state.isVisible == true)

        state.dismiss()

        #expect(state.query.isEmpty)
        #expect(state.matchRanges.isEmpty)
        #expect(state.currentMatchIndex == 0)
        #expect(state.isVisible == false)
    }

    @Test("useSelection sets query and shows bar")
    @MainActor func useSelection() {
        let state = FindState()
        #expect(state.isVisible == false)
        #expect(state.query.isEmpty)

        state.useSelection("pipeline")

        #expect(state.isVisible == true)
        #expect(state.query == "pipeline")
    }

    @Test("show sets isVisible to true")
    @MainActor func showSetsVisible() {
        let state = FindState()
        #expect(state.isVisible == false)

        state.show()

        #expect(state.isVisible == true)
    }

    // MARK: - Content Change and Index Clamping

    @Test("Content change recomputes matches")
    @MainActor func contentChangeRecomputes() {
        let state = FindState()
        state.query = "foo"

        state.performSearch(in: "foo bar foo")
        #expect(state.matchCount == 2)

        state.performSearch(in: "foo bar baz foo quux foo")
        #expect(state.matchCount == 3)

        state.performSearch(in: "bar baz quux")
        #expect(state.matchCount == 0)
    }

    @Test("currentMatchIndex clamped when match count decreases")
    @MainActor func indexClampedOnDecrease() {
        let state = FindState()
        state.query = "a"
        state.performSearch(in: "a a a a a")
        #expect(state.matchCount == 5)

        state.currentMatchIndex = 4

        state.performSearch(in: "a a")
        #expect(state.matchCount == 2)
        #expect(state.currentMatchIndex == 1)
    }

    @Test("currentMatchIndex reset to zero when all matches disappear")
    @MainActor func indexResetOnNoMatches() {
        let state = FindState()
        state.query = "x"
        state.performSearch(in: "x x x")
        state.currentMatchIndex = 2

        state.query = "z"
        state.performSearch(in: "x x x")
        #expect(state.matchCount == 0)
        #expect(state.currentMatchIndex == 0)
    }
}
