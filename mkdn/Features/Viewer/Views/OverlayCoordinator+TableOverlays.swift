import AppKit
import SwiftUI

/// Table overlay management for ``OverlayCoordinator``.
///
/// Table overlays use text-range-based positioning (via ``TableAttributes/range``
/// in the text storage) instead of attachment-based positioning. Each table gets
/// a visual overlay (`TableBlockView` in `NSHostingView`) and a
/// ``TableHighlightOverlay`` sibling for selection/find drawing.
extension OverlayCoordinator {
    // MARK: - Table Overlay API

    /// Creates, updates, or removes table overlay views that use text-range-based
    /// positioning via `TableAttributes.range` in the text storage.
    func updateTableOverlays(
        tableOverlays: [TableOverlayInfo],
        appSettings: AppSettings,
        in textView: NSTextView
    ) {
        self.textView = textView
        self.appSettings = appSettings

        let validIndices = Set(tableOverlays.map(\.blockIndex))
        removeStaleTableOverlays(keeping: validIndices)

        for info in tableOverlays {
            updateOrCreateTableOverlay(
                for: info,
                appSettings: appSettings,
                in: textView
            )
        }

        adjustTableRowHeights(in: textView)
        observeLayoutChanges(on: textView)
        observeScrollChanges(on: textView)
        repositionOverlays()
    }

    /// Maps the current NSTextView selection to cell positions for each table
    /// and updates the corresponding ``TableHighlightOverlay``.
    func updateTableSelections(selectedRange: NSRange) {
        guard let textView,
              let textStorage = textView.textStorage
        else { return }

        for (_, entry) in entries {
            guard let tableRangeID = entry.tableRangeID,
                  let cellMap = entry.cellMap,
                  let highlightOverlay = entry.highlightOverlay
            else { continue }

            guard let tableRange = findTableTextRange(
                for: tableRangeID, in: textStorage
            )
            else {
                highlightOverlay.selectedCells = []
                highlightOverlay.needsDisplay = true
                highlightOverlay.displayIfNeeded()
                continue
            }

            let intersection = NSIntersectionRange(selectedRange, tableRange)
            if intersection.length > 0 {
                let relativeRange = NSRange(
                    location: intersection.location - tableRange.location,
                    length: intersection.length
                )
                highlightOverlay.selectedCells = cellMap.cellsInRange(relativeRange)
            } else {
                highlightOverlay.selectedCells = []
            }
            highlightOverlay.needsDisplay = true
            highlightOverlay.displayIfNeeded()
        }
    }

    /// Maps find match ranges to cell positions for each table and updates
    /// the corresponding ``TableHighlightOverlay`` with find highlight state.
    func updateTableFindHighlights(
        matchRanges: [NSRange],
        currentIndex: Int
    ) {
        guard let textView,
              let textStorage = textView.textStorage
        else { return }

        for (_, entry) in entries {
            guard let tableRangeID = entry.tableRangeID,
                  let cellMap = entry.cellMap,
                  let highlightOverlay = entry.highlightOverlay
            else { continue }

            updateFindHighlightsForTable(
                highlightOverlay: highlightOverlay,
                cellMap: cellMap,
                tableRangeID: tableRangeID,
                textStorage: textStorage,
                matchRanges: matchRanges,
                currentIndex: currentIndex
            )
        }
    }

    private func updateFindHighlightsForTable(
        highlightOverlay: TableHighlightOverlay,
        cellMap: TableCellMap,
        tableRangeID: String,
        textStorage: NSTextStorage,
        matchRanges: [NSRange],
        currentIndex: Int
    ) {
        guard let tableRange = findTableTextRange(
            for: tableRangeID, in: textStorage
        )
        else {
            highlightOverlay.findHighlightCells = []
            highlightOverlay.currentFindCell = nil
            highlightOverlay.needsDisplay = true
            highlightOverlay.displayIfNeeded()
            return
        }

        var findCells = Set<TableCellMap.CellPosition>()
        var currentCell: TableCellMap.CellPosition?

        for (index, matchRange) in matchRanges.enumerated() {
            let intersection = NSIntersectionRange(matchRange, tableRange)
            guard intersection.length > 0 else { continue }

            let relativeRange = NSRange(
                location: intersection.location - tableRange.location,
                length: intersection.length
            )
            let cells = cellMap.cellsInRange(relativeRange)
            findCells.formUnion(cells)

            if index == currentIndex, let firstCell = cells.min() {
                currentCell = firstCell
            }
        }

        highlightOverlay.findHighlightCells = findCells
        highlightOverlay.currentFindCell = currentCell
        highlightOverlay.needsDisplay = true
        highlightOverlay.displayIfNeeded()
    }

    // MARK: - Table Overlay Lifecycle

    private func removeStaleTableOverlays(keeping validIndices: Set<Int>) {
        for (index, entry) in entries where !validIndices.contains(index) {
            guard entry.tableRangeID != nil else { continue }
            entry.view.removeFromSuperview()
            entry.highlightOverlay?.removeFromSuperview()
            entries.removeValue(forKey: index)
            stickyHeaders[index]?.removeFromSuperview()
            stickyHeaders.removeValue(forKey: index)
        }
    }

