// swiftlint:disable file_length
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
            let anchor = hits.first { hit in
                guard let visible else { return true }
                return NSIntersectionRange(hit.range, visible).length > 0
            }?.range
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

                let label = "\(badge.count)" as NSString // swiftlint:disable:this legacy_objc_type
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

        /// The current selection if it can be commented: non-empty, mappable to a
        /// normalized tape range, and free of attachments (tables/math/images are
        /// not yet anchorable). nil otherwise. A selection inside or across existing
        /// comments is allowed — overlap adds another comment.
        func commentableSelection() -> NSRange? {
            let selection = selectedRange()
            guard selection.length > 0,
                  let tape = anchorTape,
                  tape.normalizedRange(forBuilder: selection) != nil,
                  !selectionContainsAttachment(selection)
            else {
                return nil
            }
            return selection
        }

        /// Open the box for a comment just added by paste, once the repaint (or
        /// the Find-open full rebuild) has resolved it against the rendered text.
        /// One-shot; a no-op when nothing is pending or the comment didn't resolve.
        func revealPendingComment() {
            guard let id = pendingRevealCommentID else { return }
            pendingRevealCommentID = nil
            let hits = resolvedComments?.comments(ids: [id]) ?? []
            guard let range = hits.first?.range else { return }
            // A harness-driven paste can target a span below the fold; the box
            // only anchors on visible hits, so bring the span on screen first.
            if let visible = visibleCharacterRange(), NSIntersectionRange(range, visible).length == 0 {
                scrollRangeToVisible(range)
                relayoutViewport()
            }
            showComments(hits)
        }

        /// The pasteboard's plain text trimmed of edge whitespace, or nil when it
        /// holds nothing a comment could be made of. Backs the paste-to-comment
        /// overrides in the main class.
        func pasteboardCommentBody() -> String? {
            guard let text = NSPasteboard.general.string(forType: .string) else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        private func selectionContainsAttachment(_ range: NSRange) -> Bool {
            guard let textStorage else { return false }
            var found = false
            textStorage.enumerateAttribute(.attachment, in: range, options: []) { value, _, stop in
                if value != nil { found = true; stop.pointee = true }
            }
            return found
        }

        /// Present the add-comment input over the current selection. The selector
        /// is captured now (against the rendered text); on submit it's stored in
        /// the sidecar via DocumentState — no inline markers.
        @objc func addCommentToSelection(_: Any?) {
            guard let selection = commentableSelection(),
                  let tape = anchorTape,
                  let selector = CommentSelectorCapture.capture(builderRange: selection, in: tape),
                  let theme = commentTheme,
                  let documentState,
                  let rect = boundingRect(forCharacterRange: selection)
            else {
                return
            }
            let model = CommentOverlayModel()
            presentCommentOverlay(near: rect, model: model, focusesEditor: true, content: CommentInputView(
                model: model,
                theme: theme,
                documentState: documentState,
                addComment: { body in documentState.addComment(selector, body: body) },
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
            near rect: CGRect,
            model: CommentOverlayModel,
            focusesEditor: Bool = false, // swiftlint:disable:this function_default_parameter_at_end
            content: some View
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
        /// row they're reading refers to. A draw-state change (no storage edit, so
        /// locating a comment never relayouts) that eases into/out of the highlight
        /// via ``emphasisProgress`` rather than snapping.
        func setHoveredComment(_ id: String?) {
            // Cancel before the no-op guard: a hover over the currently-flashing
            // comment (same id) must still supersede a pending flash-clear, or the
            // timer would later wipe a live hover.
            commentFlashTask?.cancel()
            guard id != hoveredCommentID else { return }
            hoveredCommentID = id
            // A new id fades in from scratch; nil keeps the last id and fades it out.
            if let id, id != emphasisDrawID {
                emphasisDrawID = id
                emphasisProgress = 0
            }
            animateCommentEmphasis(to: id == nil ? 0 : 1)
        }

        /// Tween ``emphasisProgress`` to `target` (1 = hovered, 0 = cleared) at
        /// 60fps, redrawing each frame; clears ``emphasisDrawID`` when it reaches 0.
        private func animateCommentEmphasis(to target: CGFloat) {
            commentEmphasisTimer?.cancel()
            commentEmphasisTimer = nil

            guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
                emphasisProgress = target
                if target == 0 { emphasisDrawID = nil }
                setNeedsDisplay(enclosingScrollView?.documentVisibleRect ?? bounds)
                return
            }

            let start = emphasisProgress
            commentEmphasisTimer = makeFrameRamp(
                duration: 0.16,
                easing: { $0 * $0 * (3 - 2 * $0) }, // smoothstep
                onFrame: { [weak self] progress in
                    guard let self else { return }
                    emphasisProgress = start + (target - start) * progress
                    setNeedsDisplay(enclosingScrollView?.documentVisibleRect ?? bounds)
                },
                onComplete: { [weak self] in
                    guard let self else { return }
                    emphasisProgress = target
                    if target == 0 { emphasisDrawID = nil }
                    commentEmphasisTimer = nil
                }
            )
        }

        /// Smooth-scroll a comment's span into view (no emphasis). Clicking a
        /// sidebar card uses this; the card's hover already emphasizes the span, so
        /// a flash here would only fight that hover.
        func scrollComment(to range: NSRange) {
            smoothScroll(to: range)
        }

        /// Cancel an in-flight jump scroll. Call before swapping storage so the
        /// tween (which targets the old layout) can't fight the new content's
        /// scroll position.
        func cancelCommentScroll() {
            commentScrollTimer?.cancel()
            commentScrollTimer = nil
        }

        /// Scroll a comment into view and flash it (a self-clearing emphasis on the
        /// hover channel, no storage edit). For navigating to a comment with no
        /// hover to carry the emphasis (e.g. the test harness).
        func revealComment(id: String, range: NSRange) {
            smoothScroll(to: range)
            setHoveredComment(id)
            commentFlashTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: AnimationConstants.commentFlashHold)
                guard !Task.isCancelled else { return }
                // Still our flash — no newer hover/jump took ownership.
                if self?.hoveredCommentID == id { self?.setHoveredComment(nil) }
            }
        }

        /// Animate the viewport to bring `range` into view. `scrollRangeToVisible`
        /// resolves the correct destination (even when TextKit 2's off-viewport
        /// layout is still estimated); we then snap back and tween the clip view to
        /// it with a per-frame `scroll(to:)`. A per-frame real scroll (not an
        /// implicit/`animator()` bounds animation) keeps TextKit 2's viewport range
        /// current each frame, so the layout-passive highlight draw — which clips to
        /// that range — doesn't blank out mid-scroll.
        private func smoothScroll(to range: NSRange) {
            commentScrollTimer?.cancel()
            commentScrollTimer = nil

            guard let scrollView = enclosingScrollView else {
                scrollRangeToVisible(range)
                relayoutViewport()
                return
            }
            let clipView = scrollView.contentView
            let start = clipView.bounds.origin
            scrollRangeToVisible(range) // resolve the destination AppKit would pick
            let destination = clipView.bounds.origin
            guard destination != start else { return } // already in view

            // Reduce Motion: leave the view at the resolved destination, no tween.
            guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
                relayoutViewport()
                return
            }

            // Snap back to the start (before any draw) and tween there ourselves.
            clipView.setBoundsOrigin(start)
            scrollView.reflectScrolledClipView(clipView)
            relayoutViewport()

            // Fetch the scroll view from self each tick (under [weak self]) rather
            // than capturing it: a strong capture would cycle (self → timer →
            // scrollView → documentView → self) and keep firing on a detached view
            // after teardown. The window guard no-ops the tween once the view is gone.
            commentScrollTimer = makeFrameRamp(
                duration: AnimationConstants.scrollToHeadingDuration,
                easing: { $0 < 0.5 ? 2 * $0 * $0 : 1 - pow(-2 * $0 + 2, 2) / 2 },
                onFrame: { [weak self] eased in
                    guard let self, window != nil, let scrollView = enclosingScrollView
                    else { return }
                    let clipView = scrollView.contentView
                    clipView.scroll(to: NSPoint(
                        x: start.x + (destination.x - start.x) * eased,
                        y: start.y + (destination.y - start.y) * eased
                    ))
                    scrollView.reflectScrolledClipView(clipView)
                    textLayoutManager?.textViewportLayoutController.layoutViewport()
                },
                onComplete: { [weak self] in self?.commentScrollTimer = nil }
            )
        }

        /// Force the viewport layout controller to refresh its range after a
        /// programmatic scroll, so the layout-passive highlight draw (which clips
        /// to that range) doesn't blank out.
        private func relayoutViewport() {
            textLayoutManager?.textViewportLayoutController.layoutViewport()
        }

        /// Run an eased 0→1 ramp over `duration` at ~60fps on the main queue,
        /// invoking `onFrame(easedProgress)` each tick and `onComplete()` on the
        /// final frame. The caller stores the timer (to cancel a superseding
        /// animation) and owns Reduce Motion handling.
        private func makeFrameRamp(
            duration: TimeInterval,
            easing: @escaping (CGFloat) -> CGFloat,
            onFrame: @escaping (CGFloat) -> Void,
            onComplete: @escaping () -> Void
        ) -> DispatchSourceTimer {
            // Floor at 2 so any sub-frame duration still yields one intermediate
            // step (matches the prior hand-rolled scroll loop's max(…, 2)).
            let steps = max(Int(duration * 60), 2)
            var step = 0
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(1))
            timer.setEventHandler {
                step += 1
                let t = min(CGFloat(step) / CGFloat(steps), 1) // swiftlint:disable:this identifier_name
                onFrame(easing(t))
                if t >= 1 {
                    onComplete()
                    timer.cancel()
                }
            }
            timer.resume()
            return timer
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
                guard let self, let overlay = commentOverlay else { return event }
                if event.type == .keyDown {
                    if event.keyCode == 53 { dismissCommentOverlay() } // Escape
                    return event
                }
                // Inside the visible box (not the transparent shadow padding):
                // interact, don't dismiss.
                let box = overlay.bounds.insetBy(
                    dx: CommentBoxMetrics.shadowPadding, dy: CommentBoxMetrics.shadowPadding
                )
                if box.contains(overlay.convert(event.locationInWindow, from: nil)) { return event }
                if event.type == .scrollWheel {
                    dismissCommentOverlay()
                    return event
                }
                // A click inside the text view is handled by mouseDown (toggle/
                // switch/close); only a click elsewhere dismisses here.
                if !bounds.contains(convert(event.locationInWindow, from: nil)) {
                    dismissCommentOverlay()
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
        @MainActor @objc dynamic required init?(coder _: NSCoder) { fatalError("init(coder:) unavailable") }

        override func hitTest(_ point: NSPoint) -> NSView? {
            let box = bounds.insetBy(
                dx: CommentBoxMetrics.shadowPadding, dy: CommentBoxMetrics.shadowPadding
            )
            guard box.contains(convert(point, from: superview)) else { return nil }
            return super.hitTest(point)
        }
    }
#endif
