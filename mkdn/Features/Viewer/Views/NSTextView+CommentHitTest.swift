#if os(macOS)
    import AppKit

    extension NSTextView {
        /// The document character index under a view-coordinate `point`, or nil
        /// when the point is over empty space or past the text. Mirrors the
        /// TextKit 2 / TextKit 1 hit-test in `isOverLink(at:)`.
        func characterIndex(at point: CGPoint) -> Int? {
            guard let textStorage, textStorage.length > 0 else { return nil }

            let containerPoint = CGPoint(
                x: point.x - textContainerInset.width,
                y: point.y - textContainerInset.height
            )

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
                    let charIndex = lineFragment.characterIndex(for: fragmentPoint)
                    let lineStartInFragment = lineFragment.characterRange.location
                    let fragmentStartInDoc = textContentStorage.offset(
                        from: textContentStorage.documentRange.location,
                        to: fragment.rangeInElement.location
                    )
                    let docOffset = fragmentStartInDoc + lineStartInFragment + charIndex
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

        /// The comment id and its full highlighted range under `point`, or nil if
        /// no comment is there. The range is the attribute's `effectiveRange`, so
        /// it spans the entire highlight even when other attributes split it into
        /// multiple runs.
        func commentInfo(at point: CGPoint) -> (id: String, range: NSRange)? {
            guard let textStorage, let index = characterIndex(at: point) else { return nil }
            var range = NSRange(location: 0, length: 0)
            guard let id = textStorage.attribute(
                .mkdnCommentID, at: index, effectiveRange: &range
            ) as? String
            else {
                return nil
            }
            return (id, range)
        }
    }
#endif
