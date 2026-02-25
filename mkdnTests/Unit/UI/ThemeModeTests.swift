import SwiftUI
import Testing
@testable import mkdnLib

@Suite("ThemeMode")
struct ThemeModeTests {
    // MARK: - resolved(for:)

    @Test("Auto mode resolves to solarizedDark for dark colorScheme")
    func autoResolvesDark() {
        #expect(ThemeMode.auto.resolved(for: .dark) == .solarizedDark)
    }

    @Test("Auto mode resolves to solarizedLight for light colorScheme")
    func autoResolvesLight() {
        #expect(ThemeMode.auto.resolved(for: .light) == .solarizedLight)
    }

    @Test("SolarizedDark mode ignores dark colorScheme")
    func solarizedDarkIgnoresDark() {
        #expect(ThemeMode.solarizedDark.resolved(for: .dark) == .solarizedDark)
    }

    @Test("SolarizedDark mode ignores light colorScheme")
    func solarizedDarkIgnoresLight() {
        #expect(ThemeMode.solarizedDark.resolved(for: .light) == .solarizedDark)
    }

    @Test("SolarizedLight mode ignores light colorScheme")
    func solarizedLightIgnoresLight() {
        #expect(ThemeMode.solarizedLight.resolved(for: .light) == .solarizedLight)
    }

    @Test("SolarizedLight mode ignores dark colorScheme")
    func solarizedLightIgnoresDark() {
        #expect(ThemeMode.solarizedLight.resolved(for: .dark) == .solarizedLight)
    }

    // MARK: - displayName

    @Test("Display names match expected labels")
    func displayNames() {
        #expect(ThemeMode.auto.displayName == "Auto")
        #expect(ThemeMode.solarizedDark.displayName == "Dark")
        #expect(ThemeMode.solarizedLight.displayName == "Light")
    }

    // MARK: - CaseIterable

    @Test("Has exactly three cases")
    func caseCount() {
        #expect(ThemeMode.allCases.count == 3)
    }

    // MARK: - RawValue persistence

    @Test("RawValue round-trips for all cases")
    func rawValueRoundTrip() {
        for mode in ThemeMode.allCases {
            let raw = mode.rawValue
            let restored = ThemeMode(rawValue: raw)
            #expect(restored == mode)
        }
    }

    @Test("RawValue strings match expected persistence keys")
    func rawValueStrings() {
        #expect(ThemeMode.auto.rawValue == "auto")
        #expect(ThemeMode.solarizedDark.rawValue == "solarizedDark")
        #expect(ThemeMode.solarizedLight.rawValue == "solarizedLight")
    }
}
