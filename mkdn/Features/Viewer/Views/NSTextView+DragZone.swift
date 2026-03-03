#if os(macOS)
    import AppKit

    /// Shared hit-testing helpers for text views that allow window dragging
    /// from empty space (margins, below the last line of text).
    ///
    /// Supports both TextKit 2 (``NSTextLayoutManager``) and TextKit 1
    /// (``NSLayoutManager``) text views.
    ///
    /// Used by both ``CodeBlockBackgroundTextView`` (markdown preview) and
    /// ``DraggableCodeTextView`` (code file viewer).
    extension NSTextView {
        /// Whether the view-coordinate point falls outside any text content —
        /// i.e. in the text container inset margins or below the last line.
        func isOverEmptyTextArea(_ point: CGPoint) -> Bool {
            let containerPoint = CGPoint(
                x: point.x - textContainerInset.width,
                y: point.y - textContainerInset.height
            )

            // TextKit 2 path
            if let textLayoutManager {
                guard let fragment = textLayoutManager.textLayoutFragment(
                    for: containerPoint
                )
                else {
                    return true
                }
                return !fragment.layoutFragmentFrame.contains(containerPoint)
            }

            // TextKit 1 fallback — per-line hit test using the glyph-occupied
            // portion of each line fragment, not the overall usedRect bounding box.
            if let layoutManager, let textContainer {
                let usedRect = layoutManager.usedRect(for: textContainer)
                guard usedRect.contains(containerPoint) else { return true }

                var fraction: CGFloat = 0
                let glyphIndex = layoutManager.glyphIndex(
                    for: containerPoint,
                    in: textContainer,
                    fractionOfDistanceThroughGlyph: &fraction
                )
                let lineUsedRect = layoutManager.lineFragmentUsedRect(
                    forGlyphAt: glyphIndex,
                    effectiveRange: nil
                )
                return !lineUsedRect.contains(containerPoint)
            }

            return true
        }

        /// Whether the view-coordinate point falls on a character that has a
        /// `.link` attribute in the text storage.
        ///
        /// Returns `false` when the point is over empty space (no character),
        /// when the text storage is empty, or when the character under the
        /// point has no link.
        func isOverLink(at point: CGPoint) -> Bool {
            guard let textStorage, textStorage.length > 0 else { return false }

            let containerPoint = CGPoint(
                x: point.x - textContainerInset.width,
                y: point.y - textContainerInset.height
            )

            // TextKit 2 path
            if let textLayoutManager {
                guard let fragment = textLayoutManager.textLayoutFragment(
                    for: containerPoint
                )
                else {
                    return false
                }
                let fragmentPoint = CGPoint(
                    x: containerPoint.x - fragment.layoutFragmentFrame.origin.x,
                    y: containerPoint.y - fragment.layoutFragmentFrame.origin.y
                )
                for lineFragment in fragment.textLineFragments {
                    let lineBounds = lineFragment.typographicBounds
                    guard fragmentPoint.y >= lineBounds.minY,
                          fragmentPoint.y < lineBounds.maxY
                    else { continue }
                    let charIndex = lineFragment.characterIndex(for: fragmentPoint)
                    let docOffset = lineFragment.characterRange.location + charIndex
                    guard docOffset >= 0, docOffset < textStorage.length else { return false }
                    return textStorage.attribute(.link, at: docOffset, effectiveRange: nil) != nil
                }
                return false
            }

            // TextKit 1 fallback
            if let layoutManager, let textContainer {
                var fraction: CGFloat = 0
                let charIndex = layoutManager.characterIndex(
                    for: containerPoint,
                    in: textContainer,
                    fractionOfDistanceBetweenInsertionPoints: &fraction
                )
                guard charIndex < textStorage.length else { return false }
                return textStorage.attribute(.link, at: charIndex, effectiveRange: nil) != nil
            }

            return false
        }

        /// Handles a mouse-down on empty text area with a 3pt drag threshold.
        ///
        /// Deselects any existing text selection, then enters a tracking loop
        /// waiting for either a drag gesture (cumulative distance > 3pt from
        /// the initial click) or a mouse-up. If the threshold is exceeded,
        /// initiates a window drag; otherwise returns without action.
        func handleEmptyAreaMouseDown(with event: NSEvent) {
            setSelectedRange(NSRange(location: 0, length: 0))
            let threshold: CGFloat = 3
            let initialLocation = event.locationInWindow

            while true {
                guard let nextEvent = window?.nextEvent(
                    matching: [.leftMouseDragged, .leftMouseUp]
                )
                else {
                    return
                }

                if nextEvent.type == .leftMouseUp {
                    return
                }

                let deltaX = nextEvent.locationInWindow.x - initialLocation.x
                let deltaY = nextEvent.locationInWindow.y - initialLocation.y
                let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

                if distance > threshold {
                    window?.performDrag(with: event)
                    return
                }
            }
        }

        /// Installs a full-bounds tracking area for mouse-moved events so
        /// the cursor can switch between arrow (drag zones) and I-beam (text).
        func installFullBoundsTrackingArea() {
            for area in trackingAreas where area.owner === self {
                removeTrackingArea(area)
            }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
        }
    }
#endif
