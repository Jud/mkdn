import SwiftUI

/// Solarized Light theme color definitions.
/// Reference: https://ethanschoonover.com/solarized/
enum SolarizedLight {
    // Solarized base palette (inverted from dark)
    private static let base3 = Color(red: 0.992, green: 0.965, blue: 0.890) // #fdf6e3
    private static let base2 = Color(red: 0.933, green: 0.910, blue: 0.835) // #eee8d5
    private static let base1 = Color(red: 0.345, green: 0.431, blue: 0.459) // #586e75
    private static let base00 = Color(red: 0.396, green: 0.482, blue: 0.514) // #657b83
    private static let base01 = Color(red: 0.345, green: 0.431, blue: 0.459) // #586e75

    // Solarized accent palette (same as dark)
    private static let yellow = Color(red: 0.710, green: 0.537, blue: 0.000) // #b58900
    private static let orange = Color(red: 0.796, green: 0.294, blue: 0.086) // #cb4b16
    private static let red = Color(red: 0.863, green: 0.196, blue: 0.184) // #dc322f
    private static let magenta = Color(red: 0.827, green: 0.212, blue: 0.510) // #d33682
    private static let violet = Color(red: 0.424, green: 0.443, blue: 0.769) // #6c71c4
    private static let blue = Color(red: 0.149, green: 0.545, blue: 0.824) // #268bd2
    private static let cyan = Color(red: 0.165, green: 0.631, blue: 0.596) // #2aa198
    private static let green = Color(red: 0.522, green: 0.600, blue: 0.000) // #859900

    static let colors = ThemeColors(
        background: base3,
        backgroundSecondary: base2,
        foreground: base00,
        foregroundSecondary: base1,
        accent: blue,
        border: base1,
        codeBackground: base2,
        codeForeground: base00,
        linkColor: blue,
        headingColor: base01,
        blockquoteBorder: cyan,
        blockquoteBackground: base2
    )

    static let syntaxColors = SyntaxColors(
        keyword: green,
        string: cyan,
        comment: base1,
        type: yellow,
        number: magenta,
        function: blue,
        property: orange,
        preprocessor: red
    )
}
