import SwiftUI
import Testing
@testable import mkdnLib

@Suite("HeadingTreeBuilder")
struct HeadingTreeBuilderTests {
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

    // MARK: - buildTree Tests

    @Test("empty input produces empty output")
    func buildTreeEmpty() {
        let tree = HeadingTreeBuilder.buildTree(from: [])
        #expect(tree.isEmpty)
    }

    @Test("single heading produces single root node")
    func buildTreeSingleHeading() {
        let blocks = headingBlocks([(level: 1, title: "Introduction")])
        let tree = HeadingTreeBuilder.buildTree(from: blocks)

        #expect(tree.count == 1)
        #expect(tree[0].title == "Introduction")
        #expect(tree[0].level == 1)
        #expect(tree[0].blockIndex == 0)
        #expect(tree[0].children.isEmpty)
    }

    @Test("flat headings at same level produce flat list of roots")
    func buildTreeFlatHeadings() {
        let blocks = headingBlocks([
            (level: 2, title: "First"),
            (level: 2, title: "Second"),
            (level: 2, title: "Third"),
        ])
        let tree = HeadingTreeBuilder.buildTree(from: blocks)

        #expect(tree.count == 3)
        #expect(tree[0].title == "First")
        #expect(tree[1].title == "Second")
        #expect(tree[2].title == "Third")
        for node in tree {
            #expect(node.children.isEmpty)
        }
    }

    @Test("nested h1 > h2 > h3 produces proper tree")
    func buildTreeNested() {
        let blocks = headingBlocks([
            (level: 1, title: "Chapter"),
            (level: 2, title: "Section"),
            (level: 3, title: "Subsection"),
        ])
        let tree = HeadingTreeBuilder.buildTree(from: blocks)

        #expect(tree.count == 1)
        #expect(tree[0].title == "Chapter")
        #expect(tree[0].children.count == 1)
        #expect(tree[0].children[0].title == "Section")
        #expect(tree[0].children[0].children.count == 1)
        #expect(tree[0].children[0].children[0].title == "Subsection")
        #expect(tree[0].children[0].children[0].children.isEmpty)
    }

    @Test("skip levels: h1 > h3 makes h3 child of h1")
    func buildTreeSkipLevels() {
        let blocks = headingBlocks([
            (level: 1, title: "Top"),
            (level: 3, title: "Deep"),
        ])
        let tree = HeadingTreeBuilder.buildTree(from: blocks)

        #expect(tree.count == 1)
        #expect(tree[0].title == "Top")
        #expect(tree[0].children.count == 1)
        #expect(tree[0].children[0].title == "Deep")
    }

    @Test("multiple h1s produce multiple root nodes")
    func buildTreeMultipleRoots() {
        let blocks = headingBlocks([
            (level: 1, title: "Part One"),
            (level: 1, title: "Part Two"),
            (level: 1, title: "Part Three"),
        ])
        let tree = HeadingTreeBuilder.buildTree(from: blocks)

        #expect(tree.count == 3)
        #expect(tree[0].title == "Part One")
        #expect(tree[1].title == "Part Two")
        #expect(tree[2].title == "Part Three")
    }

    @Test("mixed content: only headings extracted, indices preserved")
    func buildTreeMixedContent() {
        let blocks = mixedBlocks([
            (isHeading: false, level: 0, text: "Some intro text"),
            (isHeading: true, level: 1, text: "First Heading"),
            (isHeading: false, level: 0, text: "A paragraph"),
            (isHeading: false, level: 0, text: "Another paragraph"),
            (isHeading: true, level: 2, text: "Sub Heading"),
            (isHeading: false, level: 0, text: "Code block content"),
        ])
        let tree = HeadingTreeBuilder.buildTree(from: blocks)

        #expect(tree.count == 1)
        #expect(tree[0].title == "First Heading")
        #expect(tree[0].blockIndex == 1)
        #expect(tree[0].children.count == 1)
        #expect(tree[0].children[0].title == "Sub Heading")
        #expect(tree[0].children[0].blockIndex == 4)
    }

