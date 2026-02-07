import Testing

@testable import mkdnLib

@Suite("Controls")
struct ControlsTests {
    // MARK: - cycleTheme

    @Test("cycleTheme cycles through auto, dark, light")
    @MainActor func cycleThemeModes() {
        let state = AppState()
        #expect(state.themeMode == .auto)

        state.cycleTheme()
        #expect(state.themeMode == .solarizedDark)

        state.cycleTheme()
        #expect(state.themeMode == .solarizedLight)

        state.cycleTheme()
        #expect(state.themeMode == .auto)
    }

    // MARK: - switchMode

    @Test("switchMode to previewOnly sets viewMode and overlay label")
    @MainActor func switchModePreviewOnly() {
        let state = AppState()
        state.viewMode = .sideBySide

        state.switchMode(to: .previewOnly)
        #expect(state.viewMode == .previewOnly)
        #expect(state.modeOverlayLabel == "Preview")
    }

    @Test("switchMode to sideBySide sets viewMode and overlay label")
    @MainActor func switchModeSideBySide() {
        let state = AppState()

        state.switchMode(to: .sideBySide)
        #expect(state.viewMode == .sideBySide)
        #expect(state.modeOverlayLabel == "Edit")
    }

    // MARK: - isFileOutdated

    @Test("isFileOutdated delegates to FileWatcher state")
    @MainActor func isFileOutdatedDelegation() {
        let state = AppState()
        #expect(state.isFileOutdated == state.fileWatcher.isOutdated)
        #expect(!state.isFileOutdated)
    }
}
