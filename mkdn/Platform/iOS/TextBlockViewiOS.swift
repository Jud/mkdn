#if os(iOS)
    import SwiftUI

    /// Unified text block renderer for headings, paragraphs, blockquotes, lists,
    /// thematic breaks, and HTML blocks on iOS.
    ///
    /// Uses ``MarkdownTextStorageBuilder`` to convert a single ``IndexedBlock`` into
    /// an `NSAttributedString`, then displays it via ``MarkdownTextViewiOS``. This
    /// single view handles all text-based block types because the builder already
    /// encodes styling differences (heading font sizes, blockquote indentation,
    /// list prefixes, etc.) into the attributed string.
    struct TextBlockViewiOS: View {
        let indexedBlock: IndexedBlock
        let theme: AppTheme
        let scaleFactor: CGFloat

        var body: some View {
            let result = MarkdownTextStorageBuilder.build(
                blocks: [indexedBlock],
                theme: theme,
                scaleFactor: scaleFactor
            )
            MarkdownTextViewiOS(
                attributedString: result.attributedString,
                theme: theme
            )
        }
    }
#endif