    @Test("complex document: h1, h2, h2, h3, h1, h2")
    func buildTreeComplex() {
        let blocks = headingBlocks([
            (level: 1, title: "Chapter 1"),
            (level: 2, title: "Section 1.1"),
            (level: 2, title: "Section 1.2"),
            (level: 3, title: "Subsection 1.2.1"),
            (level: 1, title: "Chapter 2"),
            (level: 2, title: "Section 2.1"),
        ])
        let tree = HeadingTreeBuilder.buildTree(from: blocks)

        // Two root h1 nodes.
        #expect(tree.count == 2)
        #expect(tree[0].title == "Chapter 1")
        #expect(tree[1].title == "Chapter 2")

        // First h1 has two h2 children.
        #expect(tree[0].children.count == 2)
        #expect(tree[0].children[0].title == "Section 1.1")
        #expect(tree[0].children[1].title == "Section 1.2")

        // Second h2 has one h3 child.
        #expect(tree[0].children[0].children.isEmpty)
        #expect(tree[0].children[1].children.count == 1)
        #expect(tree[0].children[1].children[0].title == "Subsection 1.2.1")

        // Second h1 has one h2 child.
        #expect(tree[1].children.count == 1)
        #expect(tree[1].children[0].title == "Section 2.1")
    }

    // MARK: - flattenTree Tests

    @Test("flattenTree: empty tree produces empty result")
    func flattenTreeEmpty() {
        let result = HeadingTreeBuilder.flattenTree([])
        #expect(result.isEmpty)
    }

    @Test("flattenTree: nested tree produces depth-first pre-order")
    func flattenTreeNested() {
        let blocks = headingBlocks([
            (level: 1, title: "A"),
            (level: 2, title: "B"),
            (level: 3, title: "C"),
            (level: 2, title: "D"),
            (level: 1, title: "E"),
        ])
        let tree = HeadingTreeBuilder.buildTree(from: blocks)
        let flat = HeadingTreeBuilder.flattenTree(tree)

        #expect(flat.count == 5)
        #expect(flat.map(\.title) == ["A", "B", "C", "D", "E"])
    }

    // MARK: - breadcrumbPath Tests

    @Test("breadcrumbPath: blockIndex matches root heading gives path of length 1")
    func breadcrumbPathRoot() {
        let blocks = headingBlocks([
            (level: 1, title: "Root"),
            (level: 2, title: "Child"),
        ])
        let tree = HeadingTreeBuilder.buildTree(from: blocks)
        let path = HeadingTreeBuilder.breadcrumbPath(to: 0, in: tree)

        #expect(path.count == 1)
        #expect(path[0].title == "Root")
    }

    @Test("breadcrumbPath: blockIndex matches nested h3 gives full path")
    func breadcrumbPathNested() {
        let blocks = headingBlocks([
            (level: 1, title: "Chapter"),
            (level: 2, title: "Section"),
            (level: 3, title: "Subsection"),
        ])
        let tree = HeadingTreeBuilder.buildTree(from: blocks)
        let path = HeadingTreeBuilder.breadcrumbPath(to: 2, in: tree)

        #expect(path.count == 3)
        #expect(path.map(\.title) == ["Chapter", "Section", "Subsection"])
    }

    @Test("breadcrumbPath: blockIndex between headings gives path to preceding heading")
    func breadcrumbPathBetweenHeadings() {
        let blocks = mixedBlocks([
            (isHeading: true, level: 1, text: "First"),
            (isHeading: false, level: 0, text: "paragraph"),
            (isHeading: false, level: 0, text: "another paragraph"),
            (isHeading: true, level: 1, text: "Second"),
        ])
        let tree = HeadingTreeBuilder.buildTree(from: blocks)
        // blockIndex 2 is between "First" (0) and "Second" (3).
        let path = HeadingTreeBuilder.breadcrumbPath(to: 2, in: tree)

        #expect(path.count == 1)
        #expect(path[0].title == "First")
    }

    @Test("breadcrumbPath: blockIndex before any heading gives empty path")
    func breadcrumbPathBeforeAnyHeading() {
        let blocks = mixedBlocks([
            (isHeading: false, level: 0, text: "intro"),
            (isHeading: false, level: 0, text: "more intro"),
            (isHeading: true, level: 1, text: "First Heading"),
        ])
        let tree = HeadingTreeBuilder.buildTree(from: blocks)
        // blockIndex 0 is before the first heading at index 2.
        let path = HeadingTreeBuilder.breadcrumbPath(to: 0, in: tree)

        #expect(path.isEmpty)
    }

    @Test("breadcrumbPath: skipped levels produce correct chain")
    func breadcrumbPathSkippedLevels() {
        let blocks = headingBlocks([
            (level: 1, title: "Top"),
            (level: 3, title: "Deep"),
        ])
        let tree = HeadingTreeBuilder.buildTree(from: blocks)
        let path = HeadingTreeBuilder.breadcrumbPath(to: 1, in: tree)

        // h3 is child of h1 (skipping h2), so path is [h1, h3].
        #expect(path.count == 2)
        #expect(path.map(\.title) == ["Top", "Deep"])
    }
}
