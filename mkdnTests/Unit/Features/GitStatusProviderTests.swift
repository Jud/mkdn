import Foundation
import Testing
@testable import mkdnLib

@Suite("GitStatusProvider")
struct GitStatusProviderTests {
    // MARK: - Initial State

    @Test("Initial state: not a git repository, empty statuses")
    @MainActor
    func initialState() {
        let provider = GitStatusProvider()
        #expect(provider.isGitRepository == false)
        #expect(provider.branchName == nil)
        #expect(provider.fileStatuses.isEmpty)
        #expect(provider.directoriesWithChanges.isEmpty)
        #expect(provider.changedFileCount == 0)
        #expect(provider.showOnlyChanged == false)
    }

    // MARK: - Lookups on Empty State

    @Test("status(for:) returns nil for unknown URLs")
    @MainActor
    func statusForUnknown() {
        let provider = GitStatusProvider()
        let url = URL(fileURLWithPath: "/some/path/file.md")
        #expect(provider.status(for: url) == nil)
    }

    @Test("hasChangedDescendants returns false for unknown directories")
    @MainActor
    func hasChangedDescendantsUnknown() {
        let provider = GitStatusProvider()
        let url = URL(fileURLWithPath: "/some/dir")
        #expect(provider.hasChangedDescendants(under: url) == false)
    }

    // MARK: - applyStatuses

    @Test("applyStatuses populates file statuses")
    @MainActor
    func applyStatusesBasic() {
        let provider = GitStatusProvider()
        let repoRoot = URL(fileURLWithPath: "/repo")
        let sidebarRoot = URL(fileURLWithPath: "/repo")

        let statuses: [String: GitFileStatus] = [
            "readme.md": .modified,
            "src/lib.swift": .added,
        ]

        provider.applyStatuses(statuses, repoRoot: repoRoot, sidebarRoot: sidebarRoot)

        #expect(provider.fileStatuses.count == 2)
        #expect(provider.status(for: repoRoot.appendingPathComponent("readme.md")) == .modified)
        #expect(provider.status(for: repoRoot.appendingPathComponent("src/lib.swift")) == .added)
    }

    @Test("applyStatuses computes changedFileCount excluding deleted")
    @MainActor
    func changedFileCountExcludesDeleted() {
        let provider = GitStatusProvider()
        let root = URL(fileURLWithPath: "/repo")

        provider.applyStatuses(
            ["a.md": .modified, "b.md": .deleted, "c.md": .added],
            repoRoot: root,
            sidebarRoot: root
        )

        #expect(provider.changedFileCount == 2)
    }

    // MARK: - Directory Propagation

    @Test("Directory propagation walks ancestors")
    @MainActor
    func directoryPropagation() {
        let provider = GitStatusProvider()
        let root = URL(fileURLWithPath: "/repo")

        provider.applyStatuses(
            ["a/b/file.md": .modified],
            repoRoot: root,
            sidebarRoot: root
        )

        let dirA = root.appendingPathComponent("a")
        let dirAB = root.appendingPathComponent("a/b")

        #expect(provider.hasChangedDescendants(under: dirA))
        #expect(provider.hasChangedDescendants(under: dirAB))
        #expect(!provider.hasChangedDescendants(under: root))
    }

    @Test("Directory propagation stops at sidebar root")
    @MainActor
    func directoryPropagationStopsAtRoot() {
        let provider = GitStatusProvider()
        let repoRoot = URL(fileURLWithPath: "/repo")
        let sidebarRoot = URL(fileURLWithPath: "/repo/sub")

        provider.applyStatuses(
            ["sub/deep/file.md": .modified],
            repoRoot: repoRoot,
            sidebarRoot: sidebarRoot
        )

        // Should not propagate above sidebar root
        #expect(!provider.hasChangedDescendants(under: sidebarRoot))
        #expect(provider.hasChangedDescendants(
            under: repoRoot.appendingPathComponent("sub/deep")
        ))
    }

    // MARK: - configure Resets State

    @Test("configure resets showOnlyChanged")
    @MainActor
    func configureResetsShowOnlyChanged() {
        let provider = GitStatusProvider()
        provider.showOnlyChanged = true

        // Use the real mkdn repo to test configure
        let projectDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Features/
            .deletingLastPathComponent() // Unit/
            .deletingLastPathComponent() // mkdnTests/
            .deletingLastPathComponent() // project root

        provider.configure(sidebarRoot: projectDir)

        #expect(provider.showOnlyChanged == false)
    }
}
