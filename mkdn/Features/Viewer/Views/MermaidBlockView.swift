import SwiftUI

/// Displays a Mermaid diagram using a `WKWebView`-based rendering pipeline.
///
/// Manages focus state, loading/error UI overlays, and frame sizing.
/// When unfocused, scroll events pass through to the parent document
/// scroll view. Clicking the diagram activates focus, enabling
/// pinch-to-zoom and two-finger pan within the `WKWebView`.
struct MermaidBlockView: View {
    let code: String

    @Environment(AppSettings.self) private var appSettings

    @State private var isFocused = false
    @State private var renderedHeight: CGFloat = 200
    @State private var renderState: MermaidRenderState = .loading

    private let maxDiagramHeight: CGFloat = 600

    private var colors: ThemeColors {
        appSettings.theme.colors
    }

    var body: some View {
        ZStack {
            MermaidWebView(
                code: code,
                theme: appSettings.theme,
                isFocused: $isFocused,
                renderedHeight: $renderedHeight,
                renderState: $renderState
            )
            .opacity(renderState == .rendered ? 1 : 0)

            overlay
        }
        .frame(
            maxWidth: .infinity,
            minHeight: renderState == .rendered
                ? min(renderedHeight, maxDiagramHeight)
                : 100,
            maxHeight: min(renderedHeight, maxDiagramHeight)
        )
        .background(colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(focusBorder)
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .focusable(isFocused)
        .onKeyPress(.escape) {
            isFocused = false
            return .handled
        }
    }

    // MARK: - Overlay

    @ViewBuilder
    private var overlay: some View {
        switch renderState {
        case .loading:
            loadingView

        case .rendered:
            EmptyView()

        case let .error(message):
            errorView(message: message)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Rendering diagram\u{2026}")
                .font(.caption)
                .foregroundColor(colors.foregroundSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .foregroundColor(colors.foregroundSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Focus Border

    @ViewBuilder
    private var focusBorder: some View {
        if isFocused {
            RoundedRectangle(cornerRadius: 6)
                .stroke(colors.accent, lineWidth: 2)
        }
    }
}
