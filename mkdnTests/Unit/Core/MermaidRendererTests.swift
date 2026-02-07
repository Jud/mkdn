import Testing

@preconcurrency import SwiftDraw
@testable import mkdnLib

@Suite("MermaidRenderer")
struct MermaidRendererTests {
    @Test("Empty input produces emptyInput error")
    func emptyInputError() async {
        let renderer = MermaidRenderer()

        do {
            _ = try await renderer.renderToSVG("", theme: .solarizedDark)
            Issue.record("Expected MermaidError.emptyInput")
        } catch {
            guard let mermaidError = error as? MermaidError,
                  case .emptyInput = mermaidError
            else {
                Issue.record("Expected MermaidError.emptyInput, got \(error)")
                return
            }
        }
    }

    @Test("Whitespace-only input produces emptyInput error")
    func whitespaceOnlyInputError() async {
        let renderer = MermaidRenderer()

        do {
            _ = try await renderer.renderToSVG("   \n\t\n  ", theme: .solarizedDark)
            Issue.record("Expected MermaidError.emptyInput")
        } catch {
            guard let mermaidError = error as? MermaidError,
                  case .emptyInput = mermaidError
            else {
                Issue.record("Expected MermaidError.emptyInput, got \(error)")
                return
            }
        }
    }

    @Test("Unsupported diagram type 'gantt' produces unsupportedDiagramType error")
    func unsupportedGanttType() async {
        let renderer = MermaidRenderer()

        do {
            _ = try await renderer.renderToSVG("gantt\n    title A Schedule", theme: .solarizedDark)
            Issue.record("Expected MermaidError.unsupportedDiagramType")
        } catch {
            guard let mermaidError = error as? MermaidError,
                  case let .unsupportedDiagramType(typeName) = mermaidError
            else {
                Issue.record("Expected MermaidError.unsupportedDiagramType, got \(error)")
                return
            }
            #expect(typeName == "gantt")
        }
    }

    @Test("Unsupported diagram type 'pie' produces unsupportedDiagramType error")
    func unsupportedPieType() async {
        let renderer = MermaidRenderer()

        do {
            _ = try await renderer.renderToSVG("pie\n    title Votes", theme: .solarizedLight)
            Issue.record("Expected MermaidError.unsupportedDiagramType")
        } catch {
            guard let mermaidError = error as? MermaidError,
                  case let .unsupportedDiagramType(typeName) = mermaidError
            else {
                Issue.record("Expected MermaidError.unsupportedDiagramType, got \(error)")
                return
            }
            #expect(typeName == "pie")
        }
    }

    @Test(
        "Unsupported diagram types are all rejected",
        arguments: ["gantt", "pie", "journey", "gitGraph", "mindmap"]
    )
    func unsupportedTypeRejected(typeName: String) async {
        let renderer = MermaidRenderer()

        do {
            _ = try await renderer.renderToSVG("\(typeName)\n    content", theme: .solarizedDark)
            Issue.record("Expected MermaidError.unsupportedDiagramType for '\(typeName)'")
        } catch {
            guard let mermaidError = error as? MermaidError,
                  case let .unsupportedDiagramType(detected) = mermaidError
            else {
                Issue.record("Expected MermaidError.unsupportedDiagramType, got \(error)")
                return
            }
            #expect(detected == typeName)
        }
    }

    @Test("Same code with different themes produces different cache keys")
    func themeAwareCacheKeys() {
        let code = "graph TD\n    A --> B"
        let darkKey = mermaidStableHash(code + AppTheme.solarizedDark.rawValue)
        let lightKey = mermaidStableHash(code + AppTheme.solarizedLight.rawValue)

        #expect(darkKey != lightKey)
    }

    @Test("clearCache completes without error")
    func clearCacheSucceeds() async {
        let renderer = MermaidRenderer()

        await renderer.clearCache()
    }

    @Test("MermaidError.emptyInput has descriptive message")
    func emptyInputErrorDescription() {
        let error = MermaidError.emptyInput

        #expect(error.errorDescription?.contains("empty") == true)
    }

    @Test("MermaidError.unsupportedDiagramType includes type name in message")
    func unsupportedTypeErrorDescription() {
        let error = MermaidError.unsupportedDiagramType("gantt")

        #expect(error.errorDescription?.contains("gantt") == true)
    }

    @Test("MermaidError.contextCreationFailed includes reason in message")
    func contextCreationFailedErrorDescription() {
        let error = MermaidError.contextCreationFailed("file not found")

        #expect(error.errorDescription?.contains("file not found") == true)
    }

    @Test("MermaidError.javaScriptError includes JS message")
    func javaScriptErrorDescription() {
        let error = MermaidError.javaScriptError("ReferenceError: x is not defined")

        #expect(error.errorDescription?.contains("ReferenceError") == true)
    }

    @Test("End-to-end: renderToSVG produces valid SVG from a simple flowchart")
    func endToEndFlowchartRendering() async throws {
        let renderer = MermaidRenderer()
        let svg = try await renderer.renderToSVG("graph TD\n    A --> B", theme: .solarizedDark)

        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
    }

    @Test("End-to-end: renderToSVG produces valid SVG with solarizedLight theme")
    func endToEndFlowchartRenderingLight() async throws {
        let renderer = MermaidRenderer()
        let svg = try await renderer.renderToSVG("graph TD\n    A --> B", theme: .solarizedLight)

        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
    }

