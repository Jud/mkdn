import SwiftUI

/// Renders just the header row of a Markdown table for sticky header overlays.
///
/// Matches the visual style of `TableBlockView.headerRow`: bold text,
/// `backgroundSecondary` fill, and a bottom divider. Positioned by
/// `OverlayCoordinator` at the top of the visible table area when the
/// original header scrolls out of view.
struct TableHeaderView: View {
    let columns: [TableColumn]
    let columnWidths: [CGFloat]

    @Environment(AppSettings.self) private var appSettings

    private var colors: ThemeColors {
        appSettings.theme.colors
    }

    var body: some View {
        VStack(spacing: 0) {
            headerCells
            Divider()
                .background(colors.border)
        }
    }

    private var headerCells: some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.offset) { colIndex, column in
                Text(column.header)
                    .font(.body.bold())
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
    }
}
