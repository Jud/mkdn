import Markdown
import SwiftUI

/// Parses Markdown text and produces a native SwiftUI view hierarchy.
///
/// Uses apple/swift-markdown for parsing and a custom `MarkdownVisitor`
/// for rendering each node type as SwiftUI views.
public enum MarkdownRenderer {
    /// Parse options shared by every `Document(parsing:)` call in the app.
    ///
    /// `.disableSmartOpts` turns off swift-markdown's smart-punctuation
    /// substitution (`"` → `“”`, `'` → `’`, `--` → `–`, `...` → `…`), which is on
    /// by default. The comment feature anchors selections by mapping rendered
    /// text verbatim back to source offsets; smart substitution makes the
    /// rendered text differ from source, dropping the source span for any run
    /// that contains a quote/apostrophe/dash/ellipsis and silently making it
    /// uncommentable. Parsing verbatim keeps render and source identical.
    public static let parseOptions: ParseOptions = .disableSmartOpts

    /// Parse raw Markdown text into a structured document.
    public static func parse(_ text: String) -> Document {
        Document(parsing: text, options: parseOptions)
    }

    /// Render a Markdown document into an array of indexed block-level elements.
    /// - Parameter source: the exact text that was parsed. When provided, text
    ///   runs are tagged with `SourceSpanAttribute` for selection-to-source
    ///   mapping; when nil, rendering is unchanged.
    public static func render(
        document: Document,
        theme: AppTheme,
        generation: UInt64 = 0,
        source: String? = nil
    ) -> [IndexedBlock] {
        var visitor = MarkdownVisitor(theme: theme, source: source)
        let blocks = visitor.visitDocument(document)
        return blocks.enumerated().map { offset, element in
            IndexedBlock(index: offset, block: element, generation: generation)
        }
    }

    /// Convenience: parse and render in a single call.
    public static func render(
        text: String,
        theme: AppTheme,
        generation: UInt64 = 0
    ) -> [IndexedBlock] {
        let document = parse(text)
        return render(document: document, theme: theme, generation: generation, source: text)
    }
}
