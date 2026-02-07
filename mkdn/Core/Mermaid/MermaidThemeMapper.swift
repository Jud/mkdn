import Foundation

/// Maps application themes to Mermaid.js `themeVariables` JSON for the `base` theme.
///
/// Uses hardcoded hex values derived from the Solarized palette definitions
/// in `SolarizedDark` and `SolarizedLight`. No runtime `Color`-to-hex
/// conversion is performed.
public enum MermaidThemeMapper {
    /// Returns a JSON string of Mermaid `themeVariables` for the given theme.
    ///
    /// The output is suitable for direct injection into the Mermaid.js
    /// `initialize({ theme: 'base', themeVariables: ... })` configuration.
    public static func themeVariablesJSON(for theme: AppTheme) -> String {
        let variables = themeVariables(for: theme)

        guard let data = try? JSONSerialization.data(
            withJSONObject: variables,
            options: [.sortedKeys]
        ),
            let json = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return json
    }

    // MARK: - Internal

    static func themeVariables(for theme: AppTheme) -> [String: String] {
        switch theme {
        case .solarizedDark:
            solarizedDarkVariables
        case .solarizedLight:
            solarizedLightVariables
        }
    }

    // MARK: - Solarized Dark

    // Hex reference (from SolarizedDark.swift):
    //   base03 = #002b36  (background)
    //   base02 = #073642  (backgroundSecondary)
    //   base01 = #586e75  (foregroundSecondary, border)
    //   base0  = #839496  (foreground)
    //   base1  = #93a1a1  (headingColor)
    //   blue   = #268bd2  (accent)

    private static let solarizedDarkVariables: [String: String] = [
        "primaryColor": "#073642",
        "primaryTextColor": "#839496",
        "primaryBorderColor": "#586e75",
        "lineColor": "#586e75",
        "secondaryColor": "#002b36",
        "tertiaryColor": "#073642",
        "background": "#002b36",
        "mainBkg": "#073642",
        "nodeBorder": "#586e75",
        "clusterBkg": "#073642",
        "titleColor": "#93a1a1",
        "edgeLabelBackground": "#002b36",
        "textColor": "#839496",
        "labelTextColor": "#839496",
        "actorBkg": "#073642",
        "actorBorder": "#586e75",
        "actorTextColor": "#839496",
        "actorLineColor": "#586e75",
        "signalColor": "#839496",
        "signalTextColor": "#002b36",
        "noteBkgColor": "#073642",
        "noteTextColor": "#839496",
        "noteBorderColor": "#586e75",
        "activationBorderColor": "#268bd2",
        "labelBoxBkgColor": "#073642",
        "labelBoxBorderColor": "#586e75",
    ]

    // MARK: - Solarized Light

    // Hex reference (from SolarizedLight.swift):
    //   base3  = #fdf6e3  (background)
    //   base2  = #eee8d5  (backgroundSecondary)
    //   base1  = #586e75  (foregroundSecondary, border)
    //   base00 = #657b83  (foreground)
    //   base01 = #586e75  (headingColor)
    //   blue   = #268bd2  (accent)

    private static let solarizedLightVariables: [String: String] = [
        "primaryColor": "#eee8d5",
        "primaryTextColor": "#657b83",
        "primaryBorderColor": "#586e75",
        "lineColor": "#586e75",
        "secondaryColor": "#fdf6e3",
        "tertiaryColor": "#eee8d5",
        "background": "#fdf6e3",
        "mainBkg": "#eee8d5",
        "nodeBorder": "#586e75",
        "clusterBkg": "#eee8d5",
        "titleColor": "#586e75",
        "edgeLabelBackground": "#fdf6e3",
        "textColor": "#657b83",
        "labelTextColor": "#657b83",
        "actorBkg": "#eee8d5",
        "actorBorder": "#586e75",
        "actorTextColor": "#657b83",
        "actorLineColor": "#586e75",
        "signalColor": "#657b83",
        "signalTextColor": "#fdf6e3",
        "noteBkgColor": "#eee8d5",
        "noteTextColor": "#657b83",
        "noteBorderColor": "#586e75",
        "activationBorderColor": "#268bd2",
        "labelBoxBkgColor": "#eee8d5",
        "labelBoxBorderColor": "#586e75",
    ]
}
