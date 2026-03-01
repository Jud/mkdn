#if os(iOS)
    import SwiftUI
    import UIKit

    /// Renders a Markdown table as a native SwiftUI grid on iOS.
    ///
    /// Uses ``TableColumnSizer`` for content-aware column widths. Wide tables
    /// that exceed the available width are horizontally scrollable. Alternating
    /// row backgrounds and a styled header row match the macOS table appearance.
    struct TableBlockViewiOS: View {
        let columns: [TableColumn]
        let rows: [[AttributedString]]
        let theme: AppTheme
        let scaleFactor: CGFloat

        private var colors: ThemeColors {
            theme.colors
        }

        private var scaledBodyFont: Font {
            .system(size: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor).pointSize)
        }

        var body: some View {
            let result = TableColumnSizer.computeWidths(
                columns: columns,
                rows: rows,
                containerWidth: UIScreen.main.bounds.width - 32,
                font: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor)
            )
            let columnWidths = result.columnWidths
            let totalWidth = result.totalWidth

            ScrollView(.horizontal, showsIndicators: true) {
                tableBody(columnWidths: columnWidths, totalWidth: totalWidth)
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
                            alignment: column.alignment.swiftUIAlignmentiOS
                        )
                        .textSelection(.enabled)
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
                            ? columns[colIndex].alignment.swiftUIAlignmentiOS
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
                            .textSelection(.enabled)
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

    // MARK: - TableColumnAlignment Extension

    extension TableColumnAlignment {
        var swiftUIAlignmentiOS: Alignment {
            switch self {
            case .left: .leading
            case .center: .center
            case .right: .trailing
            }
        }
    }
#endif
