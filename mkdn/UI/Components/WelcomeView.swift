import SwiftUI

/// Welcome screen shown when no file is open.
///
/// Adapts its icon and message based on whether the window is in directory
/// mode (sidebar visible) or single-file mode. In directory mode, the
/// instruction rows are hidden and the message guides the user to select
/// a file from the sidebar.
struct WelcomeView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.isDirectoryMode) private var isDirectoryMode

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isDirectoryMode ? "sidebar.left" : "doc.richtext")
                .font(.system(size: 64))
                .foregroundColor(appSettings.theme.colors.foregroundSecondary)

            Text("mkdn")
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundColor(appSettings.theme.colors.headingColor)

            Text(
                isDirectoryMode
                    ? "Select a file from the sidebar to begin reading"
                    : "Open a Markdown file to get started"
            )
            .font(.body)
            .foregroundColor(appSettings.theme.colors.foregroundSecondary)

            if !isDirectoryMode {
                VStack(alignment: .leading, spacing: 8) {
                    instructionRow(
                        icon: "doc",
                        text: "Drag and drop a .md file here"
                    )
                    instructionRow(
                        icon: "command",
                        text: "Press Cmd+O to open a file"
                    )
                    instructionRow(
                        icon: "terminal",
                        text: "Run: mkdn file.md"
                    )
                }
                .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appSettings.theme.colors.background)
    }

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(appSettings.theme.colors.accent)
            Text(text)
                .font(.callout)
                .foregroundColor(appSettings.theme.colors.foreground)
        }
    }
}
