#if os(macOS)
    import AppKit
    import SwiftUI

    extension CodeBlockBackgroundTextView: NSPopoverDelegate {
        /// A `.transient` popover dismisses on the next outside click; clicking a
        /// different comment replaces it.
        func showCommentPopover(id: String, range: NSRange) {
            guard window != nil, // NSPopover needs a hosting window to anchor
                  let comment = commentsByID[id],
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
    }
#endif
