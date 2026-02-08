import SwiftUI

/// View model for the Markdown preview feature.
///
/// Manages parsed blocks and triggers re-rendering when content changes.
@MainActor
@Observable
final class PreviewViewModel {
    /// Rendered Markdown blocks for display.
    private(set) var blocks: [IndexedBlock] = []

    /// The raw Markdown text being rendered.
    var markdownText = "" {
        didSet {
            renderBlocks()
        }
    }

    /// The active theme.
    var theme: AppTheme = .solarizedDark {
        didSet {
            renderBlocks()
        }
    }

    // MARK: - Private

    private func renderBlocks() {
        blocks = MarkdownRenderer.render(text: markdownText, theme: theme)
    }
}
