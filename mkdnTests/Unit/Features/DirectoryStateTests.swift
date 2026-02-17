import Foundation
import Testing

@testable import mkdnLib

@Suite("DirectoryState")
struct DirectoryStateTests {
    // MARK: - Initial State

    @Test("Initial state has sidebar visible and default width")
    @MainActor func initialState() {
        let url = URL(fileURLWithPath: "/tmp/test-dir")
        let state = DirectoryState(rootURL: url)

        #expect(state.rootURL == url)
        #expect(state.tree == nil)
        #expect(state.expandedDirectories.isEmpty)
        #expect(state.selectedFileURL == nil)
        #expect(state.isSidebarVisible == true)
        #expect(state.sidebarWidth == 240)
    }

    // MARK: - Sidebar Toggle

    @Test("toggleSidebar flips visibility from true to false")
    @MainActor func toggleSidebarHides() {
        let state = DirectoryState(rootURL: URL(fileURLWithPath: "/tmp"))
        #expect(state.isSidebarVisible == true)

        state.toggleSidebar()

        #expect(state.isSidebarVisible == false)
    }

    @Test("toggleSidebar flips visibility from false to true")
    @MainActor func toggleSidebarShows() {
        let state = DirectoryState(rootURL: URL(fileURLWithPath: "/tmp"))
        state.isSidebarVisible = false

        state.toggleSidebar()

        #expect(state.isSidebarVisible == true)
    }

    @Test("Double toggle returns to original state")
    @MainActor func doubleToggle() {
        let state = DirectoryState(rootURL: URL(fileURLWithPath: "/tmp"))

        state.toggleSidebar()
        state.toggleSidebar()

        #expect(state.isSidebarVisible == true)
    }

    // MARK: - File Selection

    @Test("selectFile updates selectedFileURL")
    @MainActor func selectFileUpdatesURL() {
        let state = DirectoryState(rootURL: URL(fileURLWithPath: "/tmp"))
        let fileURL = URL(fileURLWithPath: "/tmp/readme.md")

        state.selectFile(at: fileURL)

        #expect(state.selectedFileURL == fileURL)
    }

    @Test("Selecting a new file replaces previous selection")
    @MainActor func selectNewFileReplacesOld() {
        let state = DirectoryState(rootURL: URL(fileURLWithPath: "/tmp"))
        let firstFile = URL(fileURLWithPath: "/tmp/first.md")
        let secondFile = URL(fileURLWithPath: "/tmp/second.md")

        state.selectFile(at: firstFile)
        #expect(state.selectedFileURL == firstFile)

        state.selectFile(at: secondFile)
        #expect(state.selectedFileURL == secondFile)
    }

    @Test("Selecting the same file again keeps selection unchanged")
    @MainActor func selectSameFileNoOp() {
        let state = DirectoryState(rootURL: URL(fileURLWithPath: "/tmp"))
        let fileURL = URL(fileURLWithPath: "/tmp/readme.md")

        state.selectFile(at: fileURL)
        state.selectFile(at: fileURL)

        #expect(state.selectedFileURL == fileURL)
    }

    // MARK: - Expansion State

    @Test("Expansion state can be toggled for a directory URL")
    @MainActor func expansionToggle() {
        let state = DirectoryState(rootURL: URL(fileURLWithPath: "/tmp"))
        let dirURL = URL(fileURLWithPath: "/tmp/guides")

        #expect(!state.expandedDirectories.contains(dirURL))

        state.expandedDirectories.insert(dirURL)
        #expect(state.expandedDirectories.contains(dirURL))

        state.expandedDirectories.remove(dirURL)
        #expect(!state.expandedDirectories.contains(dirURL))
    }

    @Test("Multiple directories can be expanded simultaneously")
    @MainActor func multipleExpanded() {
        let state = DirectoryState(rootURL: URL(fileURLWithPath: "/tmp"))
        let dirA = URL(fileURLWithPath: "/tmp/alpha")
        let dirB = URL(fileURLWithPath: "/tmp/beta")

        state.expandedDirectories.insert(dirA)
        state.expandedDirectories.insert(dirB)

        #expect(state.expandedDirectories.count == 2)
        #expect(state.expandedDirectories.contains(dirA))
        #expect(state.expandedDirectories.contains(dirB))
    }

    // MARK: - Static Constants

    @Test("Max scan depth is 10")
    @MainActor func maxScanDepth() {
        #expect(DirectoryState.maxScanDepth == 10)
    }

    @Test("Minimum sidebar width is 160")
    @MainActor func minSidebarWidth() {
        #expect(DirectoryState.minSidebarWidth == 160)
    }

    @Test("Maximum sidebar width is 400")
    @MainActor func maxSidebarWidth() {
        #expect(DirectoryState.maxSidebarWidth == 400)
    }

    // MARK: - Sidebar Width

    @Test("Sidebar width can be set within valid range")
    @MainActor func sidebarWidthSettable() {
        let state = DirectoryState(rootURL: URL(fileURLWithPath: "/tmp"))

        state.sidebarWidth = 300
        #expect(state.sidebarWidth == 300)
    }

    // MARK: - DirectoryWatcher Initial State

    @Test("DirectoryWatcher starts with no changes")
    @MainActor func watcherStartsClean() {
        let state = DirectoryState(rootURL: URL(fileURLWithPath: "/tmp"))
        #expect(state.directoryWatcher.hasChanges == false)
    }
}
