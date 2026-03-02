#if os(macOS)
    import AppKit
    import SwiftUI

    /// Displays the root directory name at the top of the sidebar panel.
    /// Clicking the header opens an ``NSOpenPanel`` to change the working directory.
    struct SidebarHeaderView: View {
        let onChangeDirectory: (URL) -> Void
        @Environment(DirectoryState.self) private var directoryState
        @Environment(DocumentState.self) private var documentState
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
            .onTapGesture {
                openDirectoryPanel()
            }
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }

        @MainActor
        private func openDirectoryPanel() {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.directoryURL = directoryState.rootURL

            guard panel.runModal() == .OK, let url = panel.url else { return }
            onChangeDirectory(url)
        }
    }
#endif
