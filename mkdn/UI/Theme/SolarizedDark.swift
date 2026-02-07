import SwiftUI

/// Solarized Dark theme color definitions.
/// Reference: https://ethanschoonover.com/solarized/
enum SolarizedDark {
    private static let base03 = Color(red: 0.000, green: 0.169, blue: 0.212) // #002b36
    private static let base02 = Color(red: 0.027, green: 0.212, blue: 0.259) // #073642
    private static let base01 = Color(red: 0.345, green: 0.431, blue: 0.459) // #586e75
    private static let base0 = Color(red: 0.514, green: 0.580, blue: 0.588) // #839496
    private static let base1 = Color(red: 0.576, green: 0.631, blue: 0.631) // #93a1a1

    private static let yellow = Color(red: 0.710, green: 0.537, blue: 0.000) // #b58900
    private static let orange = Color(red: 0.796, green: 0.294, blue: 0.086) // #cb4b16
    private static let red = Color(red: 0.863, green: 0.196, blue: 0.184) // #dc322f
    private static let magenta = Color(red: 0.827, green: 0.212, blue: 0.510) // #d33682
    private static let violet = Color(red: 0.424, green: 0.443, blue: 0.769) // #6c71c4
    private static let blue = Color(red: 0.149, green: 0.545, blue: 0.824) // #268bd2
    private static let cyan = Color(red: 0.165, green: 0.631, blue: 0.596) // #2aa198
    private static let green = Color(red: 0.522, green: 0.600, blue: 0.000) // #859900

    static let colors = ThemeColors(
        background: base03,
        backgroundSecondary: base02,
        foreground: base0,
        foregroundSecondary: base01,
        accent: blue,
        border: base01,
        codeBackground: base02,
        codeForeground: base0,
        linkColor: blue,
        headingColor: base1,
        blockquoteBorder: cyan,
        blockquoteBackground: base02
    )

    static let syntaxColors = SyntaxColors(
        keyword: green,
        string: cyan,
        comment: base01,
        type: yellow,
        number: magenta,
        function: blue,
        property: orange,
        preprocessor: red
    )
}
