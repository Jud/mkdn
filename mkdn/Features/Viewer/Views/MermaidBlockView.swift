import SwiftUI

/// Placeholder view for Mermaid diagram blocks.
///
/// The full WKWebView-based rendering implementation will replace this
/// placeholder in a subsequent task.
struct MermaidBlockView: View {
    let code: String

    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.orange)
            Text("Mermaid rendering unavailable")
                .font(.caption.bold())
            Text("The Mermaid rendering pipeline is being rebuilt.")
                .font(.caption)
                .foregroundColor(appSettings.theme.colors.foregroundSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(appSettings.theme.colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
