import SwiftUI

/// Available application themes.
public enum AppTheme: String, CaseIterable, Sendable {
    case solarizedDark = "Solarized Dark"
    case solarizedLight = "Solarized Light"

    public var colors: ThemeColors {
        switch self {
        case .solarizedDark:
            SolarizedDark.colors
        case .solarizedLight:
            SolarizedLight.colors
        }
    }

    public var syntaxColors: SyntaxColors {
        switch self {
        case .solarizedDark:
            SolarizedDark.syntaxColors
        case .solarizedLight:
            SolarizedLight.syntaxColors
        }
    }
}