    private func updateOrCreateTableOverlay(
        for info: TableOverlayInfo,
        appSettings: AppSettings,
        in textView: NSTextView
    ) {
        if let existing = entries[info.blockIndex],
           existing.tableRangeID != nil,
           blocksMatch(existing.block, info.block)
        {
            let highlight = existing.highlightOverlay
            highlight?.cellMap = info.cellMap
            entries[info.blockIndex] = OverlayEntry(
                view: existing.view,
                block: info.block,
                preferredWidth: existing.preferredWidth,
                tableRangeID: info.tableRangeID,
                highlightOverlay: highlight,
                cellMap: info.cellMap
            )
            return
        }

        entries[info.blockIndex]?.view.removeFromSuperview()
        entries[info.blockIndex]?.highlightOverlay?.removeFromSuperview()

        let visualOverlay = makeTableOverlayView(
            for: info,
            appSettings: appSettings
        )
        visualOverlay.isHidden = true
        textView.addSubview(visualOverlay)

        let highlightOverlay = TableHighlightOverlay()
        highlightOverlay.cellMap = info.cellMap
        highlightOverlay.wantsLayer = true
        highlightOverlay.isHidden = true
        textView.addSubview(
            highlightOverlay,
            positioned: .above,
            relativeTo: visualOverlay
        )

        entries[info.blockIndex] = OverlayEntry(
            view: visualOverlay,
            block: info.block,
            tableRangeID: info.tableRangeID,
            highlightOverlay: highlightOverlay,
            cellMap: info.cellMap
        )
    }

    private func makeTableOverlayView(
        for info: TableOverlayInfo,
        appSettings: AppSettings
    ) -> NSView {
        guard case let .table(columns, rows) = info.block else {
            return NSView()
        }
        let containerWidth = textView.map { textContainerWidth(in: $0) } ?? 600
        let blockIndex = info.blockIndex
        let rootView = TableBlockView(
            columns: columns,
            rows: rows,
            containerWidth: containerWidth
        ) { [weak self] width, _ in
            self?.updateTablePreferredWidth(blockIndex: blockIndex, width: width)
        }
        .environment(appSettings)
        .environment(containerState)
        return NSHostingView(rootView: rootView)
    }

    private func updateTablePreferredWidth(blockIndex: Int, width: CGFloat) {
        guard var entry = entries[blockIndex],
              entry.preferredWidth != width
        else { return }
        entry.preferredWidth = width
        entries[blockIndex] = entry
        repositionOverlays()
    }

    // MARK: - Text-Range Positioning

    func positionTextRangeEntry(
        _ entry: OverlayEntry,
        context: LayoutContext
    ) {
        guard let tableRangeID = entry.tableRangeID else {
            hideTableEntry(entry)
            return
        }

        guard let rect = boundingRect(
            for: tableRangeID, context: context
        )
        else {
            hideTableEntry(entry)
            return
        }

        let overlayWidth = entry.preferredWidth ?? context.containerWidth
        let frame = CGRect(
            x: context.origin.x,
            y: rect.origin.y + context.origin.y,
            width: overlayWidth,
            height: rect.height
        )

        entry.view.frame = frame
        entry.view.isHidden = false

        entry.highlightOverlay?.frame = frame
        entry.highlightOverlay?.isHidden = false
    }

    private func hideTableEntry(_ entry: OverlayEntry) {
        entry.view.isHidden = true
        entry.highlightOverlay?.isHidden = true
    }

    private func boundingRect(
        for tableRangeID: String,
        context: LayoutContext
    ) -> CGRect? {
        guard let tableRange = findTableTextRange(
            for: tableRangeID, in: context.textStorage
        ), tableRange.length > 0
        else { return nil }

        let docStart = context.contentManager.documentRange.location
        guard let startLoc = context.contentManager.location(
            docStart, offsetBy: tableRange.location
        ),
            let endLoc = context.contentManager.location(
                docStart, offsetBy: NSMaxRange(tableRange)
            )
        else { return nil }

        var result: CGRect?
        context.layoutManager.enumerateTextLayoutFragments(
            from: startLoc,
            options: [.ensuresLayout]
        ) { fragment in
            let fragStart = fragment.rangeInElement.location
            guard fragStart.compare(endLoc) == .orderedAscending else {
                return false
            }
            let frame = fragment.layoutFragmentFrame
            if let existing = result {
                result = existing.union(frame)
            } else {
                result = frame
            }
            return true
        }

        guard let rect = result, rect.height > 1 else { return nil }
        return rect
    }

    // MARK: - Text Range Lookup

    func findTableTextRange(
        for tableRangeID: String,
        in textStorage: NSTextStorage
    ) -> NSRange? {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        var rangeStart: Int?
        var rangeEnd = 0

        textStorage.enumerateAttribute(
            TableAttributes.range,
            in: fullRange,
            options: []
        ) { value, attrRange, stop in
            if let ident = value as? String, ident == tableRangeID {
                if rangeStart == nil {
                    rangeStart = attrRange.location
                }
                rangeEnd = attrRange.location + attrRange.length
            } else if rangeStart != nil {
                stop.pointee = true
            }
        }

        guard let start = rangeStart else { return nil }
        return NSRange(location: start, length: rangeEnd - start)
    }
}
