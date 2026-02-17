import SwiftUI

/// Sidebar panel containing the header, scrollable file tree, and empty state.
///
/// Renders the recursive ``FileTreeNode`` tree as a flat list of
/// ``SidebarRowView`` entries, respecting the current expansion state
/// in ``DirectoryState``.
struct SidebarView: View {
    @Environment(DirectoryState.self) private var directoryState
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarHeaderView()

            Divider()
                .overlay(appSettings.theme.colors.border)

            if let tree = directoryState.tree, !tree.children.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(flattenVisibleNodes(tree)) { node in
                            SidebarRowView(node: node)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                SidebarEmptyView()
            }
        }
        .background(appSettings.theme.colors.backgroundSecondary)
    }

    // MARK: - Tree Flattening

    /// Converts a recursive ``FileTreeNode`` tree into a flat list of
    /// visible nodes, respecting directory expansion state.
    ///
    /// Only the root's children are walked (the root itself is
    /// represented by the header). Directories that are collapsed
    /// hide their children from the output.
    private func flattenVisibleNodes(_ root: FileTreeNode) -> [FileTreeNode] {
        var result: [FileTreeNode] = []
        flattenChildren(of: root, into: &result)
        return result
    }

    private func flattenChildren(of parent: FileTreeNode, into result: inout [FileTreeNode]) {
        for child in parent.children {
            result.append(child)
            if child.isDirectory, directoryState.expandedDirectories.contains(child.url) {
                flattenChildren(of: child, into: &result)
            }
        }
    }
}
