import Foundation

/// A caret position inside a table: a cell plus a UTF-16 offset within that
/// cell's plain text. Ordered in document order — row-major with the header
/// row (`row == -1`) first, matching how Chrome orders table content.
public struct TableTextPoint: Hashable, Comparable, Sendable {
    public let cell: CellPosition
    public let offset: Int

    public init(cell: CellPosition, offset: Int) {
        self.cell = cell
        self.offset = offset
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.cell != rhs.cell { return lhs.cell < rhs.cell }
        return lhs.offset < rhs.offset
    }
}

/// The unit a drag extends by, set from the mouse-down click count
/// (single = character, double = word, triple = whole cell) — the same
/// granularity escalation Chrome uses.
public enum TableSelectionGranularity: Sendable {
    case character
    case word
    case cell
}

/// A text selection across table cells with Chrome's semantics: the selected
/// region runs in document order from `start` to `end` — partial text in the
/// endpoint cells, the full text of every cell between them. `anchor` is
/// where the selection began; `focus` is where it currently extends, so a
/// backward drag normalizes through `start`/`end`.
public struct TableTextRange: Equatable, Sendable {
    public var anchor: TableTextPoint
    public var focus: TableTextPoint

    public init(anchor: TableTextPoint, focus: TableTextPoint) {
        self.anchor = anchor
        self.focus = focus
    }

    public var start: TableTextPoint { min(anchor, focus) }
    public var end: TableTextPoint { max(anchor, focus) }
    public var isCollapsed: Bool { anchor == focus }

    /// The portion of `cell`'s text inside the selection, as a UTF-16 range,
    /// or `nil` when the cell lies outside the selected span. Cells strictly
    /// between the endpoints are fully covered; the endpoint cells contribute
    /// the partial range on their side.
    public func selectedRange(in cell: CellPosition, textLength: Int) -> NSRange? {
        guard !isCollapsed else { return nil }
        let start = self.start
        let end = self.end
        guard cell >= start.cell, cell <= end.cell else { return nil }
        let lower = cell == start.cell ? min(start.offset, textLength) : 0
        let upper = cell == end.cell ? min(end.offset, textLength) : textLength
        guard upper >= lower else { return nil }
        return NSRange(location: lower, length: upper - lower)
    }
}
