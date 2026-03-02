#if os(macOS)
    import AppKit
    import SwiftUI

    /// Displayed in the sidebar area when no work directory is set.
    ///
    /// Provides a button to open an ``NSOpenPanel`` for selecting a
    /// directory, mirroring the visual style of ``SidebarEmptyView``.
    struct SidebarPlaceholderView: View {
        let onDirectorySelected: (URL) -> Void
        @Environment(AppSettings.self) private var appSettings
        @Environment(DocumentState.self) private var documentState

        var body: some View {
            Button {
                openDirectoryPanel()
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.title2)
                    Text("Set Work Directory")
                        .font(.callout)
                }
                .foregroundStyle(appSettings.theme.colors.foregroundSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .background(appSettings.theme.colors.backgroundSecondary)
        }

        @MainActor
        private func openDirectoryPanel() {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false

            if let fileURL = documentState.currentFileURL {
                panel.directoryURL = fileURL.deletingLastPathComponent()
            }

            guard panel.runModal() == .OK, let url = panel.url else { return }
            onDirectorySelected(url)
        }
    }
#endif
