import SwiftUI

/// Print-friendly color definitions for Cmd+P output.
/// White background, black text, ink-efficient styling.
/// Not a user-selectable theme -- applied automatically during print.
enum PrintPalette {
    private static let white = Color(red: 1.000, green: 1.000, blue: 1.000) // #FFFFFF
    private static let nearWhite = Color(red: 0.980, green: 0.980, blue: 0.980) // #FAFAFA
    private static let lightGray = Color(red: 0.961, green: 0.961, blue: 0.961) // #F5F5F5
    private static let borderGray = Color(red: 0.800, green: 0.800, blue: 0.800) // #CCCCCC
    private static let midGray = Color(red: 0.600, green: 0.600, blue: 0.600) // #999999
    private static let secondaryGray = Color(red: 0.333, green: 0.333, blue: 0.333) // #555555
    private static let nearBlack = Color(red: 0.102, green: 0.102, blue: 0.102) // #1A1A1A
    private static let black = Color(red: 0.000, green: 0.000, blue: 0.000) // #000000
    private static let darkBlue = Color(red: 0.000, green: 0.200, blue: 0.600) // #003399

    private static let darkGreen = Color(red: 0.102, green: 0.420, blue: 0.000) // #1A6B00
    private static let darkRed = Color(red: 0.639, green: 0.082, blue: 0.082) // #A31515
    private static let commentGray = Color(red: 0.416, green: 0.451, blue: 0.490) // #6A737D
    private static let darkAmber = Color(red: 0.482, green: 0.302, blue: 0.000) // #7B4D00
    private static let darkPurple = Color(red: 0.435, green: 0.259, blue: 0.757) // #6F42C1
    private static let functionBlue = Color(red: 0.000, green: 0.361, blue: 0.773) // #005CC5
    private static let darkOrange = Color(red: 0.702, green: 0.349, blue: 0.000) // #B35900
    private static let darkRedPink = Color(red: 0.843, green: 0.227, blue: 0.286) // #D73A49

    static let colors = ThemeColors(
        background: white,
        backgroundSecondary: lightGray,
        foreground: black,
        foregroundSecondary: secondaryGray,
        accent: darkBlue,
        border: borderGray,
        codeBackground: lightGray,
        codeForeground: nearBlack,
        linkColor: darkBlue,
        headingColor: black,
        blockquoteBorder: midGray,
        blockquoteBackground: nearWhite,
        findHighlight: darkAmber
    )

    static let syntaxColors = SyntaxColors(
        keyword: darkGreen,
        string: darkRed,
        comment: commentGray,
        type: darkAmber,
        number: darkPurple,
        function: functionBlue,
        property: darkOrange,
        preprocessor: darkRedPink,
        operator: darkRedPink,
        variable: nearBlack,
        constant: darkPurple,
        attribute: darkOrange,
        punctuation: commentGray
    )
}
