#if os(macOS)
    import AppKit
    import SwiftUI

    extension CodeBlockBackgroundTextView: NSPopoverDelegate {
        /// A `.transient` popover dismisses on the next outside click; clicking a
        /// different comment replaces it.
        func showCommentPopover(id: String, range: NSRange) {
            guard window != nil, // NSPopover needs a hosting window to anchor
                  let comment = criticDocument?.commentsByID[id],
                  let theme = commentTheme,
                  let rect = boundingRect(forCharacterRange: range)
            else {
                return
            }

            commentPopover?.close()

            let popover = NSPopover()
            popover.behavior = .transient
            popover.delegate = self
            popover.contentViewController = NSHostingController(
                rootView: CommentPopoverView(commentBody: comment.body, theme: theme)
            )
            commentPopover = popover
            popover.show(relativeTo: rect, of: self, preferredEdge: .maxY)
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
                  let theme = commentTheme,
                  let documentState,
                  let rect = boundingRect(forCharacterRange: selectedRange())
            else {
                return
            }
            commentPopover?.close()

            let popover = NSPopover()
            popover.behavior = .transient
            popover.delegate = self
            popover.contentViewController = NSHostingController(
                rootView: CommentInputView(theme: theme) { [weak self] body in
                    documentState.addComment(in: rawRange, body: body)
                    self?.commentPopover?.close()
                }
            )
            commentPopover = popover
            popover.show(relativeTo: rect, of: self, preferredEdge: .maxY)
        }
    }
#endif
