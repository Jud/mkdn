import SwiftUI

/// Renders a Mermaid diagram as a native, zoomable SwiftUI image.
///
/// Uses `MermaidRenderer` (JavaScriptCore + beautiful-mermaid) to produce SVG,
/// then SwiftDraw to rasterize to an NSImage. No WKWebView.
///
/// Scroll isolation: a `ScrollPhaseMonitor` overlay intercepts scroll wheel
/// events and uses `GestureIntentClassifier` to distinguish fresh diagram-pan
/// gestures from momentum-carry document scrolls. No visible activation state.
struct MermaidBlockView: View {
    let code: String

    @Environment(AppSettings.self) private var appSettings
    @State private var renderedImage: NSImage?
    @State private var errorMessage: String?
    @State private var isLoading: Bool
    @State private var zoomScale: CGFloat = 1.0
    @State private var baseZoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero

    @MainActor
    init(code: String) {
        self.code = code
        _renderedImage = State(initialValue: nil)
        _errorMessage = State(initialValue: nil)
        _isLoading = State(initialValue: true)
    }

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
        .task(id: TaskID(code: code, theme: appSettings.theme)) {
            await renderDiagram()
        }
    }

    // MARK: - Diagram View

    private func diagramView(image: NSImage) -> some View {
        GeometryReader { _ in
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(zoomScale)
                .offset(x: panOffset.width, y: panOffset.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: 400)
        .clipped()
        .contentShape(Rectangle())
        .overlay(
            ScrollPhaseMonitor(
                contentSize: image.size,
                zoomScale: zoomScale,
                panOffset: $panOffset
            )
        )
        .gesture(zoomGesture)
        .background(appSettings.theme.colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Gestures

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
                .foregroundColor(appSettings.theme.colors.foregroundSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(appSettings.theme.colors.backgroundSecondary)
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
                .foregroundColor(appSettings.theme.colors.foregroundSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(appSettings.theme.colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Rendering

    private func renderDiagram() async {
        let currentTheme = appSettings.theme

        if let cached = MermaidImageStore.shared.get(code, theme: currentTheme) {
            renderedImage = cached
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = renderedImage == nil
        do {
            let svgString = try await MermaidRenderer.shared.renderToSVG(code, theme: currentTheme)
            if let image = svgStringToImage(svgString) {
                renderedImage = image
                errorMessage = nil
                MermaidImageStore.shared.store(code, image: image, theme: currentTheme)
            } else {
                let preview = String(svgString.prefix(200))
                let diagnostic = "SwiftDraw failed to parse sanitized SVG "
                    + "(length: \(svgString.count), preview: \(preview))"
                errorMessage = diagnostic
                renderedImage = nil
            }
        } catch let error as MermaidError {
            errorMessage = "Mermaid rendering failed: \(error.errorDescription ?? String(describing: error))"
            renderedImage = nil
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
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

    // MARK: - Task Identity

    private struct TaskID: Hashable {
        let code: String
        let theme: AppTheme
    }
}

@preconcurrency import SwiftDraw
