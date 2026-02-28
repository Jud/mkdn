import SwiftUI

/// Color palette for a theme.
public struct ThemeColors: Sendable {
    public let background: Color
    public let backgroundSecondary: Color
    public let foreground: Color
    public let foregroundSecondary: Color
    public let accent: Color
    public let border: Color
    public let codeBackground: Color
    public let codeForeground: Color
    public let linkColor: Color
    public let headingColor: Color
    public let blockquoteBorder: Color
    public let blockquoteBackground: Color
    public let findHighlight: Color

    public init(
        background: Color,
        backgroundSecondary: Color,
        foreground: Color,
        foregroundSecondary: Color,
        accent: Color,
        border: Color,
        codeBackground: Color,
        codeForeground: Color,
        linkColor: Color,
        headingColor: Color,
        blockquoteBorder: Color,
        blockquoteBackground: Color,
        findHighlight: Color
    ) {
        self.background = background
        self.backgroundSecondary = backgroundSecondary
        self.foreground = foreground
        self.foregroundSecondary = foregroundSecondary
        self.accent = accent
        self.border = border
        self.codeBackground = codeBackground
        self.codeForeground = codeForeground
        self.linkColor = linkColor
        self.headingColor = headingColor
        self.blockquoteBorder = blockquoteBorder
        self.blockquoteBackground = blockquoteBackground
        self.findHighlight = findHighlight
    }
}

/// Syntax highlighting colors.
public struct SyntaxColors: Sendable {
    public let keyword: Color
    public let string: Color
    public let comment: Color
    public let type: Color
    public let number: Color
    public let function: Color
    public let property: Color
    public let preprocessor: Color
    public let `operator`: Color
    public let variable: Color
    public let constant: Color
    public let attribute: Color
    public let punctuation: Color

    public init(
        keyword: Color,
        string: Color,
        comment: Color,
        type: Color,
        number: Color,
        function: Color,
        property: Color,
        preprocessor: Color,
        operator: Color,
        variable: Color,
        constant: Color,
        attribute: Color,
        punctuation: Color
    ) {
        self.keyword = keyword
        self.string = string
        self.comment = comment
        self.type = type
        self.number = number
        self.function = function
        self.property = property
        self.preprocessor = preprocessor
        self.operator = `operator`
        self.variable = variable
        self.constant = constant
        self.attribute = attribute
        self.punctuation = punctuation
    }
}
