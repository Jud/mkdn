import SwiftUI

/// Individual row for a file or directory entry in the sidebar tree.
///
/// Handles selection highlight, disclosure chevron rotation,
/// depth-based indentation, and tap gestures for navigation
/// and expand/collapse.
struct SidebarRowView: View {
    let node: FileTreeNode
    @Environment(DirectoryState.self) private var directoryState
    @Environment(AppSettings.self) private var appSettings

    private var isSelected: Bool {
        !node.isDirectory && directoryState.selectedFileURL == node.url
    }

    private var isExpanded: Bool {
        directoryState.expandedDirectories.contains(node.url)
    }

    var body: some View {
        if node.isTruncated {
            truncationRow
        } else if node.isDirectory {
            directoryRow
        } else {
            fileRow
        }
    }

    // MARK: - Row Variants

    private var directoryRow: some View {
        HStack(spacing: 6) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption2)
                .foregroundStyle(appSettings.theme.colors.foregroundSecondary)
                .frame(width: 12)

            Image(systemName: "folder")
                .foregroundStyle(appSettings.theme.colors.accent)

            Text(node.name)
                .font(.callout)
                .foregroundStyle(appSettings.theme.colors.foreground)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.leading, CGFloat(node.depth) * 16 + 8)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            if isExpanded {
                directoryState.expandedDirectories.remove(node.url)
            } else {
                directoryState.expandedDirectories.insert(node.url)
            }
        }
    }

    private var fileRow: some View {
        HStack(spacing: 6) {
            Spacer()
                .frame(width: 12)

            Image(systemName: "doc.text")
                .foregroundStyle(appSettings.theme.colors.foregroundSecondary)

            Text(node.name)
                .font(.callout)
                .foregroundStyle(appSettings.theme.colors.foreground)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.leading, CGFloat(node.depth) * 16 + 8)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? appSettings.theme.colors.accent.opacity(0.2) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            directoryState.selectFile(at: node.url)
        }
    }

    private var truncationRow: some View {
        HStack(spacing: 6) {
            Spacer()
                .frame(width: 12)

            Text("...")
                .font(.callout)
                .foregroundStyle(appSettings.theme.colors.foregroundSecondary)
        }
        .padding(.leading, CGFloat(node.depth) * 16 + 8)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
