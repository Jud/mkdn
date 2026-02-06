import Foundation
import Testing

@testable import mkdnLib

@Suite("EditorViewModel")
struct EditorViewModelTests {
    @Test("Default state is empty")
    @MainActor func defaultState() {
        let viewModel = EditorViewModel()

        #expect(viewModel.text.isEmpty)
        #expect(!viewModel.hasUnsavedChanges)
        #expect(viewModel.fileURL == nil)
    }

    @Test("Loads file content")
    @MainActor func loadsFile() throws {
        let viewModel = EditorViewModel()
        let url = URL(fileURLWithPath: "/tmp/mkdn-test-\(UUID().uuidString).md")
        let content = "# Hello"

        try content.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        try viewModel.load(from: url)

        #expect(viewModel.text == content)
        #expect(viewModel.fileURL == url)
        #expect(!viewModel.hasUnsavedChanges)
    }

    @Test("Update text marks unsaved changes")
    @MainActor func updateTextMarksUnsaved() {
        let viewModel = EditorViewModel()
        viewModel.updateText("New content")

        #expect(viewModel.text == "New content")
        #expect(viewModel.hasUnsavedChanges)
    }

    @Test("Save clears unsaved flag")
    @MainActor func saveClearsUnsavedFlag() throws {
        let viewModel = EditorViewModel()
        let url = URL(fileURLWithPath: "/tmp/mkdn-test-\(UUID().uuidString).md")

        try "".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        try viewModel.load(from: url)
        viewModel.updateText("Changed")
        #expect(viewModel.hasUnsavedChanges)

        try viewModel.save()
        #expect(!viewModel.hasUnsavedChanges)

        let onDisk = try String(contentsOf: url, encoding: .utf8)
        #expect(onDisk == "Changed")
    }
}
