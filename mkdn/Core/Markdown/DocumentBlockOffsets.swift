#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Top y of one block in the document.
public struct BlockOffset {
    public let index: Int // source block index
    public let top: CGFloat // top y in text-view coordinates
}

/// Per-block vertical offsets in the markdown preview, computed from the final
/// attributed string without running the renderer's TextKit fragment layout.
/// Block `blocks[i]` spans `[blocks[i].top, blocks[i + 1].top)`; the last block
/// runs to `totalHeight`. Maps a document y to a block and back for
/// scroll-to-anchor, the scrollbar, and a minimap.
///
/// Each top is the running height of the blocks above it, corrected to the real
/// block position (see `compute`), so offsets land on the real TextKit block tops.
/// Each block is measured once, so the pass is `O(total characters)`: computed once
/// and cached, not per frame.
public struct DocumentBlockOffsets {
    public let blocks: [BlockOffset]
    public let totalHeight: CGFloat

    /// Top y of the block with source `index`, or nil if absent.
    public func offset(forBlockIndex index: Int) -> CGFloat? {
        blocks.first { $0.index == index }?.top
    }

    /// Text-view-space top y of the line a character `location` sits on — the block
    /// top plus the height of the block's text above that line. Refines the block-
    /// granular `offset(forBlockIndex:)` to intra-block precision (so two comments in
    /// one paragraph anchor at their own lines), still without TextKit fragment
    /// layout: it's the same Core Text prefix measure `compute` uses, scoped to the
    /// block. `nil` when the location maps to no block.
    @MainActor
    public func characterY(
        at location: Int,
        in attributedString: NSAttributedString,
        model: DocumentHeightModel,
        textWidth: CGFloat
    ) -> CGFloat? {
        guard textWidth > 0,
              let blockIndex = model.blockIndex(containing: location),
              let blockTop = offset(forBlockIndex: blockIndex),
              let block = model.blocks.first(where: { $0.index == blockIndex })
        else { return nil }
        let prefixLength = location - block.range.location
        guard prefixLength > 0, location <= attributedString.length else { return blockTop }
        // Height of the block's text above `location`: the prefix measure counts
        // `location`'s own line when `location` sits mid-line (the partial line
        // re-wraps as a line of its own) but not when it starts one.
        var intra = DocumentHeightEstimator.contentHeight(
            of: attributedString.attributedSubstring(
                from: NSRange(location: block.range.location, length: prefixLength)),
            textWidth: textWidth)
        // A prefix ending at an internal newline (e.g. line 2+ of a code block) carries
        // the same phantom empty line `compute` subtracts at block boundaries — drop it.
        // A newline boundary starts a line, so the corrected measure is the line top.
        if (attributedString.string as NSString).character(at: location - 1) == 0x0A {
            intra -= Self.trailingNewlinePhantom(at: location - 1, in: attributedString)
            return blockTop + intra
        }
        // Wrap-boundary probe. Greedy wrapping breaks a prefix's complete lines
        // exactly as the full layout does, so extending the measure through the
        // whole word at `location` discriminates the two cases: the height grows
        // by a line when the word starts a line (it's the word that didn't fit the
        // line above — the measure was already its top), and holds when it sits
        // mid-line (the measure included its line — subtract that line to land on
        // its top, beside the text the mark points at). The probe must cover the
        // full word: a single character can still fit where the word could not.
        let text = attributedString.string as NSString
        let limit = min(block.range.location + block.range.length, attributedString.length)
        var probeEnd = location
        while probeEnd < limit, !Self.isWhitespace(text.character(at: probeEnd)) {
            probeEnd += 1
        }
        if probeEnd > location {
            let probe = DocumentHeightEstimator.contentHeight(
                of: attributedString.attributedSubstring(
                    from: NSRange(
                        location: block.range.location,
                        length: probeEnd - block.range.location
                    )),
                textWidth: textWidth)
            if probe <= intra + 0.5 {
                let line = DocumentHeightEstimator.contentHeight(
                    of: attributedString.attributedSubstring(
                        from: NSRange(location: location, length: probeEnd - location)),
                    textWidth: textWidth)
                intra = max(intra - line, 0)
            }
        }
        return blockTop + intra
    }

