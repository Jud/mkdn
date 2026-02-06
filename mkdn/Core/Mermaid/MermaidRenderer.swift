import AppKit
import Foundation
import JXKit
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

    /// Cache of rendered SVG strings keyed by Mermaid source hash.
    private var svgCache: [Int: String] = [:]

    // MARK: - Public API

    /// Render Mermaid code to an SVG string.
    func renderToSVG(_ mermaidCode: String) throws -> String {
        let cacheKey = mermaidCode.hashValue

        if let cached = svgCache[cacheKey] {
            return cached
        }

        let context = try createContext()
        let escaped = mermaidCode
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")

        let result = try context.eval("renderMermaid(\"\(escaped)\")")
        let svg = try result.string

        svgCache[cacheKey] = svg
        return svg
    }

    /// Render Mermaid code to a native NSImage.
    func renderToImage(_ mermaidCode: String) throws -> NSImage {
        let svg = try renderToSVG(mermaidCode)
        guard let svgData = svg.data(using: .utf8) else {
            throw MermaidError.invalidSVGData
        }
        guard let svgImage = SVG(data: svgData) else {
            throw MermaidError.svgRenderingFailed
        }
        return svgImage.rasterize()
    }

    /// Clear the SVG cache.
    func clearCache() {
        svgCache.removeAll()
    }

    // MARK: - Private

    private func createContext() throws -> JXContext {
        let context = JXContext()

        // Load the beautiful-mermaid bundle from app resources.
        if let bundleURL = Bundle.main.url(forResource: "mermaid.min", withExtension: "js") {
            let source = try String(contentsOf: bundleURL, encoding: .utf8)
            try context.eval(source)
        }

        return context
    }
}

// MARK: - Errors

enum MermaidError: LocalizedError {
    case invalidSVGData
    case svgRenderingFailed
    case javaScriptError(String)

    var errorDescription: String? {
        switch self {
        case .invalidSVGData:
            "Failed to convert SVG string to data."
        case .svgRenderingFailed:
            "Failed to rasterize SVG to a native image."
        case let .javaScriptError(message):
            "JavaScript error: \(message)"
        }
    }
}
