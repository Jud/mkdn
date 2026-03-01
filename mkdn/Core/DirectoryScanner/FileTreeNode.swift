#if os(macOS)
    import Foundation

    /// A node in the Markdown file tree.
    ///
    /// Value type for efficient SwiftUI diffing. Each node represents
    /// either a directory (with children) or a Markdown file (leaf).
    ///
    /// Children semantics for directories:
    /// - `nil`: not yet scanned (show disclosure indicator, load on expand)
    /// - `[]`: scanned but empty (no recognized text files)
    /// - `[...]`: scanned with children
    ///
    /// Files always have `nil` children.
    public struct FileTreeNode: Identifiable, Hashable, Sendable {
        public let id: URL
        public let name: String
        public let url: URL
        public let isDirectory: Bool
        // swiftlint:disable:next discouraged_optional_collection
        public var children: [Self]?
        public let depth: Int

        /// Whether this node is a truncation indicator (depth limit reached).
        public let isTruncated: Bool

        /// Whether this node's children have been loaded from disk.
        ///
        /// For directories, `true` means a scan has been performed (children
        /// may be empty). `false` means the directory has not been scanned yet.
        /// Files always return `false`.
        public var isLoaded: Bool {
            children != nil
        }

        public init(
            name: String,
            url: URL,
            isDirectory: Bool,
            depth: Int,
            isTruncated: Bool = false,
            children: [Self]? = nil // swiftlint:disable:this discouraged_optional_collection
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
#endif
