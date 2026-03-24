#if os(macOS)
    import Foundation

    /// Per-table selection and find state for attachment-based table rendering.
    ///
    /// Tracks the current cell selection shape, find match positions, and focus
    /// state. Written by gesture handlers in `TableAttachmentView` and read by
    /// cell views for highlight rendering.
    @MainActor
    @Observable
    public final class TableSelectionState {
        // MARK: - Selection State

        /// The current selection shape applied to the table.
        public var selection: SelectionShape = .empty

        /// Whether this table currently has keyboard/interaction focus.
        public var isFocused = false

        // MARK: - Find State

        /// Cell positions that match the current find query.
        public var findMatches: Set<CellPosition> = []

        /// The cell position of the current (active) find match, if any.
        public var currentFindMatch: CellPosition?

        // MARK: - Init

        public init() {}

        // MARK: - Query

        /// Returns whether the cell at the given row and column is within
        /// the current selection.
        public func isSelected(row: Int, column: Int) -> Bool {
            let position = CellPosition(row: row, column: column)
            switch selection {
            case .empty:
                return false
            case let .cells(positions):
                return positions.contains(position)
            case let .rows(indexSet):
                return indexSet.contains(row)
            case let .columns(indexSet):
                return indexSet.contains(column)
            case let .rectangular(rowRange, colRange):
                return rowRange.contains(row) && colRange.contains(column)
            case .all:
                return true
            }
        }

        /// Returns whether the cell at the given row and column matches
        /// the current find query.
        public func isFindMatch(row: Int, column: Int) -> Bool {
            findMatches.contains(CellPosition(row: row, column: column))
        }

        /// Returns whether the cell at the given row and column is the
        /// current (active) find match.
        public func isCurrentFindMatch(row: Int, column: Int) -> Bool {
            currentFindMatch == CellPosition(row: row, column: column)
        }

        // MARK: - Selection Mutations

        /// Select a single cell, replacing any existing selection.
        public func selectCell(_ position: CellPosition) {
            selection = .cells([position])
            isFocused = true
        }

        /// Extend the current selection to a rectangular bounding box
        /// that includes the new position.
        ///
        /// If the current selection is empty or `.all`, falls back to
        /// selecting just the new position.
        public func extendSelection(to position: CellPosition) {
            guard let bounds = selectionBounds(including: position) else {
                selectCell(position)
                return
            }
            selection = .rectangular(rows: bounds.rows, columns: bounds.columns)
        }

        /// Computes the rectangular bounding box that encompasses both the
        /// current selection and the given position. Returns `nil` when the
        /// selection shape cannot be extended (`.empty`, `.all`, or degenerate cases).
        private func selectionBounds(
            including position: CellPosition
        ) -> (rows: Range<Int>, columns: Range<Int>)? {
            switch selection {
            case let .cells(existing) where !existing.isEmpty:
                let allPositions = existing.union([position])
                let rows = allPositions.map(\.row)
                let cols = allPositions.map(\.column)
                guard let minRow = rows.min(), let maxRow = rows.max(),
                      let minCol = cols.min(), let maxCol = cols.max()
                else { return nil }
                return (minRow ..< (maxRow + 1), minCol ..< (maxCol + 1))
            case let .rectangular(rowRange, colRange):
                let minRow = min(rowRange.lowerBound, position.row)
                let maxRow = max(rowRange.upperBound - 1, position.row)
                let minCol = min(colRange.lowerBound, position.column)
                let maxCol = max(colRange.upperBound - 1, position.column)
                return (minRow ..< (maxRow + 1), minCol ..< (maxCol + 1))
            case let .rows(indexSet):
                guard let existingMin = indexSet.min(),
                      let existingMax = indexSet.max()
                else { return nil }
                let minRow = min(existingMin, position.row)
                let maxRow = max(existingMax, position.row)
                return (minRow ..< (maxRow + 1), position.column ..< (position.column + 1))
            case let .columns(indexSet):
                guard let existingMin = indexSet.min(),
                      let existingMax = indexSet.max()
                else { return nil }
                let minCol = min(existingMin, position.column)
                let maxCol = max(existingMax, position.column)
                return (position.row ..< (position.row + 1), minCol ..< (maxCol + 1))
            default:
                return nil
            }
        }

        /// Toggle a cell in the selection (Cmd+click behavior).
        ///
        /// If the cell is currently selected, removes it. Otherwise adds it.
        /// Always uses `.cells(...)` shape.
        public func toggleCell(_ position: CellPosition) {
            switch selection {
            case let .cells(existing):
                var updated = existing
                if updated.contains(position) {
                    updated.remove(position)
                } else {
                    updated.insert(position)
                }
                selection = updated.isEmpty ? .empty : .cells(updated)
            case .empty:
                selection = .cells([position])
            default:
                // For non-cells shapes, start fresh with just this cell
                selection = .cells([position])
            }
            isFocused = true
        }

        /// Select an entire row.
        public func selectRow(_ row: Int, columnCount _: Int) {
            selection = .rows(IndexSet([row]))
            isFocused = true
        }

        /// Select an entire column.
        public func selectColumn(_ column: Int) {
            selection = .columns(IndexSet([column]))
            isFocused = true
        }

        /// Select all cells in the table.
        public func selectAll() {
            selection = .all
            isFocused = true
        }

        /// Clear the selection and unfocus the table.
        public func clearSelection() {
            selection = .empty
            isFocused = false
        }
    }
#endif
