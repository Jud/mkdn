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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isFocused = false
    @FocusState private var isKeyboardFocused: Bool
    @State private var renderedHeight: CGFloat = 200
    @State private var renderedAspectRatio: CGFloat = 0.5
    @State private var renderState: MermaidRenderState = .loading

    private var colors: ThemeColors {
        appSettings.theme.colors
    }

    private var motion: MotionPreference {
        MotionPreference(reduceMotion: reduceMotion)
    }

    var body: some View {
        diagramContent
            .background(colors.backgroundSecondary)
            .hoverBrightness()
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(focusBorder)
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
                isKeyboardFocused = true
            }
            .focusable()
            .focused($isKeyboardFocused)
            .onKeyPress(.escape) {
                isFocused = false
                isKeyboardFocused = false
                return .handled
            }
            .onChange(of: isKeyboardFocused) {
                if !isKeyboardFocused {
                    isFocused = false
                }
            }
    }

    @ViewBuilder
    private var diagramContent: some View {
        let content = ZStack {
            MermaidWebView(
                code: code,
                theme: appSettings.theme,
                isFocused: $isFocused,
                renderedHeight: $renderedHeight,
                renderedAspectRatio: $renderedAspectRatio,
                renderState: $renderState
            )
            .opacity(renderState == .rendered ? 1 : 0)
            .animation(motion.resolved(.crossfade), value: renderState)

            overlay
                .animation(motion.resolved(.crossfade), value: renderState)
        }

        if renderState == .rendered {
            content
                .aspectRatio(
                    1 / renderedAspectRatio,
                    contentMode: .fit
                )
        } else {
            content
                .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100)
        }
    }

    // MARK: - Overlay

    @ViewBuilder
    private var overlay: some View {
        switch renderState {
        case .loading:
            loadingView
                .transition(.opacity)

        case .rendered:
            EmptyView()

        case let .error(message):
            errorView(message: message)
                .transition(.opacity)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            PulsingSpinner()
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

    private var focusBorder: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(
                colors.accent,
                lineWidth: isFocused ? AnimationConstants.focusBorderWidth : 0
            )
            .opacity(isFocused ? 1.0 : 0)
            .shadow(
                color: colors.accent.opacity(isFocused ? 0.4 : 0),
                radius: isFocused ? AnimationConstants.focusGlowRadius : 0
            )
            .animation(
                isFocused
                    ? motion.resolved(.springSettle)
                    : motion.resolved(.fadeOut),
                value: isFocused
            )
    }
}
