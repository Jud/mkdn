#if os(macOS)
    import AppKit

    /// A line pinned to the top of the viewport while the comment rail animates the
    /// preview width. `location` stays valid across a width-only relayout (the text
    /// content is unchanged), and `delta` is how far the viewport top sits below that
    /// line's top — together they reproduce the exact scroll position once the text
    /// has rewrapped to the new width.
    struct SidebarResizeAnchor {
        let location: NSTextLocation
        let delta: CGFloat
    }

    extension CodeBlockBackgroundTextView {
        /// Capture the line at the viewport top, just before the slide begins, so it
        /// can be re-pinned as the width changes. Called from the preview ahead of the
        /// width animation, while the layout still reflects the old width.
        func beginSidebarResize() {
            guard let scrollView = enclosingScrollView,
                  let textLayoutManager,
                  let viewportRange = textLayoutManager.textViewportLayoutController.viewportRange
            else { return }

            let visibleTop = scrollView.contentView.bounds.origin.y
            var anchorLocation: NSTextLocation?
            var anchorTop = visibleTop
            textLayoutManager.enumerateTextLayoutFragments(
                from: viewportRange.location, options: [.ensuresLayout]
            ) { fragment in
                // The first fragment reaching past the viewport top is the line the
                // reader sees at the top edge.
                if fragment.layoutFragmentFrame.maxY > visibleTop {
                    anchorLocation = fragment.rangeInElement.location
                    anchorTop = fragment.layoutFragmentFrame.minY
                    return false
                }
                return true
            }

            guard let anchorLocation else { return }
            sidebarResizeAnchor = SidebarResizeAnchor(
                location: anchorLocation, delta: visibleTop - anchorTop
            )
            // The popover anchors to the old layout; drop it rather than chase a
            // moving target every frame.
            dismissCommentOverlay()
        }

        /// Re-pin the captured line to the same viewport y after the text has
        /// rewrapped to the current width. Driven from the scroll view's `tile()` on
        /// every resize frame while ``sidebarResizeAnchor`` is set.
        func restoreSidebarResizeAnchor() {
            guard let anchor = sidebarResizeAnchor,
                  let scrollView = enclosingScrollView,
                  let textLayoutManager
            else { return }

            let controller = textLayoutManager.textViewportLayoutController
            controller.layoutViewport()

            var newTop: CGFloat?
            textLayoutManager.enumerateTextLayoutFragments(
                from: anchor.location, options: [.ensuresLayout]
            ) { fragment in
                newTop = fragment.layoutFragmentFrame.minY
                return false
            }
            guard let newTop else { return }

            let clipView = scrollView.contentView
            clipView.setBoundsOrigin(
                NSPoint(x: clipView.bounds.origin.x, y: newTop + anchor.delta)
            )
            scrollView.reflectScrolledClipView(clipView)
            controller.layoutViewport()
        }

        /// Final settle and teardown once the slide finishes.
        func endSidebarResize() {
            restoreSidebarResizeAnchor()
            sidebarResizeAnchor = nil
        }
    }
#endif
