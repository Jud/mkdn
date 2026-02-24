import Foundation
import Testing
@testable import mkdnLib

@Suite("Multi-file CLI validation")
struct MultiFileValidationTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mkdn-multi-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func removeTempDir(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    private func createTextFile(at url: URL, content: String = "# Hello\n") throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test("All valid files produce URLs for each file")
    func allValidFilesProduceURLs() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let fileA = dir.appendingPathComponent("a.md")
        let fileB = dir.appendingPathComponent("b.md")
        let fileC = dir.appendingPathComponent("c.md")
        try createTextFile(at: fileA)
        try createTextFile(at: fileB)
        try createTextFile(at: fileC)

        var validURLs: [URL] = []
        for path in [fileA.path, fileB.path, fileC.path] {
            do {
                let url = try FileValidator.validate(path: path)
                validURLs.append(url)
            } catch {}
        }

        #expect(validURLs.count == 3)
    }

    @Test("Mixed valid and invalid files produce URLs only for valid files")
    func mixedValidityProducesPartialURLs() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let validFile = dir.appendingPathComponent("valid.md")
        try createTextFile(at: validFile)
        let missingFile = dir.appendingPathComponent("nonexistent.md")
        let badExtFile = dir.appendingPathComponent("notes.txt")
        try createTextFile(at: badExtFile)

        var validURLs: [URL] = []
        var errors: [CLIError] = []
        for path in [validFile.path, missingFile.path, badExtFile.path] {
            do {
                let url = try FileValidator.validate(path: path)
                validURLs.append(url)
            } catch let error as CLIError {
                errors.append(error)
            }
        }

        #expect(validURLs.count == 1)
        #expect(errors.count == 2)
    }

    @Test("All invalid files produce zero URLs")
    func allInvalidProducesZeroURLs() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let missingA = dir.appendingPathComponent("nope-a.md")
        let missingB = dir.appendingPathComponent("nope-b.md")

        var validURLs: [URL] = []
        var errors: [CLIError] = []
        for path in [missingA.path, missingB.path] {
            do {
                let url = try FileValidator.validate(path: path)
                validURLs.append(url)
            } catch let error as CLIError {
                errors.append(error)
            }
        }

        #expect(validURLs.isEmpty)
        #expect(errors.count == 2)
    }
}
