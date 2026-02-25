import Foundation

/// Recursively scans a directory and builds a ``FileTreeNode`` tree
/// containing only Markdown files and directories that contain them.
public enum DirectoryScanner {
    /// Scan a directory and return a ``FileTreeNode`` tree containing
    /// only Markdown files and directories that contain them.
    ///
    /// - Parameters:
    ///   - url: Root directory URL.
    ///   - maxDepth: Maximum recursion depth (default: 10).
    /// - Returns: The root ``FileTreeNode``, or `nil` if the directory
    ///   is unreadable or does not exist.
    public static func scan(url: URL, maxDepth: Int = 10) -> FileTreeNode? {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            return nil
        }

        let children = scanChildren(of: url, depth: 0, maxDepth: maxDepth, fileManager: fileManager)

        return FileTreeNode(
            name: url.lastPathComponent,
            url: url,
            isDirectory: true,
            depth: 0,
            children: children
        )
    }

    // MARK: - Private

    private static func scanChildren(
        of directoryURL: URL,
        depth: Int,
        maxDepth: Int,
        fileManager: FileManager
    ) -> [FileTreeNode] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isReadableKey],
            options: [.skipsHiddenFiles]
        )
        else {
            return []
        }

        var directories: [FileTreeNode] = []
        var files: [FileTreeNode] = []

        for itemURL in contents {
            let itemName = itemURL.lastPathComponent
            if itemName.hasPrefix(".") { continue }

            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir) else {
                continue
            }

            if isDir.boolValue {
                if let node = scanDirectory(
                    itemURL,
                    name: itemName,
                    depth: depth,
                    maxDepth: maxDepth,
                    fileManager: fileManager
                ) {
                    directories.append(node)
                }
            } else if isMarkdownFile(itemURL) {
                files.append(FileTreeNode(name: itemName, url: itemURL, isDirectory: false, depth: depth + 1))
            }
        }

        directories.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return directories + files
    }

    private static func scanDirectory(
        _ url: URL,
        name: String,
        depth: Int,
        maxDepth: Int,
        fileManager: FileManager
    ) -> FileTreeNode? {
        let childDepth = depth + 1
        if childDepth >= maxDepth {
            return truncatedDirectoryNode(url: url, name: name, depth: childDepth, fileManager: fileManager)
        }

        let children = scanChildren(of: url, depth: childDepth, maxDepth: maxDepth, fileManager: fileManager)
        guard !children.isEmpty else { return nil }

        return FileTreeNode(name: name, url: url, isDirectory: true, depth: childDepth, children: children)
    }

    private static func truncatedDirectoryNode(
        url: URL,
        name: String,
        depth: Int,
        fileManager: FileManager
    ) -> FileTreeNode? {
        guard directoryHasMarkdownFiles(at: url, fileManager: fileManager) else { return nil }

        let truncationURL = url.appendingPathComponent("...")
        let truncationNode = FileTreeNode(
            name: "...",
            url: truncationURL,
            isDirectory: false,
            depth: depth + 1,
            isTruncated: true
        )
        return FileTreeNode(name: name, url: url, isDirectory: true, depth: depth, children: [truncationNode])
    }

    private static func isMarkdownFile(_ url: URL) -> Bool {
        FileOpenCoordinator.isMarkdownURL(url)
    }

    private static func directoryHasMarkdownFiles(
        at url: URL,
        fileManager: FileManager
    ) -> Bool {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        else {
            return false
        }
        return contents.contains { isMarkdownFile($0) }
    }
}
