import Testing

@testable import mkdnLib

@Suite("AppTheme")
struct ThemeTests {

    @Test("Solarized Dark provides all colors")
    func solarizedDarkColors() {
        let colors = AppTheme.solarizedDark.colors

        // Verify all color properties exist (non-nil by construction).
        // This test ensures the theme struct is fully populated.
        #expect(colors.background != colors.foreground)
        #expect(colors.codeBackground != colors.foreground)
    }

    @Test("Solarized Light provides all colors")
    func solarizedLightColors() {
        let colors = AppTheme.solarizedLight.colors

        #expect(colors.background != colors.foreground)
        #expect(colors.codeBackground != colors.foreground)
    }

    @Test("Solarized Dark provides syntax colors")
    func solarizedDarkSyntaxColors() {
        let syntax = AppTheme.solarizedDark.syntaxColors

        // Keywords and strings should be different colors.
        #expect(syntax.keyword != syntax.string)
    }

    @Test("Solarized Light provides syntax colors")
    func solarizedLightSyntaxColors() {
        let syntax = AppTheme.solarizedLight.syntaxColors

        #expect(syntax.keyword != syntax.string)
    }

    @Test("All themes are enumerable")
    func allThemes() {
        #expect(AppTheme.allCases.count == 2)
    }
}
