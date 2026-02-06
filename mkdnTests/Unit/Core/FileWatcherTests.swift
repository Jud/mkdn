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

    // Note: Tests that call watch(url:) create a DispatchSource whose async
    // teardown can race with the test process exit, causing signal 5 crashes.
    // Integration tests for file watching should run in the full app context
    // or in a dedicated XCUITest harness.
}
