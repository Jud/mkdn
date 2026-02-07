import Foundation

/// Errors that can occur during Mermaid diagram rendering.
public enum MermaidError: LocalizedError, Sendable {
    /// The HTML template resource could not be found in the bundle.
    case templateNotFound

    /// Mermaid.js failed to render the diagram.
    case renderFailed(String)

    public var errorDescription: String? {
        switch self {
        case .templateNotFound:
            "Could not locate Mermaid HTML template in bundle resources."
        case let .renderFailed(message):
            "Mermaid rendering failed: \(message)"
        }
    }
}
