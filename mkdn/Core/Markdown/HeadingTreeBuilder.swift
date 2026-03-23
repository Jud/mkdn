/// Stateless utility that extracts a heading tree from `[IndexedBlock]`,
/// computes breadcrumb paths, and provides flat traversals.
public enum HeadingTreeBuilder {
    // MARK: - Build Tree

    /// Build a tree of `HeadingNode` values from an array of indexed blocks.
    ///
    /// Only `.heading` blocks are extracted. A heading at level N becomes
    /// a child of the most recent heading at level < N. If no such parent
    /// exists, it becomes a root node.
    public static func buildTree(from blocks: [IndexedBlock]) -> [HeadingNode] {
        // Use class wrappers so the stack holds references, allowing
        // children to be appended after a node is pushed.
        final class MutableNode {
            let id: Int
            let title: String
            let level: Int
            let blockIndex: Int
            var children: [MutableNode] = []

            init(id: Int, title: String, level: Int, blockIndex: Int) {
                self.id = id
                self.title = title
                self.level = level
                self.blockIndex = blockIndex
            }

            func toHeadingNode() -> HeadingNode {
                HeadingNode(
                    id: id,
                    title: title,
                    level: level,
                    blockIndex: blockIndex,
                    children: children.map { $0.toHeadingNode() }
                )
            }
        }

        var roots: [MutableNode] = []
        var stack: [MutableNode] = []

        for indexedBlock in blocks {
            guard case let .heading(level, text) = indexedBlock.block else {
                continue
            }
            let title = String(text.characters)
            let node = MutableNode(
                id: indexedBlock.index,
                title: title,
                level: level,
                blockIndex: indexedBlock.index
            )

            // Pop stack entries with level >= current level.
            while let top = stack.last, top.level >= level {
                stack.removeLast()
            }

            if stack.isEmpty {
                roots.append(node)
            } else if let parent = stack.last {
                parent.children.append(node)
            }
            stack.append(node)
        }

        return roots.map { $0.toHeadingNode() }
    }

    // MARK: - Flatten

    /// Depth-first pre-order traversal of the heading tree.
    public static func flattenTree(_ tree: [HeadingNode]) -> [HeadingNode] {
        var result: [HeadingNode] = []
        for node in tree {
            flattenNode(node, into: &result)
        }
        return result
    }

    // MARK: - Breadcrumb Path

    /// Returns the ancestor chain from root to the heading containing or
    /// just before `blockIndex`.
    ///
    /// Walks the tree: for each level, includes the last heading whose
    /// `blockIndex <= targetBlockIndex`.
    public static func breadcrumbPath(to blockIndex: Int, in tree: [HeadingNode]) -> [HeadingNode] {
        var path: [HeadingNode] = []
        findBreadcrumbPath(to: blockIndex, in: tree, currentPath: &path)
        return path
    }

    // MARK: - Private Helpers

    private static func flattenNode(_ node: HeadingNode, into result: inout [HeadingNode]) {
        result.append(node)
        for child in node.children {
            flattenNode(child, into: &result)
        }
    }

    private static func findBreadcrumbPath(
        to blockIndex: Int,
        in nodes: [HeadingNode],
        currentPath: inout [HeadingNode]
    ) {
        // Find the last node at this level whose blockIndex <= target.
        guard let candidate = nodes.last(where: { $0.blockIndex <= blockIndex }) else {
            return
        }
        currentPath.append(candidate)
        // Recurse into the candidate's children.
        if !candidate.children.isEmpty {
            findBreadcrumbPath(to: blockIndex, in: candidate.children, currentPath: &currentPath)
        }
    }
}
