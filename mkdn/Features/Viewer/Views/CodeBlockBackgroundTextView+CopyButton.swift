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
            if areBlockRectsValid { return }
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
                return
            }

            // Enumerating fragments with `.ensuresLayout` only realizes the
            // visible viewport; blocks outside it come back with TextKit 2's
            // *estimated* (fractional, accumulating-error) frame positions, so a
            // code block below the first viewport gets a wrong Y on first paint
            // and stays mispositioned until a scroll forces real layout. Force
            // real layout from the document start through the last code block —
            // every block's Y depends on all preceding layout — so the frames
            // below are final. (Trailing content can't affect a block rect, so
            // there's no need to lay out past the last block.)
            let lastBlockEnd = blocks.map(\.range.upperBound).max() ?? 0
            if let layoutRange = textRange(
                from: NSRange(location: 0, length: lastBlockEnd),
                contentManager: contentManager
            ) {
                layoutManager.ensureLayout(for: layoutRange)
            }

            let origin = textContainerOrigin
            let containerWidth = textContainer.size.width
            let borderInset = Self.borderWidth / 2

            cachedBlockRects = blocks.compactMap { block in
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
        }
    }
#endif
