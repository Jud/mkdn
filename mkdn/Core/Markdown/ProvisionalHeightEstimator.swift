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

    // Spacing constants (blockSpacing, margins, padding, indents) are used
    // unscaled, matching the builder's paragraph styles — only fonts zoom.
    private static func estimate(
        _ block: MarkdownBlock,
        textWidth: CGFloat,
        scaleFactor: CGFloat,
        body: FontMetrics,
        mono: FontMetrics
    ) -> CGFloat {
        let spacing = MarkdownTextStorageBuilder.blockSpacing
        switch block {
        case let .heading(level, text):
            let font = PlatformTypeConverter.headingFont(level: level, scaleFactor: scaleFactor)
            let metrics = FontMetrics(font: font)
            let lines = wrappedLines(
                String(text.characters), charsPerLine: textWidth / metrics.averageCharWidth
            )
            return lines * metrics.lineHeight
                + MarkdownTextStorageBuilder.headingTopMargin + spacing
        case let .paragraph(text):
            let lines = wrappedLines(
                String(text.characters), charsPerLine: textWidth / body.averageCharWidth
            )
            return lines * body.lineHeight
                + MarkdownTextStorageBuilder.paragraphBottomMargin + spacing
        case let .htmlBlock(content):
            let lines = wrappedLines(content, charsPerLine: textWidth / mono.averageCharWidth)
            return lines * mono.lineHeight + spacing
        case let .codeBlock(_, code):
            let codeWidth = textWidth - 2 * MarkdownTextStorageBuilder.codeBlockPadding
            let lines = wrappedLines(
                code.trimmingCharacters(in: .whitespacesAndNewlines),
                charsPerLine: codeWidth / mono.averageCharWidth
            )
            // One extra line covers the language label row.
            return (lines + 1) * mono.lineHeight
                + 2 * MarkdownTextStorageBuilder.codeBlockPadding + spacing
        case .mermaidBlock, .image, .mathBlock:
            return MarkdownTextStorageBuilder.attachmentPlaceholderHeight + spacing
        case .thematicBreak:
            return MarkdownTextStorageBuilder.thematicBreakHeight + spacing
        case let .table(columns, rows):
            return tableEstimate(columns: columns, rows: rows) + spacing
        case let .blockquote(blocks):
            let indented = textWidth - MarkdownTextStorageBuilder.blockquoteIndent
            return blocks.reduce(0) { sum, inner in
                sum + estimate(
                    inner, textWidth: max(indented, 1), scaleFactor: scaleFactor,
                    body: body, mono: mono
                )
            }
        case let .orderedList(items), let .unorderedList(items):
            let indented = textWidth - MarkdownTextStorageBuilder.listPrefixWidth
            return items.reduce(0) { sum, item in
                sum + item.blocks.reduce(0) { itemSum, inner in
                    itemSum + estimate(
                        inner, textWidth: max(indented, 1), scaleFactor: scaleFactor,
                        body: body, mono: mono
                    )
                } + MarkdownTextStorageBuilder.listItemSpacing
            }
        }
    }

    /// Mirrors the build-time table placeholder, which `TableColumnSizer`
    /// sizes at `defaultEstimationContainerWidth` with the unscaled body
    /// font, regardless of the live width or zoom: per row, the tallest
    /// cell's wrapped lines at a compressed even-split column width
    /// (compressed because the sizer can allocate a long column less than an
    /// even share), with the sizer's per-row padding and wrapping overhead.
    private static func tableEstimate(
        columns: [TableColumn],
        rows: [[AttributedString]]
    ) -> CGFloat {
        let body = FontMetrics(font: PlatformTypeConverter.bodyFont())
        let columnWidth = MarkdownTextStorageBuilder.defaultEstimationContainerWidth
            / CGFloat(max(columns.count, 1)) * 0.75
        let charsPerLine = columnWidth / body.averageCharWidth
        let headerCells = columns.map { String($0.header.characters) }
        let rowHeights = ([headerCells] + rows.map { row in
            row.map { String($0.characters) }
        }).map { cells -> CGFloat in
            let cellLines = cells.map { wrappedLines($0, charsPerLine: charsPerLine) }
            return (cellLines.max() ?? 1) * body.lineHeight * 1.2 + 12
        }
        return rowHeights.reduce(0, +)
    }

    /// Wrapped line count of `text` when each line holds `charsPerLine`
    /// width units: hard newlines split, each piece wraps by its weighted
    /// length — CJK and fullwidth glyphs count double, since they run about
    /// twice the width of the ASCII sample average.
    private static func wrappedLines(_ text: String, charsPerLine: CGFloat) -> CGFloat {
        guard charsPerLine >= 1 else { return CGFloat(max(1, text.count)) }
        var lines: CGFloat = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            lines += max(1, (CGFloat(weightedLength(of: line)) / charsPerLine).rounded(.up))
        }
        return max(1, lines)
    }

    /// Length with wide (East Asian) scalars counted as two units: CJK
    /// radicals through ideographs, kana and CJK punctuation, Hangul, and
    /// fullwidth forms.
    private static func weightedLength(of line: Substring) -> Int {
        line.unicodeScalars.reduce(0) { count, scalar in
            switch scalar.value {
            case 0x2E80 ... 0x9FFF, 0xAC00 ... 0xD7AF, 0xF900 ... 0xFAFF,
                 0xFF00 ... 0xFF60:
                count + 2
            default:
                count + 1
            }
        }
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
