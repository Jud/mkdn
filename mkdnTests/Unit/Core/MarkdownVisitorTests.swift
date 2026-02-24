import Foundation
import Testing
@testable import mkdnLib

@Suite("MarkdownVisitor")
struct MarkdownVisitorTests {
    // MARK: - Image Block Parsing

    @Test("Standalone image produces .image block with source and alt")
    func parsesImageBlock() {
        let blocks = MarkdownRenderer.render(
            text: "![A cat](https://example.com/cat.png)",
            theme: .solarizedDark
        )

        guard case let .image(source, alt) = blocks.first?.block else {
            Issue.record("Expected an image block, got \(blocks.first.debugDescription)")
            return
        }

        #expect(source == "https://example.com/cat.png")
        #expect(alt == "A cat")
    }

    @Test("Image with empty alt text produces .image block")
    func parsesImageWithEmptyAlt() {
        let blocks = MarkdownRenderer.render(
            text: "![](diagram.svg)",
            theme: .solarizedDark
        )

        guard case let .image(source, alt) = blocks.first?.block else {
            Issue.record("Expected an image block")
            return
        }

        #expect(source == "diagram.svg")
        #expect(alt.isEmpty)
    }

    // MARK: - Strikethrough

    @Test("Strikethrough text has strikethrough attribute")
    func parsesStrikethrough() {
        let blocks = MarkdownRenderer.render(
            text: "~~deleted text~~",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph block")
            return
        }

        let hasStrikethrough = text.runs.contains { run in
            run.strikethroughStyle == .single
        }
        #expect(hasStrikethrough)
    }

    @Test("Strikethrough preserves text content")
    func strikethroughPreservesContent() {
        let blocks = MarkdownRenderer.render(
            text: "~~removed~~",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph block")
            return
        }

        #expect(String(text.characters) == "removed")
    }

    // MARK: - Table Column Alignment

    @Test("Table extracts column alignments correctly")
    func parsesTableColumnAlignments() {
        let markdown = """
        | Left | Center | Right |
        |:-----|:------:|------:|
        | a    | b      | c     |
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        guard case let .table(columns, rows) = blocks.first?.block else {
            Issue.record("Expected a table block")
            return
        }

        #expect(columns.count == 3)
        #expect(columns[0].alignment == .left)
        #expect(columns[1].alignment == .center)
        #expect(columns[2].alignment == .right)

        #expect(String(columns[0].header.characters) == "Left")
        #expect(String(columns[1].header.characters) == "Center")
        #expect(String(columns[2].header.characters) == "Right")

        #expect(rows.count == 1)
    }

    @Test("Table cells contain AttributedString with inline formatting")
    func tableInlineFormatting() {
        let markdown = """
        | Header |
        |--------|
        | **bold** |
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        guard case let .table(_, rows) = blocks.first?.block else {
            Issue.record("Expected a table block")
            return
        }

        guard let firstCell = rows.first?.first else {
            Issue.record("Expected at least one row with one cell")
            return
        }

        let hasBold = firstCell.runs.contains { run in
            let intent = run.inlinePresentationIntent ?? []
            return intent.contains(.stronglyEmphasized)
        }
        #expect(hasBold)
    }

    // MARK: - Combined Inline Formatting

    @Test("Bold and italic combined preserves both styles")
    func parsesBoldItalicCombined() {
        let blocks = MarkdownRenderer.render(
            text: "***bold and italic***",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph block")
            return
        }

        let hasBothStyles = text.runs.contains { run in
            let intent = run.inlinePresentationIntent ?? []
            return intent.contains(.stronglyEmphasized) && intent.contains(.emphasized)
        }
        #expect(hasBothStyles)
    }

    @Test("Bold within italic preserves both styles")
    func parsesBoldWithinItalic() {
        let blocks = MarkdownRenderer.render(
            text: "*italic **bold italic** italic*",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph block")
            return
        }

        let hasBothStyles = text.runs.contains { run in
            let intent = run.inlinePresentationIntent ?? []
            return intent.contains(.stronglyEmphasized) && intent.contains(.emphasized)
        }
        #expect(hasBothStyles)
    }

    // MARK: - HTML Block

