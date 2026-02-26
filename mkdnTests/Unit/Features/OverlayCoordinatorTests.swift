import AppKit
import Testing
@testable import mkdnLib

@Suite("OverlayCoordinator")
struct OverlayCoordinatorTests {
    // MARK: - blocksMatch Identity

    @Test("Identical mermaid blocks match")
    @MainActor func mermaidIdentity() {
        let coordinator = OverlayCoordinator()
        let block = MarkdownBlock.mermaidBlock(code: "graph TD; A-->B")
        #expect(coordinator.blocksMatch(block, block))
    }

    @Test("Identical image blocks match")
    @MainActor func imageIdentity() {
        let coordinator = OverlayCoordinator()
        let block = MarkdownBlock.image(source: "photo.png", alt: "A photo")
        #expect(coordinator.blocksMatch(block, block))
    }

    @Test("Identical thematic breaks match")
    @MainActor func thematicBreakIdentity() {
        let coordinator = OverlayCoordinator()
        let block = MarkdownBlock.thematicBreak
        #expect(coordinator.blocksMatch(block, block))
    }

    @Test("Identical math blocks match")
    @MainActor func mathIdentity() {
        let coordinator = OverlayCoordinator()
        let block = MarkdownBlock.mathBlock(code: "E = mc^2")
        #expect(coordinator.blocksMatch(block, block))
    }

    @Test("Identical table blocks match")
    @MainActor func tableIdentity() {
        let coordinator = OverlayCoordinator()
        let columns = [
            TableColumn(header: AttributedString("Name"), alignment: .left),
            TableColumn(header: AttributedString("Value"), alignment: .right),
        ]
        let rows: [[AttributedString]] = [
            [AttributedString("Alpha"), AttributedString("100")],
            [AttributedString("Beta"), AttributedString("200")],
        ]
        let block = MarkdownBlock.table(columns: columns, rows: rows)
        #expect(coordinator.blocksMatch(block, block))
    }

    // MARK: - blocksMatch Difference

    @Test("Different mermaid code does not match")
    @MainActor func mermaidDifference() {
        let coordinator = OverlayCoordinator()
        let block1 = MarkdownBlock.mermaidBlock(code: "graph TD; A-->B")
        let block2 = MarkdownBlock.mermaidBlock(code: "graph LR; X-->Y")
        #expect(!coordinator.blocksMatch(block1, block2))
    }

    @Test("Different image source does not match")
    @MainActor func imageDifference() {
        let coordinator = OverlayCoordinator()
        let block1 = MarkdownBlock.image(source: "a.png", alt: "Alt")
        let block2 = MarkdownBlock.image(source: "b.png", alt: "Alt")
        #expect(!coordinator.blocksMatch(block1, block2))
    }

    @Test("Images with same source but different alt text still match")
    @MainActor func imageSameSourceDifferentAlt() {
        let coordinator = OverlayCoordinator()
        let block1 = MarkdownBlock.image(source: "photo.png", alt: "First")
        let block2 = MarkdownBlock.image(source: "photo.png", alt: "Second")
        #expect(coordinator.blocksMatch(block1, block2))
    }

    @Test("Different math code does not match")
    @MainActor func mathDifference() {
        let coordinator = OverlayCoordinator()
        let block1 = MarkdownBlock.mathBlock(code: "x^2")
        let block2 = MarkdownBlock.mathBlock(code: "y^2")
        #expect(!coordinator.blocksMatch(block1, block2))
    }

    @Test("Cross-type blocks never match")
    @MainActor func crossTypeMismatch() {
        let coordinator = OverlayCoordinator()
        let mermaid = MarkdownBlock.mermaidBlock(code: "graph TD")
        let math = MarkdownBlock.mathBlock(code: "x")
        let image = MarkdownBlock.image(source: "a.png", alt: "")
        let hr = MarkdownBlock.thematicBreak
        #expect(!coordinator.blocksMatch(mermaid, math))
        #expect(!coordinator.blocksMatch(image, hr))
        #expect(!coordinator.blocksMatch(mermaid, image))
        #expect(!coordinator.blocksMatch(math, hr))
    }

    // MARK: - Deep Table Comparison

    @Test("Tables with same headers but different row content do not match")
    @MainActor func tableDifferentRowContent() {
        let coordinator = OverlayCoordinator()
        let columns = [
            TableColumn(header: AttributedString("Key"), alignment: .left),
        ]
        let rows1: [[AttributedString]] = [[AttributedString("Alpha")]]
        let rows2: [[AttributedString]] = [[AttributedString("Beta")]]

        let block1 = MarkdownBlock.table(columns: columns, rows: rows1)
        let block2 = MarkdownBlock.table(columns: columns, rows: rows2)
        #expect(!coordinator.blocksMatch(block1, block2))
    }

