import SwiftUI

/// Renders a block-level math expression as a centered display equation.
///
/// Uses SwiftMath via `MathRenderer` to produce a vector-resolution NSImage,
/// which is displayed centered with vertical breathing room. Re-renders on
/// theme or zoom changes to pick up the new foreground color and font size.
/// Failed expressions degrade to centered monospace text in secondary color.
struct MathBlockView: View {
    let code: String
    var onSizeChange: ((CGFloat) -> Void)?

    @Environment(AppSettings.self) private var appSettings

    @State private var renderedImage: NSImage?
    @State private var hasFailed = false

    private var colors: ThemeColors {
        appSettings.theme.colors
    }

    var body: some View {
        Group {
            if let image = renderedImage {
                Image(nsImage: image)
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
        .onChange(of: appSettings.theme) { _, _ in renderMath() }
        .onChange(of: appSettings.scaleFactor) { _, _ in renderMath() }
    }

    private var fallbackView: some View {
        Text(code)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(colors.foregroundSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }

    private func renderMath() {
        let foreground = PlatformTypeConverter.nsColor(from: colors.foreground)
        let baseFontSize = PlatformTypeConverter.bodyFont(
            scaleFactor: appSettings.scaleFactor
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
            let totalHeight = result.image.size.height + 16
            onSizeChange?(totalHeight)
        } else {
            renderedImage = nil
            hasFailed = true
            let estimatedHeight: CGFloat = 40
            onSizeChange?(estimatedHeight)
        }
    }
}
