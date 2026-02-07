import Foundation
import Testing

@testable import mkdnLib

@Suite("FileOpenCoordinator")
struct FileOpenCoordinatorTests {
    @Test("pendingURLs starts empty")
    @MainActor func startsEmpty() {
        let coordinator = FileOpenCoordinator()
        #expect(coordinator.pendingURLs.isEmpty)
    }

    @Test("Appending URLs makes them available")
    @MainActor func appendMakesAvailable() {
        let coordinator = FileOpenCoordinator()
        let url = URL(fileURLWithPath: "/tmp/test.md")

        coordinator.pendingURLs.append(url)

        #expect(coordinator.pendingURLs.count == 1)
        #expect(coordinator.pendingURLs.first == url)
    }

    @Test("consumeAll returns all URLs and clears the list")
    @MainActor func consumeAllReturnsThenClears() {
        let coordinator = FileOpenCoordinator()
        let first = URL(fileURLWithPath: "/tmp/a.md")
        let second = URL(fileURLWithPath: "/tmp/b.md")

        coordinator.pendingURLs.append(first)
        coordinator.pendingURLs.append(second)

        let consumed = coordinator.consumeAll()

        #expect(consumed == [first, second])
        #expect(coordinator.pendingURLs.isEmpty)
    }

    @Test("consumeAll on empty list returns empty array")
    @MainActor func consumeAllEmptyReturnsEmpty() {
        let coordinator = FileOpenCoordinator()

        let consumed = coordinator.consumeAll()

        #expect(consumed.isEmpty)
        #expect(coordinator.pendingURLs.isEmpty)
    }
}
