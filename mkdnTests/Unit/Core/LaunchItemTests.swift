import Foundation
import Testing

@testable import mkdnLib

@Suite("LaunchItem")
struct LaunchItemTests {
    // MARK: - URL Accessor

    @Test("File case url accessor returns the file URL")
    func fileURLAccessor() {
        let url = URL(fileURLWithPath: "/tmp/readme.md")
        let item = LaunchItem.file(url)
        #expect(item.url == url)
    }

    @Test("Directory case url accessor returns the directory URL")
    func directoryURLAccessor() {
        let url = URL(fileURLWithPath: "/tmp/docs")
        let item = LaunchItem.directory(url)
        #expect(item.url == url)
    }

    // MARK: - Codable Round-Trip

    @Test("Codable round-trip for file case")
    func codableRoundTripFile() throws {
        let url = URL(fileURLWithPath: "/tmp/readme.md")
        let original = LaunchItem.file(url)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LaunchItem.self, from: data)

        #expect(decoded == original)
    }

    @Test("Codable round-trip for directory case")
    func codableRoundTripDirectory() throws {
        let url = URL(fileURLWithPath: "/tmp/docs")
        let original = LaunchItem.directory(url)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LaunchItem.self, from: data)

        #expect(decoded == original)
    }

    // MARK: - Hashable

    @Test("Same file URLs produce equal items")
    func hashableEqualityFile() {
        let url = URL(fileURLWithPath: "/tmp/readme.md")
        let itemA = LaunchItem.file(url)
        let itemB = LaunchItem.file(url)
        #expect(itemA == itemB)
    }

    @Test("Same directory URLs produce equal items")
    func hashableEqualityDirectory() {
        let url = URL(fileURLWithPath: "/tmp/docs")
        let itemA = LaunchItem.directory(url)
        let itemB = LaunchItem.directory(url)
        #expect(itemA == itemB)
    }

    @Test("File and directory with same URL are not equal")
    func fileAndDirectoryNotEqual() {
        let url = URL(fileURLWithPath: "/tmp/path")
        let fileItem = LaunchItem.file(url)
        let dirItem = LaunchItem.directory(url)
        #expect(fileItem != dirItem)
    }

    @Test("Different URLs produce unequal items")
    func differentURLsNotEqual() {
        let urlA = URL(fileURLWithPath: "/tmp/a.md")
        let urlB = URL(fileURLWithPath: "/tmp/b.md")
        let itemA = LaunchItem.file(urlA)
        let itemB = LaunchItem.file(urlB)
        #expect(itemA != itemB)
    }

    @Test("Can be used as dictionary key")
    func usableAsDictionaryKey() {
        let fileItem = LaunchItem.file(URL(fileURLWithPath: "/tmp/a.md"))
        let dirItem = LaunchItem.directory(URL(fileURLWithPath: "/tmp/docs"))

        var dict: [LaunchItem: String] = [:]
        dict[fileItem] = "file"
        dict[dirItem] = "directory"

        #expect(dict.count == 2)
        #expect(dict[fileItem] == "file")
        #expect(dict[dirItem] == "directory")
    }
}
