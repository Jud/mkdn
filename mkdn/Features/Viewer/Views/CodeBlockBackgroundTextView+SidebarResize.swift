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
            // The estimate is for the old width; free the height for the slide.
            estimatedHeightFloor = nil
            guard let scrollView = enclosingScrollView,
                  let textLayoutManager,
                  let viewportRange = textLayoutManager.textViewportLayoutController.viewportRange
            else { return }

            // Force real layout of the viewport and everything above it: a fragment's
            // absolute Y is the sum of all heights above it, which `.ensuresLayout`
            // alone leaves at TextKit 2's estimated (accumulating-error) values — and
            // the capture must read the *same* coordinate space the restore will, or
            // the pin starts from a wrong baseline.
            if let prefix = NSTextRange(
                location: textLayoutManager.documentRange.location,
                end: viewportRange.endLocation
            ) {
                textLayoutManager.ensureLayout(for: prefix)
            }

            let visibleTop = scrollView.contentView.bounds.origin.y
            // Fragment frames are in text-container space; shift by textContainerOrigin
            // to compare with the clip view's document-space scroll offset.
            let originY = textContainerOrigin.y
            var anchorLocation: NSTextLocation?
            var anchorTop = visibleTop
            textLayoutManager.enumerateTextLayoutFragments(
                from: viewportRange.location, options: [.ensuresLayout]
            ) { fragment in
                // The line crossing the viewport top (maxY past it, not the first one
                // fully below) is the one at the top edge.
                if fragment.layoutFragmentFrame.maxY + originY > visibleTop {
                    anchorLocation = fragment.rangeInElement.location
                    anchorTop = fragment.layoutFragmentFrame.minY + originY
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
        ///
        /// Known limit: re-measuring a *deep* anchor's absolute y every frame can't
        /// converge during the fast middle of the slide (the height of everything
        /// above it is changing faster than TextKit settles it), so far down a long
        /// document the pin lurches briefly mid-slide, then recovers. It is exact at
        /// the top of the document and at rest. This transient is an accepted
        /// trade-off for live per-frame reflow — the alternatives (a fixed reading
        /// column, or holding the text and settling once at the end) were weighed and
        /// declined in favor of watching the text reflow live.
        func restoreSidebarResizeAnchor() {
            guard let anchor = sidebarResizeAnchor,
                  let scrollView = enclosingScrollView,
                  let textLayoutManager
            else { return }

            let controller = textLayoutManager.textViewportLayoutController
            // First layout: settle the viewport at the just-applied width.
            controller.layoutViewport()
            // Then force real layout of the whole prefix through the anchor so its
            // absolute Y is final — without this, estimated heights above the anchor
            // make the pin drift vertically, the exact jump this exists to prevent.
            if let prefix = NSTextRange(
                location: textLayoutManager.documentRange.location, end: anchor.location
            ) {
                textLayoutManager.ensureLayout(for: prefix)
            }

            let originY = textContainerOrigin.y
            var newTop: CGFloat?
            textLayoutManager.enumerateTextLayoutFragments(
                from: anchor.location, options: [.ensuresLayout]
            ) { fragment in
                newTop = fragment.layoutFragmentFrame.minY + originY
                return false
            }
            guard let newTop else { return }

            let clipView = scrollView.contentView
            clipView.setBoundsOrigin(
                NSPoint(x: clipView.bounds.origin.x, y: newTop + anchor.delta)
            )
            scrollView.reflectScrolledClipView(clipView)
            // Second layout: refresh the viewport range for the new scroll origin so
            // the layout-passive comment-highlight draw (which clips to that range)
            // doesn't blank — same rationale as relayoutViewport after a scroll.
            controller.layoutViewport()
        }

        /// Final settle and teardown once the slide finishes. Two things must be made
        /// exact here, both one-shot (full-document work, never per frame): the scroll
        /// *extent* and TextKit 2's *logical viewport*.
        func endSidebarResize() {
            guard sidebarResizeAnchor != nil else { return }
            // Re-estimate the height at the new width so the scroller is right, then
            // re-pin (the frame may have grown to the estimate). The contiguous
            // container realizes exact geometry as the reader scrolls; the whole-string
            // measure just sizes the scroller up front — no full-document layout.
            restoreSidebarResizeAnchor()
            refreshEstimatedHeight()
            restoreSidebarResizeAnchor()
            sidebarResizeAnchor = nil
        }
    }
#endif