    @Test("Tables with same headers but different row count do not match")
    @MainActor func tableDifferentRowCount() {
        let coordinator = OverlayCoordinator()
        let columns = [
            TableColumn(header: AttributedString("Key"), alignment: .left),
        ]
        let rows1: [[AttributedString]] = [[AttributedString("A")]]
        let rows2: [[AttributedString]] = [
            [AttributedString("A")],
            [AttributedString("B")],
        ]

        let block1 = MarkdownBlock.table(columns: columns, rows: rows1)
        let block2 = MarkdownBlock.table(columns: columns, rows: rows2)
        #expect(!coordinator.blocksMatch(block1, block2))
    }

    @Test("Tables with different column alignments do not match")
    @MainActor func tableDifferentAlignment() {
        let coordinator = OverlayCoordinator()
        let cols1 = [TableColumn(header: AttributedString("Val"), alignment: .left)]
        let cols2 = [TableColumn(header: AttributedString("Val"), alignment: .right)]
        let rows: [[AttributedString]] = [[AttributedString("1")]]

        let block1 = MarkdownBlock.table(columns: cols1, rows: rows)
        let block2 = MarkdownBlock.table(columns: cols2, rows: rows)
        #expect(!coordinator.blocksMatch(block1, block2))
    }

    @Test("Tables with different header text do not match")
    @MainActor func tableDifferentHeaders() {
        let coordinator = OverlayCoordinator()
        let cols1 = [TableColumn(header: AttributedString("Name"), alignment: .left)]
        let cols2 = [TableColumn(header: AttributedString("Title"), alignment: .left)]
        let rows: [[AttributedString]] = [[AttributedString("A")]]

        let block1 = MarkdownBlock.table(columns: cols1, rows: rows)
        let block2 = MarkdownBlock.table(columns: cols2, rows: rows)
        #expect(!coordinator.blocksMatch(block1, block2))
    }

    @Test("Tables with different column count do not match")
    @MainActor func tableDifferentColumnCount() {
        let coordinator = OverlayCoordinator()
        let cols1 = [TableColumn(header: AttributedString("A"), alignment: .left)]
        let cols2 = [
            TableColumn(header: AttributedString("A"), alignment: .left),
            TableColumn(header: AttributedString("B"), alignment: .left),
        ]
        let rows1: [[AttributedString]] = [[AttributedString("1")]]
        let rows2: [[AttributedString]] = [[AttributedString("1"), AttributedString("2")]]

        let block1 = MarkdownBlock.table(columns: cols1, rows: rows1)
        let block2 = MarkdownBlock.table(columns: cols2, rows: rows2)
        #expect(!coordinator.blocksMatch(block1, block2))
    }

    // MARK: - Container State

    @Test("containerState initializes with default width")
    @MainActor func containerStateDefaultWidth() {
        let coordinator = OverlayCoordinator()
        #expect(coordinator.containerState.containerWidth == 600)
    }

    // MARK: - Position Index

    @Test("buildPositionIndex indexes attachment by ObjectIdentifier")
    @MainActor func buildPositionIndexAttachment() {
        let coordinator = OverlayCoordinator()
        let attachment = NSTextAttachment()
        let storage = NSTextStorage(attributedString: NSAttributedString(
            string: "\u{FFFC}",
            attributes: [.attachment: attachment]
        ))
        coordinator.buildPositionIndex(from: storage)

        let key = ObjectIdentifier(attachment)
        #expect(coordinator.attachmentIndex[key] == NSRange(location: 0, length: 1))
    }

    @Test("buildPositionIndex indexes table range by ID")
    @MainActor func buildPositionIndexTableRange() {
        let coordinator = OverlayCoordinator()
        let storage = NSTextStorage(attributedString: NSAttributedString(
            string: "table text",
            attributes: [TableAttributes.range: "table-1"]
        ))
        coordinator.buildPositionIndex(from: storage)

        #expect(coordinator.tableRangeIndex["table-1"] == NSRange(location: 0, length: 10))
    }

    @Test("buildPositionIndex merges disjoint table range spans")
    @MainActor func buildPositionIndexMergesTableRanges() {
        let coordinator = OverlayCoordinator()
        let storage = NSTextStorage()
        let part1 = NSAttributedString(
            string: "AAA",
            attributes: [TableAttributes.range: "t1"]
        )
        let gap = NSAttributedString(string: "BB")
        let part2 = NSAttributedString(
            string: "CCC",
            attributes: [TableAttributes.range: "t1"]
        )
        storage.append(part1)
        storage.append(gap)
        storage.append(part2)

        coordinator.buildPositionIndex(from: storage)

        let expected = NSRange(location: 0, length: 8)
        #expect(coordinator.tableRangeIndex["t1"] == expected)
    }
}
