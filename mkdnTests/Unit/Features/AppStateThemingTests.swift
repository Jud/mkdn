import Foundation
import SwiftUI
import Testing

@testable import mkdnLib

@Suite("AppState Theming")
struct AppStateThemingTests {
    // MARK: - Default State

    @Test("Fresh AppState defaults to auto theme mode")
    @MainActor func defaultThemeModeIsAuto() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }
        UserDefaults.standard.removeObject(forKey: "themeMode")

        let state = AppState()
        #expect(state.themeMode == .auto)
    }

    // MARK: - Auto Mode Resolution

    @Test("System color scheme changes propagate to resolved theme in auto mode")
    @MainActor func autoModeFollowsSystemColorScheme() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }
        let state = AppState()
        state.themeMode = .auto

        state.systemColorScheme = .dark
        #expect(state.theme == .solarizedDark)

        state.systemColorScheme = .light
        #expect(state.theme == .solarizedLight)
    }

    // MARK: - Pinned Mode Isolation

    @Test("System color scheme changes do not affect pinned dark mode")
    @MainActor func pinnedDarkIgnoresSystemScheme() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }
        let state = AppState()
        state.themeMode = .solarizedDark

        state.systemColorScheme = .light
        #expect(state.theme == .solarizedDark)

        state.systemColorScheme = .dark
        #expect(state.theme == .solarizedDark)
    }

    @Test("System color scheme changes do not affect pinned light mode")
    @MainActor func pinnedLightIgnoresSystemScheme() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }
        let state = AppState()
        state.themeMode = .solarizedLight

        state.systemColorScheme = .dark
        #expect(state.theme == .solarizedLight)

        state.systemColorScheme = .light
        #expect(state.theme == .solarizedLight)
    }

    // MARK: - Overlay Label

    @Test("cycleTheme sets modeOverlayLabel with the display name")
    @MainActor func cycleThemeSetsOverlayLabel() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }
        let state = AppState()
        #expect(state.themeMode == .auto)

        state.cycleTheme()
        #expect(state.modeOverlayLabel == "Dark")

        state.cycleTheme()
        #expect(state.modeOverlayLabel == "Light")

        state.cycleTheme()
        #expect(state.modeOverlayLabel == "Auto")
    }

    // MARK: - UserDefaults Persistence

    @Test("Setting themeMode persists to UserDefaults")
    @MainActor func themeModeWritesToUserDefaults() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }
        let state = AppState()

        state.themeMode = .solarizedDark
        #expect(UserDefaults.standard.string(forKey: "themeMode") == "solarizedDark")

        state.themeMode = .solarizedLight
        #expect(UserDefaults.standard.string(forKey: "themeMode") == "solarizedLight")

        state.themeMode = .auto
        #expect(UserDefaults.standard.string(forKey: "themeMode") == "auto")
    }

    @Test("Init reads themeMode from UserDefaults when value exists")
    @MainActor func initRestoresPersistedThemeMode() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }

        UserDefaults.standard.set("solarizedLight", forKey: "themeMode")
        let state = AppState()
        #expect(state.themeMode == .solarizedLight)
    }

    @Test("Init defaults to auto when UserDefaults has invalid value")
    @MainActor func initDefaultsToAutoForInvalidPersistedValue() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }

        UserDefaults.standard.set("nonexistent", forKey: "themeMode")
        let state = AppState()
        #expect(state.themeMode == .auto)
    }
}
