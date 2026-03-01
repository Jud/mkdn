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
    ///
    /// No additional accessibility modifiers are needed here. ``MarkdownTextViewiOS``
    /// wraps a `UITextView`, which provides native VoiceOver support (text content
    /// reading, element traversal, and trait announcement) out of the box.
    struct TextBlockViewiOS: View {
        let indexedBlock: IndexedBlock
        let theme: AppTheme
        let scaleFactor: CGFloat

        @State private var cachedAttributedString: NSAttributedString?

        private var cacheKey: String {
            "\(indexedBlock.id)-\(theme.rawValue)-\(scaleFactor)"
        }

        var body: some View {
            Group {
                if let cached = cachedAttributedString {
                    MarkdownTextViewiOS(
                        attributedString: cached,
                        theme: theme
                    )
                }
            }
            .task(id: cacheKey) {
                cachedAttributedString = MarkdownTextStorageBuilder.build(
                    blocks: [indexedBlock],
                    theme: theme,
                    scaleFactor: scaleFactor
                ).attributedString
            }
        }
    }
#endif
