import SwiftUI

/// Displays a Mermaid diagram using a `WKWebView`-based rendering pipeline.
///
/// Manages focus state, loading/error UI overlays, and frame sizing.
/// When unfocused, scroll events pass through to the parent document
/// scroll view. Clicking the diagram activates focus, enabling
/// pinch-to-zoom and two-finger pan within the `WKWebView`.
struct MermaidBlockView: View {
    let code: String
    var onSizeChange: ((CGFloat, CGFloat) -> Void)?

    @Environment(AppSettings.self) private var appSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isFocused = false
    @State private var renderedHeight: CGFloat = 100
    @State private var renderedAspectRatio: CGFloat = 0.5
    @State private var renderState: MermaidRenderState = .loading
    @State private var overlayDismissed = false
    @State private var isCursorPushed = false

    private var colors: ThemeColors {
        appSettings.theme.colors
    }

    private var motion: MotionPreference {
        MotionPreference(reduceMotion: reduceMotion)
    }

    var body: some View {
        diagramContent
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(focusBorder)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering, !isFocused, !isCursorPushed {
                    NSCursor.pointingHand.push()
                    isCursorPushed = true
                } else if !hovering || isFocused, isCursorPushed {
                    NSCursor.pop()
                    isCursorPushed = false
                }
            }
            .onTapGesture {
                isFocused = true
            }
            .onChange(of: isFocused) { _, focused in
                if focused, isCursorPushed {
                    NSCursor.pop()
                    isCursorPushed = false
                }
            }
            .onChange(of: renderedHeight) {
                onSizeChange?(renderedHeight, renderedAspectRatio)
            }
            .onChange(of: renderedAspectRatio) {
                onSizeChange?(renderedHeight, renderedAspectRatio)
            }
            .onChange(of: renderState) { _, newValue in
                if newValue == .rendered {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        if renderState == .rendered {
                            overlayDismissed = true
                        }
                    }
                } else {
                    overlayDismissed = false
                }
            }
    }

    private var diagramContent: some View {
        ZStack {
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
                .animation(motion.resolved(.crossfade), value: overlayDismissed)
                .animation(motion.resolved(.crossfade), value: renderState)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 100,
            maxHeight: renderState == .rendered ? .infinity : 100
        )
        .aspectRatio(
            renderState == .rendered ? 1 / renderedAspectRatio : nil,
            contentMode: .fit
        )
        .animation(motion.resolved(.gentleSpring), value: renderState)
    }

    // MARK: - Overlay

    @ViewBuilder
    private var overlay: some View {
        if case let .error(message) = renderState {
            errorView(message: message)
                .transition(.opacity)
        } else if !overlayDismissed {
            loadingView
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
                colors.border,
                lineWidth: isFocused ? AnimationConstants.focusBorderWidth : 0
            )
            .opacity(isFocused ? 1.0 : 0)
            .shadow(
                color: colors.border.opacity(isFocused ? 0.4 : 0),
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
