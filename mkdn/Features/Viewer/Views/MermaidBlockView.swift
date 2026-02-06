import SwiftUI

/// Renders a Mermaid diagram as a native, zoomable SwiftUI image.
///
/// Uses `MermaidRenderer` (JavaScriptCore + beautiful-mermaid) to produce SVG,
/// then SwiftDraw to rasterize to an NSImage. No WKWebView.
struct MermaidBlockView: View {
    let code: String

    @Environment(AppState.self) private var appState
    @State private var renderedImage: NSImage?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var zoomScale: CGFloat = 1.0

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let image = renderedImage {
                diagramView(image: image)
            } else if let error = errorMessage {
                errorView(message: error)
            }
        }
        .task {
            await renderDiagram()
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        HStack {
            ProgressView()
                .controlSize(.small)
            Text("Rendering diagram...")
                .font(.caption)
                .foregroundColor(appState.theme.colors.foregroundSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(appState.theme.colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func diagramView(image: NSImage) -> some View {
        ScrollView([.horizontal, .vertical]) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(zoomScale)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(appState.theme.colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    zoomScale = max(0.5, min(value.magnification, 4.0))
                }
        )
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.orange)
            Text("Mermaid rendering failed")
                .font(.caption.bold())
            Text(message)
                .font(.caption)
                .foregroundColor(appState.theme.colors.foregroundSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(appState.theme.colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Rendering

    private func renderDiagram() async {
        isLoading = true
        do {
            let svgString = try await MermaidRenderer.shared.renderToSVG(code)
            if let image = svgStringToImage(svgString) {
                renderedImage = image
                errorMessage = nil
            } else {
                errorMessage = "Failed to render SVG to image."
                renderedImage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
            renderedImage = nil
        }
        isLoading = false
    }

    /// Convert an SVG string to NSImage on the main actor (avoids Sendable issues).
    @MainActor
    private func svgStringToImage(_ svgString: String) -> NSImage? {
        guard let data = svgString.data(using: .utf8) else { return nil }
        guard let svg = SwiftDraw.SVG(data: data) else { return nil }
        return svg.rasterize()
    }
}

@preconcurrency import SwiftDraw
