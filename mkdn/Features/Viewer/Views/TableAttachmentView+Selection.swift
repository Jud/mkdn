#if os(macOS)
    import AppKit
    import SwiftUI

    /// Chrome-parity text selection for ``TableAttachmentView``: the drag
    /// gesture, point-to-caret hit-testing through the mirror TextKit
    /// layouts, single-global-selection arbitration, and the glyph-run
    /// highlight painting.
    extension TableAttachmentView {
        /// The same color the document text view paints selection with
        /// (`selectedTextAttributes` in SelectableTextView), so the single
        /// app-wide selection reads as one continuous concept.
        private var selectionColor: Color {
            colors.accent.opacity(0.3)
        }

        // MARK: - Selection Gesture

        /// One drag gesture over the whole grid, Chrome-style: mouse-down
        /// anchors (with click-count granularity), dragging extends — across
        /// cell boundaries in document order — and a plain click clears.
        var selectionGesture: some Gesture {
            DragGesture(minimumDistance: 0, coordinateSpace: .named(tableSpaceName))
                .onChanged { value in
                    guard let point = textPoint(at: value.location) else { return }
                    if !isDragInFlight {
                        isDragInFlight = true
                        let event = NSApp.currentEvent
                        beginSelection(
                            at: point,
                            clickCount: event?.clickCount ?? 1,
                            shiftPressed: event?.modifierFlags.contains(.shift) == true
                        )
                    } else if isShiftDrag {
                        selectionState.extendSelection(to: point)
                    } else {
                        selectionState.continueDrag(
                            to: segment(at: point, granularity: selectionState.dragGranularity)
                        )
                    }
                }
                .onEnded { _ in
                    isDragInFlight = false
                    isShiftDrag = false
                    selectionState.endDrag()
                    if selectionState.range == nil {
                        releaseSelectionOwnership()
                    }
                }
        }

        private func beginSelection(at point: TableTextPoint, clickCount: Int, shiftPressed: Bool) {
            claimSelectionOwnership()
            if shiftPressed, selectionState.range != nil {
                isShiftDrag = true
                selectionState.extendSelection(to: point)
                return
            }
            let granularity: TableSelectionGranularity = switch clickCount {
            case ...1: .character
            case 2: .word
            default: .cell
            }
            selectionState.beginDrag(
                segment: segment(at: point, granularity: granularity),
                granularity: granularity
            )
        }

        /// Test-harness entry: runs the exact selection sequence the drag
        /// gesture produces, from table-local points — synthetic events reach
        /// AppKit but never SwiftUI's gesture system, so the harness calls
        /// the logic directly (see `OverlayContainerState.tableSelectionDrivers`).
        func performHarnessSelection(from: CGPoint, to: CGPoint, clickCount: Int) -> Bool {
            guard let start = textPoint(at: from) else { return false }
            beginSelection(at: start, clickCount: clickCount, shiftPressed: false)
            if to != from,
               let end = textPoint(at: to)
            {
                selectionState.continueDrag(
                    to: segment(at: end, granularity: selectionState.dragGranularity)
                )
            }
            selectionState.endDrag()
            if selectionState.range == nil {
                releaseSelectionOwnership()
            }
            return true
        }

        /// The selection unit grabbed at `point`: the bare caret position, the
        /// word around it, or the whole cell.
        private func segment(
            at point: TableTextPoint,
            granularity: TableSelectionGranularity
        ) -> TableSelectionState.Segment {
            switch granularity {
            case .character:
                return .init(point: point)
            case .word:
                let word = cellLayout(point.cell).wordRange(at: point.offset)
                return .init(
                    start: TableTextPoint(cell: point.cell, offset: word.location),
                    end: TableTextPoint(cell: point.cell, offset: word.location + word.length)
                )
            case .cell:
                return .init(
                    start: TableTextPoint(cell: point.cell, offset: 0),
                    end: TableTextPoint(cell: point.cell, offset: cellLayout(point.cell).textLength)
                )
            }
        }

        // MARK: - Hit Testing

        /// Maps a point in table space to a caret position. Points in cell
        /// chrome clamp to the nearest cell; points above/below the table run
        /// the selection to the table's start/end, exactly like Chrome.
        private func textPoint(at location: CGPoint) -> TableTextPoint? {
            let frames = layoutStore.cellFrames
            guard !frames.isEmpty, !columns.isEmpty else { return nil }
            let tableTop = frames.values.lazy.map(\.minY).min() ?? 0
            let tableBottom = frames.values.lazy.map(\.maxY).max() ?? 0
            if location.y < tableTop {
                return TableTextPoint(cell: CellPosition(row: -1, column: 0), offset: 0)
            }
            if location.y > tableBottom {
                let last = CellPosition(
                    row: rows.isEmpty ? -1 : rows.count - 1,
                    column: columns.count - 1
                )
                return TableTextPoint(cell: last, offset: cellLayout(last).textLength)
            }
            guard let cell = layoutStore.cell(at: location),
                  let frame = frames[cell]
            else { return nil }
            let layout = cellLayout(cell)
            let local = CGPoint(
                x: location.x - frame.minX - textOriginX(layout: layout, cell: cell),
                y: location.y - frame.minY - TableColumnSizer.verticalCellPadding
            )
            return TableTextPoint(cell: cell, offset: layout.characterOffset(at: local))
        }

        private func cellContentString(_ cell: CellPosition) -> AttributedString {
            if cell.row == -1 {
                return cell.column < columns.count
                    ? columns[cell.column].header
                    : AttributedString()
            }
            guard cell.row >= 0, cell.row < rows.count, cell.column < rows[cell.row].count
            else { return AttributedString() }
            return rows[cell.row][cell.column]
        }

        private func cellLayout(_ cell: CellPosition) -> TableCellTextLayout {
            let widths = cachedSizingResult().columnWidths
            let cellWidth = cell.column < widths.count
                ? widths[cell.column]
                : TableColumnSizer.totalHorizontalPadding
            return layoutStore.layout(
                for: cell,
                text: cellContentString(cell),
                wrapWidth: max(cellWidth - TableColumnSizer.totalHorizontalPadding, 1),
                scaleFactor: scaleFactor
            )
        }

        /// X of the text block inside its cell: padding plus the block's
        /// alignment offset (a centered/trailing `Text` narrower than the
        /// column sits off the padding edge).
        private func textOriginX(layout: TableCellTextLayout, cell: CellPosition) -> CGFloat {
            let widths = cachedSizingResult().columnWidths
            let cellWidth = cell.column < widths.count ? widths[cell.column] : 0
            let available = max(cellWidth - TableColumnSizer.totalHorizontalPadding, 0)
            let alignment = cell.column < columns.count ? columns[cell.column].alignment : .left
            switch alignment {
            case .left:
                return TableColumnSizer.horizontalCellPadding
            case .center:
                return TableColumnSizer.horizontalCellPadding
                    + max(0, (available - layout.usedWidth) / 2)
            case .right:
                return TableColumnSizer.horizontalCellPadding
                    + max(0, available - layout.usedWidth)
            }
        }

        // MARK: - Single Global Selection

        private func claimSelectionOwnership() {
            containerState.tableSelectionOwner = blockIndex
            containerState.clearDocumentSelection?()
            let columns = columns
            let rows = rows
            containerState.tableSelectionPlainText = { [weak selectionState] in
                guard let selectionState, let range = selectionState.range else { return nil }
                return TableClipboardSerializer.plainText(
                    range: range, columns: columns, rows: rows
                )
            }
        }

        private func releaseSelectionOwnership() {
            guard containerState.tableSelectionOwner == blockIndex else { return }
            containerState.tableSelectionOwner = nil
            containerState.tableSelectionPlainText = nil
        }

        // MARK: - Highlight Painting

        /// Find matches fill the whole cell (a navigation aid, not a text
        /// range); the text selection paints per-line rects over the glyph
        /// runs only — the way browsers paint selection.
        @ViewBuilder
        func cellHighlight(row: Int, column: Int) -> some View {
            ZStack(alignment: .topLeading) {
                if selectionState.isCurrentFindMatch(row: row, column: column) {
                    colors.findHighlight.opacity(DesignTokens.Tint.active)
                } else if selectionState.isFindMatch(row: row, column: column) {
                    colors.findHighlight.opacity(DesignTokens.Tint.subtle)
                }
                selectionRects(row: row, column: column)
            }
        }

        @ViewBuilder
        private func selectionRects(row: Int, column: Int) -> some View {
            let position = CellPosition(row: row, column: column)
            if let range = selectionState.range, !range.isCollapsed,
               position >= range.start.cell, position <= range.end.cell
            {
                let layout = cellLayout(position)
                if let nsRange = range.selectedRange(in: position, textLength: layout.textLength),
                   nsRange.length > 0
                {
                    let originX = textOriginX(layout: layout, cell: position)
                    let rects = layout.selectionRects(for: nsRange).map { rect in
                        rect.offsetBy(dx: originX, dy: TableColumnSizer.verticalCellPadding)
                    }
                    Canvas { context, _ in
                        for rect in rects {
                            context.fill(Path(rect), with: .color(selectionColor))
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
    }
#endif
