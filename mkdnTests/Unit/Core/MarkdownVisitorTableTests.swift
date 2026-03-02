import Foundation
import Testing
@testable import mkdnLib

@Suite("MarkdownVisitor – Table Column Alignment")
struct MarkdownVisitorTableTests {
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
}