    /// Source index of the block whose span contains `y` (the last block whose top
    /// is at or above `y`), clamped to the document; nil when empty.
    public func blockIndex(atY y: CGFloat) -> Int? {
        guard !blocks.isEmpty else { return nil }
        var low = 0
        var high = blocks.count - 1
        var result = 0
        while low <= high {
            let mid = (low + high) / 2
            if blocks[mid].top <= y {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return blocks[result].index
    }

    @MainActor
    public static func compute(
        of attributedString: NSAttributedString,
        model: DocumentHeightModel,
        textWidth: CGFloat,
        verticalInset: CGFloat
    ) -> DocumentBlockOffsets {
        let measured = OpenTimeline.shared.time("blockOffsets.compute") {
            measure(
                of: attributedString, model: model, textWidth: textWidth,
                verticalInset: verticalInset, buildOffsets: true)
        }
        return DocumentBlockOffsets(blocks: measured.blocks, totalHeight: measured.totalHeight)
    }

    /// The document's estimated height from the per-block sum, without building the
    /// offsets array — the fast path for sizing the scroll view. A whole-document
    /// `boundingRect` is super-linear in string length for some content (font fallback),
    /// so the per-block sum is ~12x cheaper and lands on the same height (see `measure`).
    @MainActor
    public static func estimatedHeight(
        of attributedString: NSAttributedString,
        model: DocumentHeightModel,
        textWidth: CGFloat,
        verticalInset: CGFloat
    ) -> CGFloat {
        OpenTimeline.shared.time("blockOffsets.estimate") {
            measure(
                of: attributedString, model: model, textWidth: textWidth,
                verticalInset: verticalInset, buildOffsets: false).totalHeight
        }
    }

    /// The one per-block pass behind both the offsets and the height-only estimate, so the
    /// seam math can't drift between them. Measures each block once and accumulates its
    /// contiguous-layout contribution; records per-block tops only when `buildOffsets`.
    @MainActor
    private static func measure(
        of attributedString: NSAttributedString,
        model: DocumentHeightModel,
        textWidth: CGFloat,
        verticalInset: CGFloat,
        buildOffsets: Bool
    ) -> (totalHeight: CGFloat, blocks: [BlockOffset]) {
        guard textWidth > 0, !model.blocks.isEmpty, attributedString.length > 0 else {
            return (0, [])
        }
        OpenTimeline.shared.noteBlockOffsetsMeasure()
        let string = attributedString.string as NSString
        var blocks: [BlockOffset] = []
        if buildOffsets { blocks.reserveCapacity(model.blocks.count) }
        // Running height of every block above the current one. Each block is measured
        // once and accumulated (not the whole prefix re-measured per block), so the pass
        // is O(total characters), not O(blocks^2).
        var cumulative: CGFloat = 0
        // The phantom subtracted from the last block that ends in a newline. The whole-
        // document height keeps that final trailing empty line (the loop strips it from
        // every block), so it's added back to the total below.
        var lastTrailingPhantom: CGFloat = 0
        for block in model.blocks {
            let start = block.range.location
            // Defensive: a stale model could describe blocks past the live string; stop
            // before slicing out of bounds. Block ranges are monotonic, so once one
            // overflows the rest do too. Not reachable in normal flow — the model and the
            // text storage are swapped together — but the print path swaps storage alone.
            guard NSMaxRange(block.range) <= attributedString.length else { break }
            // This block's own leading spacing (heading top-margin, code-block top
            // padding) sits above its first glyph. `boundingRect` suppresses it on the
            // first paragraph of a measurement, so it's absent from both the running
            // height and this block's isolated measure below — add it back in both places.
            // Read it only when the block has a character — a zero-length trailing block
            // has start == length.
            let spacingBefore = start < attributedString.length
                ? ((attributedString.attribute(.paragraphStyle, at: start, effectiveRange: nil)
                        as? NSParagraphStyle)?.paragraphSpacingBefore ?? 0)
                : 0
            if buildOffsets {
                blocks.append(
                    BlockOffset(index: block.index, top: verticalInset + cumulative + spacingBefore))
            }
            guard block.range.length > 0 else { continue }
            // Advance the running height by this block's contiguous-layout contribution.
            // Two corrections to the isolated measure: subtract the phantom empty line a
            // terminating newline grows in isolation (absent at the seam to the next block,
            // the same seam the old prefix measure subtracted once), and add back the
            // suppressed leading spacing — so per-block heights telescope to the
            // whole-document height instead of drifting one empty line and one top-margin
            // per block.
            let blockHeight = DocumentHeightEstimator.contentHeight(
                of: attributedString.attributedSubstring(from: block.range), textWidth: textWidth)
            let end = NSMaxRange(block.range)
            let phantom = end <= attributedString.length && string.character(at: end - 1) == 0x0A
                ? trailingNewlinePhantom(at: end - 1, in: attributedString)
                : 0
            cumulative += blockHeight - phantom + spacingBefore
            lastTrailingPhantom = phantom
        }
        // Total from the per-block sum, not a whole-document `boundingRect`. `cumulative`
        // telescopes to the document content height minus its final trailing empty line;
        // add that line back, then ceil + insets (the over-estimate bias).
        let total = ceil(cumulative + lastTrailingPhantom) + verticalInset * 2
        return (total, blocks)
    }

    /// True for the UTF-16 unit of a whitespace or newline scalar (surrogate
    /// halves are not whitespace), bounding the wrap-probe's word scan.
    private static func isWhitespace(_ unit: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(unit) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }

    /// Height of the lone empty line `boundingRect` adds for the newline at
    /// `location`, isolated from paragraph spacing — the seam to subtract from each
    /// prefix measure. Measured from the boundary's own attributes (terminators
    /// carry no font, so this tracks whatever default they resolve to) rather than
    /// assumed constant.
    @MainActor
    private static func trailingNewlinePhantom(
        at location: Int, in attributedString: NSAttributedString
    ) -> CGFloat {
        var attributes = attributedString.attributes(at: location, effectiveRange: nil)
        if let style = (attributes[.paragraphStyle] as? NSParagraphStyle)?
            .mutableCopy() as? NSMutableParagraphStyle {
            // Isolate the phantom empty line itself. Zero trailing paragraphSpacing and
            // lineSpacing: both belong to the real paragraph's separation from its
            // neighbour (already in the block's own measure), not to the phantom line, so
            // leaving them in over-subtracts the seam by `lineSpacing` per block. KEEP
            // paragraphSpacingBefore: boundingRect applies it to the phantom line, so it is
            // part of the seam — a heading terminator's 24pt top-margin would otherwise be
            // under-subtracted.
            style.paragraphSpacing = 0
            style.lineSpacing = 0
            attributes[.paragraphStyle] = style
        }
        let wide = CGFloat.greatestFiniteMagnitude
        let withNewline = DocumentHeightEstimator.contentHeight(
            of: NSAttributedString(string: "x\n", attributes: attributes), textWidth: wide)
        let withoutNewline = DocumentHeightEstimator.contentHeight(
            of: NSAttributedString(string: "x", attributes: attributes), textWidth: wide)
        return withNewline - withoutNewline
    }
}
