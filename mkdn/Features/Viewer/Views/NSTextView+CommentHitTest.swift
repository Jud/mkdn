#if os(macOS)
    import AppKit

    extension NSTextView {
        /// The document character index under a view-coordinate `point`, or nil
        /// when the point is over empty space or past the text. Mirrors the
        /// TextKit 2 / TextKit 1 hit-test in `isOverLink(at:)`.
        func characterIndex(at point: CGPoint) -> Int? {
            guard let textStorage, textStorage.length > 0 else { return nil }

            // textContainerOrigin is the AppKit-correct container↔view offset
            // (it accounts for inset and any centering), matching boundingRect's
            // inverse and the codebase's overlay positioning.
            let origin = textContainerOrigin
            let containerPoint = CGPoint(x: point.x - origin.x, y: point.y - origin.y)

            if let textLayoutManager, let textContentStorage {
                guard let fragment = textLayoutManager.textLayoutFragment(for: containerPoint) else {
                    return nil
                }
                let fragmentPoint = CGPoint(
                    x: containerPoint.x - fragment.layoutFragmentFrame.origin.x,
                    y: containerPoint.y - fragment.layoutFragmentFrame.origin.y
                )
                for lineFragment in fragment.textLineFragments {
                    let lineBounds = lineFragment.typographicBounds
                    guard fragmentPoint.y >= lineBounds.minY, fragmentPoint.y < lineBounds.maxY
                    else { continue }
                    // `characterIndex(for:)` is already relative to the layout
                    // fragment's start, not the line's, so it must NOT be offset by
                    // the line's start again — doing so double-counts on the 2nd+
                    // line of a wrapped paragraph and overshoots the document.
                    let charIndex = lineFragment.characterIndex(for: fragmentPoint)
                    let fragmentStartInDoc = textContentStorage.offset(
                        from: textContentStorage.documentRange.location,
                        to: fragment.rangeInElement.location
                    )
                    let docOffset = fragmentStartInDoc + charIndex
                    guard docOffset >= 0, docOffset < textStorage.length else { return nil }
                    return docOffset
                }
                return nil
            }

            if let layoutManager, let textContainer {
                var fraction: CGFloat = 0
                let charIndex = layoutManager.characterIndex(
                    for: containerPoint,
                    in: textContainer,
                    fractionOfDistanceBetweenInsertionPoints: &fraction
                )
                guard charIndex < textStorage.length else { return nil }
                return charIndex
            }

            return nil
        }

        /// The bounding rect (view coordinates) of a character range, for
        /// anchoring a popover. Unions the per-line text segments. Returns nil if
        /// the range has no laid-out geometry.
        func boundingRect(forCharacterRange range: NSRange) -> CGRect? {
            if let textLayoutManager, let textContentStorage {
                guard let start = textContentStorage.location(
                    textContentStorage.documentRange.location, offsetBy: range.location
                ),
                    let end = textContentStorage.location(start, offsetBy: range.length),
                    let textRange = NSTextRange(location: start, end: end)
                else {
                    return nil
                }
                textLayoutManager.ensureLayout(for: textRange)
                var union: CGRect?
                textLayoutManager.enumerateTextSegments(
                    in: textRange, type: .standard, options: .rangeNotRequired
                ) { _, segmentFrame, _, _ in
                    union = union.map { $0.union(segmentFrame) } ?? segmentFrame
                    return true
                }
                guard var rect = union else { return nil }
                let origin = textContainerOrigin
                rect.origin.x += origin.x
                rect.origin.y += origin.y
                return rect
            }

            if let layoutManager, let textContainer {
                let glyphRange = layoutManager.glyphRange(
                    forCharacterRange: range, actualCharacterRange: nil
                )
                var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                let origin = textContainerOrigin
                rect.origin.x += origin.x
                rect.origin.y += origin.y
                return rect
            }

            return nil
        }
    }
#endif
