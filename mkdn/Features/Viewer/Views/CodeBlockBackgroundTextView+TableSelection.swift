import AppKit

/// Selection-time table highlight suppression for `CodeBlockBackgroundTextView`.
///
/// NSTextView draws its native selection background (accent color at 0.3 alpha)
/// for ALL selected text, including table invisible text regions. The visual
/// `TableBlockView` overlay only covers the table's visual bounds, so the native
/// selection extends beyond the table into subsequent content. This extension
/// erases the native selection highlight in table regions after the full draw
/// pass completes, so only the cell-level `TableHighlightOverlay` is visible.
extension CodeBlockBackgroundTextView {
    /// Fills table text regions with the document background color to erase
    /// the native selection highlight drawn by NSTextView during `draw(_:)`.
    ///
    /// Called after `super.draw(dirtyRect)` in the main `draw(_:)` override.
    /// Only paints over table regions when the current selection intersects
    /// table text, avoiding unnecessary overdraw on non-selected tables.
    func eraseTableSelectionHighlights(in dirtyRect: NSRect) {
        guard let textStorage,
              let layoutManager = textLayoutManager,
              let contentManager = layoutManager.textContentManager
        else { return }

        let selectionRanges = selectedRanges.map(\.rangeValue)
        guard selectionRanges.contains(where: { $0.length > 0 }) else { return }

        let selectionUnion = selectionRanges.filter { $0.length > 0 }
            .reduce(into: NSRange(location: 0, length: 0)) { result, range in
                result = result.length == 0 ? range : NSUnionRange(result, range)
            }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        var tableRanges: [String: NSRange] = [:]

        textStorage.enumerateAttribute(
            TableAttributes.range,
            in: fullRange,
            options: []
        ) { value, range, _ in
            guard let tableID = value as? String else { return }
            if let existing = tableRanges[tableID] {
                tableRanges[tableID] = NSUnionRange(existing, range)
            } else {
                tableRanges[tableID] = range
            }
        }

        guard !tableRanges.isEmpty else { return }

        let bgColor = backgroundColor
        let origin = textContainerOrigin

        for (_, tableRange) in tableRanges {
            guard NSIntersectionRange(tableRange, selectionUnion).length > 0
            else { continue }

            let frames = selectionEraseFragmentFrames(
                for: tableRange,
                layoutManager: layoutManager,
                contentManager: contentManager
            )
            guard !frames.isEmpty else { continue }

            let bounding = frames.reduce(frames[0]) { $0.union($1) }
            let eraseRect = CGRect(
                x: bounding.minX + origin.x,
                y: bounding.minY + origin.y,
                width: bounding.width,
                height: bounding.height
            )
            guard eraseRect.intersects(dirtyRect) else { continue }

            bgColor.setFill()
            eraseRect.fill()
        }
    }

    // MARK: - Layout Fragment Geometry

    private func selectionEraseFragmentFrames(
        for nsRange: NSRange,
        layoutManager: NSTextLayoutManager,
        contentManager: NSTextContentManager
    ) -> [CGRect] {
        guard nsRange.length > 0,
              let startLoc = contentManager.location(
                  contentManager.documentRange.location,
                  offsetBy: nsRange.location
              ),
              let endLoc = contentManager.location(
                  startLoc,
                  offsetBy: nsRange.length
              ),
              let textRange = NSTextRange(
                  location: startLoc,
                  end: endLoc
              )
        else { return [] }

        var frames: [CGRect] = []
        let endLocation = textRange.endLocation

        layoutManager.enumerateTextLayoutFragments(
            from: textRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            let fragmentStart = fragment.rangeInElement.location
            if fragmentStart.compare(endLocation) != .orderedAscending {
                return false
            }
            frames.append(fragment.layoutFragmentFrame)
            return true
        }

        return frames
    }
}
