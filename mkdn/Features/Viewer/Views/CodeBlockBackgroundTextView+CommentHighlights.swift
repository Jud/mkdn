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

            // setFill/setStroke mutate global graphics state; bracket the whole
            // draw so the emphasis colors can't leak into a sibling draw pass.
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }

            let origin = textContainerOrigin
            let base = PlatformTypeConverter.color(from: theme.colors.commentHighlight)
            let accent = PlatformTypeConverter.color(from: theme.colors.accent)
            let progress = emphasisProgress

            // Draw the emphasized comment last so a later overlapping base fill can't
            // overpaint its emphasis; with nothing emphasized, skip the reorder (this
            // runs on every viewport draw, including each scroll frame).
            let ordered = emphasisDrawID == nil
                ? Array(resolved.ranges)
                : resolved.ranges.sorted {
                    ($0.key == emphasisDrawID ? 1 : 0) < ($1.key == emphasisDrawID ? 1 : 0)
                }
            for (id, range) in ordered {
                let clipped = NSIntersectionRange(range, visibleRange)
                guard clipped.length > 0,
                      let textRange = textRange(from: clipped, contentManager: contentManager)
                else { continue }

                if id == emphasisDrawID, progress > 0 {
                    // Collect ALL the comment's viewport segments (not just the ones
                    // in dirtyRect) so the outline spans the whole span even on a
                    // partial (scroll-band) redraw; fills are clipped to dirtyRect.
                    var rects: [NSRect] = []
                    layoutManager.enumerateTextSegments(
                        in: textRange, type: .highlight, options: [.rangeNotRequired]
                    ) { _, segmentFrame, _, _ in
                        rects.append(segmentFrame.offsetBy(dx: origin.x, dy: origin.y))
                        return true
                    }
                    drawEmphasizedHighlight(
                        rects, dirtyRect: dirtyRect, base: base, accent: accent, progress: progress
                    )
                } else {
                    base.setFill()
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

        /// Hover emphasis: crossfade a comment's resting fill into a bolder accent
        /// fill + outline. A wrapped span's segments are filled clipped to one
        /// rounded outline so it reads as a single connected highlight rather than a
        /// rounded pill per line; a single-line span is just the tight pill.
        /// Assumes the span's segments are contiguous (true for a comment's
        /// character range) — the outline is their bounding union, not a traced
        /// perimeter.
        private func drawEmphasizedHighlight(
            _ rects: [NSRect], dirtyRect: NSRect, base: NSColor, accent: NSColor, progress: CGFloat
        ) {
            // alphaComponent traps on a color with no direct alpha (catalog/named);
            // normalize to sRGB first so a future themed color can't crash the draw.
            guard let first = rects.first else { return }
            let baseAlpha = base.usingColorSpace(.sRGB)?.alphaComponent ?? 1
            let union = rects.dropFirst().reduce(first) { $0.union($1) }
            let outline = NSBezierPath(
                roundedRect: union,
                xRadius: DesignTokens.Radius.inline,
                yRadius: DesignTokens.Radius.inline
            )
            let visible = rects.filter { $0.intersects(dirtyRect) }

            NSGraphicsContext.saveGraphicsState()
            outline.addClip()
            base.withAlphaComponent(baseAlpha * (1 - progress)).setFill()
            visible.forEach { $0.fill() }
            accent.withAlphaComponent(DesignTokens.Tint.active * progress).setFill()
            visible.forEach { $0.fill() }
            NSGraphicsContext.restoreGraphicsState()

            accent.withAlphaComponent(0.9 * progress).setStroke()
            outline.lineWidth = 1.5
            outline.stroke()
        }
    }
#endif
