import Testing

@testable import mkdnLib

@Suite("Controls")
struct ControlsTests {
    // MARK: - switchMode

    @Test("switchMode to previewOnly sets viewMode and overlay label")
    @MainActor func switchModePreviewOnly() {
        let state = DocumentState()
        state.viewMode = .sideBySide

        state.switchMode(to: .previewOnly)
        #expect(state.viewMode == .previewOnly)
        #expect(state.modeOverlayLabel == "Preview")
    }

    @Test("switchMode to sideBySide sets viewMode and overlay label")
    @MainActor func switchModeSideBySide() {
        let state = DocumentState()

        state.switchMode(to: .sideBySide)
        #expect(state.viewMode == .sideBySide)
        #expect(state.modeOverlayLabel == "Edit")
    }

    // MARK: - isFileOutdated

    @Test("isFileOutdated delegates to FileWatcher state")
    @MainActor func isFileOutdatedDelegation() {
        let state = DocumentState()
        #expect(state.isFileOutdated == state.fileWatcher.isOutdated)
        #expect(!state.isFileOutdated)
    }
}
