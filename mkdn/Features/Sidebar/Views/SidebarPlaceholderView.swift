import AppKit
import SwiftUI

/// Displayed in the sidebar area when no work directory is set.
///
/// Provides a button to open an ``NSOpenPanel`` for selecting a
/// directory, mirroring the visual style of ``SidebarEmptyView``.
struct SidebarPlaceholderView: View {
    let onDirectorySelected: (URL) -> Void
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.title2)
                .foregroundStyle(appSettings.theme.colors.foregroundSecondary)
            Button {
                openDirectoryPanel()
            } label: {
                Text("Set Work Directory")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .foregroundStyle(appSettings.theme.colors.foregroundSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appSettings.theme.colors.backgroundSecondary)
    }

    @MainActor
    private func openDirectoryPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        onDirectorySelected(url)
    }
}
