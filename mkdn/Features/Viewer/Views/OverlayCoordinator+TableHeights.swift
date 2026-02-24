import AppKit

/// Row height correction for table invisible text in ``OverlayCoordinator``.
///
/// The builder estimates table row heights at a fixed 600pt container width.
/// When the actual text container is wider, columns are less compressed and
/// text wraps less, producing shorter visual rows. This extension recomputes
/// row heights using the actual container width and updates the text storage
/// paragraph styles so the invisible text region matches the visual overlay.
extension OverlayCoordinator {
    // MARK: - Row Height Correction

    /// Recomputes table row heights using the actual text container width and
    /// the visual overlay's intrinsic height, then updates the invisible text
    /// paragraph styles to match.
    func adjustTableRowHeights(in textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        let containerWidth = textContainerWidth(in: textView)
        let scaleFactor = appSettings?.scaleFactor ?? 1.0
        var needsLayout = false

        for (_, entry) in entries {
            guard let tableRangeID = entry.tableRangeID,
                  let cellMap = entry.cellMap,
                  case let .table(columns, rows) = entry.block
            else { continue }

            guard let tableRange = findTableTextRange(
                for: tableRangeID, in: textStorage
            )
            else { continue }

            var corrected = correctedGeometry(
                columns: columns,
                rows: rows,
                containerWidth: containerWidth,
                scaleFactor: scaleFactor
            )

            scaleToVisualHeight(
                &corrected.rowHeights,
                visualView: entry.view
            )

            if applyRowHeights(
                corrected.rowHeights,
                in: textStorage,
                tableRange: tableRange
            ) {
                needsLayout = true
            }

            cellMap.columnWidths = corrected.columnWidths
            cellMap.rowHeights = corrected.rowHeights
        }

        if needsLayout, let layoutManager = textView.textLayoutManager {
            layoutManager.ensureLayout(for: layoutManager.documentRange)
        }
    }

    /// Scales computed row heights proportionally so their sum matches the
    /// visual overlay's intrinsic height. This compensates for the small
    /// per-row differences between `NSAttributedString.boundingRect` and
    /// SwiftUI's `Text` layout engine.
    private func scaleToVisualHeight(
        _ heights: inout [CGFloat],
        visualView: NSView
    ) {
        visualView.layoutSubtreeIfNeeded()
        let visualHeight = visualView.fittingSize.height
        guard visualHeight > 0 else { return }
        let computedTotal = heights.reduce(0, +)
        guard computedTotal > 0,
              abs(visualHeight - computedTotal) > 1
        else { return }
        let ratio = visualHeight / computedTotal
        for idx in heights.indices {
            heights[idx] = ceil(heights[idx] * ratio)
        }
    }

    // MARK: - Height Computation

    private struct CorrectedGeometry {
        let columnWidths: [CGFloat]
        var rowHeights: [CGFloat]
    }

    private func correctedGeometry(
        columns: [TableColumn],
        rows: [[AttributedString]],
        containerWidth: CGFloat,
        scaleFactor: CGFloat
    ) -> CorrectedGeometry {
        let font = PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor)
        let boldFont = NSFontManager.shared.convert(
            font, toHaveTrait: .boldFontMask
        )
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let boldLineHeight = ceil(
            boldFont.ascender - boldFont.descender + boldFont.leading
        )

        let sizer = TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: containerWidth,
            font: font
        )

        var heights: [CGFloat] = []
        let headerCells = columns.map { String($0.header.characters) }
        heights.append(wrappedRowHeight(
            cells: headerCells,
            columnWidths: sizer.columnWidths,
            font: boldFont,
            lineHeight: boldLineHeight
        ))

        let columnCount = columns.count
        for row in rows {
            let cellTexts = (0 ..< columnCount).map { colIdx in
                colIdx < row.count ? String(row[colIdx].characters) : ""
            }
            heights.append(wrappedRowHeight(
                cells: cellTexts,
                columnWidths: sizer.columnWidths,
                font: font,
                lineHeight: lineHeight
            ))
        }

        return CorrectedGeometry(
            columnWidths: sizer.columnWidths,
            rowHeights: heights
        )
    }

    private func wrappedRowHeight(
        cells: [String],
        columnWidths: [CGFloat],
        font: NSFont,
        lineHeight: CGFloat
    ) -> CGFloat {
        var maxCellHeight = lineHeight

        for (colIdx, text) in cells.enumerated() where !text.isEmpty {
            guard colIdx < columnWidths.count else { continue }
            let available = columnWidths[colIdx]
                - TableColumnSizer.totalHorizontalPadding
            guard available > 0 else { continue }

            let measured = NSAttributedString(
                string: text,
                attributes: [.font: font]
            )
            let rect = measured.boundingRect(
                with: NSSize(
                    width: available,
                    height: .greatestFiniteMagnitude
                ),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            maxCellHeight = max(maxCellHeight, ceil(rect.height))
        }

        return maxCellHeight + TableColumnSizer.verticalCellPadding * 2
    }

    // MARK: - Paragraph Style Update

    private func applyRowHeights(
        _ heights: [CGFloat],
        in textStorage: NSTextStorage,
        tableRange: NSRange
    ) -> Bool {
        // swiftlint:disable:next legacy_objc_type
        let nsString = textStorage.string as NSString
        var rowIndex = 0
        var pos = tableRange.location
        let end = NSMaxRange(tableRange)
        var changed = false

        textStorage.beginEditing()

        while pos < end, rowIndex < heights.count {
            let paraRange = nsString.paragraphRange(
                for: NSRange(location: pos, length: 0)
            )
            let targetHeight = heights[rowIndex]

            if let style = textStorage.attribute(
                .paragraphStyle, at: pos, effectiveRange: nil
            ) as? NSParagraphStyle,
                abs(style.minimumLineHeight - targetHeight) > 0.5
            {
                // swiftlint:disable:next force_cast
                let mutable = style.mutableCopy() as! NSMutableParagraphStyle
                mutable.minimumLineHeight = targetHeight
                mutable.maximumLineHeight = targetHeight
                mutable.lineBreakMode = .byClipping
                textStorage.addAttribute(
                    .paragraphStyle, value: mutable, range: paraRange
                )
                changed = true
            }

            pos = NSMaxRange(paraRange)
            rowIndex += 1
        }

        textStorage.endEditing()
        return changed
    }
}
