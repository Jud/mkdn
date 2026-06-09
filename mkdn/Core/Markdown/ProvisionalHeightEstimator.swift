#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Cheap whole-document height floor computed from the parsed blocks alone —
/// no Core Text over the content (one-line sample measurements derive the
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

    /// Table placeholders are sized with the unscaled body font (see
    /// `tableEstimate`), so their metrics are a process-wide constant.
    private static let tableBodyMetrics = FontMetrics(
        font: PlatformTypeConverter.bodyFont()
    )

    public static func provisionalHeight(
        of blocks: [IndexedBlock],
        textWidth: CGFloat,
        scaleFactor: CGFloat,
        verticalInset: CGFloat
    ) -> CGFloat {
        guard !blocks.isEmpty, textWidth > 0 else { return 0 }
        var context = Context(scaleFactor: scaleFactor)
        let total = blocks.reduce(0) { sum, indexed in
            sum + context.estimate(indexed.block, textWidth: textWidth)
        }
        return ceil(total * Self.bias) + verticalInset * 2
    }

    // MARK: - Per-Block Estimate

    /// The loop-invariant font metrics, with heading metrics cached per
    /// level.
    @MainActor
    private struct Context {
        let scaleFactor: CGFloat
        let body: FontMetrics
        let mono: FontMetrics
        private var headingMetrics = [FontMetrics?](repeating: nil, count: 6)

        init(scaleFactor: CGFloat) {
            self.scaleFactor = scaleFactor
            body = FontMetrics(
                font: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor)
            )
            mono = FontMetrics(
                font: PlatformTypeConverter.monospacedFont(scaleFactor: scaleFactor)
            )
        }

        private mutating func headingMetrics(level: Int) -> FontMetrics {
            let slot = min(max(level, 1), 6) - 1
            if let cached = headingMetrics[slot] { return cached }
            let metrics = FontMetrics(
                font: PlatformTypeConverter.headingFont(level: level, scaleFactor: scaleFactor)
            )
            headingMetrics[slot] = metrics
            return metrics
        }

        private mutating func sum(_ blocks: [MarkdownBlock], textWidth: CGFloat) -> CGFloat {
            blocks.reduce(0) { sum, block in
                sum + estimate(block, textWidth: max(textWidth, 1))
            }
        }

        // Spacing constants (blockSpacing, margins, padding, indents) are
        // used unscaled, matching the builder's paragraph styles — only
        // fonts zoom.
        mutating func estimate(_ block: MarkdownBlock, textWidth: CGFloat) -> CGFloat {
            let spacing = MarkdownTextStorageBuilder.blockSpacing
            switch block {
            case let .heading(level, text):
                let metrics = headingMetrics(level: level)
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
                return sum(
                    blocks, textWidth: textWidth - MarkdownTextStorageBuilder.blockquoteIndent
                )
            case let .orderedList(items), let .unorderedList(items):
                let indented = textWidth - MarkdownTextStorageBuilder.listPrefixWidth
                return items.reduce(0) { sum, item in
                    sum + self.sum(item.blocks, textWidth: indented)
                        + MarkdownTextStorageBuilder.listItemSpacing
                }
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
        let body = tableBodyMetrics
        let columnWidth = MarkdownTextStorageBuilder.defaultEstimationContainerWidth
            / CGFloat(max(columns.count, 1)) * 0.75
        let charsPerLine = columnWidth / body.averageCharWidth
        return ([columns.map(\.header)] + rows).reduce(0) { sum, cells in
            let maxLines = cells.reduce(CGFloat(1)) { maxSoFar, cell in
                max(maxSoFar, wrappedLines(String(cell.characters), charsPerLine: charsPerLine))
            }
            return sum + maxLines * body.lineHeight * TableColumnSizer.wrappingOverhead
                + TableColumnSizer.verticalCellPadding * 2
        }
    }

    /// Wrapped line count of `text` when each line holds `charsPerLine`
    /// width units: hard newlines split, each piece wraps by its weighted
    /// length — CJK and fullwidth glyphs count double,
    /// since they run about twice the width of the ASCII sample average.
    private static func wrappedLines(_ text: String, charsPerLine: CGFloat) -> CGFloat {
        guard charsPerLine >= 1 else { return CGFloat(max(1, text.count)) }
        var lines: CGFloat = 0
        var lineWeight = 0
        for scalar in text.unicodeScalars {
            if scalar == "\n" {
                lines += max(1, (CGFloat(lineWeight) / charsPerLine).rounded(.up))
                lineWeight = 0
            } else {
                switch scalar.value {
                case 0x2E80 ... 0x9FFF, 0xAC00 ... 0xD7AF, 0xF900 ... 0xFAFF,
                     0xFF00 ... 0xFF60:
                    lineWeight += 2
                default:
                    lineWeight += 1
                }
            }
        }
        lines += max(1, (CGFloat(lineWeight) / charsPerLine).rounded(.up))
        return lines
    }

    /// Line height and average glyph width for one font, derived from a
    /// single sample-string measurement.
    private struct FontMetrics {
        let lineHeight: CGFloat
        let averageCharWidth: CGFloat

        @MainActor
        init(font: PlatformTypeConverter.PlatformFont) {
            lineHeight = PlatformTypeConverter.lineHeight(of: font)
                + MarkdownTextStorageBuilder.lineSpacing
            let sample = "the quick brown fox jumps over 0123456789"
            let width = NSAttributedString(
                string: sample, attributes: [.font: font]
            ).size().width
            averageCharWidth = max(width / CGFloat(sample.count), 1)
        }
    }
}
