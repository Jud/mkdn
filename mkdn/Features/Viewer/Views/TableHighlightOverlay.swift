import AppKit

/// Lightweight overlay that draws cell-level selection and find highlights
/// on top of the visual ``TableBlockView`` overlay.
///
/// All mouse events pass through to the underlying ``NSTextView`` via
/// ``hitTest(_:)`` returning `nil`. The overlay is managed by
/// ``OverlayCoordinator``, which updates ``selectedCells``,
/// ``findHighlightCells``, and ``currentFindCell`` in response to
/// selection changes and find navigation.
///
/// Cell rectangles are computed from ``TableCellMap/columnWidths`` and
/// ``TableCellMap/rowHeights``. Selection uses the system accent color;
/// find uses the theme's find highlight color.
@MainActor
final class TableHighlightOverlay: NSView {
    // MARK: - Selection State

    var selectedCells: Set<TableCellMap.CellPosition> = []

    // MARK: - Find State

    var findHighlightCells: Set<TableCellMap.CellPosition> = []
    var currentFindCell: TableCellMap.CellPosition?

    // MARK: - Data

    var cellMap: TableCellMap?

    // MARK: - Colors

    var accentColor: NSColor = .controlAccentColor
    var findHighlightColor: NSColor = .yellow

    // MARK: - Coordinate System

    override var isFlipped: Bool {
        true
    }

    // MARK: - Hit Testing

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let cellMap else { return }

        NSGraphicsContext.saveGraphicsState()
        let clipPath = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        clipPath.addClip()

        drawSelectionHighlights(cellMap: cellMap, in: dirtyRect)
        drawFindHighlights(cellMap: cellMap, in: dirtyRect)

        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: - Selection Highlights

    private func drawSelectionHighlights(
        cellMap: TableCellMap,
        in dirtyRect: NSRect
    ) {
        guard !selectedCells.isEmpty else { return }

        let selectionColor = accentColor.withAlphaComponent(0.3)

        for cell in selectedCells {
            let rect = cellRect(for: cell, cellMap: cellMap)
            guard rect.intersects(dirtyRect) else { continue }

            selectionColor.setFill()
            rect.fill()
        }
    }

    // MARK: - Find Highlights

    private func drawFindHighlights(
        cellMap: TableCellMap,
        in dirtyRect: NSRect
    ) {
        guard !findHighlightCells.isEmpty else { return }

        let passiveColor = findHighlightColor.withAlphaComponent(0.15)
        let currentColor = findHighlightColor.withAlphaComponent(0.4)

        for cell in findHighlightCells {
            let rect = cellRect(for: cell, cellMap: cellMap)
            guard rect.intersects(dirtyRect) else { continue }

            let isCurrent = cell == currentFindCell
            let color = isCurrent ? currentColor : passiveColor
            color.setFill()
            rect.fill()
        }
    }

    // MARK: - Cell Geometry

    private func cellRect(
        for position: TableCellMap.CellPosition,
        cellMap: TableCellMap
    ) -> NSRect {
        let col = position.column
        let rowHeightIndex = position.row + 1

        guard col >= 0, col < cellMap.columnWidths.count,
              rowHeightIndex >= 0, rowHeightIndex < cellMap.rowHeights.count
        else { return .zero }

        let totalEstWidth = cellMap.columnWidths.reduce(0, +)
        let totalEstHeight = cellMap.rowHeights.reduce(0, +)
        guard totalEstWidth > 0, totalEstHeight > 0 else { return .zero }

        // Scale estimated widths/heights to match the actual overlay frame,
        // which is sized to the visual TableBlockView.
        let xScale = bounds.width / totalEstWidth
        let yScale = bounds.height / totalEstHeight

        var xOrigin: CGFloat = 0
        for colIdx in 0 ..< col {
            xOrigin += cellMap.columnWidths[colIdx]
        }

        var yOrigin: CGFloat = 0
        for rowIdx in 0 ..< rowHeightIndex {
            yOrigin += cellMap.rowHeights[rowIdx]
        }

        return NSRect(
            x: xOrigin * xScale,
            y: yOrigin * yScale,
            width: cellMap.columnWidths[col] * xScale,
            height: cellMap.rowHeights[rowHeightIndex] * yScale
        )
    }
}
