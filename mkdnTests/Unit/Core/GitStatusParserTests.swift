import Foundation
import Testing
@testable import mkdnLib

@Suite("GitStatusParser")
struct GitStatusParserTests {
    // MARK: - Empty Input

    @Test("Empty data returns empty dictionary")
    func emptyInput() {
        let result = GitStatusParser.parse(Data())
        #expect(result.isEmpty)
    }

    // MARK: - Single Entry

    @Test("Single modified file")
    func singleModified() {
        // " M readme.md\0"
        let raw = " M readme.md\0"
        let data = Data(raw.utf8)
        let result = GitStatusParser.parse(data)

        #expect(result.count == 1)
        #expect(result["readme.md"] == .modified)
    }

    @Test("Single added file")
    func singleAdded() {
        let raw = "A  newfile.swift\0"
        let data = Data(raw.utf8)
        let result = GitStatusParser.parse(data)

        #expect(result["newfile.swift"] == .added)
    }

    @Test("Single deleted file")
    func singleDeleted() {
        let raw = " D removed.txt\0"
        let data = Data(raw.utf8)
        let result = GitStatusParser.parse(data)

        #expect(result["removed.txt"] == .deleted)
    }

    @Test("Untracked file")
    func untracked() {
        let raw = "?? untrackedfile.md\0"
        let data = Data(raw.utf8)
        let result = GitStatusParser.parse(data)

        #expect(result["untrackedfile.md"] == .untracked)
    }

    // MARK: - Subdirectory Paths

    @Test("Subdirectory paths preserved")
    func subdirectoryPaths() {
        let raw = " M src/lib/utils.swift\0A  docs/new.md\0"
        let data = Data(raw.utf8)
        let result = GitStatusParser.parse(data)

        #expect(result.count == 2)
        #expect(result["src/lib/utils.swift"] == .modified)
        #expect(result["docs/new.md"] == .added)
    }

    // MARK: - Rename

    @Test("Rename entry consumes two NUL fields")
    func renameEntry() {
        // R  new.md\0old.md\0 M other.md\0
        let raw = "R  new.md\0old.md\0 M other.md\0"
        let data = Data(raw.utf8)
        let result = GitStatusParser.parse(data)

        #expect(result.count == 2)
        #expect(result["new.md"] == .renamed)
        #expect(result["other.md"] == .modified)
    }

    // MARK: - Y-Column Priority

    @Test("Y-column takes precedence over X-column")
    func yColumnPriority() {
        // "MM" → both staged and working tree modified, Y wins → .modified
        let raw = "MM both.swift\0"
        let data = Data(raw.utf8)
        let result = GitStatusParser.parse(data)

        #expect(result["both.swift"] == .modified)
    }

    @Test("Added in index, modified in working tree")
    func addedThenModified() {
        // "AM" → added in index, modified in working tree → Y wins → .modified
        let raw = "AM file.swift\0"
        let data = Data(raw.utf8)
        let result = GitStatusParser.parse(data)

        #expect(result["file.swift"] == .modified)
    }

    // MARK: - Mixed Statuses

    @Test("Mixed statuses parsed correctly")
    func mixedStatuses() {
        let raw = " M modified.md\0A  added.swift\0 D deleted.txt\0?? untracked.json\0"
        let data = Data(raw.utf8)
        let result = GitStatusParser.parse(data)

        #expect(result.count == 4)
        #expect(result["modified.md"] == .modified)
        #expect(result["added.swift"] == .added)
        #expect(result["deleted.txt"] == .deleted)
        #expect(result["untracked.json"] == .untracked)
    }

    // MARK: - Performance

    @Test("Parses 10k entries in under 100ms")
    func stressTest() {
        var raw = ""
        for i in 0 ..< 10_000 {
            raw += " M path/to/file\(i).swift\0"
        }
        let data = Data(raw.utf8)

        let start = ContinuousClock().now
        let result = GitStatusParser.parse(data)
        let elapsed = ContinuousClock().now - start

        #expect(result.count == 10_000)
        #expect(elapsed < .milliseconds(100))
    }
}
