import SwiftUI

/// Displays the root directory name at the top of the sidebar panel.
struct SidebarHeaderView: View {
    @Environment(DirectoryState.self) private var directoryState
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(appSettings.theme.colors.accent)
            Text(directoryState.rootURL.lastPathComponent)
                .font(.headline)
                .foregroundStyle(appSettings.theme.colors.headingColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
