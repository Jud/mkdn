import Foundation
import Testing

@testable import mkdnLib

@Suite("AppState")
struct AppStateTests {

    @Test("Default state is preview-only with no file")
    @MainActor func defaultState() {
        let state = AppState()

        #expect(state.currentFileURL == nil)
        #expect(state.markdownContent.isEmpty)
        #expect(!state.isFileOutdated)
        #expect(state.viewMode == .previewOnly)
        #expect(state.theme == .solarizedDark)
    }

    @Test("Loads a Markdown file")
    @MainActor func loadsFile() throws {
        let state = AppState()
        let url = URL(fileURLWithPath: "/tmp/mkdn-test-\(UUID().uuidString).md")
        let content = "# Test Heading\n\nSome content."

        try content.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        try state.loadFile(at: url)

        #expect(state.currentFileURL == url)
        #expect(state.markdownContent == content)
        #expect(!state.isFileOutdated)
    }

    @Test("Saves content to file")
    @MainActor func savesFile() throws {
        let state = AppState()
        let url = URL(fileURLWithPath: "/tmp/mkdn-test-\(UUID().uuidString).md")
        let original = "# Original"

        try original.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        try state.loadFile(at: url)
        state.markdownContent = "# Updated"
        try state.saveFile()

        let saved = try String(contentsOf: url, encoding: .utf8)
        #expect(saved == "# Updated")
    }

    @Test("Reload refreshes content from disk")
    @MainActor func reloadsFile() throws {
        let state = AppState()
        let url = URL(fileURLWithPath: "/tmp/mkdn-test-\(UUID().uuidString).md")

        try "# Version 1".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        try state.loadFile(at: url)
        #expect(state.markdownContent == "# Version 1")

        try "# Version 2".write(to: url, atomically: true, encoding: .utf8)
        try state.reloadFile()

        #expect(state.markdownContent == "# Version 2")
        #expect(!state.isFileOutdated)
    }

    @Test("View mode toggles correctly")
    @MainActor func viewModeToggles() {
        let state = AppState()

        #expect(state.viewMode == .previewOnly)

        state.viewMode = .sideBySide
        #expect(state.viewMode == .sideBySide)

        state.viewMode = .previewOnly
        #expect(state.viewMode == .previewOnly)
    }

    @Test("Theme can be changed")
    @MainActor func themeChange() {
        let state = AppState()

        #expect(state.theme == .solarizedDark)

        state.theme = .solarizedLight
        #expect(state.theme == .solarizedLight)
    }
}
