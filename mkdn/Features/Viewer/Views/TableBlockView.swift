import SwiftUI

/// Renders a Markdown table as a native SwiftUI grid.
struct TableBlockView: View {
    let headers: [String]
    let rows: [[String]]

    @Environment(AppState.self) private var appState

    private var colors: ThemeColors {
        appState.theme.colors
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                        Text(header)
                            .font(.body.bold())
                            .foregroundColor(colors.headingColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(minWidth: 80, alignment: .leading)
                    }
                }
                .background(colors.backgroundSecondary)

                Divider()
                    .background(colors.border)

                // Data rows
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.body)
                                .foregroundColor(colors.foreground)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(minWidth: 80, alignment: .leading)
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
