#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// A chunked `MarkdownTextStorageBuilder` run: the same output as
/// ``MarkdownTextStorageBuilder/build(blocks:colors:syntaxColors:scaleFactor:isPrint:appSettings:)``,
/// produced block-at-a-time so the open path can build and install a
/// first-viewport prefix, paint, then append the tail in main-actor slices
/// (docs/features/height-estimation/viewport-first-perf-plan.md).
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

    private let accumulated = NSMutableAttributedString()
    private var attachments: [AttachmentInfo] = []
    private var blockSpans: [BlockSpan] = []
    /// Array position of the next block to build.
    private var cursor = 0

    public var isComplete: Bool { cursor == blocks.count }

    /// UTF-16 length of everything built so far. Lets a consumer that holds
    /// an older prefix snapshot (a recreated text view mid-tail) detect and
    /// append the slice it's missing.
    public var builtUTF16Length: Int { accumulated.length }

    /// The built content from `offset` to the current end — the catch-up
    /// slice for a consumer behind the session, without copying the whole
    /// accumulated document the way `partialResult()` does.
    public func builtSlice(from offset: Int) -> NSAttributedString {
        accumulated.attributedSubstring(from: NSRange(
            location: offset, length: accumulated.length - offset
        ))
    }

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
        let fragment = NSMutableAttributedString()
        appendBlocks(
            into: fragment,
            baseOffset: accumulated.length,
            maxBlocks: maxBlocks,
            deadline: deadline
        )
        accumulated.append(fragment)
        return fragment
    }

    /// Build everything that remains in one pass, directly into the
    /// accumulated document — the one-shot path skips the per-chunk
    /// fragment and its whole-document copy.
    public func buildRemaining() {
        appendBlocks(into: accumulated, baseOffset: 0, maxBlocks: .max, deadline: nil)
    }

    private func appendBlocks(
        into target: NSMutableAttributedString,
        baseOffset: Int,
        maxBlocks: Int,
        deadline: ContinuousClock.Instant?
    ) {
        // Clamp so a computed budget that rounds to 0 (or negative) can't
        // produce an empty chunk without progress and livelock the caller.
        let maxBlocks = max(1, maxBlocks)
        var built = 0
        while cursor < blocks.count, built < maxBlocks {
            let indexedBlock = blocks[cursor]
            let documentOffset = baseOffset + target.length
            MarkdownTextStorageBuilder.appendBlock(
                indexedBlock,
                to: target,
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
                    length: baseOffset + target.length - documentOffset
                ),
                kind: indexedBlock.block.blockKind
            ))
            // Collapse the first block's top spacing so textContainerInset
            // alone controls the window-top-to-text distance.
            if cursor == 0 {
                MarkdownTextStorageBuilder.setFirstParagraphSpacing(target, spacingBefore: 0)
            }
            cursor += 1
            built += 1
            if let deadline, ContinuousClock.now >= deadline { break }
        }
    }

    /// Result over the blocks built so far. The string is copied so later
    /// chunks can't grow it under the caller — an O(built-so-far) snapshot
    /// meant for the one prefix install, not for calling per tail chunk.
    public func partialResult() -> TextStorageResult {
        makeResult(with: NSAttributedString(attributedString: accumulated))
    }

    /// The full result, identical to a one-shot build of the same blocks.
    /// The returned string aliases the session's accumulated document (no
    /// copy): safe because a complete session never builds again, and the
    /// `lastAppliedText` identity contract depends on consumers receiving
    /// this same instance.
    public func result() -> TextStorageResult {
        precondition(isComplete, "result() before the last chunk; use partialResult()")
        return makeResult(with: accumulated)
    }

    private func makeResult(with string: NSAttributedString) -> TextStorageResult {
        // Last-writer-wins on a duplicate source index (possible only with
        // hand-built IndexedBlocks) rather than trapping.
        let headingOffsets = Dictionary(
            blockSpans.compactMap { span -> (Int, Int)? in
                guard case .heading = span.kind else { return nil }
                return (span.index, span.range.location)
            }
        ) { _, last in last }
        // The default (empty) source map: nothing reads TextStorageResult's
        // sourceMap — AnchorTape superseded it for comment anchoring — and
        // building it walks every mkdnSourceSpan run in the document.
        return TextStorageResult(
            attributedString: string,
            attachments: attachments,
            headingOffsets: headingOffsets,
            documentHeightModel: DocumentHeightModel(blocks: blockSpans)
        )
    }
}
