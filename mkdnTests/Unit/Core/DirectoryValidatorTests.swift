import Foundation
import Testing

@testable import mkdnLib

@Suite("DirectoryValidator")
struct DirectoryValidatorTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mkdn-dirval-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func removeTempDir(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Valid Directory

    @Test("Validates an existing directory")
    func validatesExistingDirectory() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let result = try DirectoryValidator.validate(path: dir.path)
        #expect(result.path == dir.resolvingSymlinksInPath().path)
    }

    // MARK: - Path Resolution

    @Test("Resolves tilde paths")
    func resolvesTilde() throws {
        let home = NSHomeDirectory()
        let result = try DirectoryValidator.validate(path: "~")
        #expect(result.path == URL(fileURLWithPath: home).resolvingSymlinksInPath().path)
    }

    @Test("Handles trailing slash on directory path")
    func handlesTrailingSlash() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let pathWithSlash = dir.path + "/"
        let result = try DirectoryValidator.validate(path: pathWithSlash)
        #expect(result.path == dir.resolvingSymlinksInPath().path)
    }

    // MARK: - Rejection Cases

    @Test("Rejects nonexistent path with directoryNotFound")
    func rejectsNonexistent() {
        let fakePath = "/tmp/definitely-does-not-exist-\(UUID())"
        #expect {
            try DirectoryValidator.validate(path: fakePath)
        } throws: { error in
            guard let cliError = error as? CLIError else { return false }
            guard case .directoryNotFound = cliError else { return false }
            return true
        }
    }

    @Test("Rejects file path with directoryNotFound")
    func rejectsFilePath() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let file = dir.appendingPathComponent("file.md")
        try "# Test".write(to: file, atomically: true, encoding: .utf8)

        #expect {
            try DirectoryValidator.validate(path: file.path)
        } throws: { error in
            guard let cliError = error as? CLIError else { return false }
            guard case .directoryNotFound = cliError else { return false }
            return true
        }
    }

    // MARK: - Error Messages

    @Test("directoryNotFound error includes resolved path")
    func errorIncludesPath() {
        let fakePath = "/tmp/nonexistent-dir-\(UUID())"
        do {
            _ = try DirectoryValidator.validate(path: fakePath)
            Issue.record("Expected error was not thrown")
        } catch {
            guard let cliError = error as? CLIError else {
                Issue.record("Expected CLIError")
                return
            }
            let description = cliError.errorDescription ?? ""
            #expect(description.contains("directory not found"))
        }
    }

    @Test("directoryNotFound has exit code 1")
    func directoryNotFoundExitCode() {
        let error = CLIError.directoryNotFound(resolvedPath: "/fake")
        #expect(error.exitCode == 1)
    }

    @Test("directoryNotReadable has exit code 2")
    func directoryNotReadableExitCode() {
        let error = CLIError.directoryNotReadable(resolvedPath: "/fake", reason: "denied")
        #expect(error.exitCode == 2)
    }
}