    @Test("End-to-end: sanitized SVG is parseable by SwiftDraw")
    func endToEndSwiftDrawParsing() async throws {
        let renderer = MermaidRenderer()
        let svg = try await renderer.renderToSVG("graph TD\n    A --> B", theme: .solarizedDark)

        guard let data = svg.data(using: .utf8) else {
            Issue.record("SVG string could not be converted to UTF-8 data")
            return
        }
        let svgImage = SwiftDraw.SVG(data: data)
        #expect(svgImage != nil, "SwiftDraw failed to parse sanitized SVG. Preview: \(String(svg.prefix(300)))")
    }

    @Test("End-to-end: renderToSVG output can be rasterized via SwiftDraw")
    func endToEndRasterization() async throws {
        let renderer = MermaidRenderer()
        let svg = try await renderer.renderToSVG("graph TD\n    A --> B", theme: .solarizedDark)

        guard let data = svg.data(using: .utf8) else {
            Issue.record("SVG string could not be converted to UTF-8 data")
            return
        }
        guard let svgImage = SwiftDraw.SVG(data: data) else {
            Issue.record("SwiftDraw could not parse SVG")
            return
        }
        let nsImage = svgImage.rasterize()
        #expect(nsImage.size.width > 0)
        #expect(nsImage.size.height > 0)
    }

    @Test("End-to-end: sequence diagram renders to valid SVG")
    func endToEndSequenceDiagram() async throws {
        let renderer = MermaidRenderer()
        let code = """
        sequenceDiagram
            Alice->>Bob: Hello Bob
            Bob-->>Alice: Hi Alice
        """
        let svg = try await renderer.renderToSVG(code, theme: .solarizedDark)

        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
    }

    @Test("End-to-end: sanitized SVG contains no var() references")
    func sanitizedSVGHasNoVarReferences() async throws {
        let renderer = MermaidRenderer()
        let svg = try await renderer.renderToSVG("graph TD\n    A --> B", theme: .solarizedDark)

        #expect(!svg.contains("var(--"), "Sanitized SVG still contains var() references: \(String(svg.prefix(500)))")
    }

    @Test("End-to-end: sanitized SVG contains no color-mix() expressions")
    func sanitizedSVGHasNoColorMix() async throws {
        let renderer = MermaidRenderer()
        let svg = try await renderer.renderToSVG("graph TD\n    A --> B", theme: .solarizedDark)

        #expect(!svg.contains("color-mix("), "Sanitized SVG still contains color-mix(): \(String(svg.prefix(500)))")
    }

    @Test("End-to-end: sanitized SVG contains no @import rules")
    func sanitizedSVGHasNoImportRules() async throws {
        let renderer = MermaidRenderer()
        let svg = try await renderer.renderToSVG("graph TD\n    A --> B", theme: .solarizedDark)

        #expect(!svg.contains("@import"), "Sanitized SVG still contains @import rules")
    }

    @Test("End-to-end: class diagram renders and rasterizes")
    func endToEndClassDiagram() async throws {
        let renderer = MermaidRenderer()
        let code = """
        classDiagram
            Animal <|-- Duck
            Animal : +int age
            Duck : +String beakColor
        """
        let svg = try await renderer.renderToSVG(code, theme: .solarizedDark)
        #expect(svg.contains("<svg"))
        #expect(!svg.contains("var(--"))

        guard let data = svg.data(using: .utf8) else {
            Issue.record("SVG data conversion failed")
            return
        }
        let parsed = SwiftDraw.SVG(data: data)
        #expect(parsed != nil, "SwiftDraw rejected class diagram SVG: \(String(svg.prefix(300)))")
    }

    @Test("End-to-end: state diagram renders and rasterizes")
    func endToEndStateDiagram() async throws {
        let renderer = MermaidRenderer()
        let code = """
        stateDiagram-v2
            [*] --> Active
            Active --> Inactive
            Inactive --> [*]
        """
        let svg = try await renderer.renderToSVG(code, theme: .solarizedDark)
        #expect(svg.contains("<svg"))
        #expect(!svg.contains("var(--"))

        guard let data = svg.data(using: .utf8) else {
            Issue.record("SVG data conversion failed")
            return
        }
        let parsed = SwiftDraw.SVG(data: data)
        #expect(parsed != nil, "SwiftDraw rejected state diagram SVG: \(String(svg.prefix(300)))")
    }

    @Test("End-to-end: ER diagram renders and rasterizes")
    func endToEndERDiagram() async throws {
        let renderer = MermaidRenderer()
        let code = """
        erDiagram
            CUSTOMER ||--o{ ORDER : places
            ORDER ||--|{ LINE-ITEM : contains
        """
        let svg = try await renderer.renderToSVG(code, theme: .solarizedDark)
        #expect(svg.contains("<svg"))
        #expect(!svg.contains("var(--"))

        guard let data = svg.data(using: .utf8) else {
            Issue.record("SVG data conversion failed")
            return
        }
        let parsed = SwiftDraw.SVG(data: data)
        #expect(parsed != nil, "SwiftDraw rejected ER diagram SVG: \(String(svg.prefix(300)))")
    }

    @Test("End-to-end: flowchart with subgraph renders and rasterizes")
    func endToEndFlowchartSubgraph() async throws {
        let renderer = MermaidRenderer()
        let code = """
        flowchart TD
            subgraph sub1[Module A]
                A1 --> A2
            end
            subgraph sub2[Module B]
                B1 --> B2
            end
            A2 --> B1
        """
        let svg = try await renderer.renderToSVG(code, theme: .solarizedDark)
        #expect(svg.contains("<svg"))
        #expect(!svg.contains("var(--"))

        guard let data = svg.data(using: .utf8) else {
            Issue.record("SVG data conversion failed")
            return
        }
        let parsed = SwiftDraw.SVG(data: data)
        #expect(parsed != nil, "SwiftDraw rejected flowchart subgraph SVG: \(String(svg.prefix(300)))")
    }
}
