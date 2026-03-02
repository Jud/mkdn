import Foundation
import Testing
@testable import mkdnLib

@Suite("MarkdownVisitor – Task List Checkboxes")
struct MarkdownVisitorTaskListTests {
    @Test("Unchecked task list item produces .unchecked checkbox state")
    func parsesUncheckedCheckbox() {
        let blocks = MarkdownRenderer.render(
            text: "- [ ] incomplete task",
            theme: .solarizedDark
        )

        guard case let .unorderedList(items) = blocks.first?.block else {
            Issue.record("Expected an unordered list block")
            return
        }

        #expect(items.count == 1)
        #expect(items[0].checkbox == .unchecked)
    }

    @Test("Checked task list item produces .checked checkbox state")
    func parsesCheckedCheckbox() {
        let blocks = MarkdownRenderer.render(
            text: "- [x] completed task",
            theme: .solarizedDark
        )

        guard case let .unorderedList(items) = blocks.first?.block else {
            Issue.record("Expected an unordered list block")
            return
        }

        #expect(items.count == 1)
        #expect(items[0].checkbox == .checked)
    }

    @Test("Non-task list item has nil checkbox state")
    func nonTaskListHasNilCheckbox() {
        let blocks = MarkdownRenderer.render(
            text: "- normal item",
            theme: .solarizedDark
        )

        guard case let .unorderedList(items) = blocks.first?.block else {
            Issue.record("Expected an unordered list block")
            return
        }

        #expect(items.count == 1)
        #expect(items[0].checkbox == nil)
    }

    @Test("Mixed task and non-task items preserve checkbox states")
    func mixedTaskListItems() {
        let markdown = """
        - [ ] todo
        - [x] done
        - normal
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        guard case let .unorderedList(items) = blocks.first?.block else {
            Issue.record("Expected an unordered list block")
            return
        }

        #expect(items.count == 3)
        #expect(items[0].checkbox == .unchecked)
        #expect(items[1].checkbox == .checked)
        #expect(items[2].checkbox == nil)
    }
}
