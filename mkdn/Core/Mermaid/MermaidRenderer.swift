import AppKit
import Foundation
@preconcurrency import JXKit
import SwiftDraw
import SwiftUI

/// Renders Mermaid diagram code into native SwiftUI `Image` views.
///
/// Pipeline: Mermaid text -> JavaScriptCore -> beautiful-mermaid -> SVG string
///           -> SwiftDraw -> NSImage -> SwiftUI Image
///
/// This is entirely in-process. No WKWebView is used anywhere.
actor MermaidRenderer {
    /// Shared singleton instance.
    static let shared = MermaidRenderer()

    /// Bounded LRU cache of rendered SVG strings keyed by stable DJB2 hash.
    private var cache = MermaidCache(capacity: 50)

    /// Lazily-created JavaScript context, reused across renders.
    /// Set to `nil` on corruption to force recreation on next call.
    private var context: JXContext?

    /// Diagram type keywords that mkdn supports rendering.
    private static let supportedTypes: Set<String> = [
        "graph", "flowchart", "sequenceDiagram",
        "stateDiagram", "stateDiagram-v2",
        "classDiagram", "erDiagram",
    ]

    /// Known Mermaid diagram types that mkdn does not yet support.
    private static let unsupportedKnownTypes: Set<String> = [
        "gantt", "pie", "journey", "gitGraph", "mindmap",
    ]

    // MARK: - Public API

    /// Render Mermaid code to an SVG string themed for the given app theme.
    ///
    /// The theme controls which `beautifulMermaid.THEMES` preset is passed to the
    /// JavaScript renderer and is included in the cache key so that each theme
    /// variant is cached independently.
    func renderToSVG(_ mermaidCode: String, theme: AppTheme = .solarizedDark) async throws -> String {
        let trimmed = mermaidCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MermaidError.emptyInput
        }

        try validateDiagramType(trimmed)

        let cacheKey = mermaidStableHash(mermaidCode + theme.rawValue)

        if let cached = cache.get(cacheKey) {
            return cached
        }

        let jsContext = try getOrCreateContext()
        let escaped = mermaidCode
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")

        let themePreset = mermaidJSThemeKey(for: theme)

        let svg: String
        do {
            let js = "beautifulMermaid.renderMermaid(\"\(escaped)\", beautifulMermaid.THEMES['\(themePreset)'])"
            let promise = try jsContext.eval(js)
            let result = try await promise.awaitPromise()
            svg = try result.string
        } catch let error as JXError {
            context = nil
            throw MermaidError.javaScriptError(error.message)
        } catch {
            context = nil
            throw MermaidError.javaScriptError(error.localizedDescription)
        }

        let sanitized = SVGSanitizer.sanitize(svg)
        cache.set(cacheKey, value: sanitized)
        return sanitized
    }

    /// Render Mermaid code to a native NSImage themed for the given app theme.
    func renderToImage(_ mermaidCode: String, theme: AppTheme = .solarizedDark) async throws -> NSImage {
        let svg = try await renderToSVG(mermaidCode, theme: theme)
        guard let svgData = svg.data(using: .utf8) else {
            throw MermaidError.invalidSVGData
        }
        guard let svgImage = SVG(data: svgData) else {
            throw MermaidError.svgRenderingFailed
        }
        return svgImage.rasterize()
    }

    /// Clear the SVG cache, forcing all diagrams to re-render on next display.
    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private

    /// Returns the existing `JXContext` or creates a new one with
    /// beautiful-mermaid.js loaded from the SPM bundle resource.
    private func getOrCreateContext() throws -> JXContext {
        if let existing = context {
            return existing
        }

        let newContext = JXContext()

        guard let bundleURL = Bundle.module.url(
            forResource: "mermaid.min",
            withExtension: "js"
        )
        else {
            throw MermaidError.contextCreationFailed(
                "Could not locate mermaid.min.js in bundle resources."
            )
        }

        do {
            let source = try String(contentsOf: bundleURL, encoding: .utf8)
            try newContext.eval(source)
        } catch let error as JXError {
            throw MermaidError.contextCreationFailed(error.message)
        } catch {
            throw MermaidError.contextCreationFailed(error.localizedDescription)
        }

        context = newContext
        return newContext
    }

    /// Maps an ``AppTheme`` to the corresponding key in `beautifulMermaid.THEMES`.
    private func mermaidJSThemeKey(for theme: AppTheme) -> String {
        switch theme {
        case .solarizedDark:
            "solarized-dark"
        case .solarizedLight:
            "solarized-light"
        }
    }

    /// Validates the diagram type keyword on the first non-empty line.
    /// Throws for known-but-unsupported types; unknown keywords pass through to JS.
    private func validateDiagramType(_ trimmedCode: String) throws {
        let firstLine = trimmedCode
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?
            .trimmingCharacters(in: .whitespaces) ?? ""

        let keyword = firstLine
            .components(separatedBy: .whitespaces)
            .first ?? firstLine

        if Self.unsupportedKnownTypes.contains(keyword) {
            throw MermaidError.unsupportedDiagramType(keyword)
        }
    }
}

// MARK: - Errors

enum MermaidError: LocalizedError {
    case invalidSVGData
    case svgRenderingFailed
    case javaScriptError(String)
    case emptyInput
    case unsupportedDiagramType(String)
    case contextCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSVGData:
            "Failed to convert SVG string to data."
        case .svgRenderingFailed:
            "Failed to rasterize SVG to a native image."
        case let .javaScriptError(message):
            "JavaScript error: \(message)"
        case .emptyInput:
            "Mermaid diagram source is empty. Add a diagram type and definition."
        case let .unsupportedDiagramType(typeName):
            "Unsupported Mermaid diagram type: \(typeName). Supported types are flowchart, sequence, state, class, and ER diagrams."
        case let .contextCreationFailed(reason):
            "Failed to create JavaScript context: \(reason)"
        }
    }
}
