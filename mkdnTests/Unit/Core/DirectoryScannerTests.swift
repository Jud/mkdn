import Foundation
import Testing

@testable import mkdnLib

@Suite("DirectoryScanner")
struct DirectoryScannerTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mkdn-scanner-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func removeTempDir(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    private func createFile(at url: URL, content: String = "# Test\n") throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func createSubdir(_ parent: URL, name: String) throws -> URL {
        let sub = parent.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        return sub
    }

    // MARK: - Extension Filtering

    @Test("Scans only .md and .markdown files")
    func scansOnlyMarkdown() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        try createFile(at: dir.appendingPathComponent("readme.md"))
        try createFile(at: dir.appendingPathComponent("notes.markdown"))
        try createFile(at: dir.appendingPathComponent("image.png"), content: "fake")
        try createFile(at: dir.appendingPathComponent("data.json"), content: "{}")
        try createFile(at: dir.appendingPathComponent("script.sh"), content: "#!/bin/bash")

        let tree = DirectoryScanner.scan(url: dir)
        let names = tree?.children.map(\.name) ?? []

        #expect(names.count == 2)
        #expect(names.contains("notes.markdown"))
        #expect(names.contains("readme.md"))
    }

    // MARK: - Hidden File/Directory Exclusion

    @Test("Excludes hidden files and directories")
    func excludesHidden() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        try createFile(at: dir.appendingPathComponent("visible.md"))
        try createFile(at: dir.appendingPathComponent(".hidden.md"))
        let hiddenDir = try createSubdir(dir, name: ".hidden-dir")
        try createFile(at: hiddenDir.appendingPathComponent("inside.md"))

        let tree = DirectoryScanner.scan(url: dir)
        let names = tree?.children.map(\.name) ?? []

        #expect(names == ["visible.md"])
    }

    // MARK: - Empty Directory Pruning

    @Test("Excludes directories containing no Markdown files")
    func excludesEmptyDirectories() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let emptyDir = try createSubdir(dir, name: "empty")
        try createFile(at: emptyDir.appendingPathComponent("data.json"), content: "{}")

        let dirWithMd = try createSubdir(dir, name: "docs")
        try createFile(at: dirWithMd.appendingPathComponent("guide.md"))

        let tree = DirectoryScanner.scan(url: dir)
        let childNames = tree?.children.map(\.name) ?? []

        #expect(childNames.contains("docs"))
        #expect(!childNames.contains("empty"))
    }

    // MARK: - Sort Order

    @Test("Sorts directories first, then files, alphabetically case-insensitive")
    func sortOrder() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        try createFile(at: dir.appendingPathComponent("zebra.md"))
        try createFile(at: dir.appendingPathComponent("apple.md"))

        let dirBeta = try createSubdir(dir, name: "Beta")
        try createFile(at: dirBeta.appendingPathComponent("file.md"))

        let dirAlpha = try createSubdir(dir, name: "alpha")
        try createFile(at: dirAlpha.appendingPathComponent("file.md"))

        let tree = DirectoryScanner.scan(url: dir)
        let names = tree?.children.map(\.name) ?? []

        #expect(names == ["alpha", "Beta", "apple.md", "zebra.md"])
    }

    // MARK: - Depth Limiting

    @Test("Respects maximum depth limit")
    func respectsDepthLimit() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        // Create: dir/level0/level1/ with a .md file in level1 (at the depth limit).
        // With maxDepth=2, level1 is at childDepth 2 and triggers truncation.
        // The .md file must be a direct child of level1 so directoryHasMarkdownFiles passes.
        let level0 = try createSubdir(dir, name: "level0")
        let level1 = try createSubdir(level0, name: "level1")
        try createFile(at: level1.appendingPathComponent("deep.md"))

        let tree = DirectoryScanner.scan(url: dir, maxDepth: 2)

        func findTruncation(in node: FileTreeNode) -> Bool {
            if node.isTruncated { return true }
            return node.children.contains { findTruncation(in: $0) }
        }

        let root = try #require(tree)
        #expect(findTruncation(in: root))
    }

    @Test("Creates truncation indicator node at depth limit")
    func truncationIndicator() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let sub = try createSubdir(dir, name: "nested")
        try createFile(at: sub.appendingPathComponent("file.md"))

        let tree = DirectoryScanner.scan(url: dir, maxDepth: 1)
        let nestedNode = tree?.children.first { $0.name == "nested" }

        #expect(nestedNode != nil)
        #expect(nestedNode?.children.count == 1)
        #expect(nestedNode?.children.first?.isTruncated == true)
        #expect(nestedNode?.children.first?.name == "...")
    }

    // MARK: - Nonexistent / Unreadable

    @Test("Returns nil for nonexistent directory")
    func returnsNilForNonexistent() {
        let fakeURL = URL(fileURLWithPath: "/tmp/definitely-does-not-exist-\(UUID())")
        let result = DirectoryScanner.scan(url: fakeURL)
        #expect(result == nil)
    }

    @Test("Returns nil when given a file path instead of directory")
    func returnsNilForFilePath() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let file = dir.appendingPathComponent("file.md")
        try createFile(at: file)

        let result = DirectoryScanner.scan(url: file)
        #expect(result == nil)
    }

    // MARK: - Empty Directory

    @Test("Handles directory with no Markdown files")
    func handlesEmptyDirectory() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        try createFile(at: dir.appendingPathComponent("readme.txt"), content: "text")

        let tree = DirectoryScanner.scan(url: dir)
        #expect(tree != nil)
        #expect(tree?.children.isEmpty == true)
    }

    @Test("Handles completely empty directory")
    func handlesCompletelyEmptyDirectory() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let tree = DirectoryScanner.scan(url: dir)
        #expect(tree != nil)
        #expect(tree?.children.isEmpty == true)
    }

    // MARK: - Root Node

    @Test("Root node uses directory name and URL")
    func rootNodeProperties() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        try createFile(at: dir.appendingPathComponent("file.md"))

        let tree = DirectoryScanner.scan(url: dir)
        #expect(tree?.name == dir.lastPathComponent)
        #expect(tree?.url == dir)
        #expect(tree?.isDirectory == true)
        #expect(tree?.depth == 0)
        #expect(tree?.isTruncated == false)
    }

    // MARK: - Nested Structure

    @Test("Scans nested directories recursively")
    func scansNested() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let sub = try createSubdir(dir, name: "guides")
        try createFile(at: sub.appendingPathComponent("intro.md"))
        try createFile(at: dir.appendingPathComponent("readme.md"))

        let tree = DirectoryScanner.scan(url: dir)
        let topNames = tree?.children.map(\.name) ?? []

        #expect(topNames == ["guides", "readme.md"])

        let guidesNode = tree?.children.first { $0.name == "guides" }
        #expect(guidesNode?.isDirectory == true)
        #expect(guidesNode?.children.count == 1)
        #expect(guidesNode?.children.first?.name == "intro.md")
    }

    @Test("Child files have correct depth values")
    func childDepthValues() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let sub = try createSubdir(dir, name: "level1")
        let sub2 = try createSubdir(sub, name: "level2")
        try createFile(at: dir.appendingPathComponent("root.md"))
        try createFile(at: sub.appendingPathComponent("one.md"))
        try createFile(at: sub2.appendingPathComponent("two.md"))

        let tree = DirectoryScanner.scan(url: dir)

        let rootFile = tree?.children.first { $0.name == "root.md" }
        #expect(rootFile?.depth == 1)

        let level1Dir = tree?.children.first { $0.name == "level1" }
        #expect(level1Dir?.depth == 1)

        let level1File = level1Dir?.children.first { $0.name == "one.md" }
        #expect(level1File?.depth == 2)

        let level2Dir = level1Dir?.children.first { $0.name == "level2" }
        #expect(level2Dir?.depth == 2)

        let level2File = level2Dir?.children.first { $0.name == "two.md" }
        #expect(level2File?.depth == 3)
    }
}
