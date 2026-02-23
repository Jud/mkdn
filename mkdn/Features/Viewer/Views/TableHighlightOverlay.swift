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
///
/// Drawing implementation is provided separately (T4). This file defines
/// the structure, properties, and hit-test passthrough needed by
/// ``OverlayCoordinator`` to create and manage highlight overlays.
@MainActor
final class TableHighlightOverlay: NSView {
    var selectedCells: Set<TableCellMap.CellPosition> = []
    var findHighlightCells: Set<TableCellMap.CellPosition> = []
    var currentFindCell: TableCellMap.CellPosition?
    var cellMap: TableCellMap?

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}
