import Testing

@testable import mkdnLib

@Suite("SVGSanitizer")
struct SVGSanitizerTests {
    // MARK: - Hex Parsing

    @Test("Parses 6-digit hex color")
    func parsesHex6() {
        let rgb = SVGSanitizer.parseHex("#27272A")
        #expect(rgb?.r == 0x27)
        #expect(rgb?.g == 0x27)
        #expect(rgb?.b == 0x2A)
    }

    @Test("Parses 3-digit hex color with expansion")
    func parsesHex3() {
        let rgb = SVGSanitizer.parseHex("#F0A")
        #expect(rgb?.r == 0xFF)
        #expect(rgb?.g == 0x00)
        #expect(rgb?.b == 0xAA)
    }

    @Test("Returns nil for invalid hex")
    func invalidHex() {
        #expect(SVGSanitizer.parseHex("notacolor") == nil)
        #expect(SVGSanitizer.parseHex("#GG0000") == nil)
        #expect(SVGSanitizer.parseHex("") == nil)
    }

    // MARK: - Color Mixing

    @Test("Mixes black and white at 50%")
    func mixBlackWhite50() {
        let result = SVGSanitizer.colorMix(fg: "#000000", percent: 50, bg: "#FFFFFF")
        #expect(result == "#808080")
    }

    @Test("Mix at 0% returns background")
    func mixAtZeroPercent() {
        let result = SVGSanitizer.colorMix(fg: "#FF0000", percent: 0, bg: "#00FF00")
        #expect(result == "#00FF00")
    }

    @Test("Mix at 100% returns foreground")
    func mixAtFullPercent() {
        let result = SVGSanitizer.colorMix(fg: "#FF0000", percent: 100, bg: "#00FF00")
        #expect(result == "#FF0000")
    }

    @Test("Mix at 3% is nearly background (nodeFill blend)")
    func mixAt3Percent() {
        let result = SVGSanitizer.colorMix(fg: "#27272A", percent: 3, bg: "#FFFFFF")
        // 0x27 * 0.03 + 0xFF * 0.97 = 1.17 + 247.35 = 248.52 -> 0xF9
        // 0x2A * 0.03 + 0xFF * 0.97 = 1.26 + 247.35 = 248.61 -> 0xF9
        #expect(result == "#F9F9F9")
    }

    // MARK: - Root Variable Extraction

