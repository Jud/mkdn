import Foundation
import Testing
@testable import mkdnLib

@Suite("CLIError")
struct CLIErrorTests {
    // MARK: - Exit Codes

    @Test("unsupportedExtension exit code is 1")
    func unsupportedExtensionExitCode() {
        let error = CLIError.unsupportedExtension(path: "file.txt", ext: "txt")
        #expect(error.exitCode == 1)
    }

    @Test("fileNotFound exit code is 1")
    func fileNotFoundExitCode() {
        let error = CLIError.fileNotFound(resolvedPath: "/tmp/missing.md")
        #expect(error.exitCode == 1)
    }

    @Test("fileNotReadable exit code is 2")
    func fileNotReadableExitCode() {
        let error = CLIError.fileNotReadable(resolvedPath: "/tmp/locked.md", reason: "permission denied")
        #expect(error.exitCode == 2)
    }

    // MARK: - Error Messages

    @Test("unsupportedExtension message includes extension and accepted types")
    func unsupportedExtensionMessage() {
        let error = CLIError.unsupportedExtension(path: "notes.txt", ext: "txt")
        let message = error.errorDescription ?? ""
        #expect(message.contains(".txt"))
        #expect(message.contains("notes.txt"))
        #expect(message.contains(".md"))
        #expect(message.contains(".markdown"))
    }

    @Test("unsupportedExtension message handles empty extension")
    func unsupportedExtensionEmptyExt() {
        let error = CLIError.unsupportedExtension(path: "README", ext: "")
        let message = error.errorDescription ?? ""
        #expect(message.contains("no extension"))
        #expect(message.contains("README"))
    }

    @Test("fileNotFound message includes resolved path")
    func fileNotFoundMessage() {
        let error = CLIError.fileNotFound(resolvedPath: "/Users/dev/docs/missing.md")
        let message = error.errorDescription ?? ""
        #expect(message.contains("/Users/dev/docs/missing.md"))
        #expect(message.contains("not found"))
    }

    @Test("fileNotReadable message includes path and reason")
    func fileNotReadableMessage() {
        let error = CLIError.fileNotReadable(
            resolvedPath: "/tmp/locked.md",
            reason: "permission denied"
        )
        let message = error.errorDescription ?? ""
        #expect(message.contains("/tmp/locked.md"))
        #expect(message.contains("permission denied"))
    }
}
