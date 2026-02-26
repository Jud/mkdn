import AppKit
import SwiftUI

/// Renders a Markdown table as a native SwiftUI grid with content-aware column widths.
struct TableBlockView: View {
    let columns: [TableColumn]
    let rows: [[AttributedString]]
    var containerWidth: CGFloat = 600
    var onSizeChange: ((CGFloat, CGFloat) -> Void)?

    @Environment(AppSettings.self) private var appSettings
    @Environment(OverlayContainerState.self) private var containerState

    private var colors: ThemeColors {
        appSettings.theme.colors
    }

    private var scaleFactor: CGFloat {
        appSettings.scaleFactor
    }

    private var scaledBodyFont: Font {
        .system(size: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor).pointSize)
    }

    private var effectiveWidth: CGFloat {
        containerState.containerWidth > 0 ? containerState.containerWidth : containerWidth
    }

    private var sizingResult: TableColumnSizer.Result {
        TableColumnSizer.computeWidths(
            columns: columns,
            rows: rows,
            containerWidth: effectiveWidth,
            font: PlatformTypeConverter.bodyFont(scaleFactor: scaleFactor)
        )
    }

    var body: some View {
        let result = sizingResult
        let columnWidths = result.columnWidths
        let totalWidth = result.totalWidth

        tableBody(columnWidths: columnWidths, totalWidth: totalWidth)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                onSizeChange?(newSize.width, newSize.height)
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
                        alignment: column.alignment.swiftUIAlignment
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
                    : colors.backgroundSecondary.opacity(0.7)
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
