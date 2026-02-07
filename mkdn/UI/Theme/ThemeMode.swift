import SwiftUI

/// User's theme preference: auto (follow system), or a pinned variant.
///
/// `ThemeMode` is the persisted user preference. It resolves to a concrete
/// `AppTheme` at runtime based on the current system color scheme.
public enum ThemeMode: String, CaseIterable, Sendable {
    case auto
    case solarizedDark
    case solarizedLight

    /// Resolve this mode to a concrete `AppTheme` for the given color scheme.
    ///
    /// In `.auto` mode, dark system appearance maps to `SolarizedDark` and
    /// light appearance maps to `SolarizedLight`. Pinned modes ignore the
    /// color scheme.
    public func resolved(for colorScheme: ColorScheme) -> AppTheme {
        switch self {
        case .auto:
            colorScheme == .dark ? .solarizedDark : .solarizedLight
        case .solarizedDark:
            .solarizedDark
        case .solarizedLight:
            .solarizedLight
        }
    }

    /// Human-readable label for the picker UI.
    public var displayName: String {
        switch self {
        case .auto: "Auto"
        case .solarizedDark: "Dark"
        case .solarizedLight: "Light"
        }
    }
}
