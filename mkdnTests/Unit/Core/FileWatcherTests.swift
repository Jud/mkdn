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
        for _ in 0 ..< 20 {
            try await Task.sleep(for: .milliseconds(100))
            if !watcher.isSavePaused { break }
        }
        #expect(!watcher.isSavePaused)
    }

    // Note: Tests that call watch(url:) instantiate a file-system event source
    // (FSEvents) whose teardown races the test process exit, causing signal 5
    // crashes — so watch() is intentionally not unit-tested here.
    //
    // The watcher now uses FSEvents on the file's parent directory (was an
    // fd-bound DispatchSource vnode source, which went permanently deaf after an
    // atomic-rename save swapped the file's inode). That regression — repeated
    // atomic-rename writes must each be detected — is verified out-of-process
    // (scripts/ or a standalone harness) and via the full app, not in this suite.
}
