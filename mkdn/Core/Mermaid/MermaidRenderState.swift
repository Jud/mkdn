import Foundation

/// Tracks the lifecycle state of a Mermaid diagram render.
public enum MermaidRenderState: Equatable, Sendable {
    /// The diagram is being rendered by Mermaid.js in the WKWebView.
    case loading

    /// The diagram rendered successfully and is ready to display.
    case rendered

    /// The diagram failed to render with the given error message.
    case error(String)
}
