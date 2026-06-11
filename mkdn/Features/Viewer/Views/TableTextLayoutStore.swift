#if os(macOS)
    import AppKit
    import SwiftUI

    /// Mirror TextKit layouts for a rendered table's cells, plus the cells'
    /// frames in the table's coordinate space — everything hit-testing a
    /// mouse point to a character offset and painting selection rects needs.
    ///
    /// The mirror uses the same fonts and wrap widths as the rendered SwiftUI
    /// `Text`, so offsets and rects line up with the drawn glyphs. Layouts are
    /// cached per cell and rebuilt only when the wrap width or scale changes,
    /// and only built at all for cells the user actually touches.
    @MainActor
    final class TableTextLayoutStore {
        /// Frames of each cell view in the table's named coordinate space,
        /// captured via `onGeometryChange`. Read imperatively during drags —
        /// deliberately not observable state.
        var cellFrames: [CellPosition: CGRect] = [:]

        private struct Entry {
            let layout: TableCellTextLayout
            let wrapWidth: CGFloat
            let scaleFactor: CGFloat
        }

        private var entries: [CellPosition: Entry] = [:]

        /// The mirror layout for a cell, built lazily and cached until the
        /// wrap width or scale factor changes.
        func layout(
            for cell: CellPosition,
            text: AttributedString,
            wrapWidth: CGFloat,
            scaleFactor: CGFloat
        ) -> TableCellTextLayout {
            if let entry = entries[cell],
               entry.wrapWidth == wrapWidth,
               entry.scaleFactor == scaleFactor
            {
                return entry.layout
            }
            let layout = TableCellTextLayout(
                text: text,
                isHeader: cell.row == -1,
                wrapWidth: wrapWidth,
                scaleFactor: scaleFactor
            )
            entries[cell] = Entry(
                layout: layout, wrapWidth: wrapWidth, scaleFactor: scaleFactor
            )
            return layout
        }

        /// The cell at `point`, clamped Chrome-style: a point in the chrome
        /// between cells (padding, divider) or outside the table maps to the
        /// nearest cell — vertical distance first, then horizontal — so a
        /// drag never dead-zones.
        func cell(at point: CGPoint) -> CellPosition? {
            guard !cellFrames.isEmpty else { return nil }
            var best: (cell: CellPosition, dy: CGFloat, dx: CGFloat)?
            for (cell, frame) in cellFrames {
                let dy = max(frame.minY - point.y, point.y - frame.maxY, 0)
                let dx = max(frame.minX - point.x, point.x - frame.maxX, 0)
                if dy == 0, dx == 0 { return cell }
                if let current = best {
                    if (dy, dx) < (current.dy, current.dx) {
                        best = (cell, dy, dx)
                    }
                } else {
                    best = (cell, dy, dx)
                }
            }
            return best?.cell
        }
    }

    /// TextKit mirror of one rendered table cell: the cell's styled text laid
    /// out at the rendered wrap width, answering caret hit-tests, word
    /// boundaries, and selection rects in text-local coordinates (origin at
    /// the text block's top-left).
    @MainActor
    final class TableCellTextLayout {
        private let storage: NSTextStorage
        private let layoutManager = NSLayoutManager()
        private let container: NSTextContainer

        /// UTF-16 length of the cell's plain text.
        let textLength: Int

        init(
            text: AttributedString,
            isHeader: Bool,
            wrapWidth: CGFloat,
            scaleFactor: CGFloat
        ) {
            let styled = Self.styledText(text, isHeader: isHeader, scaleFactor: scaleFactor)
            storage = NSTextStorage(attributedString: styled)
            container = NSTextContainer(
                size: CGSize(width: max(wrapWidth, 1), height: .greatestFiniteMagnitude)
            )
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            storage.addLayoutManager(layoutManager)
            textLength = storage.length
            layoutManager.ensureLayout(for: container)
        }

        /// Width of the laid-out text block — the rendered `Text`'s tight
        /// width, needed to offset centered/trailing column content.
        var usedWidth: CGFloat {
            layoutManager.usedRect(for: container).width
        }

        /// The whole cell as a UTF-16 range.
        var fullRange: NSRange {
            NSRange(location: 0, length: textLength)
        }

        /// UTF-16 offset of the insertion point nearest `point`, rounding to
        /// the closer side of the hit character like a real caret hit-test.
        func characterOffset(at point: CGPoint) -> Int {
            guard textLength > 0 else { return 0 }
            var fraction: CGFloat = 0
            let index = layoutManager.characterIndex(
                for: point,
                in: container,
                fractionOfDistanceBetweenInsertionPoints: &fraction
            )
            guard fraction > 0.5, index < textLength else {
                return min(max(index, 0), textLength)
            }
            // swiftlint:disable:next legacy_objc_type
            let composed = (storage.string as NSString).rangeOfComposedCharacterSequence(at: index)
            return min(composed.location + composed.length, textLength)
        }

        /// Selection rects for a UTF-16 range, in text-local coordinates —
        /// one rect per line fragment, exactly how browsers paint selection.
        func selectionRects(for range: NSRange) -> [CGRect] {
            guard range.length > 0, textLength > 0 else { return [] }
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: range, actualCharacterRange: nil
            )
            var rects: [CGRect] = []
            layoutManager.enumerateEnclosingRects(
                forGlyphRange: glyphRange,
                withinSelectedGlyphRange: glyphRange,
                in: container
            ) { rect, _ in
                rects.append(rect)
            }
            return rects
        }

        /// The word range at a UTF-16 offset (AppKit's double-click semantics).
        func wordRange(at offset: Int) -> NSRange {
            guard textLength > 0 else { return NSRange(location: 0, length: 0) }
            return storage.doubleClick(at: min(max(offset, 0), textLength - 1))
        }

        /// The cell text styled the way the rendered `Text` styles it: body
        /// font (bold for headers), with bold/italic/code presentation
        /// intents applied per run — the exact attributed string the column
        /// sizer measures, so wrap points always agree.
        private static func styledText(
            _ content: AttributedString,
            isHeader: Bool,
            scaleFactor: CGFloat
        ) -> NSAttributedString {
            let bodyFont = PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor)
            let baseFont = isHeader
                ? PlatformTypeConverter.convertFont(bodyFont, toHaveTrait: .bold)
                : bodyFont
            return TableColumnSizer.styledText(content, baseFont: baseFont)
        }
    }
#endif
