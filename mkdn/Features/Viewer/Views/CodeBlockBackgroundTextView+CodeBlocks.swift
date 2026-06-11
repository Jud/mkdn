#if os(macOS)
    import AppKit

    /// Code block background drawing for `CodeBlockBackgroundTextView`.
    ///
    /// Enumerates `.codeBlockRange` attributes in the text storage, computes
    /// bounding rectangles from TextKit 2 layout fragment frames, and draws
    /// filled-and-stroked rounded rectangles behind the code text.
    extension CodeBlockBackgroundTextView {
        // MARK: - Code Block Container Drawing

        func drawCodeBlockContainers(in dirtyRect: NSRect) {
            for entry in cachedBlockRects where entry.rect.intersects(dirtyRect) {
                drawRoundedContainer(
                    in: entry.rect,
                    colorInfo: entry.colorInfo
                )
            }
        }

        // MARK: - Rounded Container

        private func drawRoundedContainer(
            in rect: NSRect,
            colorInfo: CodeBlockColorInfo
        ) {
            let path = NSBezierPath(
                roundedRect: rect,
                xRadius: Self.cornerRadius,
                yRadius: Self.cornerRadius
            )

            colorInfo.background.setFill()
            path.fill()
        }

        // MARK: - Blockquote Bars

        /// Draw a vertical bar per nesting level beside blockquote text.
        ///
        /// Layout-passive like ``drawCommentHighlights(in:)``: clips to the
        /// laid-out viewport range before asking for segment geometry, so
        /// offscreen quotes cost nothing.
        func drawBlockquoteBars(in dirtyRect: NSRect) {
            guard let storage = textStorage,
                  let layoutManager = textLayoutManager,
                  let contentManager = layoutManager.textContentManager
            else { return }
            // On screen, clip to the laid-out viewport (layout-passive). Print
            // draws page rects, not the screen viewport, so enumerate the whole
            // document there — pagination has already forced full layout, and
            // the per-bar dirtyRect check bounds the fills to the page. Gate on
            // the print operation, not isDrawingToScreen: layer-backed draws
            // also report non-screen and must stay viewport-clipped.
            let drawRange = NSPrintOperation.current != nil
                ? NSRange(location: 0, length: storage.length)
                : visibleCharacterRange()
            guard let visibleRange = drawRange else { return }

            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }

            let origin = textContainerOrigin
            let indent = MarkdownTextStorageBuilder.blockquoteIndent
            let barWidth = MarkdownTextStorageBuilder.blockquoteBarWidth
            // Glyphs start at lineFragmentPadding, not the container edge; anchor
            // the bar there so it aligns with the body-text column rather than
            // hanging into the margin.
            let textEdge = origin.x + (textContainer?.lineFragmentPadding ?? 0)

            storage.enumerateAttribute(
                BlockquoteAttributes.bar, in: visibleRange, options: []
            ) { value, range, _ in
                guard let info = value as? BlockquoteBarInfo,
                      let textRange = textRange(from: range, contentManager: contentManager)
                else { return }

                // .highlight segments hug the text's line boxes (same geometry as
                // the comment pills); .standard fragments would include paragraph
                // spacing, overshooting the quote's last line.
                var union: NSRect?
                layoutManager.enumerateTextSegments(
                    in: textRange, type: .highlight, options: [.rangeNotRequired]
                ) { _, segmentFrame, _, _ in
                    let rect = segmentFrame.offsetBy(dx: origin.x, dy: origin.y)
                    union = union.map { $0.union(rect) } ?? rect
                    return true
                }
                guard let bounds = union else { return }

                info.color.withAlphaComponent(DesignTokens.Stroke.resting).setFill()
                for level in 0 ... info.depth {
                    let bar = NSRect(
                        x: textEdge + CGFloat(level) * indent,
                        y: bounds.minY,
                        width: barWidth,
                        height: bounds.height
                    )
                    if bar.intersects(dirtyRect) { bar.fill() }
                }
            }
        }

        // MARK: - Block Collection

        func collectCodeBlocks(
            from textStorage: NSTextStorage
        ) -> [CodeBlockInfo] {
            if isCodeBlockCacheValid {
                return cachedCodeBlocks
            }

            var grouped: [String: (range: NSRange, colorInfo: CodeBlockColorInfo)] = [:]
            let fullRange = NSRange(location: 0, length: textStorage.length)

            textStorage.enumerateAttribute(
                CodeBlockAttributes.range,
                in: fullRange,
                options: []
            ) { value, range, _ in
                guard let blockID = value as? String else { return }
                if var existing = grouped[blockID] {
                    existing.range = NSUnionRange(existing.range, range)
                    grouped[blockID] = existing
                } else if let colorInfo = textStorage.attribute(
                    CodeBlockAttributes.colors,
                    at: range.location,
                    effectiveRange: nil
                ) as? CodeBlockColorInfo {
                    grouped[blockID] = (range: range, colorInfo: colorInfo)
                }
            }

            cachedCodeBlocks = grouped.map { blockID, entry in
                CodeBlockInfo(blockID: blockID, range: entry.range, colorInfo: entry.colorInfo)
            }
            isCodeBlockCacheValid = true
            return cachedCodeBlocks
        }

        // MARK: - Layout Fragment Geometry

        func fragmentFrames(
            for nsRange: NSRange,
            layoutManager: NSTextLayoutManager,
            contentManager: NSTextContentManager
        ) -> [CGRect] {
            guard let textRange = textRange(
                from: nsRange,
                contentManager: contentManager
            )
            else { return [] }

            var frames: [CGRect] = []
            let endLocation = textRange.endLocation

            layoutManager.enumerateTextLayoutFragments(
                from: textRange.location,
                options: [.ensuresLayout]
            ) { fragment in
                let fragmentStart = fragment.rangeInElement.location
                if fragmentStart.compare(endLocation) != .orderedAscending {
                    return false
                }
                frames.append(fragment.layoutFragmentFrame)
                return true
            }

            return frames
        }

        func textRange(
            from nsRange: NSRange,
            contentManager: NSTextContentManager
        ) -> NSTextRange? {
            guard nsRange.length > 0 else { return nil }

            guard let startLocation = contentManager.location(
                contentManager.documentRange.location,
                offsetBy: nsRange.location
            )
            else { return nil }

            guard let endLocation = contentManager.location(
                startLocation,
                offsetBy: nsRange.length
            )
            else { return nil }

            return NSTextRange(location: startLocation, end: endLocation)
        }
    }
#endif
