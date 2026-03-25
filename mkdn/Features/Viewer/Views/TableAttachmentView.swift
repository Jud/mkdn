#if os(macOS)
    import AppKit
    import SwiftUI
    import UniformTypeIdentifiers

    /// Renders a Markdown table inside an NSTextAttachment as a native SwiftUI grid.
    ///
    /// Visually identical to ``TableBlockView`` — same column sizing, header styling,
    /// zebra striping, and rounded border. Supports cell selection (click, Cmd+click,
    /// Shift+click), find highlighting, and copy-to-clipboard via
    /// ``TableClipboardSerializer``.
    struct TableAttachmentView: View {
        let columns: [TableColumn]
        let rows: [[AttributedString]]
        let blockIndex: Int
        var containerWidth: CGFloat = 600

        @Environment(AppSettings.self) private var appSettings
        @State private var sizingCache = SizingCache()
        @State private var selectionState = TableSelectionState()

        private var colors: ThemeColors {
            appSettings.theme.colors
        }

        private var scaleFactor: CGFloat {
            appSettings.scaleFactor
        }

        private var scaledBodyFont: Font {
            .system(size: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor).pointSize)
        }

        private func cachedSizingResult() -> TableColumnSizer.Result {
            let width = containerWidth
            let scale = scaleFactor
            if let cached = sizingCache.result,
               sizingCache.lastWidth == width,
               sizingCache.lastScaleFactor == scale
            {
                return cached
            }
            let result = TableColumnSizer.computeWidths(
                columns: columns,
                rows: rows,
                containerWidth: width,
                font: PlatformTypeConverter.bodyFont(scaleFactor: scale)
            )
            sizingCache.lastWidth = width
            sizingCache.lastScaleFactor = scale
            sizingCache.result = result
            return result
        }

        var body: some View {
            let result = cachedSizingResult()
            let columnWidths = result.columnWidths
            let totalWidth = result.totalWidth

            tableBody(columnWidths: columnWidths, totalWidth: totalWidth)
                .onCopyCommand {
                    let text = TableClipboardSerializer.tabDelimitedText(
                        selection: selectionState.selection,
                        columns: columns,
                        rows: rows
                    )
                    guard !text.isEmpty else { return [] }
                    let provider = NSItemProvider(
                        item: text as NSString, // swiftlint:disable:this legacy_objc_type
                        typeIdentifier: UTType.utf8PlainText.identifier
                    )
                    return [provider]
                }
        }

        private func tableBody(columnWidths: [CGFloat], totalWidth: CGFloat) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                headerRow(columnWidths: columnWidths)
                Divider()
                    .background(colors.border)
                dataRows(columnWidths: columnWidths)
            }
            .frame(width: totalWidth)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(colors.border.opacity(0.5), lineWidth: 1)
            )
        }

        private func headerRow(columnWidths: [CGFloat]) -> some View {
            HStack(spacing: 0) {
                ForEach(Array(columns.enumerated()), id: \.offset) { colIndex, column in
                    cellContent(
                        text: Text(column.header)
                            .font(scaledBodyFont.bold())
                            .foregroundColor(colors.headingColor),
                        row: -1,
                        column: colIndex,
                        width: colIndex < columnWidths.count ? columnWidths[colIndex] : nil,
                        alignment: column.alignment.swiftUIAlignment
                    )
                }
            }
            .background(colors.backgroundSecondary)
            .background(colors.foregroundSecondary.opacity(0.06))
        }

        private func dataRows(columnWidths: [CGFloat]) -> some View {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                        let alignment = colIndex < columns.count
                            ? columns[colIndex].alignment.swiftUIAlignment
                            : .leading
                        cellContent(
                            text: Text(cell)
                                .font(scaledBodyFont)
                                .foregroundColor(colors.foreground),
                            row: rowIndex,
                            column: colIndex,
                            width: colIndex < columnWidths.count
                                ? columnWidths[colIndex] : nil,
                            alignment: alignment
                        )
                    }
                }
                .background(
                    rowIndex.isMultiple(of: 2)
                        ? colors.background
                        : colors.backgroundSecondary.opacity(0.7)
                )
            }
        }

        // MARK: - Cell Content with Selection/Find

        private func cellContent(
            text: some View,
            row: Int,
            column: Int,
            width: CGFloat?,
            alignment: Alignment
        ) -> some View {
            let position = CellPosition(row: row, column: column)

            return text
                .tint(colors.linkColor)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .frame(width: width, alignment: alignment)
                .background(cellHighlight(row: row, column: column))
                .contentShape(Rectangle())
                .onTapGesture {
                    let flags = NSApp.currentEvent?.modifierFlags ?? []
                    if flags.contains(.command) {
                        selectionState.toggleCell(position)
                    } else if flags.contains(.shift) {
                        selectionState.extendSelection(to: position)
                    } else {
                        selectionState.selectCell(position)
                    }
                }
        }

        @ViewBuilder
        private func cellHighlight(row: Int, column: Int) -> some View {
            if selectionState.isCurrentFindMatch(row: row, column: column) {
                Color.yellow.opacity(0.4)
            } else if selectionState.isFindMatch(row: row, column: column) {
                Color.yellow.opacity(0.15)
            } else if selectionState.isSelected(row: row, column: column) {
                Color.accentColor.opacity(0.3)
            }
        }
    }

    private class SizingCache {
        var lastWidth: CGFloat = -1
        var lastScaleFactor: CGFloat = -1
        var result: TableColumnSizer.Result?
    }
#endif
