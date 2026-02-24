import Foundation
import Testing
@testable import mkdnLib

@Suite("DocumentState")
struct DocumentStateTests {
    /// Sets up a DocumentState with a file loaded but no FileWatcher DispatchSource.
    ///
    /// DispatchSource cleanup races with test process teardown (signal 5).
    /// This helper avoids creating a DispatchSource by directly setting state
    /// and using saveFile() to establish the lastSavedContent baseline.
    @MainActor
    private static func stateWithFile(
        content: String
    ) throws -> (DocumentState, URL) {
        let state = DocumentState()
        let url = URL(fileURLWithPath: "/tmp/mkdn-test-\(UUID().uuidString).md")
        try content.write(to: url, atomically: true, encoding: .utf8)
        state.currentFileURL = url
        state.markdownContent = content
        try state.saveFile()
        return (state, url)
    }

    @Test("Default state is preview-only with no file")
    @MainActor func defaultState() {
        let state = DocumentState()

        #expect(state.currentFileURL == nil)
        #expect(state.markdownContent.isEmpty)
        #expect(!state.isFileOutdated)
        #expect(state.viewMode == .previewOnly)
        #expect(state.modeOverlayLabel == nil)
    }

    @Test("Loads a Markdown file")
    @MainActor func loadsFile() throws {
        let state = DocumentState()
        let url = URL(fileURLWithPath: "/tmp/mkdn-test-\(UUID().uuidString).md")
        let content = "# Test Heading\n\nSome content."

        try content.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        try state.loadFile(at: url)
        state.fileWatcher.stopWatching()

        #expect(state.currentFileURL == url)
        #expect(state.markdownContent == content)
    }

    @Test("Saves content to file")
    @MainActor func savesFile() throws {
        let (state, url) = try Self.stateWithFile(content: "# Original")
        defer { try? FileManager.default.removeItem(at: url) }

        state.markdownContent = "# Updated"
        try state.saveFile()

        let saved = try String(contentsOf: url, encoding: .utf8)
        #expect(saved == "# Updated")
    }

    @Test("Reload refreshes content from disk")
    @MainActor func reloadsFile() throws {
        let (state, url) = try Self.stateWithFile(content: "# Version 1")
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(state.markdownContent == "# Version 1")

        try "# Version 2".write(to: url, atomically: true, encoding: .utf8)
        try state.reloadFile()
        state.fileWatcher.stopWatching()

        #expect(state.markdownContent == "# Version 2")
    }

    @Test("View mode toggles correctly")
    @MainActor func viewModeToggles() {
        let state = DocumentState()

        #expect(state.viewMode == .previewOnly)

        state.viewMode = .sideBySide
        #expect(state.viewMode == .sideBySide)

        state.viewMode = .previewOnly
        #expect(state.viewMode == .previewOnly)
    }

    // MARK: - Unsaved Changes Tracking

    @Test("hasUnsavedChanges is false after loadFile")
    @MainActor func noUnsavedChangesAfterLoad() throws {
        let state = DocumentState()
        let url = URL(fileURLWithPath: "/tmp/mkdn-test-\(UUID().uuidString).md")
        let content = "# Fresh Load"

        try content.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        try state.loadFile(at: url)
        state.fileWatcher.stopWatching()

        #expect(!state.hasUnsavedChanges)
        #expect(state.lastSavedContent == content)
    }

    @Test("hasUnsavedChanges becomes true when markdownContent diverges")
    @MainActor func unsavedChangesOnEdit() throws {
        let (state, url) = try Self.stateWithFile(content: "# Original")
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(!state.hasUnsavedChanges)

        state.markdownContent = "# Edited"
        #expect(state.hasUnsavedChanges)
    }

    @Test("hasUnsavedChanges becomes false after saveFile")
    @MainActor func unsavedChangesClearedBySave() throws {
        let (state, url) = try Self.stateWithFile(content: "# Start")
        defer { try? FileManager.default.removeItem(at: url) }

        state.markdownContent = "# Changed"
        #expect(state.hasUnsavedChanges)

        try state.saveFile()
        #expect(!state.hasUnsavedChanges)
    }

    @Test("saveFile writes correct content verified by read-back")
    @MainActor func saveFileWritesContent() throws {
        let (state, url) = try Self.stateWithFile(content: "# Initial")
        defer { try? FileManager.default.removeItem(at: url) }

        state.markdownContent = "# Written by saveFile"
        try state.saveFile()

        let readBack = try String(contentsOf: url, encoding: .utf8)
        #expect(readBack == "# Written by saveFile")
    }

    @Test("saveFile with no currentFileURL is a no-op")
    @MainActor func saveFileNoURLIsNoOp() throws {
        let state = DocumentState()

        #expect(state.currentFileURL == nil)
        try state.saveFile()
        #expect(!state.hasUnsavedChanges)
    }

    @Test("reloadFile resets both markdownContent and lastSavedContent")
    @MainActor func reloadResetsBothContentFields() throws {
        let (state, url) = try Self.stateWithFile(content: "# Version A")
        defer { try? FileManager.default.removeItem(at: url) }

        state.markdownContent = "# Unsaved Edit"
        #expect(state.hasUnsavedChanges)

        try "# Version B".write(to: url, atomically: true, encoding: .utf8)
        try state.reloadFile()
        state.fileWatcher.stopWatching()

        #expect(state.markdownContent == "# Version B")
        #expect(state.lastSavedContent == "# Version B")
        #expect(!state.hasUnsavedChanges)
    }

    @Test("lastSavedContent updates after save")
    @MainActor func lastSavedContentUpdatesOnSave() throws {
        let (state, url) = try Self.stateWithFile(content: "# First")
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(state.lastSavedContent == "# First")

        state.markdownContent = "# Second"
        try state.saveFile()
        #expect(state.lastSavedContent == "# Second")

        state.markdownContent = "# Third"
        try state.saveFile()
        #expect(state.lastSavedContent == "# Third")
    }
}
