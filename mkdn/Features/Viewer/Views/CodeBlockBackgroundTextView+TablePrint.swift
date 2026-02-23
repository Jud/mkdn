import AppKit

/// Print-time table container rendering for `CodeBlockBackgroundTextView`.
///
/// During Cmd+P, the builder generates table text with visible foreground
/// (via `isPrint: true`), but the SwiftUI `TableBlockView` overlay is not
/// present in the print rendering pipeline. This extension draws the same
/// visual structure -- rounded border, header background, alternating row
/// fills, and header-body divider -- directly behind the visible table text
/// using `NSBezierPath`, matching the on-screen appearance adapted for the
/// print palette.
///
/// On screen, this method is a no-op (guarded by `NSPrintOperation.current`).
extension CodeBlockBackgroundTextView {
    // MARK: - Constants

    private enum TablePrint {
        static let cornerRadius: CGFloat = 6
        static let borderWidth: CGFloat = 1
        static let borderOpacity: CGFloat = 0.5
        static let alternatingRowOpacity: CGFloat = 0.7
    }

    // MARK: - Types

    private struct TableBlockInfo {
        let tableID: String
        let range: NSRange
        let colorInfo: TableColorInfo
        let cellMap: TableCellMap
    }

    // MARK: - Entry Point

    /// Draws rounded-rect containers behind table text during print rendering.
    ///
    /// Called from `drawBackground(in:)` on every draw cycle but exits
    /// immediately when not printing. During print, enumerates table regions
    /// in the text storage, computes bounding rects from layout fragments,
    /// and draws the full visual container (border, header fill, alternating
    /// row fills, header-body divider).
    func drawTableContainers(in dirtyRect: NSRect) {
        guard NSPrintOperation.current != nil else { return }
        guard let textStorage,
              let layoutManager = textLayoutManager,
              let contentManager = layoutManager.textContentManager
        else { return }

        let blocks = collectTableBlocks(from: textStorage)
        guard !blocks.isEmpty else { return }

        let origin = textContainerOrigin
        let borderInset = TablePrint.borderWidth / 2

        for block in blocks {
            guard let firstFragmentY = tableFirstFragmentY(
                for: block.range,
                layoutManager: layoutManager,
                contentManager: contentManager
            )
            else { continue }

            let tableWidth = block.cellMap.columnWidths.reduce(0, +)
            let tableHeight = block.cellMap.rowHeights.reduce(0, +)

            let drawRect = CGRect(
                x: origin.x + borderInset,
                y: firstFragmentY + origin.y,
                width: tableWidth - 2 * borderInset,
                height: tableHeight
            )
            guard drawRect.intersects(dirtyRect) else { continue }

            drawTableContainer(
                in: drawRect,
                colorInfo: block.colorInfo,
                cellMap: block.cellMap
            )
        }
    }

    // MARK: - Table Block Collection

    private func collectTableBlocks(
        from textStorage: NSTextStorage
    ) -> [TableBlockInfo] {
        var grouped: [String: (
            range: NSRange, colorInfo: TableColorInfo, cellMap: TableCellMap
        )] = [:]
        let fullRange = NSRange(location: 0, length: textStorage.length)

        textStorage.enumerateAttribute(
            TableAttributes.range,
            in: fullRange,
            options: []
        ) { value, range, _ in
            guard let tableID = value as? String else { return }
            if var existing = grouped[tableID] {
                existing.range = NSUnionRange(existing.range, range)
                grouped[tableID] = existing
            } else if let colorInfo = textStorage.attribute(
                TableAttributes.colors,
                at: range.location,
                effectiveRange: nil
            ) as? TableColorInfo,
                let cellMap = textStorage.attribute(
                    TableAttributes.cellMap,
                    at: range.location,
                    effectiveRange: nil
                ) as? TableCellMap
            {
                grouped[tableID] = (
                    range: range,
                    colorInfo: colorInfo,
                    cellMap: cellMap
                )
            }
        }

        return grouped.map { tableID, entry in
            TableBlockInfo(
                tableID: tableID,
                range: entry.range,
                colorInfo: entry.colorInfo,
                cellMap: entry.cellMap
            )
        }
    }

    // MARK: - Layout Fragment Geometry

    /// Returns the Y coordinate of the first layout fragment covering the
    /// given character range, used as the table's top-edge position.
    private func tableFirstFragmentY(
        for nsRange: NSRange,
        layoutManager: NSTextLayoutManager,
        contentManager: NSTextContentManager
    ) -> CGFloat? {
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
        else { return nil }

        var firstY: CGFloat?
        layoutManager.enumerateTextLayoutFragments(
            from: textRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            let fragStart = fragment.rangeInElement.location
            if fragStart.compare(textRange.endLocation) != .orderedAscending {
                return false
            }
            firstY = fragment.layoutFragmentFrame.minY
            return false
        }
        return firstY
    }

    // MARK: - Table Container Drawing

    // swiftlint:disable:next function_body_length
    private func drawTableContainer(
        in rect: NSRect,
        colorInfo: TableColorInfo,
        cellMap: TableCellMap
    ) {
        let path = NSBezierPath(
            roundedRect: rect,
            xRadius: TablePrint.cornerRadius,
            yRadius: TablePrint.cornerRadius
        )

        NSGraphicsContext.saveGraphicsState()
        path.addClip()

        // Base background fill
        colorInfo.background.setFill()
        rect.fill()

        // Header row fill
        if !cellMap.rowHeights.isEmpty {
            let headerHeight = cellMap.rowHeights[0]
            let headerRect = CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: headerHeight
            )
            colorInfo.headerBackground.setFill()
            headerRect.fill()
        }

        // Alternating data row fills (odd rows get secondary background)
        var currentY = rect.minY + (cellMap.rowHeights.first ?? 0)
        for rowIndex in 0 ..< cellMap.rowCount {
            let heightIndex = rowIndex + 1
            guard heightIndex < cellMap.rowHeights.count else { break }
            let rowHeight = cellMap.rowHeights[heightIndex]

            if !rowIndex.isMultiple(of: 2) {
                let rowRect = CGRect(
                    x: rect.minX,
                    y: currentY,
                    width: rect.width,
                    height: rowHeight
                )
                colorInfo.backgroundSecondary
                    .withAlphaComponent(TablePrint.alternatingRowOpacity)
                    .setFill()
                rowRect.fill()
            }
            currentY += rowHeight
        }

        // Header-body divider
        if !cellMap.rowHeights.isEmpty {
            let dividerY = rect.minY + cellMap.rowHeights[0]
            let dividerPath = NSBezierPath()
            dividerPath.move(to: CGPoint(x: rect.minX, y: dividerY))
            dividerPath.line(to: CGPoint(x: rect.maxX, y: dividerY))
            dividerPath.lineWidth = TablePrint.borderWidth
            colorInfo.border.setStroke()
            dividerPath.stroke()
        }

        NSGraphicsContext.restoreGraphicsState()

        // Border stroke (after restoring clip for clean rounded corners)
        colorInfo.border
            .withAlphaComponent(TablePrint.borderOpacity)
            .setStroke()
        path.lineWidth = TablePrint.borderWidth
        path.stroke()
    }
}
