import SwiftUI

/// Displayed when the directory contains no recognized text files.
struct SidebarEmptyView: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundStyle(appSettings.theme.colors.foregroundSecondary)
            Text("No text files found")
                .font(.callout)
                .foregroundStyle(appSettings.theme.colors.foregroundSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
