import Foundation
import Testing
@testable import mkdnLib

@Suite("MermaidThemeMapper")
struct MermaidThemeMapperTests {
    private static let requiredKeys: Set<String> = [
        "primaryColor",
        "primaryTextColor",
        "primaryBorderColor",
        "lineColor",
        "secondaryColor",
        "tertiaryColor",
        "background",
        "mainBkg",
        "nodeBorder",
        "clusterBkg",
        "titleColor",
        "edgeLabelBackground",
        "textColor",
        "labelTextColor",
        "actorBkg",
        "actorBorder",
        "actorTextColor",
        "actorLineColor",
        "signalColor",
        "signalTextColor",
        "noteBkgColor",
        "noteTextColor",
        "noteBorderColor",
        "activationBorderColor",
        "labelBoxBkgColor",
        "labelBoxBorderColor",
    ]

    @Test("Solarized Dark produces correct hex values")
    func solarizedDarkHexValues() {
        let vars = MermaidThemeMapper.themeVariables(for: .solarizedDark)

        #expect(vars["primaryColor"] == "#073642")
        #expect(vars["primaryTextColor"] == "#839496")
        #expect(vars["primaryBorderColor"] == "#586e75")
        #expect(vars["lineColor"] == "#586e75")
        #expect(vars["secondaryColor"] == "#002b36")
        #expect(vars["tertiaryColor"] == "#073642")
        #expect(vars["background"] == "#002b36")
        #expect(vars["mainBkg"] == "#073642")
        #expect(vars["nodeBorder"] == "#586e75")
        #expect(vars["clusterBkg"] == "#073642")
        #expect(vars["titleColor"] == "#93a1a1")
        #expect(vars["edgeLabelBackground"] == "#002b36")
        #expect(vars["textColor"] == "#839496")
        #expect(vars["labelTextColor"] == "#839496")
        #expect(vars["actorBkg"] == "#073642")
        #expect(vars["actorBorder"] == "#586e75")
        #expect(vars["actorTextColor"] == "#839496")
        #expect(vars["actorLineColor"] == "#586e75")
        #expect(vars["signalColor"] == "#839496")
        #expect(vars["signalTextColor"] == "#002b36")
        #expect(vars["noteBkgColor"] == "#073642")
        #expect(vars["noteTextColor"] == "#839496")
        #expect(vars["noteBorderColor"] == "#586e75")
        #expect(vars["activationBorderColor"] == "#268bd2")
        #expect(vars["labelBoxBkgColor"] == "#073642")
        #expect(vars["labelBoxBorderColor"] == "#586e75")
    }

    @Test("Solarized Light produces correct hex values")
    func solarizedLightHexValues() {
        let vars = MermaidThemeMapper.themeVariables(for: .solarizedLight)

        #expect(vars["primaryColor"] == "#eee8d5")
        #expect(vars["primaryTextColor"] == "#657b83")
        #expect(vars["primaryBorderColor"] == "#586e75")
        #expect(vars["lineColor"] == "#586e75")
        #expect(vars["secondaryColor"] == "#fdf6e3")
        #expect(vars["tertiaryColor"] == "#eee8d5")
        #expect(vars["background"] == "#fdf6e3")
        #expect(vars["mainBkg"] == "#eee8d5")
        #expect(vars["nodeBorder"] == "#586e75")
        #expect(vars["clusterBkg"] == "#eee8d5")
        #expect(vars["titleColor"] == "#586e75")
        #expect(vars["edgeLabelBackground"] == "#fdf6e3")
        #expect(vars["textColor"] == "#657b83")
        #expect(vars["labelTextColor"] == "#657b83")
        #expect(vars["actorBkg"] == "#eee8d5")
        #expect(vars["actorBorder"] == "#586e75")
        #expect(vars["actorTextColor"] == "#657b83")
        #expect(vars["actorLineColor"] == "#586e75")
        #expect(vars["signalColor"] == "#657b83")
        #expect(vars["signalTextColor"] == "#fdf6e3")
        #expect(vars["noteBkgColor"] == "#eee8d5")
        #expect(vars["noteTextColor"] == "#657b83")
        #expect(vars["noteBorderColor"] == "#586e75")
        #expect(vars["activationBorderColor"] == "#268bd2")
        #expect(vars["labelBoxBkgColor"] == "#eee8d5")
        #expect(vars["labelBoxBorderColor"] == "#586e75")
    }

    @Test("JSON output is valid and parseable", arguments: AppTheme.allCases)
    func validJSON(theme: AppTheme) throws {
        let json = MermaidThemeMapper.themeVariablesJSON(for: theme)
        let data = try #require(json.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data)
        let parsed = try #require(object as? [String: String])
        #expect(!parsed.isEmpty)
    }

    @Test("All 26 required keys present", arguments: AppTheme.allCases)
    func allRequiredKeysPresent(theme: AppTheme) {
        let vars = MermaidThemeMapper.themeVariables(for: theme)
        let keys = Set(vars.keys)

        #expect(keys == Self.requiredKeys)
    }

    @Test("Dark and light themes produce different variable values")
    func darkAndLightDiffer() {
        let dark = MermaidThemeMapper.themeVariables(for: .solarizedDark)
        let light = MermaidThemeMapper.themeVariables(for: .solarizedLight)

        #expect(dark["primaryColor"] != light["primaryColor"])
        #expect(dark["background"] != light["background"])
        #expect(dark["textColor"] != light["textColor"])
        #expect(dark["secondaryColor"] != light["secondaryColor"])
    }
}
