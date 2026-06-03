#if os(macOS)
    import AppKit
    import SwiftUI

    extension CodeBlockBackgroundTextView: NSPopoverDelegate {
        /// A `.transient` popover dismisses on the next outside click; clicking a
        /// different comment replaces it. Anchored at the click `point` so the
        /// arrow lands under the cursor (not the start of the comment span); its
        /// own fade is disabled in favor of the content's themed entrance.
        func showCommentPopover(id: String, at point: CGPoint) {
            guard window != nil, // NSPopover needs a hosting window to anchor
                  let document = criticDocument,
                  let comment = document.commentsByID[id],
                  let theme = commentTheme
            else {
                return
            }

            commentPopover?.close()

            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = false
            popover.delegate = self
            popover.contentViewController = NSHostingController(
                rootView: CommentPopoverView(
                    commentID: id,
                    commentBody: comment.body,
                    source: document.rawSource,
                    theme: theme,
                    documentState: documentState,
                    onClose: { [weak self] in self?.commentPopover?.close() }
                )
            )
            commentPopover = popover
            popover.show(relativeTo: anchorRect(at: point), of: self, preferredEdge: .maxY)
        }

        /// A 1×1 rect at `point`, so the popover's arrow points at the cursor.
        private func anchorRect(at point: CGPoint) -> CGRect {
            CGRect(x: point.x, y: point.y, width: 1, height: 1)
        }

        /// Release the closed popover (and its hosted SwiftUI content) on the
        /// transient outside-click dismissal, not just when replaced/rebuilt.
        public func popoverDidClose(_ notification: Notification) {
            if (notification.object as? NSPopover) === commentPopover {
                commentPopover = nil
            }
        }

        // MARK: - Authoring

        /// The raw-source range for the current selection, if it maps to a single
        /// commentable span (reject-first: nil for empty selections or selections
        /// over links/code/existing comments/block boundaries).
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

        /// Present the add-comment input over the current selection. The raw
        /// range is captured now (valid against the rendered document); on submit
        /// it's applied to the live content via DocumentState.
        @objc func addCommentToSelection(_: Any?) {
            guard let rawRange = commentableSelectionRange(),
                  let source = criticDocument?.rawSource,
                  let theme = commentTheme,
                  let documentState,
                  let rect = boundingRect(forCharacterRange: selectedRange())
            else {
                return
            }
            commentPopover?.close()

            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = false
            popover.delegate = self
            popover.contentViewController = NSHostingController(
                rootView: CommentInputView(theme: theme) { [weak self] body in
                    // Keep the popover (and the typed text) on a rejected wrap.
                    if documentState.addComment(in: rawRange, of: source, body: body) {
                        self?.commentPopover?.close()
                    }
                }
            )
            commentPopover = popover
            popover.show(relativeTo: rect, of: self, preferredEdge: .maxY)
        }
    }
#endif
