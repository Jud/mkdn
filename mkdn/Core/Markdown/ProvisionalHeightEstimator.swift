#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Cheap whole-document height floor computed from the parsed blocks alone —
/// no Core Text over the content (two one-line sample measurements derive the
/// per-font metrics). A progressive open seeds `estimatedHeightFloor` from
/// this before any tail content exists, so the scroller reflects roughly the
/// full document from first paint; the exact per-block pass replaces it when
/// the tail completes.
///
/// Deliberately biased upward: an over-estimate briefly under-sizes the
/// scroll thumb, but an under-estimate would let a deep scroll land past the
/// provisional bottom into content that doesn't exist yet.
@MainActor
public enum ProvisionalHeightEstimator {
    /// Multiplier over the summed per-block estimates. The wrap estimate
    /// counts characters, which under-counts lines against real word
    /// wrapping (a wrapped word leaves its line short), so the bias must
    /// cover the worst fixture before the exact pass lands.
    private static let bias: CGFloat = 1.35

    public static func provisionalHeight(
        of blocks: [IndexedBlock],
        textWidth: CGFloat,
        scaleFactor: CGFloat,
        verticalInset: CGFloat
    ) -> CGFloat {
        guard !blocks.isEmpty, textWidth > 0 else { return 0 }
        let body = FontMetrics(
            font: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor)
        )
        let mono = FontMetrics(
            font: PlatformTypeConverter.monospacedFont(scaleFactor: scaleFactor)
        )
        var height: CGFloat = 0
        for indexed in blocks {
            height += estimate(
                indexed.block, textWidth: textWidth, scaleFactor: scaleFactor,
                body: body, mono: mono
            )
        }
        return ceil(height * Self.bias) + verticalInset * 2
    }

    // MARK: - Per-Block Estimate

    private static func estimate(
        _ block: MarkdownBlock,
        textWidth: CGFloat,
        scaleFactor: CGFloat,
        body: FontMetrics,
        mono: FontMetrics
    ) -> CGFloat {
        let spacing = MarkdownTextStorageBuilder.blockSpacing * scaleFactor
        switch block {
        case let .heading(level, text):
            let font = PlatformTypeConverter.headingFont(level: level, scaleFactor: scaleFactor)
            let metrics = FontMetrics(font: font)
            let lines = wrappedLines(
                String(text.characters), charsPerLine: textWidth / metrics.averageCharWidth
            )
            return lines * metrics.lineHeight
                + MarkdownTextStorageBuilder.headingTopMargin * scaleFactor + spacing
        case let .paragraph(text):
            let lines = wrappedLines(
                String(text.characters), charsPerLine: textWidth / body.averageCharWidth
            )
            return lines * body.lineHeight
                + MarkdownTextStorageBuilder.paragraphBottomMargin * scaleFactor + spacing
        case let .htmlBlock(content):
            let lines = wrappedLines(content, charsPerLine: textWidth / body.averageCharWidth)
            return lines * body.lineHeight + spacing
        case let .codeBlock(_, code):
            let codeWidth = textWidth - 2 * MarkdownTextStorageBuilder.codeBlockPadding
            let lines = wrappedLines(
                code.trimmingCharacters(in: .whitespacesAndNewlines),
                charsPerLine: codeWidth / mono.averageCharWidth
            )
            // One extra line covers the language label row.
            return (lines + 1) * mono.lineHeight
                + 2 * MarkdownTextStorageBuilder.codeBlockPadding * scaleFactor + spacing
        case .mermaidBlock, .image, .mathBlock:
            return MarkdownTextStorageBuilder.attachmentPlaceholderHeight + spacing
        case .thematicBreak:
            return MarkdownTextStorageBuilder.thematicBreakHeight + spacing
        case let .table(_, rows):
            // Header + rows at roughly double line height for cell padding;
            // multi-line cells are the bias's problem.
            return CGFloat(rows.count + 1) * body.lineHeight * 2 + spacing
        case let .blockquote(blocks):
            let indented = textWidth - MarkdownTextStorageBuilder.blockquoteIndent * scaleFactor
            return blocks.reduce(0) { sum, inner in
                sum + estimate(
                    inner, textWidth: max(indented, 1), scaleFactor: scaleFactor,
                    body: body, mono: mono
                )
            }
        case let .orderedList(items), let .unorderedList(items):
            let indented = textWidth - MarkdownTextStorageBuilder.listPrefixWidth * scaleFactor
            return items.reduce(0) { sum, item in
                sum + item.blocks.reduce(0) { itemSum, inner in
                    itemSum + estimate(
                        inner, textWidth: max(indented, 1), scaleFactor: scaleFactor,
                        body: body, mono: mono
                    )
                } + MarkdownTextStorageBuilder.listItemSpacing * scaleFactor
            }
        }
    }

    /// Wrapped line count of `text` when each line holds `charsPerLine`
    /// characters: hard newlines split, each piece wraps by character count.
    private static func wrappedLines(_ text: String, charsPerLine: CGFloat) -> CGFloat {
        guard charsPerLine >= 1 else { return CGFloat(max(1, text.count)) }
        var lines: CGFloat = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            lines += max(1, (CGFloat(line.count) / charsPerLine).rounded(.up))
        }
        return max(1, lines)
    }

    /// Line height and average glyph width for one font, derived from a
    /// single sample-string measurement rather than per-character tables.
    private struct FontMetrics {
        let lineHeight: CGFloat
        let averageCharWidth: CGFloat

        @MainActor
        init(font: PlatformTypeConverter.PlatformFont) {
            // The builder's paragraph styles add 2pt line spacing.
            lineHeight = ceil(font.ascender - font.descender + font.leading) + 2
            let sample = "the quick brown fox jumps over 0123456789"
            let width = NSAttributedString(
                string: sample, attributes: [.font: font]
            ).size().width
            averageCharWidth = max(width / CGFloat(sample.count), 1)
        }
    }
}
