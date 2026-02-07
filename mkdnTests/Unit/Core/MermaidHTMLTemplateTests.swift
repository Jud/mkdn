import Foundation
import Testing

@testable import mkdnLib

@Suite("MermaidHTMLTemplate")
struct MermaidHTMLTemplateTests {
    @MainActor
    @Test("Token substitution removes all placeholder tokens")
    func tokenSubstitutionRemovesPlaceholders() throws {
        let templateURL = try #require(
            Bundle.module.url(forResource: "mermaid-template", withExtension: "html")
        )
        let template = try String(contentsOf: templateURL, encoding: .utf8)

        let code = "graph TD; A-->B;"
        let htmlEscaped = MermaidWebView.htmlEscape(code)
        let jsEscaped = MermaidWebView.jsEscape(code)
        let themeJSON = MermaidThemeMapper.themeVariablesJSON(for: .solarizedDark)

        let html = template
            .replacingOccurrences(of: "__MERMAID_CODE_JS__", with: jsEscaped)
            .replacingOccurrences(of: "__MERMAID_CODE__", with: htmlEscaped)
            .replacingOccurrences(of: "__THEME_VARIABLES__", with: themeJSON)

        #expect(!html.contains("__MERMAID_CODE__"))
        #expect(!html.contains("__MERMAID_CODE_JS__"))
        #expect(!html.contains("__THEME_VARIABLES__"))
        #expect(html.contains("graph TD; A--&gt;B;"))
        #expect(html.contains(themeJSON))
    }

    @MainActor
    @Test("HTML escaping handles special characters")
    func htmlEscapingSpecialCharacters() {
        let input = "A<B>C&D\"E"
        let escaped = MermaidWebView.htmlEscape(input)

        #expect(escaped == "A&lt;B&gt;C&amp;D&quot;E")
        #expect(!escaped.contains("<"))
        #expect(!escaped.contains(">"))
        #expect(!escaped.contains("\""))
    }

    @MainActor
    @Test("JS escaping handles backticks, backslashes, and dollar signs")
    func jsEscapingSpecialCharacters() {
        let input = "text `with` $var and \\"
        let escaped = MermaidWebView.jsEscape(input)

        #expect(escaped == "text \\`with\\` \\$var and \\\\")
    }

    @Test("MermaidRenderState equatable conformance")
    func renderStateEquatable() {
        let loading: MermaidRenderState = .loading
        let rendered: MermaidRenderState = .rendered
        let errorA: MermaidRenderState = .error("parse error")
        let errorB: MermaidRenderState = .error("parse error")
        let errorC: MermaidRenderState = .error("different")

        #expect(loading == .loading)
        #expect(rendered == .rendered)
        #expect(errorA == errorB)

        #expect(loading != rendered)
        #expect(loading != errorA)
        #expect(rendered != errorA)
        #expect(errorA != errorC)
    }
}
