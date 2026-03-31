import Foundation
import Testing
@testable import mkdnLib

@Suite("GitProcessRunner")
struct GitProcessRunnerTests {
    // MARK: - repoRoot

    @Test("repoRoot returns non-nil for mkdn repo")
    func repoRootForMkdn() async {
        let projectDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Unit/Core/
            .deletingLastPathComponent() // Unit/
            .deletingLastPathComponent() // mkdnTests/
            .deletingLastPathComponent() // mkdn project root

        let root = await GitProcessRunner.repoRoot(for: projectDir)
        #expect(root != nil)
    }

    @Test("repoRoot returns nil for /tmp")
    func repoRootForTmp() async {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("mkdn-git-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let root = await GitProcessRunner.repoRoot(for: tmp)
        #expect(root == nil)
    }

    // MARK: - branchName

    @Test("branchName returns non-empty string")
    func branchNameNonEmpty() async {
        let projectDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let branch = await GitProcessRunner.branchName(in: projectDir)
        #expect(branch != nil)
        #expect(branch?.isEmpty == false)
    }

    // MARK: - status

    @Test("status returns data without throwing")
    func statusReturnsData() async throws {
        let projectDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let data = try await GitProcessRunner.status(in: projectDir)
        // Should not throw — data may or may not be empty
        _ = data
    }
}
