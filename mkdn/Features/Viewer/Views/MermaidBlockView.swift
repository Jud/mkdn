import SwiftUI

/// Renders a Mermaid diagram as a native, zoomable SwiftUI image.
///
/// Uses `MermaidRenderer` (JavaScriptCore + beautiful-mermaid) to produce SVG,
/// then SwiftDraw to rasterize to an NSImage. No WKWebView.
///
/// Scroll isolation: when not activated, no `ScrollView` exists in the hierarchy
/// so document-level scroll passes through. Click to activate internal panning;
/// press Escape or click outside to deactivate.
struct MermaidBlockView: View {
    let code: String

    @Environment(AppState.self) private var appState
    @State private var renderedImage: NSImage?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var zoomScale: CGFloat = 1.0
    @State private var baseZoomScale: CGFloat = 1.0
    @State private var isActivated = false
    @FocusState private var isFocused: Bool

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

    // MARK: - Diagram View

    @ViewBuilder
    private func diagramView(image: NSImage) -> some View {
        if isActivated {
            activatedDiagramView(image: image)
        } else {
            inactiveDiagramView(image: image)
        }
    }

    private func inactiveDiagramView(image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(zoomScale)
            .frame(maxWidth: .infinity, maxHeight: 400)
            .clipped()
            .contentShape(Rectangle())
            .gesture(zoomGesture)
            .onTapGesture {
                isActivated = true
                isFocused = true
            }
            .background(appState.theme.colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func activatedDiagramView(image: NSImage) -> some View {
        ScrollView([.horizontal, .vertical]) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: image.size.width * zoomScale,
                    height: image.size.height * zoomScale
                )
        }
        .frame(maxWidth: .infinity, maxHeight: 400)
        .background(appState.theme.colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(appState.theme.colors.accent, lineWidth: 2)
        )
        .gesture(zoomGesture)
        .focusable()
        .focused($isFocused)
        .onKeyPress(.escape) {
            isActivated = false
            return .handled
        }
        .onChange(of: isFocused) { _, newValue in
            if !newValue {
                isActivated = false
            }
        }
    }

    // MARK: - Zoom Gesture

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = baseZoomScale * value.magnification
                zoomScale = max(0.5, min(newScale, 4.0))
            }
            .onEnded { _ in
                baseZoomScale = zoomScale
            }
    }

    // MARK: - Loading & Error Views

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

    @MainActor
    private func svgStringToImage(_ svgString: String) -> NSImage? {
        guard let data = svgString.data(using: .utf8) else { return nil }
        guard let svg = SwiftDraw.SVG(data: data) else { return nil }
        return svg.rasterize()
    }
}

@preconcurrency import SwiftDraw
