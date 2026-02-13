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

    // MARK: - Auto-Reload

    @Test("autoReloadEnabled defaults to false")
    @MainActor func autoReloadDefaultsToFalse() {
        defer { UserDefaults.standard.removeObject(forKey: "autoReloadEnabled") }
        UserDefaults.standard.removeObject(forKey: "autoReloadEnabled")

        let settings = AppSettings()
        #expect(!settings.autoReloadEnabled)
    }

    @Test("autoReloadEnabled persists to UserDefaults")
    @MainActor func autoReloadPersistsToUserDefaults() {
        defer { UserDefaults.standard.removeObject(forKey: "autoReloadEnabled") }
        UserDefaults.standard.removeObject(forKey: "autoReloadEnabled")

        let settings = AppSettings()
        #expect(!settings.autoReloadEnabled)

        settings.autoReloadEnabled = true
        #expect(UserDefaults.standard.bool(forKey: "autoReloadEnabled"))
    }

    @Test("autoReloadEnabled restores true from UserDefaults")
    @MainActor func autoReloadRestoresTrueFromUserDefaults() {
        defer { UserDefaults.standard.removeObject(forKey: "autoReloadEnabled") }

        UserDefaults.standard.set(true, forKey: "autoReloadEnabled")
        let settings = AppSettings()
        #expect(settings.autoReloadEnabled)
    }

    // MARK: - Zoom Scale Factor

    @Test("scaleFactor defaults to 1.0")
    @MainActor func scaleFactorDefaultsTo1() {
        defer { UserDefaults.standard.removeObject(forKey: "scaleFactor") }
        UserDefaults.standard.removeObject(forKey: "scaleFactor")

        let settings = AppSettings()
        #expect(settings.scaleFactor == 1.0)
    }

    @Test("zoomIn increments by 0.1")
    @MainActor func zoomInIncrementsBy10Percent() {
        defer { UserDefaults.standard.removeObject(forKey: "scaleFactor") }
        UserDefaults.standard.removeObject(forKey: "scaleFactor")

        let settings = AppSettings()
        #expect(settings.scaleFactor == 1.0)
        settings.zoomIn()
        #expect(abs(settings.scaleFactor - 1.1) < 0.001)
    }

    @Test("zoomOut decrements by 0.1")
    @MainActor func zoomOutDecrementsBy10Percent() {
        defer { UserDefaults.standard.removeObject(forKey: "scaleFactor") }
        UserDefaults.standard.removeObject(forKey: "scaleFactor")

        let settings = AppSettings()
        settings.scaleFactor = 1.5
        settings.zoomOut()
        #expect(abs(settings.scaleFactor - 1.4) < 0.001)
    }

    @Test("zoomReset sets to 1.0")
    @MainActor func zoomResetSetsTo1() {
        defer { UserDefaults.standard.removeObject(forKey: "scaleFactor") }
        UserDefaults.standard.removeObject(forKey: "scaleFactor")

        let settings = AppSettings()
        settings.scaleFactor = 2.0
        settings.zoomReset()
        #expect(settings.scaleFactor == 1.0)
    }

    @Test("zoomIn clamps at maximum 3.0")
    @MainActor func zoomInClampsAtMax() {
        defer { UserDefaults.standard.removeObject(forKey: "scaleFactor") }

        let settings = AppSettings()
        settings.scaleFactor = 2.95
        settings.zoomIn()
        #expect(settings.scaleFactor == 3.0)
        settings.zoomIn()
        #expect(settings.scaleFactor == 3.0)
    }

    @Test("zoomOut clamps at minimum 0.5")
    @MainActor func zoomOutClampsAtMin() {
        defer { UserDefaults.standard.removeObject(forKey: "scaleFactor") }

        let settings = AppSettings()
        settings.scaleFactor = 0.55
        settings.zoomOut()
        #expect(abs(settings.scaleFactor - 0.5) < 0.001)
        settings.zoomOut()
        #expect(settings.scaleFactor == 0.5)
    }

    @Test("scaleFactor persists to UserDefaults")
    @MainActor func scaleFactorPersistsToUserDefaults() {
        defer { UserDefaults.standard.removeObject(forKey: "scaleFactor") }
        UserDefaults.standard.removeObject(forKey: "scaleFactor")

        let settings = AppSettings()
        settings.scaleFactor = 1.5
        #expect(abs(UserDefaults.standard.double(forKey: "scaleFactor") - 1.5) < 0.001)
    }

    @Test("scaleFactor restores from UserDefaults")
    @MainActor func scaleFactorRestoresFromUserDefaults() {
        defer { UserDefaults.standard.removeObject(forKey: "scaleFactor") }

        UserDefaults.standard.set(1.8, forKey: "scaleFactor")
        let settings = AppSettings()
        #expect(abs(settings.scaleFactor - 1.8) < 0.001)
    }

    @Test("zoomLabel formats correctly")
    @MainActor func zoomLabelFormatsCorrectly() {
        defer { UserDefaults.standard.removeObject(forKey: "scaleFactor") }
        UserDefaults.standard.removeObject(forKey: "scaleFactor")

        let settings = AppSettings()
        #expect(settings.zoomLabel == "100%")

        settings.scaleFactor = 1.5
        #expect(settings.zoomLabel == "150%")

        settings.scaleFactor = 0.5
        #expect(settings.zoomLabel == "50%")
    }
}
