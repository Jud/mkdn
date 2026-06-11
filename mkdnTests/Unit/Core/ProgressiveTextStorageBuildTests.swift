import AppKit
import Testing
@testable import mkdnLib

@Suite("ProgressiveTextStorageBuild")
struct ProgressiveTextStorageBuildTests {
    let theme: AppTheme = .solarizedDark

    /// Covers every block kind the builder dispatches on, including the
    /// attachment-backed ones (image, mermaid, math, table, thematic break),
    /// nested lists, and inline styling, so chunk boundaries can land next
    /// to any of them.
    private let markdown = """
    # Title

    A paragraph with **bold**, `inline code`, a [link](https://example.com),
    and ~~strikethrough~~ text that wraps across lines.

    ## Section one

    ```swift
    func measure(_ width: CGFloat) -> CGFloat {
        width * 2
    }
    ```

    - first item
    - second item
      - nested item
    - [ ] task item

    1. ordered one
    2. ordered two

    > A blockquote with a nested list:
    > - quoted item

    | Column | Value |
    | --- | --- |
    | a | 1 |
    | b | 2 |

    ![alt text](missing.png)

    ```mermaid
    graph TD; A-->B;
    ```

    $$
    e^{i\\pi} + 1 = 0
    $$

    Inline math $x^2$ inside prose.

    ---

    ### Last section

    Final paragraph.
    """

    @MainActor
    private func renderBlocks() -> [IndexedBlock] {
        MarkdownRenderer.render(text: markdown, theme: theme)
    }

    // MARK: - Equivalence Helpers

    private func attributeRuns(
        of string: NSAttributedString
    ) -> [(NSRange, [NSAttributedString.Key: Any])] {
        var runs: [(NSRange, [NSAttributedString.Key: Any])] = []
        string.enumerateAttributes(
            in: NSRange(location: 0, length: string.length), options: []
        ) { attrs, range, _ in
            runs.append((range, attrs))
        }
        return runs
    }

