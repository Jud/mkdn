#if os(iOS)
    import SwiftUI

    /// Wraps ``MermaidWebViewiOS`` with render state overlays and size reporting.
    ///
    /// Displays a loading indicator while the diagram renders, an error view on
    /// failure, and the rendered diagram on success. Reports the rendered height
    /// via binding for layout sizing by the parent ``BlockWrapperView``.
    struct MermaidBlockViewiOS: View {
        let code: String
        let theme: AppTheme

        @State private var renderedHeight: CGFloat = 100
        @State private var renderState: MermaidRenderState = .loading

        private var colors: ThemeColors {
            theme.colors
        }

        var body: some View {
            ZStack {
                MermaidWebViewiOS(
                    code: code,
                    theme: theme,
                    renderedHeight: $renderedHeight,
                    renderState: $renderState
                )
                .opacity(renderState == .rendered ? 1 : 0)

                overlay
            }
            .frame(
                maxWidth: .infinity,
                minHeight: 100,
                maxHeight: renderState == .rendered ? .infinity : 100
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(colors.border.opacity(0.3), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.3), value: renderState)
        }

        // MARK: - Overlay

        @ViewBuilder
        private var overlay: some View {
            if case let .error(message) = renderState {
                errorView(message: message)
            } else if renderState == .loading {
                loadingView
            }
        }

        private var loadingView: some View {
            VStack(spacing: 8) {
                ProgressView()
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
    }
#endif