    @Test("HTML block produces .htmlBlock with raw content")
    func parsesHTMLBlock() {
        let markdown = """
        <div>
        hello world
        </div>
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        guard case let .htmlBlock(content) = blocks.first?.block else {
            Issue.record("Expected an htmlBlock, got \(blocks.first.debugDescription)")
            return
        }

        #expect(content.contains("hello world"))
        #expect(content.contains("<div>"))
    }

    // MARK: - Link Attributes

    @Test("Link has URL attribute set")
    func parsesLinkURL() {
        let blocks = MarkdownRenderer.render(
            text: "[click here](https://example.com)",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph block")
            return
        }

        let hasLink = text.runs.contains { run in
            run.link == URL(string: "https://example.com")
        }
        #expect(hasLink)
    }

    @Test("Link has foreground color and underline styling")
    func parsesLinkStyling() {
        let blocks = MarkdownRenderer.render(
            text: "[styled](https://example.com)",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph block")
            return
        }

        let hasUnderline = text.runs.contains { run in
            run.underlineStyle == .single
        }
        #expect(hasUnderline)

        let hasForegroundColor = text.runs.contains { run in
            run.foregroundColor != nil
        }
        #expect(hasForegroundColor)
    }

    @Test("Link text content preserved")
    func linkTextPreserved() {
        let blocks = MarkdownRenderer.render(
            text: "[visit site](https://example.com)",
            theme: .solarizedDark
        )

        guard case let .paragraph(text) = blocks.first?.block else {
            Issue.record("Expected a paragraph block")
            return
        }

        #expect(String(text.characters) == "visit site")
    }

    // MARK: - Nested List Structure

    @Test("Four-level nested unordered list preserves structure")
    func parsesNestedUnorderedList() {
        let markdown = """
        - Level 1
            - Level 2
                - Level 3
                    - Level 4
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        guard case let .unorderedList(level1Items) = blocks.first?.block else {
            Issue.record("Expected an unordered list at level 1")
            return
        }
        #expect(level1Items.count == 1)

        let level1Blocks = level1Items[0].blocks
        let nestedList = level1Blocks.first { block in
            if case .unorderedList = block { return true }
            return false
        }

        guard case let .unorderedList(level2Items) = nestedList else {
            Issue.record("Expected an unordered list at level 2")
            return
        }
        #expect(level2Items.count == 1)

        let level2Blocks = level2Items[0].blocks
        let nestedList2 = level2Blocks.first { block in
            if case .unorderedList = block { return true }
            return false
        }

        guard case let .unorderedList(level3Items) = nestedList2 else {
            Issue.record("Expected an unordered list at level 3")
            return
        }
        #expect(level3Items.count == 1)

        let level3Blocks = level3Items[0].blocks
        let nestedList3 = level3Blocks.first { block in
            if case .unorderedList = block { return true }
            return false
        }

        guard case let .unorderedList(level4Items) = nestedList3 else {
            Issue.record("Expected an unordered list at level 4")
            return
        }
        #expect(level4Items.count == 1)
    }

    @Test("Nested ordered list preserves item count at each level")
    func parsesNestedOrderedList() {
        let markdown = """
        1. First
            1. Nested A
            2. Nested B
        2. Second
        """

        let blocks = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        guard case let .orderedList(items) = blocks.first?.block else {
            Issue.record("Expected an ordered list")
            return
        }

        #expect(items.count == 2)

        let firstItemBlocks = items[0].blocks
        let nestedList = firstItemBlocks.first { block in
            if case .orderedList = block { return true }
            return false
        }

        guard case let .orderedList(nestedItems) = nestedList else {
            Issue.record("Expected a nested ordered list in first item")
            return
        }
        #expect(nestedItems.count == 2)
    }

    // MARK: - Task List Checkboxes

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

    // MARK: - Empty / Malformed Inputs

    @Test("Whitespace-only input produces no blocks")
    func handlesWhitespaceOnlyInput() {
        let blocks = MarkdownRenderer.render(text: "   \n\n   \n", theme: .solarizedDark)
        #expect(blocks.isEmpty)
    }

    @Test("Unclosed formatting does not crash")
    func handlesUnclosedFormatting() {
        let blocks = MarkdownRenderer.render(
            text: "**unclosed bold",
            theme: .solarizedDark
        )
        #expect(!blocks.isEmpty)
    }

    @Test("Very long single line does not crash")
    func handlesLongLine() {
        let longLine = String(repeating: "word ", count: 1_000)
        let blocks = MarkdownRenderer.render(text: longLine, theme: .solarizedDark)
        #expect(!blocks.isEmpty)
    }

    // MARK: - Deterministic Block IDs

    @Test("Same input produces identical block IDs")
    func deterministicIDs() {
        let markdown = """
        # Heading

        A paragraph with **bold**.

        - Item 1
        - Item 2

        ---

        ```swift
        let x = 1
        ```
        """

        let blocks1 = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)
        let blocks2 = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)

        #expect(blocks1.count == blocks2.count)

        for (block1, block2) in zip(blocks1, blocks2) {
            #expect(block1.id == block2.id)
        }
    }

    @Test("Different themes produce identical block IDs for non-link content")
    func deterministicIDsAcrossThemes() {
        let markdown = "# Hello World"

        let blocksDark = MarkdownRenderer.render(text: markdown, theme: .solarizedDark)
        let blocksLight = MarkdownRenderer.render(text: markdown, theme: .solarizedLight)

        #expect(blocksDark.first?.id == blocksLight.first?.id)
    }
}
