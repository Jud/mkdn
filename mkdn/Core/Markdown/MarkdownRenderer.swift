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

    /// Render a Markdown document into an array of block-level elements.
    static func render(
        document: Document,
        theme: AppTheme
    ) -> [MarkdownBlock] {
        let visitor = MarkdownVisitor(theme: theme)
        return visitor.visitDocument(document)
    }

    /// Convenience: parse and render in a single call.
    static func render(
        text: String,
        theme: AppTheme
    ) -> [MarkdownBlock] {
        let document = parse(text)
        return render(document: document, theme: theme)
    }
}
