import Foundation

public extension URL {
    /// Whether this URL has a Markdown file extension (`.md` or `.markdown`, case-insensitive).
    var isMarkdownFile: Bool {
        let ext = pathExtension.lowercased()
        return ext == "md" || ext == "markdown"
    }
}
