#if os(macOS)
    import AppKit
    import SwiftUI

    /// Displays git status info and the root directory name at the top of the sidebar.
    ///
    /// Layout:
    /// ```
    /// ┌─────────────────────────┐
    /// │ ⎇ main    [7] ☰        │  ← git info line (when in a repo)
    /// │ 📁 my-project           │  ← folder line (always)
    /// └─────────────────────────┘
    /// ```
    struct SidebarHeaderView: View {
        let onChangeDirectory: (URL) -> Void
        @Environment(DirectoryState.self) private var directoryState
        @Environment(DocumentState.self) private var documentState
        @Environment(AppSettings.self) private var appSettings
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private var motion: MotionPreference {
            MotionPreference(reduceMotion: reduceMotion)
        }

        private var gitStatusProvider: GitStatusProvider {
            directoryState.gitStatusProvider
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                if gitStatusProvider.isGitRepository {
                    gitInfoLine
                }

                folderLine
            }
        }

        // MARK: - Git Info Line

        private var gitInfoLine: some View {
            let changeCount = gitStatusProvider.changedFileCount
            return HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.body)
                    .foregroundStyle(appSettings.theme.colors.foreground.opacity(0.7))

                Text(gitStatusProvider.branchName ?? "detached")
                    .font(.body.monospaced().weight(.medium))
                    .foregroundStyle(appSettings.theme.colors.foreground)
                    .lineLimit(1)

                if changeCount > 0 {
                    countBadge(changeCount)
                    filterToggle
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }

        private func countBadge(_ count: Int) -> some View {
            Text("\(count)")
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(appSettings.theme.colors.foreground.opacity(0.7))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(appSettings.theme.colors.foreground.opacity(0.12))
                )
        }

        private var filterToggle: some View {
            Button {
                if !gitStatusProvider.showOnlyChanged {
                    Task { @MainActor in
                        let results = await directoryState.scanChangedDirectories()
                        withAnimation(motion.resolved(.quickSettle)) {
                            directoryState.applyScannedDirectories(results)
                            gitStatusProvider.showOnlyChanged = true
                        }
                    }
                } else {
                    withAnimation(motion.resolved(.quickSettle)) {
                        gitStatusProvider.showOnlyChanged = false
                    }
                }
            } label: {
                Image(
                    systemName: gitStatusProvider.showOnlyChanged
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle"
                )
                .font(.title3)
                .foregroundStyle(
                    gitStatusProvider.showOnlyChanged
                        ? appSettings.theme.colors.accent
                        : appSettings.theme.colors.foreground.opacity(0.6)
                )
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                gitStatusProvider.showOnlyChanged
                    ? "Show all files"
                    : "Show only changed files"
            )
        }

        // MARK: - Folder Line

        private var folderLine: some View {
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
