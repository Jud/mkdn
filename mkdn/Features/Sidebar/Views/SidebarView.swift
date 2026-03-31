#if os(macOS)
    import SwiftUI

    /// Sidebar panel containing the header, scrollable file tree, and empty state.
    ///
    /// Renders the recursive ``FileTreeNode`` tree as a flat list of
    /// ``SidebarRowView`` entries, respecting the current expansion state
    /// in ``DirectoryState``. Directories with unloaded children (`nil`)
    /// are still shown with a disclosure chevron; their children are
    /// lazily loaded when expanded.
    struct SidebarView: View {
        let onChangeDirectory: (URL) -> Void
        @Environment(DirectoryState.self) private var directoryState
        @Environment(AppSettings.self) private var appSettings

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                SidebarHeaderView(onChangeDirectory: onChangeDirectory)

                if let tree = directoryState.tree, !(tree.children ?? []).isEmpty {
                    let nodes = flattenVisibleNodes(tree)
                    if nodes.isEmpty, directoryState.gitStatusProvider.showOnlyChanged {
                        filterEmptyState
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(nodes) { node in
                                    SidebarRowView(node: node)
                                        .transition(.move(edge: .leading))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    SidebarEmptyView()
                }
            }
            .background(appSettings.theme.colors.backgroundSecondary)
        }

        // MARK: - Filter Empty State

        private var filterEmptyState: some View {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(appSettings.theme.colors.foregroundSecondary)
                Text("No changed files")
                    .font(.callout)
                    .foregroundStyle(appSettings.theme.colors.foregroundSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        // MARK: - Tree Flattening

        /// Converts a recursive ``FileTreeNode`` tree into a flat list of
        /// visible nodes, respecting directory expansion state.
        ///
        /// In filter mode (``GitStatusProvider/showOnlyChanged``), only files
        /// with git status and their ancestor directories are shown. Directories
        /// are auto-expanded. The original ``expandedDirectories`` set is preserved
        /// for when the filter is toggled off.
        private func flattenVisibleNodes(_ root: FileTreeNode) -> [FileTreeNode] {
            var result: [FileTreeNode] = []
            if directoryState.gitStatusProvider.showOnlyChanged {
                flattenChangedNodes(of: root, into: &result)
            } else {
                flattenChildren(of: root, into: &result)
            }
            return result
        }

        private func flattenChildren(of parent: FileTreeNode, into result: inout [FileTreeNode]) {
            for child in parent.children ?? [] {
                result.append(child)
                if child.isDirectory, directoryState.expandedDirectories.contains(child.url) {
                    flattenChildren(of: child, into: &result)
                }
            }
        }

        private func flattenChangedNodes(of parent: FileTreeNode, into result: inout [FileTreeNode]) {
            let provider = directoryState.gitStatusProvider
            for child in parent.children ?? [] {
                if child.isDirectory {
                    if provider.hasChangedDescendants(under: child.url) {
                        result.append(child)
                        if child.isLoaded {
                            flattenChangedNodes(of: child, into: &result)
                        }
                    }
                } else if provider.status(for: child.url) != nil {
                    result.append(child)
                }
            }
        }
    }
#endif
