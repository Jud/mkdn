import Foundation
import Testing
@testable import mkdnLib

@Suite("FileTreeNode")
struct FileTreeNodeTests {
    // MARK: - Identity

    @Test("Identity is URL-based")
    func identityIsURLBased() {
        let url = URL(fileURLWithPath: "/tmp/docs/readme.md")
        let node = FileTreeNode(name: "readme.md", url: url, isDirectory: false, depth: 1)
        #expect(node.id == url)
    }

    @Test("Two nodes with same URL are equal")
    func equalityBySameURL() {
        let url = URL(fileURLWithPath: "/tmp/docs/readme.md")
        let nodeA = FileTreeNode(name: "readme.md", url: url, isDirectory: false, depth: 1)
        let nodeB = FileTreeNode(name: "readme.md", url: url, isDirectory: false, depth: 1)
        #expect(nodeA == nodeB)
    }

    @Test("Two nodes with different URLs are not equal")
    func inequalityByDifferentURL() {
        let urlA = URL(fileURLWithPath: "/tmp/docs/a.md")
        let urlB = URL(fileURLWithPath: "/tmp/docs/b.md")
        let nodeA = FileTreeNode(name: "a.md", url: urlA, isDirectory: false, depth: 1)
        let nodeB = FileTreeNode(name: "b.md", url: urlB, isDirectory: false, depth: 1)
        #expect(nodeA != nodeB)
    }

    // MARK: - Default Values

    @Test("isTruncated defaults to false")
    func isTruncatedDefaultsFalse() {
        let url = URL(fileURLWithPath: "/tmp/docs/readme.md")
        let node = FileTreeNode(name: "readme.md", url: url, isDirectory: false, depth: 0)
        #expect(node.isTruncated == false)
    }

    @Test("children defaults to nil")
    func childrenDefaultsNil() {
        let url = URL(fileURLWithPath: "/tmp/docs/readme.md")
        let node = FileTreeNode(name: "readme.md", url: url, isDirectory: false, depth: 0)
        #expect(node.children == nil)
    }

    // MARK: - Truncation Indicator

    @Test("Truncation indicator node has isTruncated set")
    func truncationIndicatorFlag() {
        let url = URL(fileURLWithPath: "/tmp/docs/deep/...")
        let node = FileTreeNode(
            name: "...",
            url: url,
            isDirectory: false,
            depth: 10,
            isTruncated: true
        )
        #expect(node.isTruncated == true)
        #expect(node.name == "...")
        #expect(node.isDirectory == false)
    }

    // MARK: - Directory Nodes

    @Test("Directory node stores children")
    func directoryNodeChildren() {
        let parentURL = URL(fileURLWithPath: "/tmp/docs")
        let childURL = URL(fileURLWithPath: "/tmp/docs/readme.md")
        let child = FileTreeNode(name: "readme.md", url: childURL, isDirectory: false, depth: 1)
        let parent = FileTreeNode(
            name: "docs",
            url: parentURL,
            isDirectory: true,
            depth: 0,
            children: [child]
        )

        #expect(parent.isDirectory == true)
        #expect(parent.children?.count == 1)
        #expect(parent.children?.first == child)
    }

    // MARK: - isLoaded

    @Test("isLoaded is false when children is nil")
    func isLoadedFalseForNilChildren() {
        let url = URL(fileURLWithPath: "/tmp/docs")
        let node = FileTreeNode(name: "docs", url: url, isDirectory: true, depth: 0)
        #expect(node.isLoaded == false)
    }

    @Test("isLoaded is true when children is empty array")
    func isLoadedTrueForEmptyChildren() {
        let url = URL(fileURLWithPath: "/tmp/docs")
        let node = FileTreeNode(name: "docs", url: url, isDirectory: true, depth: 0, children: [])
        #expect(node.isLoaded == true)
    }

    @Test("isLoaded is true when children has elements")
    func isLoadedTrueForPopulatedChildren() {
        let childURL = URL(fileURLWithPath: "/tmp/docs/readme.md")
        let child = FileTreeNode(name: "readme.md", url: childURL, isDirectory: false, depth: 1)
        let url = URL(fileURLWithPath: "/tmp/docs")
        let node = FileTreeNode(name: "docs", url: url, isDirectory: true, depth: 0, children: [child])
        #expect(node.isLoaded == true)
    }

    @Test("File node isLoaded is false")
    func fileNodeIsLoadedFalse() {
        let url = URL(fileURLWithPath: "/tmp/docs/readme.md")
        let node = FileTreeNode(name: "readme.md", url: url, isDirectory: false, depth: 1)
        #expect(node.isLoaded == false)
    }

    // MARK: - Hashable

    @Test("Hashable produces consistent hash values")
    func hashableConsistency() {
        let url = URL(fileURLWithPath: "/tmp/docs/readme.md")
        let nodeA = FileTreeNode(name: "readme.md", url: url, isDirectory: false, depth: 1)
        let nodeB = FileTreeNode(name: "readme.md", url: url, isDirectory: false, depth: 1)
        #expect(nodeA.hashValue == nodeB.hashValue)
    }

    @Test("Can be used as Set element")
    func usableInSet() {
        let urlA = URL(fileURLWithPath: "/tmp/a.md")
        let urlB = URL(fileURLWithPath: "/tmp/b.md")
        let nodeA = FileTreeNode(name: "a.md", url: urlA, isDirectory: false, depth: 0)
        let nodeB = FileTreeNode(name: "b.md", url: urlB, isDirectory: false, depth: 0)
        let duplicateA = FileTreeNode(name: "a.md", url: urlA, isDirectory: false, depth: 0)

        let set: Set<FileTreeNode> = [nodeA, nodeB, duplicateA]
        #expect(set.count == 2)
    }
}
