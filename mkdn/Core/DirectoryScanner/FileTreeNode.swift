import Foundation

/// A node in the Markdown file tree.
///
/// Value type for efficient SwiftUI diffing. Each node represents
/// either a directory (with children) or a Markdown file (leaf).
public struct FileTreeNode: Identifiable, Hashable, Sendable {
    public let id: URL
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public let children: [Self]
    public let depth: Int

    /// Whether this node is a truncation indicator (depth limit reached).
    public let isTruncated: Bool

    public init(
        name: String,
        url: URL,
        isDirectory: Bool,
        depth: Int,
        isTruncated: Bool = false,
        children: [Self] = []
    ) {
        id = url
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
        self.depth = depth
        self.isTruncated = isTruncated
    }
}
