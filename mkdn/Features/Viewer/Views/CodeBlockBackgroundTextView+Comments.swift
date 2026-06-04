#if os(macOS)
    import AppKit
    import SwiftUI

    extension CodeBlockBackgroundTextView {
        /// The comments under a view-coordinate point — innermost (smallest span)
        /// first — resolved from the drawn-comment index rather than a baked
        /// attribute. Empty when no comment covers the point.
        func commentHits(at point: CGPoint) -> [(entry: CommentSidecar.Entry, range: NSRange)] {
            guard let index = characterIndex(at: point) else { return [] }
            return resolvedComments?.comments(containing: index) ?? []
        }

        /// Open the given comments, or close them if that same set is already open
        /// (re-click toggle), shared by highlight clicks and badge clicks.
        func toggleComments(_ hits: [(entry: CommentSidecar.Entry, range: NSRange)]) {
            if Set(hits.map(\.entry.id)) == Set(openCommentIDs) {
                dismissCommentOverlay()
            } else {
                showComments(hits)
            }
        }

        /// Toggle a badge cluster's comments by id — resolved from the index, since
        /// no single offset lies inside every overlapping comment.
        func toggleComments(ids: [String]) {
            toggleComments(resolvedComments?.comments(ids: ids) ?? [])
        }

        /// Show the comment(s) covering a click as a hosted overlay near the span.
        /// Overlapping comments are stacked innermost-first; the whole box pops in.
        func showComments(_ hits: [(entry: CommentSidecar.Entry, range: NSRange)]) {
            // Anchor on the smallest hit that's on screen (hits are innermost-first),
            // so a badge whose smallest comment is offscreen doesn't force layout
            // there and mis-place the box.
            let visible = visibleCharacterRange()
            let anchor = hits.first { visible == nil || NSIntersectionRange($0.range, visible!).length > 0 }?.range
            guard window != nil,
                  let theme = commentTheme,
                  let anchor,
                  let rect = boundingRect(forCharacterRange: anchor)
            else {
                return
            }
            let comments = hits.map { DisplayedComment(id: $0.entry.id, body: $0.entry.body) }
            guard !comments.isEmpty else { return }

            let model = CommentOverlayModel()
            presentCommentOverlay(near: rect, model: model, content: CommentPopoverView(
                model: model,
                comments: comments,
                theme: theme,
                documentState: documentState,
                onClose: { [weak self] in self?.dismissCommentOverlay() },
                onEdited: { [weak self] in self?.keepCommentOverlayThroughRebuild = true },
                onHover: { [weak self] id in self?.setHoveredComment(id) },
                onDragChanged: { [weak self] translation in self?.dragCommentOverlay(by: translation) },
                onDragEnded: { [weak self] in self?.endCommentOverlayDrag() }
            ))
            openCommentIDs = comments.map(\.id)
        }

        // MARK: - Overlap indicator

        /// One count badge per cluster of overlapping comments, so a reader can tell
        /// how many are there (clicking shows them stacked). Clusters are merged
        /// from the resolved-range index; only clusters whose anchor character is in
        /// the laid-out viewport get a badge, so an offscreen overlap never forces
        /// layout (no `boundingRect` on unlaid text).
        func refreshCachedCommentOverlapBadges() {
            guard let resolved = resolvedComments, !resolved.ranges.isEmpty,
                  let visibleRange = visibleCharacterRange()
            else {
                cachedCommentOverlapBadges = []
                return
            }
            // Cluster the VISIBLE portions of each comment, so a badge's count
            // reflects the comments actually overlapping on screen and its anchor is
            // always laid out (no offscreen `boundingRect`).
            let visible = resolved.ranges.compactMap { id, range -> (id: String, range: NSRange)? in
                let clipped = NSIntersectionRange(range, visibleRange)
                return clipped.length > 0 ? (id, clipped) : nil
            }
            .sorted { $0.range.location < $1.range.location }

            var clusters: [(range: NSRange, ids: [String])] = []
            for entry in visible {
                if let last = clusters.last, NSMaxRange(last.range) > entry.range.location {
                    clusters[clusters.count - 1].range = NSUnionRange(last.range, entry.range)
                    clusters[clusters.count - 1].ids.append(entry.id)
                } else {
                    clusters.append((entry.range, [entry.id]))
                }
            }
            cachedCommentOverlapBadges = clusters.compactMap { cluster in
                guard cluster.ids.count >= 2,
                      let rect = boundingRect(
                          forCharacterRange: NSRange(location: NSMaxRange(cluster.range) - 1, length: 1)
                      )
                else { return nil }
                let size = max(rect.height * Self.overlapBadgeLineFraction, Self.overlapBadgeMinDiameter)
                let badgeRect = CGRect(
                    x: rect.maxX - size * 0.5, y: rect.minY - size * 0.5, width: size, height: size
                )
                return OverlapBadge(rect: badgeRect, ids: cluster.ids, range: cluster.range)
            }
        }

        /// Keep the badge overlay subview sized to the text view and repainted.
        /// It lives above the text so the highlight can't cover the badges.
        func syncCommentBadgeOverlay() {
            let overlay: CommentBadgeOverlayView
            if let existing = commentBadgeOverlay {
                overlay = existing
            } else {
                overlay = CommentBadgeOverlayView()
                overlay.textView = self
                addSubview(overlay)
                commentBadgeOverlay = overlay
            }
            overlay.frame = bounds
            overlay.needsDisplay = true
        }

        func drawCommentOverlapIndicators(in dirtyRect: NSRect) {
            guard let theme = commentTheme, !cachedCommentOverlapBadges.isEmpty else { return }
            let fill = PlatformTypeConverter.color(from: theme.colors.accent)
            let halo = PlatformTypeConverter.color(from: theme.colors.background)
            for badge in cachedCommentOverlapBadges where badge.rect.insetBy(dx: -2, dy: -2).intersects(dirtyRect) {
                // A halo ring in the box color separates the badge from the
                // highlight so the number stays legible on any background.
                halo.setFill()
                NSBezierPath(ovalIn: badge.rect.insetBy(dx: -1.5, dy: -1.5)).fill()
                fill.setFill()
                NSBezierPath(ovalIn: badge.rect).fill()

                let label = "\(badge.count)" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: badge.rect.height * 0.6, weight: .bold),
                    .foregroundColor: NSColor.white,
                ]
                let labelSize = label.size(withAttributes: attributes)
                label.draw(
                    at: CGPoint(
                        x: badge.rect.midX - labelSize.width / 2,
                        y: badge.rect.midY - labelSize.height / 2
                    ),
                    withAttributes: attributes
                )
            }
        }

        // MARK: - Authoring

        /// The raw-source range for the current selection, if it maps to source
        /// text (nil for an empty selection or one that can't be mapped). A
        /// selection inside or across existing comments is allowed — v3 supports
        /// nesting/overlap, so wrapping it adds another comment.
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
            presentCommentOverlay(near: rect, model: model, focusesEditor: true, content: CommentInputView(
                model: model,
                theme: theme,
                documentState: documentState,
                addComment: { body in documentState.addComment(in: rawRange, of: source, body: body) },
                onClose: { [weak self] in self?.dismissCommentOverlay() },
                onAdded: { [weak self] id in
                    // The box morphs in place to show the new comment; keep it
                    // through the rebuild and mark it open so a re-click toggles.
                    self?.openCommentIDs = [id]
                    self?.keepCommentOverlayThroughRebuild = true
                },
                onEdited: { [weak self] in self?.keepCommentOverlayThroughRebuild = true },
                onHover: { [weak self] id in self?.setHoveredComment(id) },
                onDragChanged: { [weak self] translation in self?.dragCommentOverlay(by: translation) },
                onDragEnded: { [weak self] in self?.endCommentOverlayDrag() }
            ))
        }

        // MARK: - Overlay presentation

        private func presentCommentOverlay(
            near rect: CGRect, model: CommentOverlayModel, focusesEditor: Bool = false, content: some View
        ) {
            dismissCommentOverlay()
            let host = CommentOverlayHostingView(rootView: content)
            // Size to content via Auto Layout so the box grows/shrinks when the
            // row switches between display and edit, anchored at its top-left.
            host.sizingOptions = [.intrinsicContentSize]
            host.translatesAutoresizingMaskIntoConstraints = false
            host.alphaValue = 0 // fade in via the host (see commentOverlayTransition)
            addSubview(host)
            host.layoutSubtreeIfNeeded()
            let origin = overlayOrigin(near: rect, size: host.fittingSize)
            let leading = host.leadingAnchor.constraint(equalTo: leadingAnchor, constant: origin.x)
            let top = host.topAnchor.constraint(equalTo: topAnchor, constant: origin.y)
            NSLayoutConstraint.activate([leading, top])
            commentOverlay = host
            commentOverlayModel = model
            commentOverlayLeading = leading
            commentOverlayTop = top
            installCommentDismissMonitor()

            // Route key input to the box so its editor's @FocusState can take the
            // caret — the reader can type a new comment without clicking first.
            if focusesEditor { window?.makeFirstResponder(host) }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = CommentBoxMetrics.fadeDuration
                host.animator().alphaValue = 1
            }
        }

        // MARK: - Hover-to-locate

        /// Emphasize the hovered comment's span so the reader sees which text the
        /// row they're reading refers to. A draw-state change (``hoveredCommentID``
        /// drives the fill color in ``drawCommentHighlights(in:)``) — no storage
        /// edit, so locating a comment never relayouts.
        func setHoveredComment(_ id: String?) {
            guard id != hoveredCommentID else { return }
            hoveredCommentID = id
            setNeedsDisplay(enclosingScrollView?.documentVisibleRect ?? bounds)
        }

        // MARK: - Dragging

        /// Move the open overlay by a drag translation (from its header), so it can
        /// be pulled off text it covers.
        func dragCommentOverlay(by translation: CGSize) {
            guard let leading = commentOverlayLeading, let top = commentOverlayTop else { return }
            let base = commentOverlayDragBase ?? CGPoint(x: leading.constant, y: top.constant)
            commentOverlayDragBase = base
            // Disable implicit layer animations (otherwise each move tick fades the
            // layer, flashing its backing) and snap to whole pixels (so the 1px
            // border stays crisp).
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            leading.constant = (base.x + translation.width).rounded()
            top.constant = (base.y + translation.height).rounded()
            layoutSubtreeIfNeeded()
            CATransaction.commit()
        }

        func endCommentOverlayDrag() {
            commentOverlayDragBase = nil
        }

        /// Play the contract animation, then remove the host once it finishes.
        func dismissCommentOverlay() {
            guard let host = commentOverlay else { return }
            setHoveredComment(nil) // restore any emphasized highlight
            if let monitor = commentDismissMonitor {
                NSEvent.removeMonitor(monitor)
                commentDismissMonitor = nil
            }
            // A dismissed overlay can't keep itself through a rebuild; clear the
            // one-shot so a later unrelated rebuild doesn't honor a stale request.
            keepCommentOverlayThroughRebuild = false
            openCommentIDs = []
            commentOverlayModel?.presented = false // SwiftUI scale-out
            commentOverlayModel = nil
            commentOverlay = nil
            commentOverlayLeading = nil
            commentOverlayTop = nil
            commentOverlayDragBase = nil
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = CommentBoxMetrics.fadeDuration
                host.animator().alphaValue = 0
            }, completionHandler: {
                // The completion fires on the main thread (AppKit animation), but
                // its closure is nonisolated — assert the main actor to call the
                // @MainActor removeFromSuperview() without hopping.
                MainActor.assumeIsolated { host.removeFromSuperview() }
            })
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

    /// Transparent subview that paints the overlapping-comment count badges above
    /// the text (a `draw(_:)` override is covered by the highlight). Flipped to
    /// match the text view's coordinates, and click-through so it doesn't intercept
    /// comment/text clicks.
    final class CommentBadgeOverlayView: NSView {
        weak var textView: CodeBlockBackgroundTextView?

        override var isFlipped: Bool { true }

        /// Capture clicks only on a badge (so it opens the comments); elsewhere is
        /// click-through to the text.
        override func hitTest(_ point: NSPoint) -> NSView? {
            let local = convert(point, from: superview)
            return badge(at: local) != nil ? self : nil
        }

        override func mouseDown(with event: NSEvent) {
            let local = convert(event.locationInWindow, from: nil)
            if let badge = badge(at: local) {
                textView?.toggleComments(ids: badge.ids)
            }
        }

        private func badge(at point: NSPoint) -> CodeBlockBackgroundTextView.OverlapBadge? {
            textView?.cachedCommentOverlapBadges.first { $0.rect.contains(point) }
        }

        override func draw(_ dirtyRect: NSRect) {
            textView?.drawCommentOverlapIndicators(in: dirtyRect)
        }
    }

    /// Hosts a comment overlay but ignores its transparent shadow padding when
    /// hit-testing, so clicks there fall through to the text view (e.g. a click on
    /// the open comment's highlight, which the padding overlaps, reaches mouseDown
    /// to toggle it closed).
    final class CommentOverlayHostingView<Content: View>: NSHostingView<Content> {
        required init(rootView: Content) {
            super.init(rootView: rootView)
            // A clear, non-opaque layer so the box (and its transparent shadow
            // padding) never composites against black during the alpha fade.
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.isOpaque = false
            layer?.masksToBounds = false
        }

        override var isOpaque: Bool { false }

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
