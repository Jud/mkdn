#if os(macOS)
    import AppKit
    import SwiftUI

    extension CodeBlockBackgroundTextView {
        /// A `.transient` popover dismisses on the next outside click; clicking a
        /// different comment replaces it.
        func showCommentPopover(id: String, range: NSRange) {
            guard let comment = commentsByID[id],
                  let theme = commentTheme,
                  let rect = boundingRect(forCharacterRange: range)
            else {
                return
            }

            commentPopover?.close()

            let popover = NSPopover()
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(
                rootView: CommentPopoverView(commentBody: comment.body, theme: theme)
            )
            commentPopover = popover
            popover.show(relativeTo: rect, of: self, preferredEdge: .maxY)
        }
    }
#endif
