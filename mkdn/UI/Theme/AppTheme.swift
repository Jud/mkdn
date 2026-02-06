import SwiftUI

/// Available application themes.
public enum AppTheme: String, CaseIterable, Sendable {
    case solarizedDark = "Solarized Dark"
    case solarizedLight = "Solarized Light"

    var colors: ThemeColors {
        switch self {
        case .solarizedDark:
            SolarizedDark.colors
        case .solarizedLight:
            SolarizedLight.colors
        }
    }

    var syntaxColors: SyntaxColors {
        switch self {
        case .solarizedDark:
            SolarizedDark.syntaxColors
        case .solarizedLight:
            SolarizedLight.syntaxColors
        }
    }
}
