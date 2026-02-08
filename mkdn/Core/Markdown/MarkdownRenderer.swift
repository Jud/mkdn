import Markdown
import SwiftUI

/// Parses Markdown text and produces a native SwiftUI view hierarchy.
///
/// Uses apple/swift-markdown for parsing and a custom `MarkdownVisitor`
/// for rendering each node type as SwiftUI views.
enum MarkdownRenderer {
    /// Parse raw Markdown text into a structured document.
    static func parse(_ text: String) -> Document {
        Document(parsing: text)
    }

    /// Render a Markdown document into an array of indexed block-level elements.
    static func render(
        document: Document,
        theme: AppTheme
    ) -> [IndexedBlock] {
        let visitor = MarkdownVisitor(theme: theme)
        let blocks = visitor.visitDocument(document)
        return blocks.enumerated().map { IndexedBlock(index: $0.offset, block: $0.element) }
    }

    /// Convenience: parse and render in a single call.
    static func render(
        text: String,
        theme: AppTheme
    ) -> [IndexedBlock] {
        let document = parse(text)
        return render(document: document, theme: theme)
    }
}
