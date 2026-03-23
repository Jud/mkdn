import SwiftUI
import Testing
@testable import mkdnLib

@Suite("OutlineState")
struct OutlineStateTests {
    // MARK: - Helpers

    /// Build an array of `IndexedBlock` from `(level, title)` pairs,
    /// assigning sequential indices.
    private func headingBlocks(_ headings: [(level: Int, title: String)]) -> [IndexedBlock] {
        headings.enumerated().map { offset, heading in
            IndexedBlock(
                index: offset,
                block: .heading(level: heading.level, text: AttributedString(heading.title))
            )
        }
    }

    /// Build an array of `IndexedBlock` that interleaves headings with
    /// paragraph blocks, preserving realistic indices.
    private func mixedBlocks(
        _ items: [(isHeading: Bool, level: Int, text: String)]
    ) -> [IndexedBlock] {
        items.enumerated().map { offset, item in
            if item.isHeading {
                IndexedBlock(
                    index: offset,
                    block: .heading(level: item.level, text: AttributedString(item.text))
                )
            } else {
                IndexedBlock(
                    index: offset,
                    block: .paragraph(text: AttributedString(item.text))
                )
            }
        }
    }

    // MARK: - updateHeadings

    @Test("updateHeadings populates headingTree and flatHeadings")
    @MainActor func updateHeadingsPopulates() {
        let state = OutlineState()
        let blocks = headingBlocks([
            (level: 1, title: "Introduction"),
            (level: 2, title: "Overview"),
            (level: 2, title: "Details"),
        ])
        state.updateHeadings(from: blocks)

        #expect(state.headingTree.count == 1)
        #expect(state.flatHeadings.count == 3)
        #expect(state.flatHeadings[0].title == "Introduction")
        #expect(state.flatHeadings[1].title == "Overview")
        #expect(state.flatHeadings[2].title == "Details")
    }

    @Test("updateHeadings with no headings leaves both empty")
    @MainActor func updateHeadingsEmpty() {
        let state = OutlineState()
        let blocks = [
            IndexedBlock(index: 0, block: .paragraph(text: AttributedString("Some text"))),
        ]
        state.updateHeadings(from: blocks)

        #expect(state.headingTree.isEmpty)
        #expect(state.flatHeadings.isEmpty)
        #expect(state.isBreadcrumbVisible == false)
        #expect(state.isHUDVisible == false)
    }

    // MARK: - updateScrollPosition

    @Test("updateScrollPosition after first heading shows breadcrumb")
    @MainActor func scrollPositionAfterFirstHeading() {
        let state = OutlineState()
        let blocks = mixedBlocks([
            (isHeading: false, level: 0, text: "Intro paragraph"),
            (isHeading: true, level: 1, text: "Chapter One"),
            (isHeading: false, level: 0, text: "Body text"),
            (isHeading: true, level: 2, text: "Section A"),
        ])
        state.updateHeadings(from: blocks)
        state.updateScrollPosition(currentBlockIndex: 3)

        #expect(state.isBreadcrumbVisible == true)
        #expect(state.currentHeadingIndex == 3)
        #expect(state.breadcrumbPath.count == 2)
        #expect(state.breadcrumbPath[0].title == "Chapter One")
        #expect(state.breadcrumbPath[1].title == "Section A")
    }

    @Test("updateScrollPosition before first heading hides breadcrumb")
    @MainActor func scrollPositionBeforeFirstHeading() {
        let state = OutlineState()
        let blocks = mixedBlocks([
            (isHeading: false, level: 0, text: "Intro paragraph"),
            (isHeading: true, level: 1, text: "Chapter One"),
        ])
        state.updateHeadings(from: blocks)
        state.updateScrollPosition(currentBlockIndex: 0)

        #expect(state.isBreadcrumbVisible == false)
        #expect(state.currentHeadingIndex == nil)
    }

    // MARK: - HUD Lifecycle

    @Test("toggleHUD when hidden shows HUD")
    @MainActor func toggleHUDShowsWhenHidden() {
        let state = OutlineState()
        state.updateHeadings(from: headingBlocks([
            (level: 1, title: "Heading"),
        ]))

        #expect(state.isHUDVisible == false)
        state.toggleHUD()
        #expect(state.isHUDVisible == true)
    }

    @Test("toggleHUD when visible dismisses HUD")
    @MainActor func toggleHUDDismissesWhenVisible() {
        let state = OutlineState()
        state.updateHeadings(from: headingBlocks([
            (level: 1, title: "Heading"),
        ]))
        state.showHUD()

        #expect(state.isHUDVisible == true)
        state.toggleHUD()
        #expect(state.isHUDVisible == false)
    }

    @Test("showHUD auto-selects current heading index")
    @MainActor func showHUDAutoSelectsCurrentHeading() {
        let state = OutlineState()
        let blocks = headingBlocks([
            (level: 1, title: "First"),
            (level: 2, title: "Second"),
            (level: 2, title: "Third"),
        ])
        state.updateHeadings(from: blocks)
        state.updateScrollPosition(currentBlockIndex: 2)

        state.showHUD()

        #expect(state.isHUDVisible == true)
        #expect(state.selectedIndex == 2) // Third is at index 2 in flatHeadings
    }

