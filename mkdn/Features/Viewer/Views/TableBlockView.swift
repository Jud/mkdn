import SwiftUI

/// Renders a Markdown table as a native SwiftUI grid.
struct TableBlockView: View {
    let columns: [TableColumn]
    let rows: [[AttributedString]]

    @Environment(AppState.self) private var appState

    private var colors: ThemeColors {
        appState.theme.colors
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                        Text(column.header)
                            .font(.body.bold())
                            .foregroundColor(colors.headingColor)
                            .tint(colors.linkColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(minWidth: 80, alignment: column.alignment.swiftUIAlignment)
                    }
                }
                .background(colors.backgroundSecondary)

                Divider()
                    .background(colors.border)

                // Data rows
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                            let alignment = colIndex < columns.count
                                ? columns[colIndex].alignment.swiftUIAlignment
                                : .leading
                            Text(cell)
                                .font(.body)
                                .foregroundColor(colors.foreground)
                                .tint(colors.linkColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(minWidth: 80, alignment: alignment)
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
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(colors.border.opacity(0.3), lineWidth: 1)
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
