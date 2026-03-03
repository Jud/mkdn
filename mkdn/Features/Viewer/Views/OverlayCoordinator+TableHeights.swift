#if os(macOS)
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
            var modifiedRanges: [NSRange] = []

            for (_, entry) in entries {
                guard let tableRangeID = entry.tableRangeID,
                      let cellMap = entry.cellMap,
                      case let .table(columns, rows) = entry.block
                else { continue }

                guard let tableRange = findTableTextRange(
                    for: tableRangeID
                )
                else { continue }

                let corrected = correctedGeometry(
                    columns: columns,
                    rows: rows,
                    containerWidth: containerWidth,
                    scaleFactor: scaleFactor
                )

                if applyRowHeights(
                    corrected.rowHeights,
                    columns: columns,
                    columnWidths: corrected.columnWidths,
                    in: textStorage,
                    tableRange: tableRange
                ) {
                    modifiedRanges.append(tableRange)
                }

                cellMap.columnWidths = corrected.columnWidths
                cellMap.rowHeights = corrected.rowHeights
            }

            if !modifiedRanges.isEmpty,
               let layoutManager = textView.textLayoutManager,
               let contentManager = layoutManager.textContentManager
            {
                let docStart = layoutManager.documentRange.location
                for range in modifiedRanges {
                    if let start = contentManager.location(docStart, offsetBy: range.location),
                       let end = contentManager.location(docStart, offsetBy: NSMaxRange(range)),
                       let textRange = NSTextRange(location: start, end: end)
                    {
                        layoutManager.invalidateLayout(for: textRange)
                    }
                }
            }
        }

        /// Distributes the SwiftUI-reported visual height proportionally across
        /// rows and writes the result to the text storage paragraph styles.
        /// A convergence guard (2pt threshold) prevents feedback loops.
        func applyVisualHeight(blockIndex: Int, height: CGFloat) {
            guard var entry = entries[blockIndex],
                  let tableRangeID = entry.tableRangeID,
                  let cellMap = entry.cellMap,
                  case let .table(columns, rows) = entry.block
            else { return }

            if let lastHeight = entry.lastAppliedVisualHeight,
               abs(lastHeight - height) <= 2
            {
                return
            }

            guard let textView,
                  let textStorage = textView.textStorage
            else { return }

            guard let tableRange = findTableTextRange(for: tableRangeID)
            else { return }

            let containerWidth = textContainerWidth(in: textView)
            let scaleFactor = appSettings?.scaleFactor ?? 1.0

            let corrected = correctedGeometry(
                columns: columns,
                rows: rows,
                containerWidth: containerWidth,
                scaleFactor: scaleFactor
            )

            let distributed = distributeHeights(
                corrected.rowHeights, toTotal: height
            )

            if applyRowHeights(
                distributed,
                columns: columns,
                columnWidths: corrected.columnWidths,
                in: textStorage,
                tableRange: tableRange
            ) {
                invalidateTableLayout(tableRange, in: textView)
            }

            cellMap.columnWidths = corrected.columnWidths
            cellMap.rowHeights = distributed

            entry.lastAppliedVisualHeight = height
            entries[blockIndex] = entry
        }

        private func distributeHeights(
            _ rowHeights: [CGFloat],
            toTotal targetHeight: CGFloat
        ) -> [CGFloat] {
            let computedTotal = rowHeights.reduce(0, +)
            guard computedTotal > 0 else { return rowHeights }
            let ratio = targetHeight / computedTotal
            var distributed = rowHeights.map { floor($0 * ratio) }
            let distributedTotal = distributed.reduce(0, +)
            if !distributed.isEmpty {
                distributed[distributed.count - 1] += targetHeight - distributedTotal
            }
            return distributed
        }

        private func invalidateTableLayout(
            _ tableRange: NSRange, in textView: NSTextView
        ) {
            guard let layoutManager = textView.textLayoutManager,
                  let contentManager = layoutManager.textContentManager
            else { return }
            let docStart = layoutManager.documentRange.location
            if let start = contentManager.location(docStart, offsetBy: tableRange.location),
               let end = contentManager.location(docStart, offsetBy: NSMaxRange(tableRange)),
               let textRange = NSTextRange(location: start, end: end)
            {
                layoutManager.invalidateLayout(for: textRange)
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
            columns: [TableColumn],
            columnWidths: [CGFloat],
            in textStorage: NSTextStorage,
            tableRange: NSRange
        ) -> Bool {
            let newTabStops = MarkdownTextStorageBuilder.buildTableTabStops(
                columns: columns, columnWidths: columnWidths
            )
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
                ) as? NSParagraphStyle {
                    let heightDiffers = abs(style.minimumLineHeight - targetHeight) > 0.5
                    let tabsDiffer = style.tabStops != newTabStops

                    if heightDiffers || tabsDiffer {
                        // swiftlint:disable:next force_cast
                        let mutable = style.mutableCopy() as! NSMutableParagraphStyle
                        mutable.minimumLineHeight = targetHeight
                        mutable.maximumLineHeight = targetHeight
                        mutable.lineBreakMode = .byClipping
                        mutable.tabStops = newTabStops
                        textStorage.addAttribute(
                            .paragraphStyle, value: mutable, range: paraRange
                        )
                        changed = true
                    }
                }

                pos = NSMaxRange(paraRange)
                rowIndex += 1
            }

            textStorage.endEditing()
            return changed
        }
    }
#endif
