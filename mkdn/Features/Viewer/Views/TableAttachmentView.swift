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
        @Environment(FindState.self) private var findState: FindState?
        @Environment(OverlayContainerState.self) private var containerState
        @State private var sizingCache = SizingCache()
        @State private var selectionState = TableSelectionState()

        /// Live container width so the table re-sizes on window/sidebar width
        /// changes (mirrors image/Mermaid); the captured width is the fallback.
        private var effectiveWidth: CGFloat {
            containerState.containerWidth > 0 ? containerState.containerWidth : containerWidth
        }

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
            let width = effectiveWidth
            let scale = scaleFactor
            if let cached = sizingCache.result,
               sizingCache.lastWidth == width,
               sizingCache.lastScaleFactor == scale
            {
                return cached
            }
            // The per-cell Core Text measure is width-independent; cache it per
            // scale so a width animation (comment-rail slide, window resize)
            // pays only the O(columns) fit on each frame.
            let paddedWidths: [CGFloat]
            if let cached = sizingCache.paddedWidths, sizingCache.lastScaleFactor == scale {
                paddedWidths = cached
            } else {
                paddedWidths = TableColumnSizer.measureIntrinsicPaddedWidths(
                    columns: columns,
                    rows: rows,
                    font: PlatformTypeConverter.bodyFont(scaleFactor: scale)
                )
                sizingCache.paddedWidths = paddedWidths
            }
            let result = TableColumnSizer.fit(paddedWidths: paddedWidths, containerWidth: width)
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
                .onChange(of: findState?.query) { _, newQuery in
                    updateFindHighlights(query: newQuery ?? "")
                }
                .onChange(of: findState?.currentMatchIndex) { _, _ in
                    updateFindCurrentMatch()
                }
                .onChange(of: findState?.isVisible) { _, isVisible in
                    if isVisible != true {
                        selectionState.findMatches = []
                        selectionState.currentFindMatch = nil
                    }
                }
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
                    .background(colors.border.opacity(DesignTokens.Stroke.resting))
                dataRows(columnWidths: columnWidths)
            }
            .frame(width: totalWidth)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.block))
            .overlay(
                // strokeBorder (not stroke): a centered stroke straddles the
                // shape edge by half a point, and when the table is
                // compressed to the full container width the host view's
                // clip shaves that outer half off the right edge.
                RoundedRectangle(cornerRadius: DesignTokens.Radius.block)
                    .strokeBorder(
                        colors.border.opacity(DesignTokens.Stroke.resting),
                        lineWidth: DesignTokens.Stroke.width
                    )
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("markdown-table")
            .accessibilityLabel("Table, \(columns.count) columns, \(rows.count) rows")
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
                    .accessibilityLabel("\(String(column.header.characters)), header")
                }
            }
            .background(colors.backgroundSecondary)
            .background(colors.foregroundSecondary.opacity(0.06))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Header row")
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
                        .accessibilityLabel(cellAccessibilityLabel(colIndex: colIndex, cell: cell))
                    }
                }
                .background(
                    rowIndex.isMultiple(of: 2)
                        ? colors.background
                        : colors.backgroundSecondary.opacity(0.7)
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Row \(rowIndex + 1)")
            }
        }

        /// "Header: cell text", so VoiceOver reads each cell with its column
        /// context; headerless columns fall back to the bare text.
        private func cellAccessibilityLabel(colIndex: Int, cell: AttributedString) -> String {
            let text = String(cell.characters)
            guard colIndex < columns.count else { return text }
            let header = String(columns[colIndex].header.characters)
            return header.isEmpty ? text : "\(header): \(text)"
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
                .padding(.horizontal, TableColumnSizer.horizontalCellPadding)
                .padding(.vertical, TableColumnSizer.verticalCellPadding)
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
                colors.findHighlight.opacity(DesignTokens.Tint.active)
            } else if selectionState.isFindMatch(row: row, column: column) {
                colors.findHighlight.opacity(DesignTokens.Tint.subtle)
            } else if selectionState.isSelected(row: row, column: column) {
                colors.accent.opacity(DesignTokens.Tint.resting)
            }
        }

        // MARK: - Find Integration

        private func updateFindHighlights(query: String) {
            guard let findState, findState.isVisible else {
                selectionState.findMatches = []
                selectionState.currentFindMatch = nil
                return
            }
            let matches = TableFindAdapter.findMatches(
                query: query,
                columns: columns,
                rows: rows
            )
            selectionState.findMatches = Set(matches)
            updateFindCurrentMatch()
        }

        private func updateFindCurrentMatch() {
            guard let findState, findState.isVisible else {
                selectionState.currentFindMatch = nil
                return
            }
            // The current match index is global (across the whole document).
            // Table cells don't participate in the global match index — they
            // just highlight all matches. Set currentFindMatch to nil (no
            // "current" concept for table cells, just passive highlighting).
            selectionState.currentFindMatch = nil
        }
    }

    private class SizingCache {
        var lastWidth: CGFloat = -1
        var lastScaleFactor: CGFloat = -1
        var paddedWidths: [CGFloat]? // swiftlint:disable:this discouraged_optional_collection
        var result: TableColumnSizer.Result?
    }

    extension TableColumnAlignment {
        var swiftUIAlignment: Alignment {
            switch self {
            case .left: .leading
            case .center: .center
            case .right: .trailing
            }
        }
    }
#endif
