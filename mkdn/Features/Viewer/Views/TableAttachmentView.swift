#if os(macOS)
    import AppKit
    import SwiftUI

    /// Renders a Markdown table inside an NSTextAttachment as a native SwiftUI grid.
    ///
    /// Visually identical to ``TableBlockView`` — same column sizing, header styling,
    /// zebra striping, and rounded border. This view is designed for use inside an
    /// ``NSTextAttachmentViewProvider`` (T4) rather than the overlay coordinator.
    ///
    /// Selection, find highlighting, and copy support will be added in T4 after
    /// ``TableSelectionState`` and ``TableClipboardSerializer`` are merged.
    struct TableAttachmentView: View {
        let columns: [TableColumn]
        let rows: [[AttributedString]]
        let blockIndex: Int
        var containerWidth: CGFloat = 600

        @Environment(AppSettings.self) private var appSettings
        @State private var sizingCache = SizingCache()

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
                    Text(column.header)
                        .font(scaledBodyFont.bold())
                        .foregroundColor(colors.headingColor)
                        .tint(colors.linkColor)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6)
                        .frame(
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
                        Text(cell)
                            .font(scaledBodyFont)
                            .foregroundColor(colors.foreground)
                            .tint(colors.linkColor)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 6)
                            .frame(
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
    }

    private class SizingCache {
        var lastWidth: CGFloat = -1
        var lastScaleFactor: CGFloat = -1
        var result: TableColumnSizer.Result?
    }
#endif
