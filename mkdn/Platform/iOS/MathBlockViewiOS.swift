#if os(iOS)
    import SwiftUI
    import UIKit

    /// Renders a block-level LaTeX math expression as a centered display equation on iOS.
    ///
    /// Uses ``MathRenderer`` to produce a resolution-independent `UIImage`, which is
    /// displayed centered with vertical breathing room. Publishes the rendered image
    /// to ``BlockInteractionContext/renderedImage`` so consumer wrappers can observe it.
    /// Failed expressions degrade to centered monospace text in secondary color.
    struct MathBlockViewiOS: View {
        let code: String
        let theme: AppTheme
        let scaleFactor: CGFloat
        let context: BlockInteractionContext?

        @State private var renderedImage: UIImage?
        @State private var hasFailed = false

        private var colors: ThemeColors {
            theme.colors
        }

        var body: some View {
            Group {
                if let image = renderedImage {
                    Image(uiImage: image)
                        .interpolation(.high)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else if hasFailed {
                    fallbackView
                } else {
                    Color.clear.frame(height: 40)
                }
            }
            .onAppear { renderMath() }
            .accessibilityLabel("Math expression: \(code)")
        }

        private var fallbackView: some View {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(colors.foregroundSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        }

        private func renderMath() {
            let foreground = PlatformTypeConverter.color(from: colors.foreground)
            let baseFontSize = PlatformTypeConverter.bodyFont(
                scaleFactor: scaleFactor
            ).pointSize
            let displayFontSize = baseFontSize * 1.2

            if let result = MathRenderer.renderToImage(
                latex: code,
                fontSize: displayFontSize,
                textColor: foreground,
                displayMode: true
            ) {
                renderedImage = result.image
                hasFailed = false
                context?.setRenderedImage(result.image)
            } else {
                renderedImage = nil
                hasFailed = true
            }
        }
    }
#endif
