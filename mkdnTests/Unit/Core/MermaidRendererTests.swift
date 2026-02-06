import Testing

@testable import mkdnLib

@Suite("MermaidRenderer")
struct MermaidRendererTests {
    @Test("Empty input produces emptyInput error")
    func emptyInputError() async {
        let renderer = MermaidRenderer()

        do {
            _ = try await renderer.renderToSVG("")
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
            _ = try await renderer.renderToSVG("   \n\t\n  ")
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
            _ = try await renderer.renderToSVG("gantt\n    title A Schedule")
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
            _ = try await renderer.renderToSVG("pie\n    title Votes")
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
            _ = try await renderer.renderToSVG("\(typeName)\n    content")
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

    @Test("clearCache completes without error")
    func clearCacheSucceeds() async {
        let renderer = MermaidRenderer()

        await renderer.clearCache()
    }

    @Test("MermaidError.emptyInput has descriptive message")
    func emptyInputErrorDescription() {
        let error = MermaidError.emptyInput

        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("empty"))
    }

    @Test("MermaidError.unsupportedDiagramType includes type name in message")
    func unsupportedTypeErrorDescription() {
        let error = MermaidError.unsupportedDiagramType("gantt")

        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("gantt"))
    }

    @Test("MermaidError.contextCreationFailed includes reason in message")
    func contextCreationFailedErrorDescription() {
        let error = MermaidError.contextCreationFailed("file not found")

        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("file not found"))
    }

    @Test("MermaidError.javaScriptError includes JS message")
    func javaScriptErrorDescription() {
        let error = MermaidError.javaScriptError("ReferenceError: x is not defined")

        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("ReferenceError"))
    }
}