    @Test("Extracts bg and fg from SVG style attribute")
    func extractsRootVars() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" style="--bg:#FFFFFF;--fg:#27272A;background:var(--bg)">
        </svg>
        """
        let vars = SVGSanitizer.extractRootVariables(from: svg)
        #expect(vars["bg"] == "#FFFFFF")
        #expect(vars["fg"] == "#27272A")
    }

    @Test("Extracts optional theme variables")
    func extractsOptionalVars() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" \
        style="--bg:#002b36;--fg:#839496;--line:#586e75;--accent:#268bd2;--muted:#586e75">
        </svg>
        """
        let vars = SVGSanitizer.extractRootVariables(from: svg)
        #expect(vars["bg"] == "#002b36")
        #expect(vars["fg"] == "#839496")
        #expect(vars["line"] == "#586e75")
        #expect(vars["accent"] == "#268bd2")
        #expect(vars["muted"] == "#586e75")
    }

    @Test("Returns empty dict when no style attribute")
    func noStyleAttribute() {
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>"
        let vars = SVGSanitizer.extractRootVariables(from: svg)
        #expect(vars.isEmpty)
    }

    // MARK: - Variable Map Building

    @Test("Variable map includes all derived variables")
    func variableMapComplete() {
        let colors = SVGThemeColors(bg: "#FFFFFF", fg: "#27272A")
        let map = SVGSanitizer.buildVariableMap(from: colors)

        #expect(map["--bg"] == "#FFFFFF")
        #expect(map["--fg"] == "#27272A")
        #expect(map["--_text"] == "#27272A")
        #expect(map["--_group-fill"] == "#FFFFFF")
        #expect(map["--_node-fill"] != nil)
        #expect(map["--_arrow"] != nil)
    }

    @Test("Variable map uses explicit overrides when provided")
    func variableMapWithOverrides() {
        let colors = SVGThemeColors(
            bg: "#002b36",
            fg: "#839496",
            line: "#586e75",
            accent: "#268bd2",
            muted: "#586e75"
        )
        let map = SVGSanitizer.buildVariableMap(from: colors)

        #expect(map["--_line"] == "#586e75")
        #expect(map["--_arrow"] == "#268bd2")
        #expect(map["--_text-sec"] == "#586e75")
        #expect(map["--_text-muted"] == "#586e75")
    }

    // MARK: - @import Stripping

    @Test("Strips @import url() declarations")
    func stripsImport() {
        let svg = """
        <style>
          @import url('https://fonts.googleapis.com/css2?family=Inter');
          .node { fill: red; }
        </style>
        """
        let result = SVGSanitizer.stripImportRules(svg)
        #expect(!result.contains("@import"))
        #expect(result.contains(".node { fill: red; }"))
    }

    // MARK: - var() Resolution

    @Test("Resolves simple var references")
    func resolvesSimpleVar() {
        let svg = ##"fill="var(--bg)" stroke="var(--fg)""##
        let map = ["--bg": "#FFFFFF", "--fg": "#000000"]
        let result = SVGSanitizer.resolveVarReferences(svg, variableMap: map)
        let expected = ##"fill="#FFFFFF" stroke="#000000""##
        #expect(result == expected)
    }

    @Test("Resolves var with fallback when variable is missing")
    func resolvesVarWithFallback() {
        let svg = ##"fill="var(--unknown, #AABBCC)""##
        let result = SVGSanitizer.resolveVarReferences(svg, variableMap: [:])
        #expect(result.contains("#AABBCC"))
    }

    // MARK: - color-mix Resolution

    @Test("Resolves color-mix expressions with hex colors")
    func resolvesColorMix() {
        let svg = "fill=\"color-mix(in srgb, #000000 50%, #FFFFFF)\""
        let result = SVGSanitizer.resolveColorMixExpressions(svg)
        #expect(result.contains("#808080"))
    }

    // MARK: - Font Replacement

    @Test("Replaces Inter font with system fonts")
    func replacesInterFont() {
        let svg = "font-family: Inter"
        let result = SVGSanitizer.replaceGoogleFonts(svg)
        #expect(result.contains("-apple-system"))
        #expect(!result.contains("Inter"))
    }

    @Test("Replaces JetBrains Mono with system monospace")
    func replacesJetBrainsMono() {
        let svg = "font-family: JetBrains Mono"
        let result = SVGSanitizer.replaceGoogleFonts(svg)
        #expect(result.contains("SF Mono"))
        #expect(!result.contains("JetBrains"))
    }

    // MARK: - Full Sanitization

    @Test("Sanitize produces SwiftDraw-compatible SVG")
    func fullSanitization() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100" \
        width="200" height="100" style="--bg:#FFFFFF;--fg:#27272A;background:var(--bg)">
        <style>
          @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500&amp;display=swap');
          --_text: var(--fg);
          --_node-fill: var(--surface, color-mix(in srgb, var(--fg) 3%, var(--bg)));
        </style>
        <rect fill="var(--_node-fill)" stroke="var(--_node-stroke)" />
        <text fill="var(--_text)" font-family="Inter">Hello</text>
        </svg>
        """

        let result = SVGSanitizer.sanitize(svg)

        #expect(!result.contains("var(--"))
        #expect(!result.contains("@import"))
        #expect(!result.contains("color-mix"))
        #expect(!result.contains("font-family: Inter"))
        #expect(result.contains("#27272A"))
        #expect(result.contains("-apple-system"))
    }

    @Test("Sanitize handles solarized-dark theme variables")
    func solarizedDarkSanitization() {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100" width="200" height="100" \
        style="--bg:#002b36;--fg:#839496;--line:#586e75;--accent:#268bd2;--muted:#586e75">
        <rect fill="var(--_node-fill)" stroke="var(--_arrow)" />
        <text fill="var(--_text-sec)">Label</text>
        </svg>
        """

        let result = SVGSanitizer.sanitize(svg)

        #expect(!result.contains("var(--"))
        #expect(result.contains("#268bd2"))
        #expect(result.contains("#586e75"))
    }
}