    /// Attributed equality that compares attachments by their placeholder
    /// bounds instead of identity: two independent builds create distinct
    /// `NSTextAttachment` instances, so `isEqual(to:)` would always fail on
    /// attachment runs.
    private func expectEquivalent(
        _ built: NSAttributedString,
        _ reference: NSAttributedString,
        _ label: Comment
    ) throws {
        try #require(built.string == reference.string, label)

        let runs = attributeRuns(of: built)
        let referenceRuns = attributeRuns(of: reference)
        try #require(runs.count == referenceRuns.count, label)

        for ((range, attrs), (refRange, refAttrs)) in zip(runs, referenceRuns) {
            #expect(range == refRange, label)
            #expect(Set(attrs.keys) == Set(refAttrs.keys), label)
            for (key, value) in attrs {
                guard let refValue = refAttrs[key] else { continue }
                switch key {
                case .attachment:
                    let bounds = (value as? NSTextAttachment)?.bounds
                    let refBounds = (refValue as? NSTextAttachment)?.bounds
                    #expect(bounds == refBounds, label)
                case CodeBlockAttributes.range:
                    // The value is a per-build unique block id; presence at
                    // matching ranges is the equivalence.
                    #expect(value is String && refValue is String, label)
                case CodeBlockAttributes.colors:
                    let colors = value as? CodeBlockColorInfo
                    let refColors = refValue as? CodeBlockColorInfo
                    #expect(colors?.background == refColors?.background, label)
                case BlockquoteAttributes.bar:
                    // Per-build instances with identity equality (so separate
                    // quotes don't coalesce); compare the resolved values.
                    let bar = value as? BlockquoteBarInfo
                    let refBar = refValue as? BlockquoteBarInfo
                    #expect(bar?.color == refBar?.color, label)
                    #expect(bar?.depth == refBar?.depth, label)
                default:
                    #expect(
                        (value as AnyObject).isEqual(refValue as AnyObject), label
                    )
                }
            }
        }
    }

    private func expectSameMetadata(
        _ built: TextStorageResult,
        _ reference: TextStorageResult,
        _ label: Comment
    ) {
        #expect(built.headingOffsets == reference.headingOffsets, label)

        let spans = built.documentHeightModel.blocks
        let referenceSpans = reference.documentHeightModel.blocks
        #expect(spans.count == referenceSpans.count, label)
        for (span, refSpan) in zip(spans, referenceSpans) {
            #expect(span.index == refSpan.index, label)
            #expect(span.range == refSpan.range, label)
            #expect(span.kind == refSpan.kind, label)
        }

        #expect(built.attachments.count == reference.attachments.count, label)
        for (info, refInfo) in zip(built.attachments, reference.attachments) {
            #expect(info.blockIndex == refInfo.blockIndex, label)
            #expect(info.block.blockKind == refInfo.block.blockKind, label)
            #expect(info.attachment.bounds == refInfo.attachment.bounds, label)
        }
    }

    // MARK: - Tests

    @Test("Chunked builds match the one-shot build for any chunk size")
    @MainActor func chunkedMatchesOneShot() throws {
        let blocks = renderBlocks()
        let reference = MarkdownTextStorageBuilder.build(blocks: blocks, theme: theme)
        #expect(blocks.count > 10)

        for chunkSize in [1, 2, 5, blocks.count] {
            let session = ProgressiveTextStorageBuild(blocks: blocks, theme: theme)
            let installed = NSMutableAttributedString()
            while let fragment = session.buildNext(maxBlocks: chunkSize) {
                installed.append(fragment)
            }
            #expect(session.isComplete)

            let result = session.result()
            let label: Comment = "chunk size \(chunkSize)"
            try expectEquivalent(result.attributedString, reference.attributedString, label)
            // The fragments appended chunk-wise must reassemble the same
            // document the session reports — the live text storage receives
            // only the fragments.
            try expectEquivalent(installed, reference.attributedString, label)
            expectSameMetadata(result, reference, label)
        }
    }

    @Test("A passed deadline still makes progress, one block per chunk")
    @MainActor func deadlineMakesProgress() {
        let blocks = renderBlocks()
        let session = ProgressiveTextStorageBuild(blocks: blocks, theme: theme)
        var chunks = 0
        while session.buildNext(deadline: .now) != nil {
            chunks += 1
        }
        #expect(chunks == blocks.count)
        #expect(session.isComplete)
    }

    @Test("partialResult covers exactly the blocks built so far")
    @MainActor func partialResultIsPrefix() throws {
        let blocks = renderBlocks()
        let reference = MarkdownTextStorageBuilder.build(blocks: blocks, theme: theme)
        let session = ProgressiveTextStorageBuild(blocks: blocks, theme: theme)
        let prefixBlocks = 4
        _ = session.buildNext(maxBlocks: prefixBlocks)
        #expect(!session.isComplete)

        let partial = session.partialResult()
        let prefix = reference.attributedString.attributedSubstring(
            from: NSRange(location: 0, length: partial.attributedString.length)
        )
        try expectEquivalent(partial.attributedString, prefix, "prefix")
        #expect(partial.documentHeightModel.blocks.count == prefixBlocks)

        // The partial string must be a snapshot: building the tail can't
        // grow it under the caller.
        let lengthBefore = partial.attributedString.length
        session.buildRemaining()
        #expect(partial.attributedString.length == lengthBefore)
        #expect(session.isComplete)
        try expectEquivalent(
            session.result().attributedString, reference.attributedString, "after tail"
        )
    }

    @Test("Empty document completes immediately")
    @MainActor func emptyDocument() {
        let session = ProgressiveTextStorageBuild(blocks: [], theme: theme)
        #expect(session.isComplete)
        #expect(session.buildNext() == nil)
        let result = session.result()
        #expect(result.attributedString.length == 0)
        #expect(result.attachments.isEmpty)
    }
}
