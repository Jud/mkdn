#if os(macOS)
    import AppKit

    /// Drawn comment highlights for `CodeBlockBackgroundTextView`.
    ///
    /// Comments anchor by content (``ResolvedComments``) and render as a background
    /// fill rather than a baked `.backgroundColor` attribute, so adding or editing a
    /// comment never edits the text storage — and therefore never triggers the
    /// attachment-height settle that shifts the viewport (the comment-save "jump").
    ///
    /// The draw is **layout-passive**: it fills only the part of each comment range
    /// that intersects the already-laid-out viewport, clipping to the viewport range
    /// before asking for segment rects. It never forces layout of offscreen text
    /// (no `ensureLayout`, no `boundingRect(forCharacterRange:)`, no `.ensuresLayout`
    /// enumeration), so a comment far below the fold costs nothing and can't settle
    /// estimated heights.
    extension CodeBlockBackgroundTextView {
        /// The character range currently laid out in the viewport, or nil. Clip to
        /// this before asking for any geometry so comment drawing, badges, and
        /// popover anchoring stay layout-passive (never touch offscreen text).
        func visibleCharacterRange() -> NSRange? {
            guard let layoutManager = textLayoutManager,
                  let contentManager = layoutManager.textContentManager,
                  let viewport = layoutManager.textViewportLayoutController.viewportRange
            else { return nil }
            let docStart = contentManager.documentRange.location
            let lo = contentManager.offset(from: docStart, to: viewport.location)
            let hi = contentManager.offset(from: docStart, to: viewport.endLocation)
            guard hi > lo else { return nil }
            return NSRange(location: lo, length: hi - lo)
        }

        func drawCommentHighlights(in dirtyRect: NSRect) {
            guard let resolved = resolvedComments, !resolved.ranges.isEmpty,
                  let layoutManager = textLayoutManager,
                  let contentManager = layoutManager.textContentManager,
                  let theme = commentTheme,
                  let visibleRange = visibleCharacterRange()
            else { return }

            let origin = textContainerOrigin
            let base = PlatformTypeConverter.color(from: theme.colors.commentHighlight)
            // Hover emphasis is a draw-state change (a brighter fill for the hovered
            // comment), not a storage edit — so locating a comment from its sidebar
            // row never relayouts.
            let emphasis = PlatformTypeConverter.color(from: theme.colors.accent).withAlphaComponent(0.3)

            // Draw the hovered comment last so a later overlapping base fill can't
            // overpaint its emphasis.
            let ordered = resolved.ranges.sorted {
                ($0.key == hoveredCommentID ? 1 : 0) < ($1.key == hoveredCommentID ? 1 : 0)
            }
            for (id, range) in ordered {
                let clipped = NSIntersectionRange(range, visibleRange)
                guard clipped.length > 0,
                      let textRange = textRange(from: clipped, contentManager: contentManager)
                else { continue }
                (id == hoveredCommentID ? emphasis : base).setFill()
                layoutManager.enumerateTextSegments(
                    in: textRange, type: .highlight, options: [.rangeNotRequired]
                ) { _, segmentFrame, _, _ in
                    let rect = segmentFrame.offsetBy(dx: origin.x, dy: origin.y)
                    if rect.intersects(dirtyRect) { rect.fill() }
                    return true
                }
            }
        }
    }
#endif
