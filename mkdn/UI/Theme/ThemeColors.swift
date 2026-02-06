import SwiftUI

/// Color palette for a theme.
struct ThemeColors: Sendable {
    let background: Color
    let backgroundSecondary: Color
    let foreground: Color
    let foregroundSecondary: Color
    let accent: Color
    let border: Color
    let codeBackground: Color
    let codeForeground: Color
    let linkColor: Color
    let headingColor: Color
    let blockquoteBorder: Color
    let blockquoteBackground: Color
}

/// Syntax highlighting colors.
struct SyntaxColors: Sendable {
    let keyword: Color
    let string: Color
    let comment: Color
    let type: Color
    let number: Color
    let function: Color
    let property: Color
    let preprocessor: Color
}
