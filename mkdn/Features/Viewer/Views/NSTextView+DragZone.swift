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
