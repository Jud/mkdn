import AppKit
import SwiftUI

/// Renders a Markdown table as a native SwiftUI grid with content-aware column widths.
struct TableBlockView: View {
    let columns: [TableColumn]
    let rows: [[AttributedString]]
    var containerWidth: CGFloat = 600
    var onSizeChange: ((CGFloat, CGFloat) -> Void)?

    @Environment(AppSettings.self) private var appSettings

    private var colors: ThemeColors {
        appSettings.theme.colors
    }

    private var scaleFactor: CGFloat {
        appSettings.scaleFactor
    }

    private var scaledBodyFont: Font {
        .system(size: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor).pointSize)
    }

    private var sizingResult: TableColumnSizer.Result {
        TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: containerWidth,
            font: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor)
        )
    }

    var body: some View {
        let result = sizingResult
        let columnWidths = result.columnWidths

        tableContent(columnWidths: columnWidths, needsScroll: result.needsHorizontalScroll)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                onSizeChange?(newSize.width, newSize.height)
            }
    }

    @ViewBuilder
    private func tableContent(
        columnWidths: [CGFloat],
        needsScroll: Bool
    ) -> some View {
        if needsScroll {
            ScrollView(.horizontal, showsIndicators: true) {
                tableBody(columnWidths: columnWidths)
            }
            .frame(maxWidth: containerWidth)
        } else {
            tableBody(columnWidths: columnWidths)
        }
    }

    private func tableBody(columnWidths: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow(columnWidths: columnWidths)
            Divider()
                .background(colors.border)
            dataRows(columnWidths: columnWidths)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(colors.border.opacity(0.3), lineWidth: 1)
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
                    .textSelection(.enabled)
            }
        }
        .background(colors.backgroundSecondary)
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
                        .textSelection(.enabled)
                }
            }
            .background(
                rowIndex.isMultiple(of: 2)
                    ? colors.background
                    : colors.backgroundSecondary.opacity(0.5)
            )
        }
    }
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
