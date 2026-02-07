import AppKit
import Foundation
import SwiftUI
import Testing

@testable import mkdnLib

@Suite("AppSettings")
struct AppSettingsTests {
    // MARK: - Init-Time Appearance Resolution

    @Test("Init resolves systemColorScheme from OS appearance, not hardcoded default")
    @MainActor func initResolvesSystemAppearance() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }
        UserDefaults.standard.removeObject(forKey: "themeMode")

        let settings = AppSettings()
        let appearance = NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()
        let expectedDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let expectedScheme: ColorScheme = expectedDark ? .dark : .light
        #expect(settings.systemColorScheme == expectedScheme)
    }

    // MARK: - Default State

    @Test("Fresh AppSettings defaults to auto theme mode")
    @MainActor func defaultThemeModeIsAuto() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }
        UserDefaults.standard.removeObject(forKey: "themeMode")

        let settings = AppSettings()
        #expect(settings.themeMode == .auto)
    }

    @Test("Default state resolves theme correctly")
    @MainActor func defaultState() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }
        UserDefaults.standard.removeObject(forKey: "themeMode")

        let settings = AppSettings()
        #expect(settings.themeMode == .auto)
        #expect(settings.theme == .solarizedDark)
    }

    @Test("Theme mode can be changed and resolves correctly")
    @MainActor func themeChange() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }

        let settings = AppSettings()

        #expect(settings.themeMode == .auto)
        #expect(settings.theme == .solarizedDark) // auto + dark system scheme

        settings.themeMode = .solarizedLight
        #expect(settings.theme == .solarizedLight)

        settings.systemColorScheme = .light
        settings.themeMode = .auto
        #expect(settings.theme == .solarizedLight) // auto + light system scheme
    }

    // MARK: - Auto Mode Resolution

    @Test("System color scheme changes propagate to resolved theme in auto mode")
    @MainActor func autoModeFollowsSystemColorScheme() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }
        let settings = AppSettings()
        settings.themeMode = .auto

        settings.systemColorScheme = .dark
        #expect(settings.theme == .solarizedDark)

        settings.systemColorScheme = .light
        #expect(settings.theme == .solarizedLight)
    }

    // MARK: - Pinned Mode Isolation

    @Test("System color scheme changes do not affect pinned dark mode")
    @MainActor func pinnedDarkIgnoresSystemScheme() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }
        let settings = AppSettings()
        settings.themeMode = .solarizedDark

        settings.systemColorScheme = .light
        #expect(settings.theme == .solarizedDark)

        settings.systemColorScheme = .dark
        #expect(settings.theme == .solarizedDark)
    }

    @Test("System color scheme changes do not affect pinned light mode")
    @MainActor func pinnedLightIgnoresSystemScheme() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }
        let settings = AppSettings()
        settings.themeMode = .solarizedLight

        settings.systemColorScheme = .dark
        #expect(settings.theme == .solarizedLight)

        settings.systemColorScheme = .light
        #expect(settings.theme == .solarizedLight)
    }

    // MARK: - cycleTheme

    @Test("cycleTheme cycles through auto, dark, light")
    @MainActor func cycleThemeModes() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }

        let settings = AppSettings()
        #expect(settings.themeMode == .auto)

        settings.cycleTheme()
        #expect(settings.themeMode == .solarizedDark)

        settings.cycleTheme()
        #expect(settings.themeMode == .solarizedLight)

        settings.cycleTheme()
        #expect(settings.themeMode == .auto)
    }

    // MARK: - UserDefaults Persistence

    @Test("Setting themeMode persists to UserDefaults")
    @MainActor func themeModeWritesToUserDefaults() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }
        let settings = AppSettings()

        settings.themeMode = .solarizedDark
        #expect(UserDefaults.standard.string(forKey: "themeMode") == "solarizedDark")

        settings.themeMode = .solarizedLight
        #expect(UserDefaults.standard.string(forKey: "themeMode") == "solarizedLight")

        settings.themeMode = .auto
        #expect(UserDefaults.standard.string(forKey: "themeMode") == "auto")
    }

    @Test("Init reads themeMode from UserDefaults when value exists")
    @MainActor func initRestoresPersistedThemeMode() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }

        UserDefaults.standard.set("solarizedLight", forKey: "themeMode")
        let settings = AppSettings()
        #expect(settings.themeMode == .solarizedLight)
    }

    @Test("Init defaults to auto when UserDefaults has invalid value")
    @MainActor func initDefaultsToAutoForInvalidPersistedValue() {
        defer { UserDefaults.standard.removeObject(forKey: "themeMode") }

        UserDefaults.standard.set("nonexistent", forKey: "themeMode")
        let settings = AppSettings()
        #expect(settings.themeMode == .auto)
    }

    // MARK: - Default Handler Hint

    @Test("hasShownDefaultHandlerHint defaults to false")
    @MainActor func hintDefaultsToFalse() {
        defer { UserDefaults.standard.removeObject(forKey: "hasShownDefaultHandlerHint") }
        UserDefaults.standard.removeObject(forKey: "hasShownDefaultHandlerHint")

        let settings = AppSettings()
        #expect(!settings.hasShownDefaultHandlerHint)
    }

    @Test("hasShownDefaultHandlerHint persists to UserDefaults")
    @MainActor func hintPersistsToUserDefaults() {
        defer { UserDefaults.standard.removeObject(forKey: "hasShownDefaultHandlerHint") }
        UserDefaults.standard.removeObject(forKey: "hasShownDefaultHandlerHint")

        let settings = AppSettings()
        #expect(!settings.hasShownDefaultHandlerHint)

        settings.hasShownDefaultHandlerHint = true
        #expect(UserDefaults.standard.bool(forKey: "hasShownDefaultHandlerHint"))
    }

    @Test("hasShownDefaultHandlerHint restores true from UserDefaults")
    @MainActor func hintRestoresTrueFromUserDefaults() {
        defer { UserDefaults.standard.removeObject(forKey: "hasShownDefaultHandlerHint") }

        UserDefaults.standard.set(true, forKey: "hasShownDefaultHandlerHint")
        let settings = AppSettings()
        #expect(settings.hasShownDefaultHandlerHint)
    }
}
