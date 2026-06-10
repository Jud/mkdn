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
            // Mark the gesture in flight up front — before the anchor-capture guards below,
            // which can bail (a degenerate viewport) while the slide still animates the
            // width. The flag, not the anchor, is what suppresses per-frame measures.
            isSidebarResizeInFlight = true
            // The estimate is for the old width; free the height for the slide. The cached
            // per-block offsets are stale at the old width too — the settle recomputes both.
            estimatedHeightFloor = nil
            blockOffsets = nil
            guard let scrollView = enclosingScrollView, let textLayoutManager else { return }

            // Lay out just the viewport (not the whole prefix above it) so the capture reads
            // the visible fragments' current on-screen positions. The pin tracks the anchor's
            // screen position via per-frame drift, so an estimate-backed absolute y is the
            // right baseline here and in the restore.
            let controller = textLayoutManager.textViewportLayoutController
            controller.layoutViewport()
            guard let viewportRange = controller.viewportRange else { return }

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
            // Viewport-bounded layout for the slide, now that the anchor was captured
            // from the real (contiguous) geometry; the settle restores exact geometry.
            prefersLazyGestureLayout = true
            // The popover anchors to the old layout; drop it rather than chase a
            // moving target every frame.
            dismissCommentOverlay()
        }

        /// Re-pin the captured line to the same viewport y after the text has rewrapped to the
        /// current width. Driven from the scroll view's `tile()` on every resize frame while
        /// ``sidebarResizeAnchor`` is set.
        ///
        /// Per frame (`exact == false`) the pin reads the anchor's position from
        /// `layoutViewport` alone — no prefix layout — and nudges the scroll origin so the line
        /// holds its screen position. `newTop` and the scroll target both come from that one
        /// layout pass, so `newTop + delta` is self-consistent within the frame even though the
        /// absolute y is estimate-backed; the frame-to-frame estimate shift is absorbed by the
        /// nudge, so the line stays put visually. The settle (`exact == true`) lays the prefix
        /// out once so the final absolute scroll position — and the off-viewport content — is exact.
        func restoreSidebarResizeAnchor(exact: Bool) {
            guard let anchor = sidebarResizeAnchor,
                  let scrollView = enclosingScrollView,
                  let textLayoutManager
            else { return }

            let controller = textLayoutManager.textViewportLayoutController
            // Settle the viewport at the just-applied width.
            controller.layoutViewport()
            // Settle only: force exact layout of the whole prefix through the anchor so its
            // absolute y is final.
            if exact, let prefix = NSTextRange(
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
            guard isSidebarResizeInFlight || sidebarResizeAnchor != nil else { return }
            // Back to contiguous layout before the exact pass, so the settle re-pins
            // against real geometry and the at-rest guarantees (stable frame height,
            // no blank space past TextKit's estimate) hold again.
            prefersLazyGestureLayout = false
            // Re-estimate the height at the new width first so the document-view frame is tall
            // enough, then re-pin exactly: the pin can't clamp against a still-short frame, and
            // the prefix layout runs once instead of being thrown away by the resize. The whole-
            // string measure just sizes the scroller up front — no full-document layout.
            refreshSettledHeight()
            restoreSidebarResizeAnchor(exact: true)
            sidebarResizeAnchor = nil
            isSidebarResizeInFlight = false
            // The settle's final layout may produce no further frame/scroll change;
            // nudge the scroll-spy so the breadcrumb reflects the reflowed viewport.
            onResizeSettled?()
        }
    }
#endif
