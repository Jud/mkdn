#if os(macOS)
    import AppKit
    import SwiftUI
    import UniformTypeIdentifiers

    /// Renders a Markdown table inside an NSTextAttachment as a native SwiftUI grid.
    ///
    /// Visually identical to ``TableBlockView`` — same column sizing, header styling,
    /// zebra striping, and rounded border. Text selection works exactly like Chrome's:
    /// drag selects characters, crossing a cell boundary extends the selection in
    /// document order (partial endpoint cells, full cells between), double-click
    /// selects a word, triple-click a cell, Shift+click extends. Copy produces
    /// Chrome's clipboard format via ``TableClipboardSerializer``.
    struct TableAttachmentView: View {
        let columns: [TableColumn]
        let rows: [[AttributedString]]
        let blockIndex: Int
        var containerWidth: CGFloat = 600

        @Environment(AppSettings.self) private var appSettings
        @Environment(FindState.self) private var findState: FindState?
        @Environment(OverlayContainerState.self) var containerState
        @State private var sizingCache = SizingCache()
        // Shared with TableAttachmentView+Selection.swift (the selection
        // machinery is split out for file length); state can't be private
        // across the extension boundary.
        // swiftlint:disable private_swiftui_state
        @State var selectionState = TableSelectionState()
        @State var layoutStore = TableTextLayoutStore()
        @State var isDragInFlight = false
        @State var isShiftDrag = false
        // swiftlint:enable private_swiftui_state
        @State private var isCursorPushed = false

        /// Live container width so the table re-sizes on window/sidebar width
        /// changes (mirrors image/Mermaid); the captured width is the fallback.
        private var effectiveWidth: CGFloat {
            containerState.containerWidth > 0 ? containerState.containerWidth : containerWidth
        }

        var colors: ThemeColors {
            appSettings.theme.colors
        }

        var scaleFactor: CGFloat {
            appSettings.scaleFactor
        }

        private var scaledBodyFont: Font {
            .system(size: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor).pointSize)
        }

        var tableSpaceName: String {
            "mkdn-table-\(blockIndex)"
        }

        func cachedSizingResult() -> TableColumnSizer.Result {
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
            let constraints: TableColumnSizer.ColumnConstraints
            if let cached = sizingCache.constraints, sizingCache.lastScaleFactor == scale {
                constraints = cached
            } else {
                constraints = TableColumnSizer.measureConstraints(
                    columns: columns,
                    rows: rows,
                    font: PlatformTypeConverter.bodyFont(scaleFactor: scale)
                )
                sizingCache.constraints = constraints
            }
            let result = TableColumnSizer.fit(constraints: constraints, containerWidth: width)
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
                .onChange(of: containerState.tableSelectionOwner) { _, owner in
                    // One selection in the whole document, like a browser:
                    // when another table or the text view takes it, drop ours.
                    if owner != blockIndex {
                        selectionState.clearSelection()
                    }
                }
                .onAppear {
                    containerState.tableSelectionDrivers[blockIndex] = { from, to, clicks in
                        performHarnessSelection(from: from, to: to, clickCount: clicks)
                    }
                }
                .onDisappear {
                    containerState.tableSelectionDrivers[blockIndex] = nil
                    // A disappearing table releases the document selection —
                    // Cmd+C must never serialize through a dead table.
                    if containerState.tableSelectionOwner == blockIndex {
                        containerState.tableSelectionOwner = nil
                        containerState.tableSelectionPlainText = nil
                    }
                }
                .onCopyCommand {
                    guard let range = selectionState.range else { return [] }
                    let text = TableClipboardSerializer.plainText(
                        range: range,
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
            let grid = VStack(alignment: .leading, spacing: 0) {
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
            .coordinateSpace(name: tableSpaceName)
            .contentShape(Rectangle())
            // High priority so the horizontal overflow ScrollView can't
            // steal the drag: in Chrome, click-dragging in a scrollable
            // table selects text (panning is the scroll wheel's job).
            .highPriorityGesture(selectionGesture)
            .onHover { hovering in
                if hovering, !isCursorPushed {
                    isCursorPushed = true
                    NSCursor.iBeam.push()
                } else if !hovering, isCursorPushed {
                    isCursorPushed = false
                    NSCursor.pop()
                }
            }

            return Group {
                if totalWidth > effectiveWidth {
                    // Min-content widths overflow the container: columns never
                    // shrink below their longest word, the table pans instead
                    // (Chrome's overflow behavior for markdown tables).
                    ScrollView(.horizontal, showsIndicators: true) {
                        grid
                    }
                    .frame(width: effectiveWidth, alignment: .leading)
                } else {
                    grid
                }
            }
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

        // MARK: - Cell Content

        private func cellContent(
            text: some View,
            row: Int,
            column: Int,
            width: CGFloat?,
            alignment: Alignment
        ) -> some View {
            let position = CellPosition(row: row, column: column)
            let spaceName = tableSpaceName

            return text
                .tint(colors.linkColor)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, TableColumnSizer.horizontalCellPadding)
                .padding(.vertical, TableColumnSizer.verticalCellPadding)
                .frame(width: width, alignment: alignment)
                .background(cellHighlight(row: row, column: column))
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named(spaceName))
                } action: { frame in
                    layoutStore.cellFrames[position] = frame
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
        var constraints: TableColumnSizer.ColumnConstraints?
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
