#if os(macOS)
    import AppKit
    import SwiftUI

    extension CodeBlockBackgroundTextView {
        /// Show the comment(s) covering a click as a hosted overlay near the span.
        /// Overlapping comments are stacked innermost-first; the whole box pops in.
        func showComments(ids: [String], range: NSRange) {
            guard window != nil,
                  let document = criticDocument,
                  let theme = commentTheme,
                  let rect = boundingRect(forCharacterRange: range)
            else {
                return
            }
            let comments = document.commentsInnermostFirst(among: ids)
                .map { DisplayedComment(id: $0.id, body: $0.body) }
            guard !comments.isEmpty else { return }

            let model = CommentOverlayModel()
            presentCommentOverlay(near: rect, model: model, content: CommentPopoverView(
                model: model,
                comments: comments,
                source: document.rawSource,
                theme: theme,
                documentState: documentState,
                onClose: { [weak self] in self?.dismissCommentOverlay() }
            ))
            openCommentIDs = comments.map(\.id)
        }

        // MARK: - Overlap indicator

        /// A small dot marking each span covered by 2+ overlapping comments, so a
        /// reader can tell there's more than one comment there. Cached as
        /// view-coordinate rects (the `.mkdnCommentID` value is a list whose count
        /// is the overlap depth).
        func refreshCachedCommentOverlapDots() {
            guard let textStorage, !textStorage.string.isEmpty else {
                cachedCommentOverlapDots = []
                return
            }
            var dots: [CGRect] = []
            let diameter = Self.overlapDotDiameter
            textStorage.enumerateAttribute(
                .mkdnCommentID, in: NSRange(location: 0, length: textStorage.length)
            ) { value, range, _ in
                guard let ids = value as? [String], ids.count >= 2,
                      let rect = boundingRect(forCharacterRange: range)
                else {
                    return
                }
                dots.append(CGRect(
                    x: rect.maxX - diameter, y: rect.minY + 1, width: diameter, height: diameter
                ))
            }
            cachedCommentOverlapDots = dots
        }

        func drawCommentOverlapIndicators(in dirtyRect: NSRect) {
            guard let theme = commentTheme, !cachedCommentOverlapDots.isEmpty else { return }
            PlatformTypeConverter.color(from: theme.colors.accent).setFill()
            for dot in cachedCommentOverlapDots where dot.intersects(dirtyRect) {
                NSBezierPath(ovalIn: dot).fill()
            }
        }

        // MARK: - Authoring

        /// The raw-source range for the current selection, if it maps to a single
        /// commentable span (reject-first: nil for empty selections or selections
        /// over existing comments/block boundaries).
        func commentableSelectionRange() -> Range<String.Index>? {
            let selection = selectedRange()
            guard selection.length > 0,
                  let document = criticDocument,
                  let sourceMap = commentSourceMap
            else {
                return nil
            }
            return CommentRangeResolver(document: document, sourceMap: sourceMap)
                .rawRange(forBuilderRange: selection)
        }

        /// Present the add-comment input over the current selection. The raw range
        /// is captured now (valid against the rendered document); on submit it's
        /// applied to the live content via DocumentState.
        @objc func addCommentToSelection(_: Any?) {
            guard let rawRange = commentableSelectionRange(),
                  let source = criticDocument?.rawSource,
                  let theme = commentTheme,
                  let documentState,
                  let rect = boundingRect(forCharacterRange: selectedRange())
            else {
                return
            }
            let model = CommentOverlayModel()
            presentCommentOverlay(near: rect, model: model, content: CommentInputView(model: model, theme: theme) { [weak self] body in
                // Keep the overlay (and the typed text) on a rejected wrap.
                if documentState.addComment(in: rawRange, of: source, body: body) {
                    self?.dismissCommentOverlay()
                }
            })
        }

        // MARK: - Overlay presentation

        private func presentCommentOverlay(near rect: CGRect, model: CommentOverlayModel, content: some View) {
            dismissCommentOverlay()
            let host = CommentOverlayHostingView(rootView: content)
            addSubview(host)
            host.layoutSubtreeIfNeeded()
            host.frame = CGRect(origin: overlayOrigin(near: rect, size: host.fittingSize),
                                size: host.fittingSize)
            commentOverlay = host
            commentOverlayModel = model
            installCommentDismissMonitor()
        }

        /// Play the contract animation, then remove the host once it finishes.
        func dismissCommentOverlay() {
            guard let host = commentOverlay else { return }
            if let monitor = commentDismissMonitor {
                NSEvent.removeMonitor(monitor)
                commentDismissMonitor = nil
            }
            openCommentIDs = []
            commentOverlayModel?.presented = false // animate out
            commentOverlayModel = nil
            commentOverlay = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + CommentBoxMetrics.exitDuration) { [weak host] in
                host?.removeFromSuperview()
            }
        }

        /// Place the box just below the comment (flipping above when it would fall
        /// past the visible area), clamped horizontally. `host.fittingSize` includes
        /// the `commentBox` shadow padding, so the visible box is inset within it.
        private func overlayOrigin(near rect: CGRect, size: CGSize) -> CGPoint {
            let inset = CommentBoxMetrics.shadowPadding
            let gap: CGFloat = 4
            let visible = enclosingScrollView?.documentVisibleRect ?? bounds

            let boxWidth = size.width - 2 * inset
            let boxHeight = size.height - 2 * inset
            var boxLeft = rect.midX - boxWidth / 2
            boxLeft = min(max(boxLeft, visible.minX + 8), max(visible.minX + 8, visible.maxX - boxWidth - 8))

            // The text view is flipped (y grows downward), so "below" is +y.
            var boxTop = rect.maxY + gap
            if boxTop + boxHeight > visible.maxY {
                boxTop = rect.minY - gap - boxHeight
            }
            return CGPoint(x: boxLeft - inset, y: boxTop - inset)
        }

        /// Dismiss on Escape, scroll, or a click outside the text view. Clicks
        /// INSIDE the text view (including comment highlights) are left to
        /// `mouseDown`, which owns the open/switch/toggle decision by comparing the
        /// clicked comment to `openCommentIDs` — so the toggle doesn't depend on the
        /// overlay's geometry. Clicks within the visible box (Edit/Delete) pass
        /// through untouched.
        private func installCommentDismissMonitor() {
            commentDismissMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .scrollWheel, .keyDown]
            ) { [weak self] event in
                guard let self, let overlay = self.commentOverlay else { return event }
                if event.type == .keyDown {
                    if event.keyCode == 53 { self.dismissCommentOverlay() } // Escape
                    return event
                }
                // Inside the visible box (not the transparent shadow padding):
                // interact, don't dismiss.
                let box = overlay.bounds.insetBy(
                    dx: CommentBoxMetrics.shadowPadding, dy: CommentBoxMetrics.shadowPadding
                )
                if box.contains(overlay.convert(event.locationInWindow, from: nil)) { return event }
                if event.type == .scrollWheel {
                    self.dismissCommentOverlay()
                    return event
                }
                // A click inside the text view is handled by mouseDown (toggle/
                // switch/close); only a click elsewhere dismisses here.
                if !self.bounds.contains(self.convert(event.locationInWindow, from: nil)) {
                    self.dismissCommentOverlay()
                }
                return event
            }
        }
    }

    /// Hosts a comment overlay but ignores its transparent shadow padding when
    /// hit-testing, so clicks there fall through to the text view (e.g. a click on
    /// the open comment's highlight, which the padding overlaps, reaches mouseDown
    /// to toggle it closed).
    final class CommentOverlayHostingView<Content: View>: NSHostingView<Content> {
        required init(rootView: Content) { super.init(rootView: rootView) }

        @available(*, unavailable)
        @MainActor @objc dynamic required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }

        override func hitTest(_ point: NSPoint) -> NSView? {
            let box = bounds.insetBy(
                dx: CommentBoxMetrics.shadowPadding, dy: CommentBoxMetrics.shadowPadding
            )
            guard box.contains(convert(point, from: superview)) else { return nil }
            return super.hitTest(point)
        }
    }
#endif
