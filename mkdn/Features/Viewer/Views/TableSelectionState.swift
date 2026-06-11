#if os(macOS)
    import Foundation

    /// Per-table selection and find state for attachment-based table rendering.
    ///
    /// Holds the Chrome-style text selection range plus the in-flight drag
    /// session (the segment grabbed at mouse-down and its granularity).
    /// Written by the drag gesture in `TableAttachmentView` and read by cell
    /// views for highlight rendering.
    @MainActor
    @Observable
    public final class TableSelectionState {
        /// A contiguous span of table text: collapsed for a single-click
        /// anchor, the clicked word or cell for double/triple clicks.
        public struct Segment: Equatable, Sendable {
            public var start: TableTextPoint
            public var end: TableTextPoint

            public init(start: TableTextPoint, end: TableTextPoint) {
                self.start = start
                self.end = end
            }

            public init(point: TableTextPoint) {
                start = point
                end = point
            }
        }

        // MARK: - Selection State

        /// The current text selection, or `nil` when nothing is selected.
        public var range: TableTextRange?

        /// The segment selected at mouse-down. Chrome extends a double-click
        /// drag by whole words *from the anchor word*, so the drag keeps the
        /// original segment and unions it with the segment under the pointer.
        public private(set) var dragSegment: Segment?

        /// Granularity of the in-flight drag, from the mouse-down click count.
        public private(set) var dragGranularity: TableSelectionGranularity = .character

        // MARK: - Find State

        /// Cell positions that match the current find query.
        public var findMatches: Set<CellPosition> = []

        /// The cell position of the current (active) find match, if any.
        public var currentFindMatch: CellPosition?

        // MARK: - Init

        public init() {}

        // MARK: - Selection Mutations

        /// Mouse-down: select the grabbed segment and remember it as the
        /// anchor for the drag.
        public func beginDrag(segment: Segment, granularity: TableSelectionGranularity) {
            dragSegment = segment
            dragGranularity = granularity
            range = TableTextRange(anchor: segment.start, focus: segment.end)
        }

        /// Mouse-dragged: the selection is the union of the anchor segment
        /// and the segment under the pointer, anchored on the far side —
        /// Chrome's behavior for character, word, and cell granularity alike.
        public func continueDrag(to segment: Segment) {
            guard let anchorSegment = dragSegment else { return }
            if segment.end >= anchorSegment.end {
                range = TableTextRange(anchor: anchorSegment.start, focus: segment.end)
            } else {
                range = TableTextRange(anchor: anchorSegment.end, focus: segment.start)
            }
        }

        /// Mouse-up: a click that never extended (collapsed range) clears the
        /// selection, exactly like clicking in Chrome.
        public func endDrag() {
            dragSegment = nil
            if range?.isCollapsed == true { range = nil }
        }

        /// Shift+click: keep the existing anchor, move the focus.
        public func extendSelection(to point: TableTextPoint) {
            if let existing = range {
                range = TableTextRange(anchor: existing.anchor, focus: point)
            } else {
                range = TableTextRange(anchor: point, focus: point)
            }
        }

        /// Clear the selection and any drag session.
        public func clearSelection() {
            range = nil
            dragSegment = nil
        }

        // MARK: - Query

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
    }
#endif
