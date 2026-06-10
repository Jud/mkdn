#if os(macOS)
    import AppKit
    import SwiftUI

    /// Copy button overlay for `CodeBlockBackgroundTextView`.
    ///
    /// Manages the hover-triggered copy button that appears at the top-right
    /// corner of code blocks. On mouse hover, a `CodeBlockCopyButton` overlay
    /// fades in; clicking it copies the raw code content to the system clipboard.
    extension CodeBlockBackgroundTextView {
        // MARK: - Mouse → Copy Button

        func updateCopyButtonForMouse(at point: CGPoint) {
            refreshCachedBlockRects()
            for entry in cachedBlockRects where entry.rect.contains(point) {
                if hoveredBlockID != entry.blockID {
                    showCopyButton(for: entry)
                }
                return
            }
            hideCopyButton()
        }

        // MARK: - Show / Hide

        private func showCopyButton(for entry: CodeBlockGeometry) {
            hoveredBlockID = entry.blockID

            let buttonX = entry.rect.maxX - Self.copyButtonSize - Self.copyButtonInset
            let buttonY = entry.rect.minY + Self.copyButtonInset
            let buttonFrame = CGRect(
                x: buttonX,
                y: buttonY,
                width: Self.copyButtonSize,
                height: Self.copyButtonSize
            )

            if let existing = copyButtonOverlay {
                existing.frame = buttonFrame
                if let hostingView = existing as? NSHostingView<CodeBlockCopyButton> {
                    hostingView.rootView = makeCopyButtonView(
                        colorInfo: entry.colorInfo,
                        range: entry.range
                    )
                }
            } else {
                let hostingView = NSHostingView(
                    rootView: makeCopyButtonView(
                        colorInfo: entry.colorInfo,
                        range: entry.range
                    )
                )
                hostingView.frame = buttonFrame
                addSubview(hostingView)
                copyButtonOverlay = hostingView
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.copyButtonOverlay?.animator().alphaValue = 1.0
            }
        }

        func hideCopyButton() {
            guard hoveredBlockID != nil else { return }
            hoveredBlockID = nil
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.copyButtonOverlay?.animator().alphaValue = 0.0
            }
        }

        // MARK: - Copy Button View Factory

        private func makeCopyButtonView(
            colorInfo: CodeBlockColorInfo,
            range: NSRange
        ) -> CodeBlockCopyButton {
            CodeBlockCopyButton(codeBlockColors: colorInfo) { [weak self] in
                self?.copyCodeBlock(at: range)
            }
        }

        private func copyCodeBlock(at range: NSRange) {
            guard let textStorage,
                  range.location + range.length <= textStorage.length,
                  let rawCode = textStorage.attribute(
                      CodeBlockAttributes.rawCode,
                      at: range.location,
                      effectiveRange: nil
                  ) as? String
            else { return }

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(rawCode, forType: .string)
        }

        // MARK: - Block Rect Cache

        func refreshCachedBlockRects() {
            // The cache is viewport-scoped, so it's keyed by the scroll origin
            // as well as content validity: a scroll brings new blocks into view.
            let scrollOrigin = enclosingScrollView?.contentView.bounds.origin ?? .zero
            if areBlockRectsValid, scrollOrigin == cachedBlockRectsOrigin { return }
            guard let textStorage,
                  let layoutManager = textLayoutManager,
                  let contentManager = layoutManager.textContentManager
            else {
                cachedBlockRects = []
                areBlockRectsValid = true
                return
            }

            // Bail without validating while the view is unsized so the first
            // real sizing pass recomputes.
            guard bounds.width > 0,
                  let textContainer,
                  textContainer.size.width > 0
            else {
                cachedBlockRects = []
                areBlockRectsValid = false
                return
            }

            let blocks = collectCodeBlocks(from: textStorage)
            guard !blocks.isEmpty else {
                cachedBlockRects = []
                areBlockRectsValid = true
                cachedBlockRectsOrigin = scrollOrigin
                return
            }

            // Only blocks intersecting the viewport get rects. The contiguous
            // container lays out everything from the document start through
            // the viewport, so their fragment frames are already final — while
            // a block past the viewport's end would force the document tail to
            // lay out just to compute a rect that can't be drawn (outside every
            // dirty rect) or hovered. Off-viewport blocks get their rects when
            // a scroll brings them in (the origin key above).
            var viewportCharRange = NSRange(location: 0, length: textStorage.length)
            if let viewportRange = layoutManager.textViewportLayoutController.viewportRange {
                let start = contentManager.offset(
                    from: contentManager.documentRange.location, to: viewportRange.location
                )
                let end = contentManager.offset(
                    from: contentManager.documentRange.location, to: viewportRange.endLocation
                )
                viewportCharRange = NSRange(location: start, length: max(end - start, 0))
            }

            let origin = textContainerOrigin
            let containerWidth = textContainer.size.width
            let borderInset = Self.borderWidth / 2

            cachedBlockRects = blocks.compactMap { block in
                guard NSIntersectionRange(block.range, viewportCharRange).length > 0
                    || NSLocationInRange(viewportCharRange.location, block.range)
                else { return nil }
                let frames = fragmentFrames(
                    for: block.range,
                    layoutManager: layoutManager,
                    contentManager: contentManager
                )
                guard !frames.isEmpty else { return nil }

                let bounding = frames.reduce(frames[0]) { $0.union($1) }
                let drawRect = CGRect(
                    x: origin.x + borderInset,
                    y: bounding.minY + origin.y,
                    width: containerWidth - 2 * borderInset,
                    height: bounding.height + Self.bottomPadding
                )
                return CodeBlockGeometry(
                    blockID: block.blockID,
                    rect: drawRect,
                    range: block.range,
                    colorInfo: block.colorInfo
                )
            }
            areBlockRectsValid = true
            cachedBlockRectsOrigin = scrollOrigin
        }
    }
#endif
