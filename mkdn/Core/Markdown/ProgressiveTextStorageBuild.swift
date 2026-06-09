#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// A chunked `MarkdownTextStorageBuilder` run: the same output as
/// ``MarkdownTextStorageBuilder/build(blocks:colors:syntaxColors:scaleFactor:isPrint:appSettings:)``,
/// produced block-at-a-time so the open path can build and install a
/// first-viewport prefix, paint, then append the tail in main-actor slices
/// (the viewport-first plan's progressive open).
///
/// Heading offsets, block spans, and attachment block indices are recorded in
/// final-document coordinates as chunks build, so ``partialResult()`` is a
/// valid `TextStorageResult` for the blocks built so far and ``result()``
/// after the last chunk matches a one-shot build — `build` itself runs one
/// session to completion.
@MainActor
public final class ProgressiveTextStorageBuild {
    private let blocks: [IndexedBlock]
    private let colors: ThemeColors
    private let syntaxColors: SyntaxColors
    private let scaleFactor: CGFloat
    private let isPrint: Bool
    private let appSettings: AppSettings?

    /// Everything built so far; each chunk's fragment is appended here.
    private let accumulated = NSMutableAttributedString()
    private var attachments: [AttachmentInfo] = []
    private var headingOffsets: [Int: Int] = [:]
    private var blockSpans: [BlockSpan] = []
    /// Array position of the next block to build.
    private var cursor = 0

    public var isComplete: Bool { cursor == blocks.count }

    public init(
        blocks: [IndexedBlock],
        colors: ThemeColors,
        syntaxColors: SyntaxColors,
        scaleFactor: CGFloat = 1.0,
        isPrint: Bool = false,
        appSettings: AppSettings? = nil
    ) {
        self.blocks = blocks
        self.colors = colors
        self.syntaxColors = syntaxColors
        self.scaleFactor = scaleFactor
        self.isPrint = isPrint
        self.appSettings = appSettings
    }

    public convenience init(
        blocks: [IndexedBlock],
        theme: AppTheme,
        scaleFactor: CGFloat = 1.0,
        isPrint: Bool = false,
        appSettings: AppSettings? = nil
    ) {
        self.init(
            blocks: blocks,
            colors: theme.colors,
            syntaxColors: theme.syntaxColors,
            scaleFactor: scaleFactor,
            isPrint: isPrint,
            appSettings: appSettings
        )
    }

    /// Build the next chunk — up to `maxBlocks` blocks, stopping early once
    /// `deadline` passes (checked between blocks, so a chunk always makes
    /// progress: at least one block whenever any remain). Returns the chunk's
    /// fragment for appending to a live text storage, or nil when the
    /// document is already complete.
    public func buildNext(
        maxBlocks: Int = .max, deadline: ContinuousClock.Instant? = nil
    ) -> NSAttributedString? {
        guard cursor < blocks.count else { return nil }
        // Clamp so a computed budget that rounds to 0 (or negative) can't
        // return an empty fragment without progress and livelock the caller.
        let maxBlocks = max(1, maxBlocks)
        let fragment = NSMutableAttributedString()
        var built = 0
        while cursor < blocks.count, built < maxBlocks {
            let indexedBlock = blocks[cursor]
            let documentOffset = accumulated.length + fragment.length
            if case .heading = indexedBlock.block {
                headingOffsets[indexedBlock.index] = documentOffset
            }
            MarkdownTextStorageBuilder.appendBlock(
                indexedBlock,
                to: fragment,
                colors: colors,
                syntaxColors: syntaxColors,
                scaleFactor: scaleFactor,
                attachments: &attachments,
                isPrint: isPrint,
                appSettings: appSettings
            )
            blockSpans.append(BlockSpan(
                index: indexedBlock.index,
                range: NSRange(
                    location: documentOffset,
                    length: accumulated.length + fragment.length - documentOffset
                ),
                kind: indexedBlock.block.blockKind
            ))
            // Collapse the first block's top spacing so textContainerInset
            // alone controls the window-top-to-text distance.
            if cursor == 0, fragment.length > 0 {
                collapseFirstBlockTopSpacing(of: fragment)
            }
            cursor += 1
            built += 1
            if let deadline, ContinuousClock.now >= deadline { break }
        }
        accumulated.append(fragment)
        return fragment
    }

    /// Build everything that remains in one pass.
    public func buildRemaining() {
        _ = buildNext()
    }

    /// Result over the blocks built so far. The string is copied so later
    /// chunks can't grow it under the caller.
    public func partialResult() -> TextStorageResult {
        makeResult(with: NSAttributedString(attributedString: accumulated))
    }

    /// The full result, identical to a one-shot build of the same blocks.
    public func result() -> TextStorageResult {
        precondition(isComplete, "result() before the last chunk; use partialResult()")
        return makeResult(with: accumulated)
    }

    private func makeResult(with string: NSAttributedString) -> TextStorageResult {
        TextStorageResult(
            attributedString: string,
            attachments: attachments,
            headingOffsets: headingOffsets,
            documentHeightModel: DocumentHeightModel(blocks: blockSpans),
            sourceMap: SourceMap(attributedString: string)
        )
    }

    private func collapseFirstBlockTopSpacing(of fragment: NSMutableAttributedString) {
        let firstParaRange = (fragment.string as NSString) // swiftlint:disable:this legacy_objc_type
            .paragraphRange(for: NSRange(location: 0, length: 0))
        guard let style = fragment.attribute(
            .paragraphStyle, at: 0, effectiveRange: nil
        ) as? NSParagraphStyle else { return }
        // swiftlint:disable:next force_cast
        let mutable = style.mutableCopy() as! NSMutableParagraphStyle
        mutable.paragraphSpacingBefore = 0
        fragment.addAttribute(.paragraphStyle, value: mutable, range: firstParaRange)
    }
}
