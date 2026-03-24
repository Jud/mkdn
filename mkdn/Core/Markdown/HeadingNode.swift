/// Tree node representing a heading in the document outline.
public struct HeadingNode: Identifiable, Sendable, Equatable {
    /// Same as `blockIndex` — unique per heading, no UUID allocation needed.
    public let id: Int
    /// Plain text of the heading (stripped from AttributedString).
    public let title: String
    /// Heading level, 1-6.
    public let level: Int
    /// `IndexedBlock.index` for scroll targeting.
    public let blockIndex: Int
    /// Sub-headings nested under this heading.
    public var children: [Self]

    public init(id: Int, title: String, level: Int, blockIndex: Int, children: [Self] = []) {
        self.id = id
        self.title = title
        self.level = level
        self.blockIndex = blockIndex
        self.children = children
    }
}
