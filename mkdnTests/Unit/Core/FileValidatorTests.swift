import Foundation
import Testing
@testable import mkdnLib

@Suite("FileValidator")
struct FileValidatorTests {
    /// Creates a temporary directory for test files.
    /// Returns the directory URL. Caller is responsible for cleanup.
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mkdn-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Removes a temporary directory and all its contents.
    private func removeTempDir(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    /// Creates a UTF-8 text file at the given URL with the provided content.
    private func createTextFile(at url: URL, content: String = "# Hello\n") throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Path Resolution

    @Test("Resolves absolute path preserving directory and filename")
    func resolvesAbsolutePath() {
        let resolved = FileValidator.resolvePath("/usr/local/share/test.md")
        #expect(resolved.lastPathComponent == "test.md")
        #expect(resolved.path.contains("/usr/local/share"))
    }

    @Test("Resolves relative path against current working directory")
    func resolvesRelativePath() {
        let cwd = FileManager.default.currentDirectoryPath
        let resolved = FileValidator.resolvePath("subdir/file.md")
        #expect(resolved.path.hasPrefix(cwd) || resolved.path.contains("subdir/file.md"))
        #expect(resolved.lastPathComponent == "file.md")
    }

    @Test("Expands tilde to home directory")
    func expandsTilde() {
        let resolved = FileValidator.resolvePath("~/Documents/test.md")
        let home = NSHomeDirectory()
        #expect(resolved.path.hasPrefix(home))
        #expect(resolved.lastPathComponent == "test.md")
    }

    @Test("Resolves parent directory (..) segments")
    func resolvesParentSegments() {
        let resolved = FileValidator.resolvePath("/usr/local/share/../lib/test.md")
        #expect(!resolved.path.contains(".."))
        #expect(resolved.path.contains("/usr/local/lib/test.md"))
    }

    @Test("Resolves symlinks to their target")
    func resolvesSymlinks() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let realFile = dir.appendingPathComponent("real.md")
        try createTextFile(at: realFile)

        let linkPath = dir.appendingPathComponent("link.md").path
        try FileManager.default.createSymbolicLink(
            atPath: linkPath,
            withDestinationPath: realFile.path
        )

        let resolved = FileValidator.resolvePath(linkPath)
        #expect(resolved.path == realFile.resolvingSymlinksInPath().path)
    }

    // MARK: - Extension Validation

    @Test("Accepts .md extension")
    func acceptsMdExtension() throws {
        let url = URL(fileURLWithPath: "/tmp/file.md")
        #expect(throws: Never.self) {
            try FileValidator.validateExtension(url: url, originalPath: "file.md")
        }
    }

    @Test("Accepts .markdown extension")
    func acceptsMarkdownExtension() throws {
        let url = URL(fileURLWithPath: "/tmp/file.markdown")
        #expect(throws: Never.self) {
            try FileValidator.validateExtension(url: url, originalPath: "file.markdown")
        }
    }

    @Test("Accepts uppercase .MD extension")
    func acceptsUppercaseMdExtension() throws {
        let url = URL(fileURLWithPath: "/tmp/file.MD")
        #expect(throws: Never.self) {
            try FileValidator.validateExtension(url: url, originalPath: "file.MD")
        }
    }

    @Test("Rejects .txt extension with descriptive error")
    func rejectsTxtExtension() {
        let url = URL(fileURLWithPath: "/tmp/notes.txt")
        #expect {
            try FileValidator.validateExtension(url: url, originalPath: "notes.txt")
        } throws: { error in
            guard let cliError = error as? CLIError else { return false }
            guard case let .unsupportedExtension(path, ext) = cliError else { return false }
            return path == "notes.txt" && ext == "txt"
        }
    }

    @Test("Rejects file with no extension")
    func rejectsNoExtension() {
        let url = URL(fileURLWithPath: "/tmp/README")
        #expect {
            try FileValidator.validateExtension(url: url, originalPath: "README")
        } throws: { error in
            guard let cliError = error as? CLIError else { return false }
            guard case let .unsupportedExtension(path, ext) = cliError else { return false }
            return path == "README" && ext.isEmpty
        }
    }

    // MARK: - Existence Validation

    @Test("Passes for existing file")
    func existencePassesForExistingFile() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let file = dir.appendingPathComponent("exists.md")
        try createTextFile(at: file)

        #expect(throws: Never.self) {
            try FileValidator.validateExistence(url: file)
        }
    }

    @Test("Throws fileNotFound for missing file with resolved path in message")
    func existenceThrowsForMissingFile() {
        let missingURL = URL(fileURLWithPath: "/tmp/definitely-does-not-exist-\(UUID()).md")
        #expect {
            try FileValidator.validateExistence(url: missingURL)
        } throws: { error in
            guard let cliError = error as? CLIError else { return false }
            guard case let .fileNotFound(resolvedPath) = cliError else { return false }
            return resolvedPath == missingURL.path
        }
    }

    // MARK: - Readability Validation

    @Test("Passes for readable UTF-8 file")
    func readabilityPassesForUTF8File() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let file = dir.appendingPathComponent("readable.md")
        try createTextFile(at: file, content: "# Valid UTF-8 content\n")

        #expect(throws: Never.self) {
            try FileValidator.validateReadability(url: file)
        }
    }

    @Test("Throws fileNotReadable for non-UTF-8 binary file")
    func readabilityThrowsForBinaryFile() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let file = dir.appendingPathComponent("binary.md")
        let invalidUTF8 = Data([0xFF, 0xFE, 0x80, 0x81, 0xC0, 0xC1])
        try invalidUTF8.write(to: file)

        #expect {
            try FileValidator.validateReadability(url: file)
        } throws: { error in
            guard let cliError = error as? CLIError else { return false }
            guard case let .fileNotReadable(resolvedPath, reason) = cliError else { return false }
            return resolvedPath == file.path && reason.contains("UTF-8")
        }
    }

    // MARK: - Full Pipeline

    @Test("validate(path:) returns URL for valid Markdown file")
    func validateReturnsURLForValidFile() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let file = dir.appendingPathComponent("valid.md")
        try createTextFile(at: file)

        let result = try FileValidator.validate(path: file.path)
        #expect(result.lastPathComponent == "valid.md")
    }

    @Test("validate(path:) checks extension before existence")
    func validateChecksExtensionBeforeExistence() {
        // A .txt file that does not exist should produce an unsupported extension
        // error, NOT a file-not-found error -- proving extension is checked first.
        let fakePath = "/tmp/definitely-does-not-exist-\(UUID()).txt"
        #expect {
            try FileValidator.validate(path: fakePath)
        } throws: { error in
            guard let cliError = error as? CLIError else { return false }
            if case .unsupportedExtension = cliError { return true }
            return false
        }
    }
}
