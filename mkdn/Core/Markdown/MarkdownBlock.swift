import SwiftUI

/// Represents a rendered Markdown block element.
enum MarkdownBlock: Identifiable {
    case heading(level: Int, text: AttributedString)
    case paragraph(text: AttributedString)
    case codeBlock(language: String?, code: String)
    case mermaidBlock(code: String)
    case blockquote(blocks: [MarkdownBlock])
    case orderedList(items: [ListItem])
    case unorderedList(items: [ListItem])
    case thematicBreak
    case table(headers: [String], rows: [[String]])

    var id: String {
        switch self {
        case let .heading(level, text):
            "heading-\(level)-\(text.hashValue)"
        case let .paragraph(text):
            "paragraph-\(text.hashValue)"
        case let .codeBlock(language, code):
            "code-\(language ?? "none")-\(code.hashValue)"
        case let .mermaidBlock(code):
            "mermaid-\(code.hashValue)"
        case let .blockquote(blocks):
            "blockquote-\(blocks.count)"
        case let .orderedList(items):
            "ol-\(items.count)"
        case let .unorderedList(items):
            "ul-\(items.count)"
        case .thematicBreak:
            "hr-\(UUID().uuidString)"
        case let .table(headers, _):
            "table-\(headers.joined())"
        }
    }
}

/// A list item containing child blocks.
struct ListItem: Identifiable {
    let id = UUID()
    let blocks: [MarkdownBlock]
}