    @Test("dismissHUD clears filterQuery")
    @MainActor func dismissHUDClearsFilter() {
        let state = OutlineState()
        state.updateHeadings(from: headingBlocks([
            (level: 1, title: "Heading"),
        ]))
        state.showHUD()
        state.filterQuery = "something"

        state.dismissHUD()

        #expect(state.isHUDVisible == false)
        #expect(state.filterQuery.isEmpty)
    }

    // MARK: - Filtering

    @Test("filteredHeadings with empty query returns all flatHeadings")
    @MainActor func filteredHeadingsEmptyQuery() {
        let state = OutlineState()
        state.updateHeadings(from: headingBlocks([
            (level: 1, title: "One"),
            (level: 2, title: "Two"),
        ]))

        #expect(state.filteredHeadings.count == 2)
        #expect(state.filteredHeadings[0].title == "One")
        #expect(state.filteredHeadings[1].title == "Two")
    }

    @Test("filteredHeadings fuzzy matches 'morch' to 'Migration Orchestrator'")
    @MainActor func filteredHeadingsFuzzyMatch() {
        let state = OutlineState()
        state.updateHeadings(from: headingBlocks([
            (level: 1, title: "Introduction"),
            (level: 2, title: "Migration Orchestrator"),
            (level: 2, title: "Testing Guide"),
        ]))
        state.filterQuery = "morch"
        state.applyFilter()

        let filtered = state.filteredHeadings
        #expect(filtered.count == 1)
        #expect(filtered[0].title == "Migration Orchestrator")
    }

    @Test("filteredHeadings with no matching query returns empty")
    @MainActor func filteredHeadingsNoMatch() {
        let state = OutlineState()
        state.updateHeadings(from: headingBlocks([
            (level: 1, title: "Introduction"),
            (level: 2, title: "Overview"),
        ]))
        state.filterQuery = "xyz"
        state.applyFilter()

        #expect(state.filteredHeadings.isEmpty)
    }

    @Test("applyFilter recomputes filteredHeadings from filterQuery")
    @MainActor func applyFilterRecomputes() {
        let state = OutlineState()
        state.updateHeadings(from: headingBlocks([
            (level: 1, title: "Architecture"),
            (level: 2, title: "Components"),
            (level: 2, title: "API Design"),
        ]))

        // Initially all headings are present.
        #expect(state.filteredHeadings.count == 3)

        // Apply a filter.
        state.filterQuery = "api"
        state.applyFilter()
        #expect(state.filteredHeadings.count == 1)
        #expect(state.filteredHeadings[0].title == "API Design")

        // Clear filter and reapply.
        state.filterQuery = ""
        state.applyFilter()
        #expect(state.filteredHeadings.count == 3)
    }

    @Test("applyFilter clamps selectedIndex when list shrinks")
    @MainActor func applyFilterClampsSelectedIndex() {
        let state = OutlineState()
        state.updateHeadings(from: headingBlocks([
            (level: 1, title: "First"),
            (level: 1, title: "Second"),
            (level: 1, title: "Third"),
        ]))
        state.selectedIndex = 2

        // Filter to only one result — selectedIndex should clamp to 0.
        state.filterQuery = "fir"
        state.applyFilter()
        #expect(state.filteredHeadings.count == 1)
        #expect(state.selectedIndex == 0)
    }

    // MARK: - Navigation

    @Test("moveSelectionUp wraps from 0 to last")
    @MainActor func moveSelectionUpWraps() {
        let state = OutlineState()
        state.updateHeadings(from: headingBlocks([
            (level: 1, title: "First"),
            (level: 1, title: "Second"),
            (level: 1, title: "Third"),
        ]))
        state.selectedIndex = 0

        state.moveSelectionUp()

        #expect(state.selectedIndex == 2)
    }

    @Test("moveSelectionDown wraps from last to 0")
    @MainActor func moveSelectionDownWraps() {
        let state = OutlineState()
        state.updateHeadings(from: headingBlocks([
            (level: 1, title: "First"),
            (level: 1, title: "Second"),
            (level: 1, title: "Third"),
        ]))
        state.selectedIndex = 2

        state.moveSelectionDown()

        #expect(state.selectedIndex == 0)
    }

    @Test("selectAndNavigate returns correct blockIndex and dismisses HUD")
    @MainActor func selectAndNavigateReturnsBlockIndex() {
        let state = OutlineState()
        state.updateHeadings(from: headingBlocks([
            (level: 1, title: "First"),
            (level: 2, title: "Second"),
            (level: 2, title: "Third"),
        ]))
        state.showHUD()
        state.selectedIndex = 1

        let result = state.selectAndNavigate()

        #expect(result == 1) // blockIndex of "Second"
        #expect(state.isHUDVisible == false)
    }
}
