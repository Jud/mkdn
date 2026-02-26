import Foundation
import Testing
@testable import mkdnLib

@Suite("FileWatcher")
struct FileWatcherTests {
    @Test("Starts not outdated")
    @MainActor func startsClean() {
        let watcher = FileWatcher()
        #expect(!watcher.isOutdated)
        #expect(watcher.watchedURL == nil)
    }

    @Test("Acknowledge clears outdated flag")
    @MainActor func acknowledgeClearsOutdated() {
        let watcher = FileWatcher()
        watcher.acknowledge()
        #expect(!watcher.isOutdated)
    }

    // MARK: - Save-Pause Behavior

    @Test("pauseForSave prevents isOutdated from being set")
    @MainActor func pauseForSavePreventsOutdated() {
        let watcher = FileWatcher()
        #expect(!watcher.isSavePaused)

        watcher.pauseForSave()

        #expect(watcher.isSavePaused)
        #expect(!watcher.isOutdated)
    }

    @Test("resumeAfterSave re-enables detection after delay")
    @MainActor func resumeAfterSaveReEnables() async throws {
        let watcher = FileWatcher()
        watcher.pauseForSave()
        #expect(watcher.isSavePaused)

        watcher.resumeAfterSave()
        #expect(watcher.isSavePaused)

        // Poll instead of fixed sleep — the 200ms internal delay can stretch
        // under MainActor contention during full test suite runs.
        for _ in 0..<20 {
            try await Task.sleep(for: .milliseconds(100))
            if !watcher.isSavePaused { break }
        }
        #expect(!watcher.isSavePaused)
    }

    // Note: Tests that call watch(url:) create a DispatchSource whose async
    // teardown can race with the test process exit, causing signal 5 crashes.
    // Integration tests for file watching should run in the full app context
    // or in a dedicated XCUITest harness.
}
